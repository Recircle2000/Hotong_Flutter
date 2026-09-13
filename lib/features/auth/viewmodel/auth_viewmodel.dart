import 'dart:async';

import 'package:get/get.dart';
import 'package:hsro/core/network/authenticated_api_client.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/auth/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum TaxiAuthStep {
  checking,
  email,
  otp,
  verified,
  serverUnavailable,
  unavailable
}

class AuthViewModel extends GetxController {
  AuthViewModel({
    required AuthService authService,
    required AuthRepository repository,
  })  : _authService = authService,
        _repository = repository;

  final AuthService _authService;
  final AuthRepository _repository;

  final step = TaxiAuthStep.checking.obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final resendSeconds = 0.obs;
  final verifiedUserId = RxnString();

  String? _pendingEmail;
  Timer? _resendTimer;
  int _operationGeneration = 0;

  String? get pendingEmail => _pendingEmail;
  bool get hasSession => _authService.currentSession.value != null;

  @override
  void onInit() {
    super.onInit();
    unawaited(checkCurrentSession());
  }

  Future<void> checkCurrentSession() async {
    final generation = ++_operationGeneration;
    errorMessage.value = '';
    step.value = TaxiAuthStep.checking;

    if (!_authService.isAvailable) {
      if (generation == _operationGeneration) {
        errorMessage.value = _authService.unavailableMessage;
        step.value = TaxiAuthStep.unavailable;
      }
      return;
    }

    try {
      final token = await _authService.getValidAccessToken();
      if (generation != _operationGeneration) return;
      if (token == null) {
        step.value = TaxiAuthStep.email;
        return;
      }
      await _verifyServerSession(generation);
    } on AuthException catch (error) {
      if (generation != _operationGeneration) return;
      await _handleInvalidSession();
      errorMessage.value = _authErrorMessage(error);
    } catch (_) {
      if (generation != _operationGeneration) return;
      step.value = TaxiAuthStep.serverUnavailable;
      errorMessage.value = '로그인 상태를 확인할 수 없습니다. 다시 시도해주세요.';
    }
  }

