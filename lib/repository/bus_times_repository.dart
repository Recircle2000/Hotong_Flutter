import 'dart:convert';

import 'package:http/http.dart' as http;

class BusTimesRepository {
  BusTimesRepository({http.Client? client}) : _client = client ?? http.Client();

  static const String versionApiUrl =
      'https://hotong.click/bus-timetable/version';
  static const String downloadUrl =
      'https://recircle2000.github.io/hotong_station_image/bus_times.json';

  final http.Client _client;

  Future<String?> fetchServerVersion() async {
    final response = await _client
        .get(Uri.parse(versionApiUrl))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      return null;
    }

    try {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return decoded['version']?.toString() ?? response.body.trim();
    } catch (_) {
      return response.body.trim();
    }
  }

  Future<String?> downloadBusTimesJson() async {
    final response = await _client
        .get(Uri.parse(downloadUrl))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return null;
    }
    return response.body;
  }
}
