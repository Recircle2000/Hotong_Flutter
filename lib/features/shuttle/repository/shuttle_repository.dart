import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';

class ShuttleRepository {
  ShuttleRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<ShuttleRoute>> fetchRoutes({int? routeId}) async {
    // 전체 노선 또는 특정 노선 조회
    final response = await _get(
      '/shuttle/routes',
      query: routeId != null ? {'route_id': '$routeId'} : null,
      headers: _utf8Headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load routes (${response.statusCode})');
    }

    // UTF-8 응답을 노선 목록으로 변환
    final List<dynamic> data = _decodeList(response.bodyBytes);
    return data
        .map((item) => ShuttleRoute.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchSchedulesByDate({
    required int routeId,
    required String date,
  }) async {
    // 노선과 날짜 기준 시간표 조회
    final response = await _get(
      '/shuttle/schedules-by-date',
      query: {'route_id': '$routeId', 'date': date},
      headers: _utf8Headers,
    );

    if (response.statusCode == 404) {
      // 해당 날짜 운행 정보가 없으면 null 반환
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
    // 회차별 정류장 목록 조회
    final response = await _get(
      '/shuttle/schedules/$scheduleId/stops',
      headers: _utf8Headers,
    );

    if (response.statusCode == 404) {
      // 정류장 상세가 없으면 null 반환
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
    // 전체 정류장 또는 특정 정류장 조회
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

  Future<List<StationRouteMembership>> fetchStationRouteMemberships() async {
    // 정류장별 노선 매핑 조회
    final response = await _get(
      '/shuttle/stations/route-memberships',
      headers: _utf8Headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load station route memberships (${response.statusCode})',
      );
    }

    final List<dynamic> data = _decodeList(response.bodyBytes);
    return data
        .map(
          (item) => StationRouteMembership.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>?> fetchScheduleTypeByDate(String date) async {
    // 날짜 기준 평일/토요일/공휴일 유형 조회
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
    // 정류장 기준 날짜별 도착 시간표 조회
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
    // 레거시 정류장 시간표 조회
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
    // 셔틀 실시간 버스 목록 조회
    final response = await _get('/buses', headers: _utf8Headers);

    if (response.statusCode != 200) {
      return null;
    }

    return _decodeMap(response.bodyBytes);
  }

  Future<String?> fetchRouteName(int routeId) async {
    // 노선 ID로 노선명 1건 조회
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
    // 공통 GET 요청 헬퍼
    final uri =
        Uri.parse('${EnvConfig.baseUrl}$path').replace(queryParameters: query);
    return _client.get(uri, headers: headers);
  }

  Map<String, dynamic> _decodeMap(List<int> bodyBytes) {
    // UTF-8 JSON 객체 디코딩
    return Map<String, dynamic>.from(
      json.decode(utf8.decode(bodyBytes)) as Map,
    );
  }

  List<dynamic> _decodeList(List<int> bodyBytes) {
    // UTF-8 JSON 배열 디코딩
    return json.decode(utf8.decode(bodyBytes)) as List<dynamic>;
  }

  static const Map<String, String> _utf8Headers = {
    // 한글 응답 깨짐 방지용 헤더
    'Accept-Charset': 'UTF-8',
  };
}
