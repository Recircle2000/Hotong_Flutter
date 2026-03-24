import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/notice_model.dart';
import '../utils/env_config.dart';

class NoticeRepository {
  NoticeRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Notice>> fetchAllNotices() async {
    final response = await _client.get(
      Uri.parse('${EnvConfig.baseUrl}/notices/'),
      headers: _defaultHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load notices (${response.statusCode})');
    }

    final decodedBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = json.decode(decodedBody) as List<dynamic>;
    return jsonList
        .map((item) => Notice.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Notice> fetchLatestNotice() async {
    final response = await _client.get(
      Uri.parse('${EnvConfig.baseUrl}/notices/latest'),
      headers: _defaultHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load latest notice (${response.statusCode})');
    }

    final decodedBody = utf8.decode(response.bodyBytes);
    final Map<String, dynamic> jsonData =
        Map<String, dynamic>.from(json.decode(decodedBody) as Map);
    return Notice.fromJson(jsonData);
  }

  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=UTF-8',
  };
}
