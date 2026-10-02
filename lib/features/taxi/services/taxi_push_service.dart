import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_push_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 택시팟 푸시 알림. 권한과 기기 토큰 등록, 알림을 눌렀을 때 열 채팅방을 관리한다.
class TaxiPushService extends GetxService {
  TaxiPushService({
    required TaxiPushMessaging messaging,
    required TaxiRepository repository,
    required SharedPreferences preferences,
    required this.openTaxi,
    this.showBanner,
  }) : _messaging = messaging,
       _repository = repository,
       _preferences = preferences;

  static const _enabledKey = 'taxi_push_enabled';
  static const _askedKey = 'taxi_push_asked';

  final TaxiPushMessaging _messaging;
  final TaxiRepository _repository;
  final SharedPreferences _preferences;

  /// 택시 화면이 열려 있지 않을 때 알림을 누르면 택시 화면을 연다.
  final VoidCallback openTaxi;

  /// 앱을 보고 있을 때 도착한 알림을 앱 안에서 보여준다.
  final void Function(TaxiPushMessage message, VoidCallback onTap)? showBanner;

  /// 내정보의 알림 스위치.
  final enabled = false.obs;

  /// 알림을 눌러서 열어야 하는 채팅방. 택시 홈 화면이 가져가서 연다.
  final pendingPartyId = RxnString();

  /// 지금 보고 있는 채팅방. 이 방의 알림은 앱 안에서 다시 띄우지 않는다.
  String? activeChatPartyId;

  final _subscriptions = <StreamSubscription<dynamic>>[];
  int _homeCount = 0;
  String? _registeredToken;

  /// 처음 팟을 만들거나 참여했을 때 한 번만 권한을 묻는다.
  bool get shouldAsk => !(_preferences.getBool(_askedKey) ?? false);

  Future<TaxiPushService> init() async {
    enabled.value = _preferences.getBool(_enabledKey) ?? false;
    _subscriptions.addAll([
      _messaging.onTokenRefresh.listen((_) => unawaited(sync())),
      _messaging.onOpened.listen((message) => _open(message.partyId)),
      _messaging.onForegroundMessage.listen(_handleForeground),
    ]);
    try {
      final initial = await _messaging.initialMessage();
      if (initial != null) {
        pendingPartyId.value = initial.partyId;
        // 첫 화면이 그려진 뒤에 택시 화면을 연다.
        WidgetsBinding.instance.addPostFrameCallback((_) => openTaxi());
      }
    } catch (_) {}
    return this;
  }

  @override
  void onClose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.onClose();
  }

  void attachHome() => _homeCount++;

  void detachHome() => _homeCount--;

  /// 열어야 할 채팅방을 꺼내고 비운다.
  String? takePending() {
    final partyId = pendingPartyId.value;
    pendingPartyId.value = null;
    return partyId;
  }

  void markAsked() => unawaited(_preferences.setBool(_askedKey, true));

  /// 알림을 켠다. OS 권한이 거부되면 false를 돌려주고 꺼진 상태로 둔다.
  Future<bool> enable() async {
    markAsked();
    var granted = false;
    try {
      granted = await _messaging.requestPermission();
    } catch (_) {}
    if (!granted) return false;
    enabled.value = true;
    await _preferences.setBool(_enabledKey, true);
    await sync();
    return true;
  }

  /// 알림을 끄고 서버에서 이 기기를 지운다.
  Future<void> disable() async {
    enabled.value = false;
    await _preferences.setBool(_enabledKey, false);
    await unregister();
  }

  /// 켜져 있으면 이 기기를 현재 계정에 등록한다. 택시 화면에 들어올 때마다 부른다.
  Future<void> sync() async {
    if (!enabled.value) return;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _repository.registerPushToken(
        token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      );
      _registeredToken = token;
    } catch (_) {
      // 알림 등록 실패가 택시 화면 이용을 막지 않는다. 다음 진입 때 다시 시도한다.
    }
  }

  /// 로그아웃·탈퇴 전에 서버에서 이 기기를 지운다. 스위치 설정은 그대로 둔다.
  Future<void> unregister() async {
    try {
      final token = _registeredToken ?? await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _repository.removePushToken(token);
      _registeredToken = null;
    } catch (_) {}
  }

  void _handleForeground(TaxiPushMessage message) {
    if (message.partyId == activeChatPartyId) return;
    showBanner?.call(message, () => _open(message.partyId));
  }

  void _open(String partyId) {
    if (partyId == activeChatPartyId) return;
    pendingPartyId.value = partyId;
    if (_homeCount == 0) openTaxi();
  }
}
