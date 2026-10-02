import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_chat_viewmodel.dart';

import 'taxi_test_api.dart';

/// 실제 WebSocket 대신 테스트에서 이벤트를 직접 흘려보낸다.
class _FakeRealtime extends TaxiRealtimeService {
  _FakeRealtime() : super(AuthService.unavailable());

  final controller = StreamController<TaxiRealtimeEvent>.broadcast();

  @override
  Stream<TaxiRealtimeEvent> get events => controller.stream;

  final sent = <String>[];

  @override
  Future<void> connect() async {}

  @override
  void sendMessage({
    required String partyId,
    required String clientMessageId,
    required String content,
  }) => sent.add(clientMessageId);

  @override
  Future<void> dispose() async => controller.close();
}

TaxiRealtimeEvent _message(int id) => TaxiRealtimeEvent(
  type: 'message.created',
  partyId: 'party',
  message: TaxiMessage(
    id: id,
    partyId: 'party',
    messageType: 'chat',
    senderLabel: '참여자 1',
    isMine: false,
    content: 'm$id',
    createdAt: DateTime.now(),
  ),
);

void main() {
  testWidgets('연달아 온 메시지의 읽음 처리는 1초 모아 한 번만 보낸다', (tester) async {
    final api = TaxiTestApi();
    final realtime = _FakeRealtime();
    final viewModel = TaxiChatViewModel(
      partyId: 'party',
      readOnlyAt: DateTime.now().add(const Duration(hours: 1)),
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
      initiallyReadOnly: false,
      initiallyExpired: false,
      repository: api.repository,
      realtime: realtime,
    )..onInit();
    await tester.pump();

    for (var id = 1; id <= 3; id++) {
      realtime.controller.add(_message(id));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.markReads, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(api.markReads, 1);
    expect(api.lastMarkedMessageId, 3);

    // 이미 보낸 위치는 다시 보내지 않고, 나갈 때 남은 읽음 처리는 바로 보낸다.
    realtime.controller.add(_message(4));
    await tester.pump();
    viewModel.onClose();
    await tester.pump();
    expect(api.markReads, 2);
    expect(api.lastMarkedMessageId, 4);
  });

  TaxiChatViewModel build(TaxiTestApi api, _FakeRealtime realtime) =>
      TaxiChatViewModel(
        partyId: 'party',
        readOnlyAt: DateTime.now().add(const Duration(hours: 1)),
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
        initiallyReadOnly: false,
        initiallyExpired: false,
        repository: api.repository,
        realtime: realtime,
      )..onInit();

  TaxiRealtimeEvent mine(int id, String content, {String? clientId}) =>
      TaxiRealtimeEvent(
        type: 'message.created',
        partyId: 'party',
        message: TaxiMessage(
          id: id,
          partyId: 'party',
          messageType: 'chat',
          senderLabel: '방장',
          isMine: true,
          content: content,
          createdAt: DateTime.now(),
          clientMessageId: clientId,
        ),
      );

  testWidgets('보낸 메시지는 서버 확인이 오면 전송 중 목록에서 빠진다', (tester) async {
    final realtime = _FakeRealtime();
    final viewModel = build(TaxiTestApi(), realtime);
    await tester.pump();

    expect(viewModel.send(' 안녕하세요 '), isTrue);
    expect(viewModel.pending.single.content, '안녕하세요');
    final clientId = realtime.sent.single;

    realtime.controller.add(mine(10, '안녕하세요', clientId: clientId));
    await tester.pump();
    expect(viewModel.pending, isEmpty);
    expect(viewModel.messages.single.id, 10);

    // 구버전 서버는 식별자를 돌려주지 않아 내용으로 짝짓는다.
    viewModel.send('두 번째');
    realtime.controller.add(mine(11, '두 번째'));
    await tester.pump();
    expect(viewModel.pending, isEmpty);

    viewModel.onClose();
    await tester.pump();
  });

  testWidgets('확인이 없거나 서버가 거부하면 실패로 표시하고 다시 보낼 수 있다', (tester) async {
    final realtime = _FakeRealtime();
    final viewModel = build(TaxiTestApi(), realtime);
    await tester.pump();

    viewModel.send('첫 번째');
    await tester.pump(const Duration(seconds: 11));
    expect(viewModel.pending.single.isFailed, isTrue);

    // 같은 식별자로 다시 보내 서버가 중복을 걸러낼 수 있게 한다.
    final clientId = viewModel.pending.single.clientMessageId;
    viewModel.retryPending(clientId);
    expect(viewModel.pending.single.isFailed, isFalse);
    expect(realtime.sent, [clientId, clientId]);

    realtime.controller.add(
      TaxiRealtimeEvent(
        type: 'error',
        code: 'MESSAGE_RATE_LIMITED',
        errorMessage: '메시지를 너무 빠르게 보내고 있습니다.',
        clientMessageId: clientId,
      ),
    );
    await tester.pump();
    expect(viewModel.pending.single.isFailed, isTrue);
    expect(viewModel.pending.single.error, '메시지를 너무 빠르게 보내고 있습니다.');

    viewModel.discardPending(clientId);
    expect(viewModel.pending, isEmpty);

    viewModel.onClose();
    await tester.pump();
  });

  Map<String, Object?> json(int id) => {
    'id': id,
    'party_id': 'party',
    'message_type': 'chat',
    'sender_label': '참여자 1',
    'is_mine': false,
    'content': 'm$id',
    'created_at': DateTime.now().toUtc().toIso8601String(),
  };

  testWidgets('이전 메시지는 위로 올릴 때 이어서 불러온다', (tester) async {
    final api = TaxiTestApi()
      ..messages = [json(51), json(52)]
      ..messagesNextBeforeId = 51
      ..olderMessages = [json(49), json(50)];
    final viewModel = build(api, _FakeRealtime());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(viewModel.messages.map((item) => item.id), [51, 52]);
    expect(viewModel.hasOlder.value, isTrue);

    await tester.runAsync(viewModel.loadOlder);
    expect(viewModel.messages.map((item) => item.id), [49, 50, 51, 52]);
    expect(viewModel.hasOlder.value, isFalse);

    viewModel.onClose();
    await tester.pump();
  });

  testWidgets('처음 불러오기에 실패하면 다시 시도할 수 있다', (tester) async {
    final api = TaxiTestApi()
      ..messages = [json(1)]
      ..failMessages = true;
    final viewModel = build(api, _FakeRealtime());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(viewModel.loadFailed.value, isTrue);
    expect(viewModel.messages, isEmpty);

    api.failMessages = false;
    await tester.runAsync(viewModel.load);
    expect(viewModel.loadFailed.value, isFalse);
    expect(viewModel.messages.single.id, 1);

    viewModel.onClose();
    await tester.pump();
  });
}
