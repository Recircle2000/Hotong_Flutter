import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hsro/features/auth/viewmodel/auth_viewmodel.dart';

class SchoolEmailAuthView extends StatelessWidget {
  const SchoolEmailAuthView({
    super.key,
    required this.controller,
    required this.emailController,
    required this.otpController,
  });

  final AuthViewModel controller;
  final TextEditingController emailController;
  final TextEditingController otpController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOtpStep = controller.step.value == TaxiAuthStep.otp;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          '호서대학교 구성원 인증',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '택시팟 이용을 위해 학교 이메일 인증이 필요합니다.\n'
          '이메일은 학교 구성원 확인 및 로그인 용도로만 사용됩니다.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 32),
        if (!isOtpStep) _buildEmailForm(context) else _buildOtpForm(context),
        if (controller.errorMessage.value.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            controller.errorMessage.value,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildEmailForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: emailController,
          enabled: !controller.isLoading.value,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: '학교 이메일',
            hintText: 'xxxx@vision.hoseo.edu',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => controller.sendOtp(emailController.text),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.isLoading.value
              ? null
              : () => controller.sendOtp(emailController.text),
          child: controller.isLoading.value
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('인증번호 받기'),
        ),
      ],
    );
  }

  Widget _buildOtpForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${controller.pendingEmail ?? ''}로 인증번호를 보냈습니다.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: otpController,
          enabled: !controller.isLoading.value,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '6자리 인증번호',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          onSubmitted: (_) => controller.verifyOtp(otpController.text),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.isLoading.value
              ? null
              : () => controller.verifyOtp(otpController.text),
          child: controller.isLoading.value
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('인증하기'),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: controller.isLoading.value
                  ? null
                  : () {
                      otpController.clear();
                      controller.editEmail();
                    },
              child: const Text('이메일 수정'),
            ),
            TextButton(
              onPressed: controller.resendSeconds.value == 0 &&
                      !controller.isLoading.value
                  ? controller.resendOtp
                  : null,
              child: Text(
                controller.resendSeconds.value == 0
                    ? '인증번호 재전송'
                    : '${controller.resendSeconds.value}초 후 재전송',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '가장 최근에 받은 인증번호를 입력해주세요.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
