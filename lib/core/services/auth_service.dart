import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppAuthSessionState { unavailable, signedOut, signedIn }

class InvalidSchoolEmailException implements Exception {}

class InvalidOtpException implements Exception {}

class AuthService extends GetxService {
  AuthService(
    this._client, {
    Set<String> allowedTestEmails = const {},
    Set<String> reviewEmails = const {},
    String? unavailableMessage,
  })  : allowedTestEmails =
            Set.unmodifiable({...allowedTestEmails, ...reviewEmails}),
        reviewEmails = Set.unmodifiable(reviewEmails),
        unavailableMessage = unavailableMessage ?? '';

  AuthService.unavailable([String? message])
      : _client = null,
        allowedTestEmails = const {},
        reviewEmails = const {},
        unavailableMessage = message ?? '인증 설정을 불러오지 못했습니다.';

  static const schoolEmailDomain = 'vision.hoseo.edu';

  final SupabaseClient? _client;
  final Set<String> allowedTestEmails;

  /// 앱 심사용 계정. 메일함을 열 수 없는 심사자를 위해 인증번호 메일을 보내지 않고,
  /// 인증번호 칸에 입력한 값을 Supabase에 지정해 둔 비밀번호로 확인한다.
  final Set<String> reviewEmails;
  final String unavailableMessage;
  final sessionState = AppAuthSessionState.unavailable.obs;
  final currentSession = Rxn<Session>();

  StreamSubscription<AuthState>? _authSubscription;
  Future<AuthResponse>? _refreshInFlight;

  bool get isAvailable => _client != null;
  String? get currentUserId => currentSession.value?.user.id;
  String? get currentUserEmail => currentSession.value?.user.email;

  Future<AuthService> init() async {
    final client = _client;
    if (client == null) {
      sessionState.value = AppAuthSessionState.unavailable;
      return this;
    }

    _setSession(client.auth.currentSession);
    _authSubscription = client.auth.onAuthStateChange.listen(
      (authState) => _setSession(authState.session),
    );
    return this;
  }

  static String normalizeSchoolEmail(
    String rawEmail, {
    Set<String> allowedTestEmails = const {},
  }) {
    final email = rawEmail.trim().toLowerCase();
    final parts = email.split('@');
    if (parts.length != 2 ||
        parts.first.isEmpty ||
        (parts.last != schoolEmailDomain &&
            !allowedTestEmails.contains(email)) ||
        email.runes.any(
            (character) => String.fromCharCode(character).trim().isEmpty)) {
      throw InvalidSchoolEmailException();
    }
    return email;
  }

  Future<String> sendOtp(String rawEmail) async {
    final client = _requireClient();
    final email = normalizeSchoolEmail(
      rawEmail,
      allowedTestEmails: allowedTestEmails,
    );
    if (reviewEmails.contains(email)) return email;
    await client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
    );
    return email;
  }

  Future<Session> verifyOtp(
      {required String email, required String otp}) async {
    final client = _requireClient();
    final normalizedEmail = normalizeSchoolEmail(
      email,
      allowedTestEmails: allowedTestEmails,
    );
    final normalizedOtp = otp.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedOtp)) {
      throw InvalidOtpException();
    }

    final response = reviewEmails.contains(normalizedEmail)
        ? await client.auth.signInWithPassword(
            email: normalizedEmail,
            password: normalizedOtp,
          )
        : await client.auth.verifyOTP(
            email: normalizedEmail,
            token: normalizedOtp,
            type: OtpType.email,
          );
    final session = response.session;
    if (session == null || response.user == null) {
      throw const AuthException('인증 세션이 생성되지 않았습니다.');
    }
    _setSession(session);
    return session;
  }

  Future<String?> getValidAccessToken({bool forceRefresh = false}) async {
    final client = _client;
    if (client == null) {
      return null;
    }

    var session = client.auth.currentSession;
    if (session == null) {
      _setSession(null);
      return null;
    }

    if (forceRefresh || session.isExpired) {
      final response = await _refreshSession(client);
      session = response.session;
    }

    _setSession(session);
    return session?.accessToken;
  }

  Future<void> signOutCurrentDevice() async {
    final client = _requireClient();
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } finally {
      _setSession(null);
    }
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const AuthException('인증 서비스를 사용할 수 없습니다.');
    }
    return client;
  }

  Future<AuthResponse> _refreshSession(SupabaseClient client) async {
    final activeRefresh = _refreshInFlight;
    if (activeRefresh != null) {
      return activeRefresh;
    }

    final refresh = client.auth.refreshSession();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    }
  }

  void _setSession(Session? session) {
    currentSession.value = session;
    sessionState.value = session == null
        ? AppAuthSessionState.signedOut
        : AppAuthSessionState.signedIn;
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }
}
