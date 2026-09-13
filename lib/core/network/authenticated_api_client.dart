import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:hsro/core/services/auth_service.dart';

class AuthenticationRequiredException implements Exception {}

class AuthenticatedApiClient extends http.BaseClient {
  AuthenticatedApiClient({
    required AuthService authService,
    http.Client? innerClient,
  })  : _authService = authService,
        _innerClient = innerClient ?? http.Client();

  final AuthService _authService;
  final http.Client _innerClient;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final originalHeaders = Map<String, String>.from(request.headers);
    final accessToken = await _authService.getValidAccessToken();
    if (accessToken == null) {
      throw AuthenticationRequiredException();
    }

    request.headers['Authorization'] = 'Bearer $accessToken';
    final response = await _innerClient.send(request);
    if (response.statusCode != 401 || request.method != 'GET') {
      return response;
    }

    await response.stream.drain<void>();
    final refreshedToken =
        await _authService.getValidAccessToken(forceRefresh: true);
    if (refreshedToken == null) {
      throw AuthenticationRequiredException();
    }

    final retryRequest = http.Request('GET', request.url)
      ..headers.addAll(originalHeaders)
      ..headers['Authorization'] = 'Bearer $refreshedToken';
    return _innerClient.send(retryRequest);
  }

  @override
  void close() {
    _innerClient.close();
    super.close();
  }
}
