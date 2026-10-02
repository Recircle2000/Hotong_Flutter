import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:hsro/core/utils/env_config.dart';

class AppAuthApiException implements Exception {
  const AppAuthApiException(this.statusCode, [this.message]);

  final int statusCode;

  /// 서버가 사용자에게 보여줄 안내 문구를 보냈을 때만 있다.
  final String? message;
}

class InvalidAppAuthResponseException implements Exception {}

class AuthRepository {
  AuthRepository({
    required http.Client client,
    http.Client? publicClient,
    String? baseUrl,
  })  : _client = client,
        _publicClient = publicClient ?? http.Client(),
        _baseUrl = baseUrl;

  final http.Client _client;

  /// 로그인 전에 부르는 요청용. [_client]는 로그인 토큰이 없으면 요청을 보내지 않는다.
  final http.Client _publicClient;
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

  /// 앱 심사용 계정의 고정 코드를 서버에서 일회용 인증번호로 바꾼다.
  /// 코드가 틀리면 403, 여러 번 틀려 잠기면 429를 돌려준다.
  Future<String> exchangeReviewCode({
    required String email,
    required String code,
  }) async {
    final baseUrl =
        (_baseUrl ?? EnvConfig.baseUrl).replaceFirst(RegExp(r'/$'), '');
    final response = await _publicClient.post(
      Uri.parse('$baseUrl/api/app-auth/review-otp'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (response.statusCode != 200) {
      throw AppAuthApiException(response.statusCode);
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final otp = body is Map<String, dynamic> ? body['otp'] : null;
    if (otp is! String || otp.isEmpty) {
      throw InvalidAppAuthResponseException();
    }
    return otp;
  }

  /// 회원 탈퇴. 진행 중인 팟이 있으면 서버가 409와 안내 문구를 돌려준다.
  Future<void> deleteAccount() async {
    final baseUrl =
        (_baseUrl ?? EnvConfig.baseUrl).replaceFirst(RegExp(r'/$'), '');
    final response = await _client.delete(
      Uri.parse('$baseUrl/api/app-auth/me'),
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode == 204) return;
    String? message;
    try {
      final detail = jsonDecode(utf8.decode(response.bodyBytes))['detail'];
      if (detail is Map<String, dynamic>) {
        message = detail['message'] as String?;
      }
    } catch (_) {}
    throw AppAuthApiException(response.statusCode, message);
  }

  void close() {
    _client.close();
    _publicClient.close();
  }

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
}
