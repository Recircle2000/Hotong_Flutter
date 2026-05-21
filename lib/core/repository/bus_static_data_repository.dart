import 'dart:convert';

import 'package:http/http.dart' as http;

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
  BusStaticDataRepository({http.Client? client})
      : _client = client ?? http.Client();

  static const String manifestUrl =
      'https://recircle2000.github.io/hotong_station_image/bus_static_manifest.json';
  static const String defaultDownloadUrl =
      'https://recircle2000.github.io/hotong_station_image/bus_static_data.json';

  final http.Client _client;

  @override
  Future<BusStaticDataManifest?> fetchRemoteManifest() async {
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

    return response.body;
  }
}
