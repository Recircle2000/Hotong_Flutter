import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/view/taxi_home_view.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_tab_bar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'taxi_test_api.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko'));
  tearDown(() {
    Get.reset();
  });

  Future<void> launch(
    WidgetTester tester,
    TaxiTestApi api, {
    VoidCallback? logout,
    TargetPlatform platform = TargetPlatform.android,
    TaxiHomeViewModel Function(AuthService auth)? viewModelBuilder,
  }) async {
    Get.testMode = true;
    final auth = AuthService.unavailable();
    Get.put<AuthService>(auth);
    final suppliedViewModel = viewModelBuilder?.call(auth);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(platform: platform),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TaxiHomeView(
                    onLogout: () async {
                      logout?.call();
                    },
                    viewModel:
                        suppliedViewModel ??
                        TaxiHomeViewModel(
                          repository: api.repository,
                          realtime: TaxiRealtimeService(auth),
                        ),
                  ),
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

  testWidgets('검색 기본값, 빈 현재팟, 내정보와 로그아웃', (tester) async {
    var loggedOut = false;
    await launch(tester, TaxiTestApi(), logout: () => loggedOut = true);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await tab(tester, '현재팟');
    expect(find.text('모집 중인 팟이 없어요'), findsOneWidget);
    await tab(tester, '내정보');
    expect(find.text('이메일 인증 완료'), findsOneWidget);
    expect(find.text('로그인 정보'), findsNothing);
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('연속 탭 전환은 마지막 선택을 반영하고 탭 바를 유지한다', (tester) async {
    await launch(tester, TaxiTestApi());
    final barElement = tester.element(find.byType(TaxiTabBar));
    final navigationElement = tester.element(find.byType(NavigationBar));
    final select = tester
        .widget<TaxiTabBar>(find.byType(TaxiTabBar))
        .onSelected;

    // No frame/lifecycle round-trip should lock or drop the next selection.
    select(0);
    select(2);
    select(3);
    await tester.pumpAndSettle();

    expect(tester.widget<TaxiTabBar>(find.byType(TaxiTabBar)).index, 3);
    expect(tester.element(find.byType(TaxiTabBar)), same(barElement));
    expect(tester.element(find.byType(NavigationBar)), same(navigationElement));
    expect(find.text('이메일 인증 완료'), findsOneWidget);
    await tab(tester, '팟 검색');
    expect(tester.element(find.byType(NavigationBar)), same(navigationElement));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('생성 입력 유지, 뒤로가기 단계 처리, 성공 후 현재팟 이동', (tester) async {
    final api = TaxiTestApi();
    await launch(tester, api);
    await tab(tester, '팟 생성');
    await tester.tap(find.text('출발 거점'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('아산캠퍼스').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('도착 거점'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('천안아산역').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '정문에서 만나요');
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tab(tester, '팟 검색');
    await tab(tester, '팟 생성');
    expect(find.text('정문에서 만나요'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('출발 거점'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '택시팟 만들기'));
    await tester.pumpAndSettle();
    expect(api.creates, 1);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.text('택시팟 채팅하기'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('택시팟 관리'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('current-party-pane')),
        matching: find.byTooltip('택시팟 관리'),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('기존 팟이 있으면 생성과 다른 팟 참여 차단', (tester) async {
    final api = TaxiTestApi()..activeIds.add('existing');
    await launch(tester, api);
    await tab(tester, '팟 생성');
    expect(find.text('현재팟 보기'), findsOneWidget);
    await tab(tester, '팟 검색');
    await tester.tap(find.text('아산캠퍼스 → 천안아산역').first);
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '현재팟 확인 후 참여할 수 있어요'),
    );
    expect(button.onPressed, isNull);
    expect(api.joins, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('참여 성공 후 현재팟으로 이동', (tester) async {
    final api = TaxiTestApi();
    await launch(tester, api);
    await tester.tap(find.text('아산캠퍼스 → 천안아산역').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('택시팟 참여하기'));
    await tester.pumpAndSettle();
    expect(api.joins, 1);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.text('택시팟 채팅하기'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('조회 실패는 빈 현재팟으로 취급하지 않음, 재시도 복구', (tester) async {
    final api = TaxiTestApi()..fail = true;
    await launch(tester, api);
    await tab(tester, '팟 생성');
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '택시팟 만들기'), findsNothing);
    api.fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('출발 거점'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('다중 팟 기존 계정은 팟을 전환할 수 있고 생성은 차단', (tester) async {
    final api = TaxiTestApi()..activeIds.addAll(['first', 'second']);
    await launch(tester, api);
    await tab(tester, '현재팟');
    expect(find.text('기존 참여 팟 선택'), findsOneWidget);
    expect(find.byKey(const ValueKey('first')), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('아산캠퍼스 → 천안아산역').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('second')), findsOneWidget);
    await tab(tester, '팟 생성');
    expect(find.text('현재팟 보기'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('숨겨진 생성 폼이 검색 화면 뒤로가기를 막지 않음', (tester) async {
    await launch(tester, TaxiTestApi());
    await tab(tester, '팟 생성');
    await tab(tester, '팟 검색');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('택시 열기'), findsOneWidget);
    expect(find.byType(TaxiTabBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('현재팟 경로는 거점과 상세 장소를 중복 없이 보여준다', (tester) async {
    final api = TaxiTestApi()..activeIds.add('existing');
    await launch(tester, api);
    await tab(tester, '현재팟');
    expect(find.text('출발'), findsOneWidget);
    expect(find.text('도착'), findsOneWidget);
    expect(find.text('아산캠퍼스'), findsOneWidget);
    expect(find.text('정문 택시승강장'), findsOneWidget);
    // No destination detail: do not repeat the location as a fallback subtitle.
    expect(find.text('천안아산역'), findsOneWidget);
    expect(find.text('출발 장소'), findsNothing);
    expect(find.text('도착 장소'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('모집 종료 팟은 현재팟의 최근 채팅으로 분리된다', (tester) async {
    final api = TaxiTestApi()..recentChatIds.add('recent');
    await launch(tester, api);
    await tab(tester, '현재팟');
    expect(find.byKey(const ValueKey('current-party-segment')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-chat-segment')), findsOneWidget);
    expect(find.text('모집 중인 팟이 없어요'), findsOneWidget);
    expect(find.textContaining('채팅 가능'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('recent-chat-segment')));
    await tester.pumpAndSettle();

    expect(find.text('모집 중인 팟이 없어요'), findsNothing);
    expect(find.byKey(const ValueKey('recent-chats-pane')), findsOneWidget);
    expect(find.textContaining('채팅 가능'), findsOneWidget);
    expect(find.text('아산캠퍼스 → 천안아산역'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('채팅 실시간 이벤트는 전체 API 재조회 없이 배지를 갱신한다', (tester) async {
    final api = TaxiTestApi()..recentChatIds.add('recent');
    late TaxiHomeViewModel viewModel;
    await launch(
      tester,
      api,
      viewModelBuilder: (auth) => viewModel = TaxiHomeViewModel(
        repository: api.repository,
        realtime: TaxiRealtimeService(auth),
      ),
    );
    api.resetReads();
    final payload = Map<String, dynamic>.from(api.party('recent'))
      ..['unread_count'] = 9
      ..['is_member'] = true;

    viewModel.handleRealtimeEvent(
      TaxiRealtimeEvent(
        type: 'message.created',
        partyId: 'recent',
        party: TaxiPartySummary.fromJson(payload),
        message: TaxiMessage(
          id: 10,
          partyId: 'recent',
          messageType: 'chat',
          senderLabel: '참여자 1',
          isMine: false,
          content: '곳 도착해요',
          createdAt: DateTime.now(),
        ),
      ),
    );
    await tester.pump();

    expect(viewModel.recentChats.single.unreadCount, 9);
    expect(viewModel.totalUnread, 9);
    expect(api.totalReads, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('다크모드 내비게이션과 99+ 배지', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          bottomNavigationBar: TaxiTabBar(
            index: 1,
            onSelected: (_) {},
            unread: 101,
          ),
        ),
      ),
    );
    expect(find.text('99+'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('구형 iOS 폴백과 배지', (tester) async {
    final api = TaxiTestApi()..activeIds.add('existing');
    await launch(tester, api, platform: TargetPlatform.iOS);
    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(
      find.descendant(of: find.byType(TaxiTabBar), matching: find.text('3')),
      findsOneWidget,
    );
    await tab(tester, '현재팟');
    expect(find.text('택시팟 채팅하기'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform 나가기 확인창 닫기는 참여 상태를 유지한다', (tester) async {
      final api = TaxiTestApi()..activeIds.add('existing');
      await launch(tester, api, platform: platform);
      await tab(tester, '현재팟');
      final leave = find.text('택시팟 나가기');
      await tester.ensureVisible(leave);
      await tester.tap(leave);
      await tester.pumpAndSettle();
      expect(
        find.byType(
          platform == TargetPlatform.iOS ? CupertinoAlertDialog : AlertDialog,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(api.activeIds, contains('existing'));
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
