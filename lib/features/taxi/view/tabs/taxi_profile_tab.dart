import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  });

  final TaxiHomeViewModel controller;
  final String? email;
  final VoidCallback onHistory;

  /// null이면 로그아웃 버튼을 비활성화한다.
  final VoidCallback? onLogout;

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
            ],
          ),
        ),
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
      ],
    ),
  );
}
