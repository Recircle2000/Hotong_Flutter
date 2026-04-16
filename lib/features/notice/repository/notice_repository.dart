import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/notice/models/notice_model.dart';

class NoticeRepository {
  NoticeRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Notice>> fetchAllNotices() async {
    // 전체 공지 목록 조회
    final response = await _client.get(
      Uri.parse('${EnvConfig.baseUrl}/notices/'),
      headers: _defaultHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load notices (${response.statusCode})');
    }

    // 한글 깨짐 방지를 위해 bodyBytes 기준 UTF-8 디코딩
    final decodedBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = json.decode(decodedBody) as List<dynamic>;
    return jsonList
        .map((item) => Notice.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Notice> fetchLatestNotice() async {
    // 최신 공지 1건 조회
    final response = await _client.get(
      Uri.parse('${EnvConfig.baseUrl}/notices/latest'),
      headers: _defaultHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load latest notice (${response.statusCode})');
    }

    // 단건 응답을 모델 객체로 변환
    final decodedBody = utf8.decode(response.bodyBytes);
    final Map<String, dynamic> jsonData =
        Map<String, dynamic>.from(json.decode(decodedBody) as Map);
    return Notice.fromJson(jsonData);
  }

  static const Map<String, String> _defaultHeaders = {
    // 공통 JSON 요청 헤더
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=UTF-8',
  };
}
