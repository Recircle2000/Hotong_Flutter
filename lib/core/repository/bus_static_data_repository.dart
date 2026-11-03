import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hsro/core/repository/app_config_repository.dart';

class BusStaticDataManifest {
  const BusStaticDataManifest({
    required this.version,
    required this.downloadUrl,
    this.effectiveFrom,
  });

  final String version;
  final String downloadUrl;
  final DateTime? effectiveFrom;

  factory BusStaticDataManifest.fromJson(
    Map<String, dynamic> json, {
    String? fallbackDownloadUrl,
  }) {
    final version = json['version']?.toString().trim() ?? '';
    final downloadUrl =
        json['downloadUrl']?.toString().trim() ?? fallbackDownloadUrl ?? '';
    final effectiveFromText = json['effectiveFrom']?.toString().trim();
    final effectiveFrom = effectiveFromText == null || effectiveFromText.isEmpty
        ? null
        : DateTime.tryParse(effectiveFromText);

    if (version.isEmpty ||
        downloadUrl.isEmpty ||
        effectiveFromText != null && effectiveFrom == null) {
      throw const FormatException('Invalid bus static data manifest');
    }

    return BusStaticDataManifest(
      version: version,
      downloadUrl: downloadUrl,
      effectiveFrom: effectiveFrom,
    );
  }
}

abstract class BusStaticDataRemoteSource {
  Future<BusStaticDataManifest?> fetchRemoteManifest();

  Future<String?> downloadBusStaticData(String downloadUrl);
}

class BusStaticDataRepository implements BusStaticDataRemoteSource {
  BusStaticDataRepository({
    http.Client? client,
    AppConfigRepository? appConfig,
  })  : _client = client ?? http.Client(),
        _appConfig = appConfig ?? AppConfigRepository.shared;

  // 서버가 app-config에 노선도 버전을 담기 전(구버전 서버)에 쓰던 깃허브 경로
  static const String manifestUrl =
      'https://recircle2000.github.io/hotong_station_image/bus_static_manifest.json';
  static const String defaultDownloadUrl =
      'https://recircle2000.github.io/hotong_station_image/bus_static_data.json';

  final http.Client _client;
  final AppConfigRepository _appConfig;

  /// app-config에 담긴 노선도 버전을 우선 쓰고, 없으면 깃허브 매니페스트를 읽는다.
  @override
  Future<BusStaticDataManifest?> fetchRemoteManifest() async {
    final config = await _appConfig.fetch();
    final release = config?.busStatic;
    if (release != null) {
      return BusStaticDataManifest(
        version: release.version,
        downloadUrl: _appConfig.resolveUrl(release.downloadUrl),
        effectiveFrom: release.effectiveFrom,
      );
    }
    return _fetchLegacyManifest();
  }

  Future<BusStaticDataManifest?> _fetchLegacyManifest() async {
    final response = await _client
        .get(Uri.parse(manifestUrl))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      return null;
    }

    try {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return BusStaticDataManifest.fromJson(
        decoded,
        fallbackDownloadUrl: defaultDownloadUrl,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> downloadBusStaticData(String downloadUrl) async {
    final response = await _client
        .get(Uri.parse(downloadUrl))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return null;
    }

    // Storage는 charset 없이 JSON을 주므로 한글이 깨지지 않게 바이트에서 직접 읽는다.
    return utf8.decode(response.bodyBytes);
  }
}
