import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/notice/models/emergency_notice_model.dart';

class EmergencyNoticeRepository {
  Future<EmergencyNotice?> fetchLatestNotice(
    EmergencyNoticeCategory category,
  ) async {
    // 카테고리별 최신 긴급 공지 조회
    final uri = Uri.parse('${EnvConfig.baseUrl}/emergency-notices/latest')
        .replace(queryParameters: {'category': category.apiValue});

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    if (response.statusCode == 200) {
      // 빈 응답이나 null 문자열은 공지 없음으로 처리
      final rawBody = utf8.decode(response.bodyBytes).trim();
      if (rawBody.isEmpty || rawBody == 'null') {
        return null;
      }

      final jsonData = json.decode(rawBody);
      if (jsonData == null) {
        return null;
      }

      return EmergencyNotice.fromJson(Map<String, dynamic>.from(jsonData));
    }

    // 카테고리 값이 잘못된 경우 포맷 오류로 구분
    if (response.statusCode == 422) {
      throw FormatException(
        'Invalid emergency notice category: ${category.apiValue}',
      );
    }

    throw Exception(
      // 그 외 상태 코드는 일반 네트워크/서버 오류로 처리
      'Failed to load emergency notice (status: ${response.statusCode})',
    );
  }
}
