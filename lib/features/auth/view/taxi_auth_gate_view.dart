import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/core/network/authenticated_api_client.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/auth/repository/auth_repository.dart';
import 'package:hsro/features/auth/view/school_email_auth_view.dart';
import 'package:hsro/features/auth/viewmodel/auth_viewmodel.dart';

class TaxiAuthGateView extends StatefulWidget {
  const TaxiAuthGateView({super.key});

  @override
  State<TaxiAuthGateView> createState() => _TaxiAuthGateViewState();
}

class _TaxiAuthGateViewState extends State<TaxiAuthGateView> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  late final String _controllerTag;
  late final AuthViewModel _controller;

  @override
  void initState() {
    super.initState();
    _controllerTag = 'taxi-auth-${identityHashCode(this)}';
    final authService = Get.find<AuthService>();
    _controller = Get.put(
      AuthViewModel(
        authService: authService,
        repository: AuthRepository(
          client: AuthenticatedApiClient(authService: authService),
        ),
      ),
      tag: _controllerTag,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    Get.delete<AuthViewModel>(tag: _controllerTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('택시팟')),
      body: SafeArea(
        child: Obx(() => _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_controller.step.value) {
      case TaxiAuthStep.checking:
        return const Center(child: CircularProgressIndicator());
      case TaxiAuthStep.email:
      case TaxiAuthStep.otp:
        return SchoolEmailAuthView(
          controller: _controller,
          emailController: _emailController,
          otpController: _otpController,
        );
      case TaxiAuthStep.verified:
        return _StatusView(
          icon: Icons.verified_rounded,
          title: '학교 이메일 인증 완료',
          message: '택시팟 기능을 준비 중입니다.',
          primaryLabel: '로그아웃',
          isLoading: _controller.isLoading.value,
          onPrimary: _controller.logout,
        );
      case TaxiAuthStep.serverUnavailable:
        return _StatusView(
          icon: Icons.cloud_off_outlined,
          title: '로그인 상태를 확인할 수 없습니다',
          message: _controller.errorMessage.value,
          primaryLabel: '다시 시도',
          isLoading: _controller.isLoading.value,
          onPrimary: _controller.retryServerVerification,
          secondaryLabel: _controller.hasSession ? '로그아웃' : null,
          onSecondary: _controller.hasSession ? _controller.logout : null,
        );
      case TaxiAuthStep.unavailable:
        return _StatusView(
          icon: Icons.error_outline,
          title: '인증 서비스를 사용할 수 없습니다',
          message: _controller.errorMessage.value,
          primaryLabel: '다시 확인',
          isLoading: _controller.isLoading.value,
          onPrimary: _controller.checkCurrentSession,
        );
    }
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.isLoading,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final bool isLoading;
  final Future<void> Function() onPrimary;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: isLoading ? null : onPrimary,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(primaryLabel),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: isLoading ? null : onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
