import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shuttle_models.dart';
import '../utils/env_config.dart';

class ShuttleRepository {
  ShuttleRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<ShuttleRoute>> fetchRoutes({int? routeId}) async {
    final response = await _get(
      '/shuttle/routes',
      query: routeId != null ? {'route_id': '$routeId'} : null,
      headers: _utf8Headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load routes (${response.statusCode})');
    }

    final List<dynamic> data = _decodeList(response.bodyBytes);
    return data
        .map((item) => ShuttleRoute.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchSchedulesByDate({
    required int routeId,
    required String date,
  }) async {
    final response = await _get(
      '/shuttle/schedules-by-date',
      query: {'route_id': '$routeId', 'date': date},
      headers: _utf8Headers,
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load schedules-by-date (${response.statusCode})',
      );
    }

    return _decodeMap(response.bodyBytes);
  }

  Future<List<ScheduleStop>?> fetchScheduleStops(int scheduleId) async {
    final response = await _get(
      '/shuttle/schedules/$scheduleId/stops',
      headers: _utf8Headers,
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load schedule stops (${response.statusCode})',
      );
    }

    final List<dynamic> data = _decodeList(response.bodyBytes);
    return data
        .map((item) => ScheduleStop.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ShuttleStation>> fetchStations({int? stationId}) async {
    final response = await _get(
      '/shuttle/stations',
      query: stationId != null ? {'station_id': '$stationId'} : null,
      headers: _utf8Headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load stations (${response.statusCode})');
    }

    final List<dynamic> data = _decodeList(response.bodyBytes);
    return data
        .map((item) => ShuttleStation.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchScheduleTypeByDate(String date) async {
    final response = await _get(
      '/shuttle/schedule-type-by-date',
      query: {'date': date},
      headers: _utf8Headers,
    );

    if (response.statusCode != 200) {
      return null;
    }

    return _decodeMap(response.bodyBytes);
  }

  Future<Map<String, dynamic>> fetchStationSchedulesByDate({
    required int stationId,
    required String date,
  }) async {
    final response = await _get(
      '/shuttle/stations/$stationId/schedules-by-date',
      query: {'date': date},
      headers: _utf8Headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load station schedules-by-date (${response.statusCode})',
      );
    }

    return _decodeMap(response.bodyBytes);
  }

  Future<List<StationSchedule>> fetchStationSchedules(int stationId) async {
    final response = await _get(
      '/shuttle/stations/$stationId/schedules',
      headers: _utf8Headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load station schedules (${response.statusCode})',
      );
    }

    final List<dynamic> data = _decodeList(response.bodyBytes);
    return data
        .map(
            (item) => StationSchedule.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchRealtimeBuses() async {
    final response = await _get('/buses', headers: _utf8Headers);

    if (response.statusCode != 200) {
      return null;
    }

    return _decodeMap(response.bodyBytes);
  }

  Future<String?> fetchRouteName(int routeId) async {
    final routeList = await fetchRoutes(routeId: routeId);
    if (routeList.isEmpty) {
      return null;
    }
    return routeList.first.routeName;
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) {
    final uri =
        Uri.parse('${EnvConfig.baseUrl}$path').replace(queryParameters: query);
    return _client.get(uri, headers: headers);
  }

  Map<String, dynamic> _decodeMap(List<int> bodyBytes) {
    return Map<String, dynamic>.from(
      json.decode(utf8.decode(bodyBytes)) as Map,
    );
  }

  List<dynamic> _decodeList(List<int> bodyBytes) {
    return json.decode(utf8.decode(bodyBytes)) as List<dynamic>;
  }

  static const Map<String, String> _utf8Headers = {
    'Accept-Charset': 'UTF-8',
  };
}
