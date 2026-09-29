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

  @override
  Future<void> connect() async {}

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
}
