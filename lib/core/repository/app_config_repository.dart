import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hsro/core/utils/env_config.dart';

/// 서버가 게시한 시내버스 데이터 한 종류(시간표 또는 노선도)의 버전 정보.
class BusDataRelease {
  const BusDataRelease({
    required this.version,
    required this.downloadUrl,
    this.effectiveFrom,
  });

  final String version;

  /// 시간표는 서버 상대 경로(/bus-timetable), 노선도는 Storage 절대 URL이다.
  final String downloadUrl;
  final DateTime? effectiveFrom;

  static BusDataRelease? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final version = json['version']?.toString().trim() ?? '';
    final downloadUrl = json['download_url']?.toString().trim() ?? '';
    if (version.isEmpty || downloadUrl.isEmpty) return null;
    final effectiveFromText = json['effective_from']?.toString();
    return BusDataRelease(
      version: version,
      downloadUrl: downloadUrl,
      effectiveFrom: effectiveFromText == null
          ? null
          : DateTime.tryParse(effectiveFromText),
    );
  }
}

/// `/api/app-config` 응답. 서버가 구버전이면 없는 필드는 null로 둔다.
class AppConfig {
  const AppConfig({this.taxiEnabled, this.busTimetable, this.busStatic});

  final bool? taxiEnabled;
  final BusDataRelease? busTimetable;
  final BusDataRelease? busStatic;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final busData = json['bus_data'];
    final busDataMap = busData is Map<String, dynamic> ? busData : null;
    final taxiEnabled = json['taxi_enabled'];
    return AppConfig(
      taxiEnabled: taxiEnabled is bool ? taxiEnabled : null,
      busTimetable: BusDataRelease.tryParse(busDataMap?['timetable']),
      busStatic: BusDataRelease.tryParse(busDataMap?['static']),
    );
  }
}

/// 앱 시작·복귀 때 여러 곳(택시 메뉴, 시내버스 데이터)이 같은 설정을 읽으므로
/// 동시에 들어온 요청은 하나로 합치고 잠깐 기억해 둔다.
class AppConfigRepository {
  AppConfigRepository({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  static final AppConfigRepository shared = AppConfigRepository();

  static const Duration _memoDuration = Duration(seconds: 5);

  final http.Client _client;
  final String? _baseUrl;

  Future<AppConfig?>? _inFlight;
  AppConfig? _memo;
  DateTime? _memoAt;

  String get baseUrl =>
      (_baseUrl ?? EnvConfig.baseUrl).replaceFirst(RegExp(r'/$'), '');

  /// 서버 상대 경로는 baseUrl을 붙여 절대 URL로 만든다.
  String resolveUrl(String url) =>
      url.startsWith('/') ? '$baseUrl$url' : url;

  /// 실패하면 null. 호출하는 쪽은 마지막 값이나 예전 경로를 쓴다.
  Future<AppConfig?> fetch() {
    final memo = _memo;
    final memoAt = _memoAt;
    if (memo != null &&
        memoAt != null &&
        DateTime.now().difference(memoAt) < _memoDuration) {
      return Future.value(memo);
    }
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<AppConfig?> _fetch() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/app-config'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) return null;
      final config = AppConfig.fromJson(body);
      _memo = config;
      _memoAt = DateTime.now();
      return config;
    } catch (_) {
      return null;
    }
  }
}
