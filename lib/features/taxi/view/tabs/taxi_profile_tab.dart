import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/services/taxi_push_service.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';

/// 택시팟 홈의 내정보 탭.
class TaxiProfileTab extends StatelessWidget {
  const TaxiProfileTab({
    super.key,
    required this.controller,
    required this.email,
    required this.onHistory,
    required this.onLogout,
    required this.onAppeal,
    this.onDeleteAccount,
    this.push,
    this.onPushChanged,
    required this.onBlocks,
    required this.onTerms,
  });

  final TaxiHomeViewModel controller;
  final String? email;
  final VoidCallback onHistory;

  /// null이면 로그아웃 버튼을 비활성화한다.
  final VoidCallback? onLogout;
  final VoidCallback onAppeal;

  /// null이면 회원 탈퇴 버튼을 숨기거나(미지원) 비활성화한다(처리 중).
  final VoidCallback? onDeleteAccount;

  /// null이면 알림 스위치를 숨긴다(푸시를 쓸 수 없는 환경).
  final TaxiPushService? push;
  final ValueChanged<bool>? onPushChanged;
  final VoidCallback onBlocks;
  final VoidCallback onTerms;

  @override
  Widget build(BuildContext context) => Obx(
    () => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: taxiCardDecoration(context),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 42,
                color: taxiAccent,
              ),
              const SizedBox(height: 16),
              SelectableText(
                email ?? '인증된 사용자',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('이메일 인증 완료'),
              if (controller.userKey case final userKey?) ...[
                const SizedBox(height: 12),
                _UserKeyRow(userKey: userKey),
              ],
            ],
          ),
        ),
        if (controller.suspension case final suspension?) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                Icons.block_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              title: Text(
                suspension.isPermanent
                    ? '택시팟 이용 영구 제한'
                    : '이용 제한 중 · ${suspension.periodLabel}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '사유: ${suspension.reason}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              trailing: TextButton(
                onPressed: onAppeal,
                child: const Text('이의제기'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history, color: taxiAccent),
            title: const Text('참여 기록'),
            subtitle: Text('최근 30일 · ${controller.history.length}건'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onHistory,
          ),
        ),
        if (push case final push?) ...[
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              key: const ValueKey('taxi-push-switch'),
              secondary: const Icon(
                Icons.notifications_outlined,
                color: taxiAccent,
              ),
              title: const Text('택시팟 알림'),
              subtitle: const Text('새 메시지와 팟 취소·변경을 알려드려요'),
              value: push.enabled.value,
              onChanged: onPushChanged,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            key: const ValueKey('taxi-block-list'),
            leading: const Icon(Icons.block_rounded, color: taxiAccent),
            title: const Text('차단 목록'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onBlocks,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.description_outlined, color: taxiAccent),
            title: const Text('이용약관'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTerms,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('로그아웃'),
            onTap: onLogout,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('delete-account'),
            onPressed: onDeleteAccount,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              textStyle: Theme.of(context).textTheme.bodySmall,
            ),
            child: const Text('회원 탈퇴'),
          ),
        ),
      ],
    ),
  );
}

/// 이의제기·문의 때 운영진이 사용자를 찾을 수 있는 고유번호.
class _UserKeyRow extends StatelessWidget {
  const _UserKeyRow({required this.userKey});

  final String userKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '고유번호',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          userKey,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            unawaited(Clipboard.setData(ClipboardData(text: userKey)));
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('고유번호를 복사했어요.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('복사'),
        ),
      ],
    );
  }
}
