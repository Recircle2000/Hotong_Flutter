import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/services/taxi_push_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeMessaging implements TaxiPushMessaging {
  bool permitted = false;
  bool grantOnRequest = true;
  String? token = 'token-1';
  final tokenRefresh = StreamController<String>.broadcast();
  final opened = StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic>? initialData;

  @override
  Future<bool> requestPermission() async => permitted = grantOnRequest;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Stream<Map<String, dynamic>> get onNotificationOpened => opened.stream;

  @override
  Future<Map<String, dynamic>?> initialNotificationData() async => initialData;
}

AuthService _signedIn(String userId) {
  final auth = AuthService.unavailable();
  auth.currentSession.value = Session(
    accessToken: 'access',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-01T00:00:00Z',
    ),
  );
  auth.sessionState.value = AppAuthSessionState.signedIn;
  return auth;
}

void main() {
  late List<http.Request> requests;
  late MockClient client;
  late _FakeMessaging messaging;
  var openedTaxiHome = 0;

  TaxiPushService service(AuthService auth) => TaxiPushService(
    authService: auth,
    messaging: messaging,
    client: client,
    baseUrl: 'http://test',
    platform: 'android',
    openTaxiHome: () => openedTaxiHome++,
  );

  setUp(() {
    requests = [];
    openedTaxiHome = 0;
    messaging = _FakeMessaging();
    client = MockClient((request) async {
      requests.add(request);
      return http.Response('', 204);
    });
  });

  test('택시 채팅 알림 데이터에서만 팟 id를 꺼낸다', () {
    expect(
      taxiPartyIdFromPushData({'type': 'taxi_message', 'party_id': 'p1'}),
      'p1',
    );
    expect(taxiPartyIdFromPushData({'type': 'notice', 'party_id': 'p1'}), null);
    expect(taxiPartyIdFromPushData({'type': 'taxi_message'}), null);
  });

  test('이미 권한이 있으면 로그인 상태에서 토큰을 한 번만 등록한다', () async {
    messaging.permitted = true;
    final push = await service(_signedIn('user-1')).init();
    await push.syncRegistration();
    await push.syncRegistration();

    expect(requests, hasLength(1));
    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/api/push/devices');
    expect(jsonDecode(requests.single.body), {
      'token': 'token-1',
      'platform': 'android',
    });
  });

  test('권한이 없으면 택시 화면에서 권한을 받은 뒤 등록한다', () async {
    final push = await service(_signedIn('user-1')).init();
    await push.syncRegistration();
    expect(requests, isEmpty);

    await push.requestPermissionAndRegister();
    expect(requests.single.method, 'PUT');
  });

  test('거절하면 등록하지 않는다', () async {
    messaging.grantOnRequest = false;
    final push = await service(_signedIn('user-1')).init();
    await push.requestPermissionAndRegister();
    expect(requests, isEmpty);
  });

  test('로그인하지 않았으면 등록하지 않는다', () async {
    messaging.permitted = true;
    final push = await service(AuthService.unavailable()).init();
    await push.syncRegistration();
    await push.requestPermissionAndRegister();
    expect(requests, isEmpty);
  });

  test('토큰이 바뀌면 새 토큰을 등록한다', () async {
    messaging.permitted = true;
    final push = await service(_signedIn('user-1')).init();
    await push.syncRegistration();
    messaging.tokenRefresh.add('token-2');
    await pumpEventQueue();

    expect(requests, hasLength(2));
    expect(jsonDecode(requests.last.body)['token'], 'token-2');
  });

  test('로그아웃 전에 등록한 토큰을 지운다', () async {
    messaging.permitted = true;
    final push = await service(_signedIn('user-1')).init();
    await push.syncRegistration();
    await push.unregister();

    expect(requests.last.method, 'DELETE');
    expect(jsonDecode(requests.last.body), {'token': 'token-1'});
  });

  test('알림을 누르면 택시 화면이 없을 때만 택시 화면을 연다', () async {
    final push = await service(_signedIn('user-1')).init();

    messaging.opened.add({'type': 'taxi_message', 'party_id': 'p1'});
    await pumpEventQueue();
    expect(openedTaxiHome, 1);
    expect(push.takePendingChatPartyId(), 'p1');
    expect(push.pendingChatPartyId.value, isNull);

    push.attachTaxiHome();
    messaging.opened.add({'type': 'taxi_message', 'party_id': 'p2'});
    await pumpEventQueue();
    expect(openedTaxiHome, 1);
    expect(push.pendingChatPartyId.value, 'p2');
  });

  test('앱을 실행한 알림도 같은 채팅으로 이어진다', () async {
    messaging.initialData = {'type': 'taxi_message', 'party_id': 'p3'};
    final push = await service(_signedIn('user-1')).init();
    await push.handleInitialNotification();
    expect(push.pendingChatPartyId.value, 'p3');
    expect(openedTaxiHome, 1);
  });
}
