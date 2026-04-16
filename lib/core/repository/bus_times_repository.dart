import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hsro/core/utils/env_config.dart';

class BusTimesRepository {
  BusTimesRepository({http.Client? client}) : _client = client ?? http.Client();

  // 서버에 저장된 현재 시간표 버전 정보 조회용 API 주소
  static String get versionApiUrl =>
      '${EnvConfig.baseUrl.replaceFirst(RegExp(r'/$'), '')}/bus-timetable/version';
  // 실제 시간표 JSON 파일 내려받음용 고정 주소
  static const String downloadUrl =
      'https://recircle2000.github.io/hotong_station_image/bus_times.json';

  final http.Client _client;

  Future<String?> fetchServerVersion() async {
    // 서버에서 최신 시간표 버전 가져옴
    final response = await _client
        .get(Uri.parse(versionApiUrl))
        .timeout(const Duration(seconds: 5));

    // 정상 응답이 아니면 버전 확인 실패로 처리
    if (response.statusCode != 200) {
      return null;
    }

    try {
      // JSON 형식 응답이면 version 필드만 추출
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return decoded['version']?.toString() ?? response.body.trim();
    } catch (_) {
      // 단순 문자열 응답도 허용하기 위해 본문 전체 사용
      return response.body.trim();
    }
  }

  Future<String?> downloadBusTimesJson() async {
    // 원격 저장소에서 최신 버스 시간표 파일 내려받음
    final response = await _client
        .get(Uri.parse(downloadUrl))
        .timeout(const Duration(seconds: 10));
    // 다운로드 실패 시 null 반환
    if (response.statusCode != 200) {
      return null;
    }
    // 성공 시 JSON 문자열 원문 반환
    return response.body;
  }
}
