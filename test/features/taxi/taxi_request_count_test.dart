import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/view/taxi_chat_view.dart';
import 'package:hsro/features/taxi/view/taxi_home_view.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_tab_bar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'taxi_test_api.dart';

/// 화면 동작마다 서버로 나가는 요청 수를 고정해 둔다.
/// 요청이 늘어나는 변경은 이 테스트에서 먼저 드러난다.
void main() {
  setUpAll(() => initializeDateFormatting('ko'));
  tearDown(Get.reset);

  late TaxiTestApi api;
  late FakeTaxiRealtime realtime;
  late TaxiHomeViewModel viewModel;

  Future<void> launch(WidgetTester tester, {bool member = true}) async {
    Get.testMode = true;
    Get.put<AuthService>(AuthService.unavailable());
    api = TaxiTestApi();
    if (member) api.activeIds.add('existing');
    api.messages = [
      {
        'id': 1,
        'party_id': 'existing',
        'message_type': 'chat',
        'sender_label': '방장',
        'is_mine': false,
        'content': '정문 앞에서 봬요',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    ];
    realtime = FakeTaxiRealtime();
    viewModel = TaxiHomeViewModel(
      repository: api.repository,
      realtime: realtime,
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      TaxiHomeView(onLogout: () async {}, viewModel: viewModel),
                ),
              ),
              child: const Text('택시 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('택시 열기'));
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(
      find
          .descendant(of: find.byType(TaxiTabBar), matching: find.text(name))
          .last,
    );
    await tester.pumpAndSettle();
  }

  TaxiPartySummary summary(String id, {int unread = 3, int members = 2}) =>
      TaxiPartySummary.fromJson(
        Map<String, dynamic>.from(api.party(id))
          ..['unread_count'] = unread
          ..['current_members'] = members,
      );

  TaxiRealtimeEvent incoming(int id, {bool mine = false, int unread = 4}) =>
      TaxiRealtimeEvent(
        type: 'message.created',
        partyId: 'existing',
        party: summary('existing', unread: unread),
        message: TaxiMessage(
          id: id,
          partyId: 'existing',
          messageType: 'chat',
          senderLabel: mine ? '참여자 1' : '방장',
          isMine: mine,
          content: 'm$id',
          createdAt: DateTime.now(),
        ),
      );

  Future<void> openChat(WidgetTester tester) async {
    await tester.tap(find.text('채팅하기'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(TaxiChatView), findsOneWidget);
  }

  testWidgets('택시 화면 진입과 현재팟 탭 열기', (tester) async {
    await launch(tester);
    await tab(tester, '현재팟');

    // 목록, 이용 제한, 현재팟 상세까지 묶음 조회 하나로 받는다.
    expect(api.requests, ['GET /api/taxi/home']);
    expect(
      find.text('2 / 4명', findRichText: true, skipOffstage: false),
      findsOneWidget,
    );
    expect(viewModel.userKey, 'a1b2c3');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('날짜를 바꾸면 검색 목록만 다시 받는다', (tester) async {
    await launch(tester);
    api.resetReads();

    viewModel.changeDate(1);
    await tester.pumpAndSettle();

    expect(api.requests, ['GET /api/taxi/parties']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('검색에서 팟 상세를 보고 돌아오기', (tester) async {
    await launch(tester, member: false);
    api.resetReads();

    await tester.tap(find.text('아산캠퍼스 → 천안아산역').first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(api.requests, ['GET /api/taxi/parties/search-party']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('현재팟에서 채팅을 열고 돌아오기', (tester) async {
    await launch(tester);
    await tab(tester, '현재팟');
    api.resetReads();

    await openChat(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(api.requests, [
      'GET /api/taxi/parties/existing/messages',
      'PUT /api/taxi/parties/existing/messages/read',
    ]);
    // 읽고 나오면 다시 조회하지 않고 배지만 지운다.
    expect(viewModel.totalUnread, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('채팅 밖에서 메시지를 받으면 다시 조회하지 않는다', (tester) async {
    await launch(tester);
    await tab(tester, '현재팟');
    api.resetReads();

    realtime.controller.add(incoming(2));
    await tester.pumpAndSettle();

    expect(api.requests, isEmpty);
    expect(viewModel.totalUnread, 4);
    expect(find.text('4'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('채팅 안에서 메시지를 받고 보낼 때', (tester) async {
    await launch(tester);
    await tab(tester, '현재팟');
    await openChat(tester);
    api.resetReads();

    realtime.controller.add(incoming(2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final received = api.requests.length;

    api.resetReads();
    realtime.controller.add(incoming(3, mine: true, unread: 0));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(received, 1);
    // 내가 보낸 메시지는 서버가 읽음 처리하므로 따로 보내지 않는다.
    expect(api.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('팟 변경 알림을 받을 때', (tester) async {
    await launch(tester);
    await tab(tester, '현재팟');
    api.resetReads();

    // 서버는 팟 변경 알림에 상세를 실어 보낸다.
    api.currentMembers = 3;
    realtime.controller.add(
      TaxiRealtimeEvent.fromJson({
        'type': 'party.updated',
        'party_id': 'existing',
        'party': api.party('existing'),
      }),
    );
    await tester.pumpAndSettle();

    expect(api.requests, isEmpty);
    expect(
      find.text('3 / 4명', findRichText: true, skipOffstage: false),
      findsOneWidget,
    );

    // 상세가 없는 알림(구버전 서버)은 한 번만 다시 조회한다.
    api.currentMembers = 4;
    realtime.controller.add(
      TaxiRealtimeEvent(
        type: 'party.updated',
        partyId: 'existing',
        party: summary('existing', members: 4),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.requests, ['GET /api/taxi/parties/existing']);
    expect(
      find.text('4 / 4명', findRichText: true, skipOffstage: false),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('최근 채팅을 열고 돌아오기', (tester) async {
    await launch(tester, member: false);
    api.recentChatIds.add('recent');
    api.activeIds.add('recent');
    await viewModel.refreshAll();
    await tab(tester, '현재팟');
    await tester.tap(find.byKey(const ValueKey('recent-chat-segment')));
    await tester.pumpAndSettle();
    api.resetReads();

    await tester.tap(find.text('아산캠퍼스 → 천안아산역').first);
    await tester.pumpAndSettle();
    expect(find.byType(TaxiChatView), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(api.requests, [
      'GET /api/taxi/parties/recent/messages',
      'PUT /api/taxi/parties/recent/messages/read',
    ]);
    expect(viewModel.totalUnread, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('놓친 변경은 전체 새로고침으로 따라잡는다', (tester) async {
    await launch(tester);
    await tab(tester, '현재팟');
    api.resetReads();

    // 실시간 연결이 끊긴 사이 누군가 참여했다고 가정한다.
    api.currentMembers = 3;
    await viewModel.refreshAll();
    await tester.pumpAndSettle();

    // 묶음 조회에 상세가 들어 있어 따로 다시 받지 않는다.
    expect(
      find.text('3 / 4명', findRichText: true, skipOffstage: false),
      findsOneWidget,
    );
    expect(api.requests, ['GET /api/taxi/home']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('필터 조회가 실패하면 오류를 보여주고 다시 바꾸면 전체를 복구한다', (tester) async {
    await launch(tester);
    api.resetReads();

    api.fail = true;
    viewModel.changeDate(1);
    await tester.pumpAndSettle();
    expect(viewModel.errorMessage.value, isNotEmpty);
    expect(viewModel.isSearching.value, isFalse);

    api.fail = false;
    api.resetReads();
    viewModel.changeDate(-1);
    await tester.pumpAndSettle();
    expect(viewModel.errorMessage.value, isEmpty);
    expect(api.requests, ['GET /api/taxi/home']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('앱으로 돌아오거나 참여 직전 확인은 묶음 조회 하나다', (tester) async {
    await launch(tester, member: false);
    api.resetReads();

    viewModel.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(api.requests, ['GET /api/taxi/home']);

    api.resetReads();
    await tester.tap(find.text('아산캠퍼스 → 천안아산역').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('택시팟 참여하기'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(api.requests, [
      'GET /api/taxi/parties/search-party',
      'GET /api/taxi/home',
      'POST /api/taxi/parties/search-party/join',
    ]);
    await tester.pumpWidget(const SizedBox());
  });
}
