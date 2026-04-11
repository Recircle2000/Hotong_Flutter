import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/subway/models/subway_schedule_model.dart';

class SubwayRepository {
  Future<SubwaySchedule> fetchSchedule(
      String stationName, String dayType) async {
    // 역명과 요일 유형 기준 시간표 조회
    final baseUrl = EnvConfig.baseUrl;
    final uri = Uri.parse('$baseUrl/subway/schedule').replace(queryParameters: {
      'station_name': stationName,
      'day_type': dayType,
    });

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        // 한글 깨짐 방지를 위해 UTF-8 기준 디코딩
        final decodedBody = utf8.decode(response.bodyBytes);
        final jsonResponse = jsonDecode(decodedBody);
        return SubwaySchedule.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to load schedule: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching schedule: $e');
    }
  }
}