  Future<void> sendOtp(String rawEmail) async {
    if (isLoading.value) return;
    final generation = ++_operationGeneration;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final email = await _authService.sendOtp(rawEmail);
      if (generation != _operationGeneration) return;
      _pendingEmail = email;
      step.value = TaxiAuthStep.otp;
      _startResendTimer();
    } on InvalidSchoolEmailException {
      errorMessage.value = '호서대학교 학교 이메일을 정확히 입력해주세요.';
    } on AuthException catch (error) {
      errorMessage.value = _authErrorMessage(error);
    } catch (_) {
      errorMessage.value = '인증번호를 보내지 못했습니다. 네트워크 상태를 확인해주세요.';
    } finally {
      if (generation == _operationGeneration) {
        isLoading.value = false;
      }
    }
  }

  Future<void> verifyOtp(String otp) async {
    final email = _pendingEmail;
    if (email == null || isLoading.value) return;

    final generation = ++_operationGeneration;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await _authService.verifyOtp(email: email, otp: otp);
      if (generation != _operationGeneration) return;
      await _verifyServerSession(generation);
    } on InvalidOtpException {
      errorMessage.value = '6자리 인증번호를 입력해주세요.';
    } on AuthException catch (error) {
      errorMessage.value = _authErrorMessage(error);
    } catch (_) {
      errorMessage.value = '인증을 완료하지 못했습니다. 잠시 후 다시 시도해주세요.';
    } finally {
      if (generation == _operationGeneration) {
        isLoading.value = false;
      }
    }
  }

  Future<void> resendOtp() async {
    final email = _pendingEmail;
    if (email == null || resendSeconds.value > 0 || isLoading.value) return;
    await sendOtp(email);
  }

  void editEmail() {
    _operationGeneration++;
    _pendingEmail = null;
    _resendTimer?.cancel();
    resendSeconds.value = 0;
    errorMessage.value = '';
    isLoading.value = false;
    step.value = TaxiAuthStep.email;
  }

  Future<void> retryServerVerification() async {
    if (isLoading.value) return;
    final generation = ++_operationGeneration;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await _verifyServerSession(generation);
    } on AuthException catch (error) {
      if (generation != _operationGeneration) return;
      await _handleInvalidSession();
      errorMessage.value = _authErrorMessage(error);
    } catch (_) {
      if (generation != _operationGeneration) return;
      step.value = TaxiAuthStep.serverUnavailable;
      errorMessage.value = '서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.';
    } finally {
      if (generation == _operationGeneration) {
        isLoading.value = false;
      }
    }
  }

  Future<void> logout() async {
    if (isLoading.value) return;
    final generation = ++_operationGeneration;
    isLoading.value = true;
    errorMessage.value = '';
    String? logoutWarning;
    try {
      await _authService.signOutCurrentDevice();
    } catch (_) {
      logoutWarning = '이 기기에서는 로그아웃되었습니다. 서버 연결은 확인하지 못했습니다.';
    } finally {
      if (generation == _operationGeneration) {
        _pendingEmail = null;
        verifiedUserId.value = null;
        step.value = TaxiAuthStep.email;
        errorMessage.value = logoutWarning ?? '';
        isLoading.value = false;
      }
    }
  }

  Future<void> _verifyServerSession(int generation) async {
    try {
      final serverUserId = await _repository.fetchCurrentUserId();
      if (generation != _operationGeneration) return;
      final localUserId = _authService.currentUserId?.toLowerCase();
      if (localUserId == null || localUserId != serverUserId) {
        await _handleInvalidSession();
        errorMessage.value = '사용자 정보를 확인할 수 없습니다. 다시 인증해주세요.';
        return;
      }
      verifiedUserId.value = serverUserId;
      _pendingEmail = null;
      _resendTimer?.cancel();
      resendSeconds.value = 0;
      errorMessage.value = '';
      step.value = TaxiAuthStep.verified;
    } on AppAuthApiException catch (error) {
      if (generation != _operationGeneration) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _handleInvalidSession();
        errorMessage.value = '인증이 만료되었습니다. 학교 이메일로 다시 인증해주세요.';
        return;
      }
      step.value = TaxiAuthStep.serverUnavailable;
      errorMessage.value = error.statusCode == 503
          ? '인증 서버를 일시적으로 사용할 수 없습니다.'
          : '로그인 상태를 확인하지 못했습니다.';
    } on AuthenticationRequiredException {
      if (generation != _operationGeneration) return;
      await _handleInvalidSession();
      errorMessage.value = '로그인이 필요합니다.';
    }
  }

  Future<void> _handleInvalidSession() async {
    try {
      await _authService.signOutCurrentDevice();
    } catch (_) {
      // The Supabase client removes its local session before the network call.
    }
    verifiedUserId.value = null;
    step.value = TaxiAuthStep.email;
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    resendSeconds.value = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendSeconds.value <= 1) {
        resendSeconds.value = 0;
        timer.cancel();
      } else {
        resendSeconds.value--;
      }
    });
  }

  String _authErrorMessage(AuthException error) {
    if (error.statusCode == '429' ||
        error.code == 'over_email_send_rate_limit' ||
        error.code == 'over_request_rate_limit') {
      return '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
    }
    if (error.code == 'otp_expired' ||
        error.code == 'email_not_confirmed' ||
        error.message.toLowerCase().contains('expired') ||
        error.message.toLowerCase().contains('invalid')) {
      return '인증번호가 올바르지 않거나 만료되었습니다.';
    }
    if (error.statusCode == '403') {
      return '호서대학교 학교 이메일만 인증할 수 있습니다.';
    }
    return '인증 요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  }

  @override
  void onClose() {
    _operationGeneration++;
    _resendTimer?.cancel();
    _repository.close();
    super.onClose();
  }
}
