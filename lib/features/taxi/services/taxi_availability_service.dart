import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:hsro/core/network/authenticated_api_client.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/core/services/preferences_service.dart';
import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';

/// 서버의 택시 서비스 운영 스위치를 읽어 홈 메뉴에 택시를 보여줄지 정한다.
///
/// 운영을 멈춰도 진행 중인 팟이나 아직 대화할 수 있는 채팅이 있는 사용자는
/// 약속을 마칠 수 있도록 택시 메뉴를 계속 보여준다.
class TaxiAvailabilityService extends GetxService with WidgetsBindingObserver {
  TaxiAvailabilityService({
    required AuthService authService,
    http.Client? client,
    PreferencesService? preferences,
    String? baseUrl,
  }) : _authService = authService,
       _client = client ?? http.Client(),
       _preferences = preferences ?? PreferencesService(),
       _baseUrl = baseUrl;

  static const _enabledCacheKey = 'taxi_service_enabled';

  final AuthService _authService;
  final http.Client _client;
  final PreferencesService _preferences;
  final String? _baseUrl;

  /// 서버 스위치 값. 마지막으로 받은 값을 기기에 저장해 두고, 처음 설치 후
  /// 서버에 닿지 못하면 숨긴 상태로 시작한다.
  final taxiEnabled = false.obs;

  /// 서비스가 꺼져 있어도 진행 중인 팟이나 대화 가능한 채팅이 있으면 true.
  final hasOngoingParty = false.obs;

  Future<void>? _refreshInFlight;

  bool get showTaxiMenu => taxiEnabled.value || hasOngoingParty.value;

  Future<TaxiAvailabilityService> init() async {
    taxiEnabled.value = await _preferences.getBoolOrDefault(
      _enabledCacheKey,
      false,
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
    return this;
  }

  /// 앱 시작, 복귀, 택시 화면에서 돌아올 때 호출한다. 동시에 여러 번 불려도
  /// 요청은 하나로 합친다.
  Future<void> refresh() => _refreshInFlight ??= _refresh().whenComplete(
    () => _refreshInFlight = null,
  );

  Future<void> _refresh() async {
    await _fetchSwitch();
    if (taxiEnabled.value) {
      hasOngoingParty.value = false;
    } else {
      await _checkOngoingParty();
    }
  }

  Future<void> _fetchSwitch() async {
    try {
      final baseUrl = (_baseUrl ?? EnvConfig.baseUrl).replaceFirst(
        RegExp(r'/$'),
        '',
      );
      final response = await _client
          .get(Uri.parse('$baseUrl/api/app-config'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> || body['taxi_enabled'] is! bool) {
        return;
      }
      final enabled = body['taxi_enabled'] as bool;
      taxiEnabled.value = enabled;
      await _preferences.setBool(_enabledCacheKey, enabled);
    } catch (_) {
      // 오프라인이면 마지막으로 받은 값을 그대로 쓴다.
    }
  }

  Future<void> _checkOngoingParty() async {
    if (_authService.currentSession.value == null) {
      hasOngoingParty.value = false;
      return;
    }
    final repository = TaxiRepository(
      client: AuthenticatedApiClient(authService: _authService),
      baseUrl: _baseUrl,
    );
    try {
      final results = await Future.wait([
        repository.getMyParties(),
        repository.getMyParties(scope: 'recent_chats'),
      ]);
      // 진행 중인 팟이 있거나, 종료 후에도 아직 대화할 수 있는 채팅이 있을 때만 유지한다.
      // 읽기만 가능한 지난 채팅은 서비스를 껐을 때 메뉴를 붙잡지 않는다.
      hasOngoingParty.value =
          results[0].isNotEmpty ||
          results[1].any((party) => party.chatStatus == 'writable');
    } catch (_) {
      // 확인하지 못하면 이전 판단을 유지한다.
    } finally {
      repository.close();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _client.close();
    super.onClose();
  }
}
