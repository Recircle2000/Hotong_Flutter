import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hsro/core/repository/app_config_repository.dart';

/// 서버에 게시된 시간표의 버전과 내려받을 주소.
class BusTimesRemoteInfo {
  const BusTimesRemoteInfo({required this.version, required this.downloadUrl});

  final String version;
  final String downloadUrl;
}

class BusTimesRepository {
  BusTimesRepository({http.Client? client, AppConfigRepository? appConfig})
      : _client = client ?? http.Client(),
        _appConfig = appConfig ?? AppConfigRepository.shared;

  // 서버가 app-config에 시간표 버전을 담기 전(구버전 서버)에 쓰던 경로
  static const String legacyVersionPath = '/bus-timetable/version';
  static const String legacyDownloadUrl =
      'https://recircle2000.github.io/hotong_station_image/bus_times.json';

  final http.Client _client;
  final AppConfigRepository _appConfig;

  /// app-config에 담긴 시간표 버전을 우선 쓰고, 없으면 예전 버전 API와 깃허브 주소를 쓴다.
  Future<BusTimesRemoteInfo?> fetchRemoteInfo() async {
    final config = await _appConfig.fetch();
    final timetable = config?.busTimetable;
    if (timetable != null) {
      return BusTimesRemoteInfo(
        version: timetable.version,
        downloadUrl: _appConfig.resolveUrl(timetable.downloadUrl),
      );
    }

    final legacyVersion = await _fetchLegacyVersion();
    if (legacyVersion == null || legacyVersion.isEmpty) {
      return null;
    }
    return BusTimesRemoteInfo(
      version: legacyVersion,
      downloadUrl: legacyDownloadUrl,
    );
  }

  Future<String?> _fetchLegacyVersion() async {
    try {
      final response = await _client
          .get(Uri.parse(_appConfig.resolveUrl(legacyVersionPath)))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return decoded['version']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> downloadBusTimesJson(String downloadUrl) async {
    final response = await _client
        .get(Uri.parse(downloadUrl))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return null;
    }
    // 서버가 charset 없이 JSON을 줘도 한글이 깨지지 않게 바이트에서 직접 읽는다.
    return utf8.decode(response.bodyBytes);
  }
}
