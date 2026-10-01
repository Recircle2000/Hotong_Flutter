import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/services/taxi_push_messaging.dart';
import 'package:hsro/features/taxi/services/taxi_push_service.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/view/taxi_chat_view.dart';
import 'package:hsro/features/taxi/view/taxi_home_view.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_tab_bar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'taxi_test_api.dart';

class FakePushMessaging implements TaxiPushMessaging {
  bool granted = true;
  String? token = 'device-token';
  int permissionRequests = 0;
  TaxiPushMessage? initial;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<TaxiPushMessage>.broadcast();
  final opened = StreamController<TaxiPushMessage>.broadcast();

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<TaxiPushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<TaxiPushMessage> get onOpened => opened.stream;

  @override
  Future<TaxiPushMessage?> initialMessage() async => initial;
}

void main() {
  setUpAll(() => initializeDateFormatting('ko'));
  tearDown(Get.reset);

  late TaxiTestApi api;
  late FakePushMessaging messaging;
  late int taxiOpens;
  late List<TaxiPushMessage> banners;
  late List<VoidCallback> bannerTaps;

  Future<TaxiPushService> service({
    Map<String, Object> stored = const {},
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    api = TaxiTestApi();
    messaging = FakePushMessaging();
    taxiOpens = 0;
    banners = [];
    bannerTaps = [];
    final push = TaxiPushService(
      messaging: messaging,
      repository: api.repository,
      preferences: await SharedPreferences.getInstance(),
      openTaxi: () => taxiOpens++,
      showBanner: (message, onTap) {
        banners.add(message);
        bannerTaps.add(onTap);
      },
    );
    return Get.put<TaxiPushService>(await push.init());
  }

  Future<void> launch(
    WidgetTester tester, {
    Future<void> Function()? onLogout,
  }) async {
    Get.testMode = true;
    final auth = AuthService.unavailable();
    Get.put<AuthService>(auth);
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TaxiHomeView(
                    onLogout: onLogout ?? () async {},
                    viewModel: TaxiHomeViewModel(
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

  test('알림을 켜면 권한을 요청하고 기기를 등록하며, 끄면 지운다', () async {
    final push = await service();
    expect(push.enabled.value, isFalse);
    expect(push.shouldAsk, isTrue);

    expect(await push.enable(), isTrue);
    expect(messaging.permissionRequests, 1);
    expect(push.enabled.value, isTrue);
    expect(push.shouldAsk, isFalse);
    expect(api.pushTokens, {'device-token': 'android'});

    await push.disable();
    expect(push.enabled.value, isFalse);
    expect(api.pushTokens, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('taxi_push_enabled'), isFalse);
  });

  test('권한이 거부되면 꺼진 채로 두고 기기를 등록하지 않는다', () async {
    final push = await service();
    messaging.granted = false;

    expect(await push.enable(), isFalse);

    expect(push.enabled.value, isFalse);
    expect(api.pushCalls, isEmpty);
  });

  test('꺼져 있으면 등록하지 않고, 토큰이 바뀌면 새 토큰을 등록한다', () async {
    final push = await service();
    await push.sync();
    expect(api.pushCalls, isEmpty);

    await push.enable();
    messaging.token = 'rotated-token';
    messaging.refresh.add('rotated-token');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(api.pushTokens.keys, contains('rotated-token'));
  });

  test('로그아웃용 해제는 서버에서만 지우고 설정은 유지한다', () async {
    final push = await service(stored: {'taxi_push_enabled': true});
    await push.sync();
    expect(api.pushTokens, isNotEmpty);

    await push.unregister();

    expect(api.pushTokens, isEmpty);
    expect(push.enabled.value, isTrue);
  });

  test('서버 연결이 안 돼도 예외 없이 넘어간다', () async {
    final push = await service(stored: {'taxi_push_enabled': true});
    api.fail = true;

    await push.sync();
    await push.unregister();

    expect(api.pushTokens, isEmpty);
  });

  test('알림을 누르면 택시 화면을 열고, 보고 있는 채팅방 알림은 무시한다', () async {
    final push = await service();
    const message = TaxiPushMessage(
      partyId: 'party-1',
      title: '아산캠퍼스 → 천안아산역',
      body: '방장: 곧 도착해요',
    );

    messaging.opened.add(message);
    await Future<void>.delayed(Duration.zero);
    expect(push.pendingPartyId.value, 'party-1');
    expect(taxiOpens, 1);
    expect(push.takePending(), 'party-1');
    expect(push.takePending(), isNull);

    // 택시 화면이 이미 열려 있으면 새로 열지 않는다.
    push.attachHome();
    messaging.opened.add(message);
    await Future<void>.delayed(Duration.zero);
    expect(taxiOpens, 1);
    expect(push.takePending(), 'party-1');

    messaging.foreground.add(message);
    await Future<void>.delayed(Duration.zero);
    expect(banners.single.body, '방장: 곧 도착해요');
    bannerTaps.single();
    expect(push.takePending(), 'party-1');

    push.activeChatPartyId = 'party-1';
    messaging.foreground.add(message);
    messaging.opened.add(message);
    await Future<void>.delayed(Duration.zero);
    expect(banners, hasLength(1));
    expect(push.pendingPartyId.value, isNull);
  });

  testWidgets('꺼진 앱을 알림으로 켜면 택시 화면에서 그 채팅방이 열린다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    api = TaxiTestApi()..activeIds.add('party-1');
    messaging = FakePushMessaging()
      ..initial = const TaxiPushMessage(partyId: 'party-1');
    taxiOpens = 0;
    final push = TaxiPushService(
      messaging: messaging,
      repository: api.repository,
      preferences: await SharedPreferences.getInstance(),
      openTaxi: () => taxiOpens++,
    );
    Get.put<TaxiPushService>(await push.init());
    expect(push.pendingPartyId.value, 'party-1');

    await launch(tester);

    expect(taxiOpens, 1);
    expect(find.byType(TaxiChatView), findsOneWidget);
    expect(push.activeChatPartyId, 'party-1');
    expect(push.pendingPartyId.value, isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(push.activeChatPartyId, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('처음 참여하면 알림을 받을지 한 번만 묻는다', (tester) async {
    final push = await service();
    await launch(tester);

    await tester.tap(find.text('아산캠퍼스 → 천안아산역').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('택시팟 참여하기'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('알림을 받을까요?'), findsOneWidget);
    await tester.tap(find.text('알림 받기'));
    await tester.pumpAndSettle();

    expect(messaging.permissionRequests, 1);
    expect(push.enabled.value, isTrue);
    expect(api.pushTokens, {'device-token': 'android'});
    expect(push.shouldAsk, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('내정보 스위치로 알림을 끄고, 권한이 없으면 설정 안내를 보여준다', (tester) async {
    final push = await service(stored: {'taxi_push_enabled': true});
    await launch(tester);
    expect(api.pushTokens, isNotEmpty);
    await tab(tester, '내정보');

    final toggle = find.byKey(const ValueKey('taxi-push-switch'));
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(push.enabled.value, isFalse);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(api.pushTokens, isEmpty);

    messaging.granted = false;
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(push.enabled.value, isFalse);
    expect(find.text('기기 설정에서 알림을 허용해주세요.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('로그아웃하면 먼저 이 기기를 알림 대상에서 뺀다', (tester) async {
    await service(stored: {'taxi_push_enabled': true});
    final order = <String>[];
    await launch(
      tester,
      onLogout: () async => order.add('logout:${api.pushTokens.length}'),
    );
    await tab(tester, '내정보');

    await tester.ensureVisible(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃할까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await tester.pumpAndSettle();

    expect(order, ['logout:0']);
    expect(api.pushCalls.last, 'remove:device-token');
    await tester.pumpWidget(const SizedBox());
  });
}
