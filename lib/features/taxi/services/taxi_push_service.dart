import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:hsro/core/network/authenticated_api_client.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/core/utils/env_config.dart';

/// 푸시 데이터에서 열어야 할 택시팟 id를 꺼낸다. 택시 채팅 알림이 아니면 null.
String? taxiPartyIdFromPushData(Map<String, dynamic> data) {
  if (data['type'] != 'taxi_message') return null;
  final partyId = data['party_id'];
  return partyId is String && partyId.isNotEmpty ? partyId : null;
}

/// 테스트에서 Firebase 없이 바꿔 끼울 수 있도록 FCM 호출을 감싼다.
abstract class TaxiPushMessaging {
  Future<bool> requestPermission();
  Future<bool> hasPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<Map<String, dynamic>> get onNotificationOpened;
  Future<Map<String, dynamic>?> initialNotificationData();
}

class FirebaseTaxiPushMessaging implements TaxiPushMessaging {
  FirebaseTaxiPushMessaging(this._messaging);

  final FirebaseMessaging _messaging;

  static bool _isAllowed(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  @override
  Future<bool> requestPermission() async =>
      _isAllowed((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<bool> hasPermission() async => _isAllowed(
    (await _messaging.getNotificationSettings()).authorizationStatus,
  );

  @override
  Future<String?> getToken() async {
    if (Platform.isIOS) {
      // iOS는 APNs 토큰이 먼저 와야 FCM 토큰을 받을 수 있다.
      var apnsToken = await _messaging.getAPNSToken();
      for (var attempt = 0; apnsToken == null && attempt < 5; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        apnsToken = await _messaging.getAPNSToken();
      }
      if (apnsToken == null) return null;
    }
    return _messaging.getToken();
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<Map<String, dynamic>> get onNotificationOpened =>
      FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);

  @override
  Future<Map<String, dynamic>?> initialNotificationData() async =>
      (await _messaging.getInitialMessage())?.data;
}

/// 택시팟 채팅 푸시 알림.
///
/// 로그인한 기기의 FCM 토큰을 서버에 등록하고, 알림을 누르면 해당 팟 채팅을 연다.
/// 앱이 화면에 떠 있을 때는 실시간 채팅이 이미 보이므로 알림을 따로 띄우지 않는다.
class TaxiPushService extends GetxService {
  TaxiPushService({
    required AuthService authService,
    TaxiPushMessaging? messaging,
    http.Client? client,
    String? baseUrl,
    String? platform,
    void Function()? openTaxiHome,
  }) : _authService = authService,
       _messaging = messaging,
       _client = client ?? AuthenticatedApiClient(authService: authService),
       _baseUrl = (baseUrl ?? EnvConfig.baseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       ),
       _platform = platform ?? (Platform.isIOS ? 'ios' : 'android'),
       _openTaxiHome = openTaxiHome;

  final AuthService _authService;
  final http.Client _client;
  final String _baseUrl;
  final String _platform;
  final void Function()? _openTaxiHome;
  TaxiPushMessaging? _messaging;

  /// 알림을 눌러 열어야 하는 채팅. 택시 화면이 꺼내 쓰고 비운다.
  final pendingChatPartyId = RxnString();

  final _subscriptions = <StreamSubscription<dynamic>>[];
  Worker? _sessionWorker;
  int _attachedHomeViews = 0;
  String? _registeredToken;
  String? _registeredUserId;
  Future<void> _registration = Future.value();

  bool get isEnabled => _messaging != null;

  Future<TaxiPushService> init() async {
    if (_messaging == null) {
      final options = EnvConfig.firebaseOptions;
      if (options == null || !(Platform.isAndroid || Platform.isIOS)) {
        return this;
      }
      try {
        await Firebase.initializeApp(options: options);
        _messaging = FirebaseTaxiPushMessaging(FirebaseMessaging.instance);
      } catch (_) {
        return this;
      }
    }
    final messaging = _messaging!;
    _subscriptions
      ..add(messaging.onTokenRefresh.listen((token) => _register(token)))
      ..add(messaging.onNotificationOpened.listen(_handleOpened));
    _sessionWorker = ever(_authService.sessionState, (_) => syncRegistration());
    unawaited(syncRegistration());
    return this;
  }

  /// 앱이 꺼져 있을 때 알림을 눌러 실행됐으면 그 채팅을 연다. 첫 화면을 그린 뒤 부른다.
  Future<void> handleInitialNotification() async {
    final data = await _messaging?.initialNotificationData();
    if (data != null) _handleOpened(data);
  }

  /// 택시 화면에 들어올 때 부른다. 처음이면 알림 권한을 묻는다.
  Future<void> requestPermissionAndRegister() async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      if (await messaging.requestPermission()) {
        await _registerCurrentToken();
      }
    } catch (_) {}
  }

  /// 로그인 상태가 바뀌면 이미 허용된 권한으로 토큰만 다시 등록한다.
  Future<void> syncRegistration() async {
    final messaging = _messaging;
    if (messaging == null ||
        _authService.sessionState.value != AppAuthSessionState.signedIn) {
      return;
    }
    try {
      if (await messaging.hasPermission()) {
        await _registerCurrentToken();
      }
    } catch (_) {}
  }

  /// 로그아웃 직전에 불러 이 기기로 다른 사람의 채팅 알림이 오지 않게 한다.
  Future<void> unregister() async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      final token = _registeredToken ?? await messaging.getToken();
      if (token == null) return;
      await _client.delete(
        Uri.parse('$_baseUrl/api/push/devices'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
    } catch (_) {
      // 지우지 못해도 다음 로그인 계정이 같은 토큰을 등록하면 서버에서 주인이 바뀐다.
    } finally {
      _registeredToken = null;
      _registeredUserId = null;
    }
  }

  void attachTaxiHome() => _attachedHomeViews++;

  void detachTaxiHome() {
    if (_attachedHomeViews > 0) _attachedHomeViews--;
  }

  String? takePendingChatPartyId() {
    final partyId = pendingChatPartyId.value;
    pendingChatPartyId.value = null;
    return partyId;
  }

  void _handleOpened(Map<String, dynamic> data) {
    final partyId = taxiPartyIdFromPushData(data);
    if (partyId == null) return;
    pendingChatPartyId.value = partyId;
    // 택시 화면이 열려 있으면 그 화면이 채팅을 열고, 아니면 로그인 확인부터 거쳐 들어간다.
    if (_attachedHomeViews == 0) _openTaxiHome?.call();
  }

  Future<void> _registerCurrentToken() async {
    final token = await _messaging?.getToken();
    if (token != null) await _register(token);
  }

  // 시작·로그인·토큰 갱신이 겹쳐도 같은 토큰을 두 번 보내지 않도록 차례로 처리한다.
  Future<void> _register(String token) =>
      _registration = _registration.then((_) => _registerNow(token));

  Future<void> _registerNow(String token) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;
    if (token == _registeredToken && userId == _registeredUserId) return;
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/api/push/devices'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'platform': _platform}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _registeredToken = token;
        _registeredUserId = userId;
      }
    } catch (_) {}
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.onClose();
  }
}
