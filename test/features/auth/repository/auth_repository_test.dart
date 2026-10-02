import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hsro/features/auth/repository/auth_repository.dart';

void main() {
  test('returns a validated UUID from the current-user endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/app-auth/me');
      expect(request.headers['Accept'], 'application/json');
      return http.Response(
        jsonEncode(
          const {'user_id': 'A02F10F1-7D61-4B4A-8F24-4CA3F4BE0C55'},
        ),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

    final repository = AuthRepository(
      client: client,
      baseUrl: 'http://localhost:8000',
    );
    expect(
      await repository.fetchCurrentUserId(),
      'a02f10f1-7d61-4b4a-8f24-4ca3f4be0c55',
    );
  });

  test('throws an API exception for a non-success status', () async {
    final repository = AuthRepository(
      client: MockClient((_) async => http.Response('unauthorized', 401)),
      baseUrl: 'http://localhost:8000',
    );

    await expectLater(
      repository.fetchCurrentUserId(),
      throwsA(
        isA<AppAuthApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });

  test('rejects a malformed UUID response', () async {
    final repository = AuthRepository(
      client: MockClient(
        (_) async => http.Response(jsonEncode({'user_id': 'not-a-uuid'}), 200),
      ),
      baseUrl: 'http://localhost:8000',
    );

    await expectLater(
      repository.fetchCurrentUserId(),
      throwsA(isA<InvalidAppAuthResponseException>()),
    );
  });
}
