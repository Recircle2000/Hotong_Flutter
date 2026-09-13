import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:hsro/core/utils/env_config.dart';

class AppAuthApiException implements Exception {
  const AppAuthApiException(this.statusCode);

  final int statusCode;
}

class InvalidAppAuthResponseException implements Exception {}

class AuthRepository {
  AuthRepository({required http.Client client, String? baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  final http.Client _client;
  final String? _baseUrl;

  Future<String> fetchCurrentUserId() async {
    final baseUrl =
        (_baseUrl ?? EnvConfig.baseUrl).replaceFirst(RegExp(r'/$'), '');
    final response = await _client.get(
      Uri.parse('$baseUrl/api/app-auth/me'),
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw AppAuthApiException(response.statusCode);
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw InvalidAppAuthResponseException();
    }
    final userId = body['user_id'];
    if (userId is! String || !_uuidPattern.hasMatch(userId)) {
      throw InvalidAppAuthResponseException();
    }
    return userId.toLowerCase();
  }

  void close() => _client.close();

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
}
