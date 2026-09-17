import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hsro/core/network/authenticated_api_client.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/view/taxi_party_create_view.dart';
import 'package:hsro/features/taxi/view/taxi_party_detail_view.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:intl/intl.dart';

// 홈의 택시 메뉴와 동일한 포인트 색상을 사용한다.
const _taxiAccent = Color(0xFFF5A623);

Color _taxiTint(BuildContext context) => _taxiAccent.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.12,
    );

Color _taxiAccentText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFC766)
        : const Color(0xFF855300);

BoxDecoration _taxiCardDecoration(BuildContext context) => BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );

class TaxiHomeView extends StatefulWidget {
  const TaxiHomeView({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<TaxiHomeView> createState() => _TaxiHomeViewState();
}

class _TaxiHomeViewState extends State<TaxiHomeView> {
  static const _iosTaxiMenuChannel = MethodChannel('hsro/ios_taxi_menu');

  late final String _tag;
  late final AuthService authService;
  late final TaxiHomeViewModel controller;

  @override
  void initState() {
    super.initState();
    _tag = 'taxi-home-${identityHashCode(this)}';
    authService = Get.find<AuthService>();
    controller = Get.put(
      TaxiHomeViewModel(
        repository: TaxiRepository(
            client: AuthenticatedApiClient(authService: authService)),
        realtime: TaxiRealtimeService(authService),
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<TaxiHomeViewModel>(tag: _tag);
    super.dispose();
  }

  Future<void> _openCreateView() async {
    if (controller.locations.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자가 등록한 택시 거점이 부족합니다.')),
      );
      return;
    }
    await Get.to(() => TaxiPartyCreateView(
          locations: controller.locations.toList(),
          repository: controller.repository,
        ));
    await controller.refreshAll();
  }

  Future<void> _openParty(TaxiPartySummary party) async {
    await Get.to(() => TaxiPartyDetailView(
          partyId: party.id,
          locations: controller.locations.toList(),
          repository: controller.repository,
          realtime: controller.realtime,
        ));
    await controller.refreshAll();
  }

  Future<void> _showMenu() async {
    final action =
        Platform.isIOS ? await _showIOSMenu() : await _showFlutterMenu();
    if (!mounted || action == null) return;
    switch (action) {
      case _TaxiMenuAction.loginInfo:
        await _showLoginInfo();
      case _TaxiMenuAction.history:
        await Get.to(() => _TaxiPartyHistoryView(
              controller: controller,
              onPartyTap: _openParty,
            ));
        await controller.refreshAll();
      case _TaxiMenuAction.logout:
        await widget.onLogout();
    }
  }

  Future<_TaxiMenuAction?> _showIOSMenu() async {
    try {
      final action = await _iosTaxiMenuChannel.invokeMethod<String>(
        'show',
        <String, Object>{
          'title': '택시팟 메뉴',
          'email': authService.currentUserEmail ?? '인증된 사용자',
          'historyCount': controller.history.length,
          'loginInfoTitle': '로그인 정보',
          'historyTitle': '파티 이용 기록',
          'logoutTitle': '로그아웃',
          'cancelTitle': '닫기',
        },
      );
      return switch (action) {
        'loginInfo' => _TaxiMenuAction.loginInfo,
        'history' => _TaxiMenuAction.history,
        'logout' => _TaxiMenuAction.logout,
        _ => null,
      };
    } on PlatformException {
      return _showFlutterMenu();
    } on MissingPluginException {
      return _showFlutterMenu();
    }
  }

  Future<_TaxiMenuAction?> _showFlutterMenu() {
    return showModalBottomSheet<_TaxiMenuAction>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (context) => _TaxiMenuSheet(
        email: authService.currentUserEmail,
        historyCount: controller.history.length,
      ),
    );
  }

  Future<void> _showLoginInfo() async {
    final email = authService.currentUserEmail ?? '이메일 정보를 확인할 수 없습니다.';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그인 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('인증된 이메일'),
            const SizedBox(height: 6),
            SelectableText(
              email,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 18,
                  color: _taxiAccentText(context),
                ),
                const SizedBox(width: 6),
                const Text('이메일 인증 완료'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('택시팟'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '택시팟 메뉴',
            onPressed: _showMenu,
            icon: const Icon(Icons.menu_outlined),
          ),
        ],
      ),
      body: _FindParties(controller: controller, onPartyTap: _openParty),
      bottomNavigationBar: Obx(() => _TaxiBottomAction(
            party: controller.currentParty,
            additionalPartyCount:
                (controller.myParties.length - 1).clamp(0, 999),
            onCreate: _openCreateView,
            onPartyTap: _openParty,
          )),
    );
  }
}

enum _TaxiMenuAction { loginInfo, history, logout }

class _TaxiMenuSheet extends StatelessWidget {
  const _TaxiMenuSheet({required this.email, required this.historyCount});

  final String? email;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _taxiTint(context),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_taxi_outlined,
                      color: _taxiAccent,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '택시팟 메뉴',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email ?? '인증된 사용자',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                decoration: _taxiCardDecoration(context),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _TaxiMenuTile(
                      icon: Icons.account_circle_outlined,
                      title: '로그인 정보',
                      subtitle: '인증된 계정 정보 확인',
                      onTap: () =>
                          Navigator.of(context).pop(_TaxiMenuAction.loginInfo),
                    ),
                    Divider(
                      height: 1,
                      indent: 68,
                      color: colors.onSurface.withValues(alpha: 0.08),
                    ),
                    _TaxiMenuTile(
                      icon: Icons.history_rounded,
                      title: '파티 이용 기록',
                      subtitle: '최근 30일의 참여 내역',
                      badge: '$historyCount',
                      onTap: () =>
                          Navigator.of(context).pop(_TaxiMenuAction.history),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: colors.errorContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () =>
                      Navigator.of(context).pop(_TaxiMenuAction.logout),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            size: 20, color: colors.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '로그아웃',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 20, color: colors.error),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaxiMenuTile extends StatelessWidget {
  const _TaxiMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _taxiTint(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 21, color: _taxiAccentText(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _taxiTint(context),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _taxiAccentText(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindParties extends StatelessWidget {
  const _FindParties({required this.controller, required this.onPartyTap});
  final TaxiHomeViewModel controller;
  final Future<void> Function(TaxiPartySummary party) onPartyTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() => RefreshIndicator(
          color: _taxiAccentText(context),
          onRefresh: controller.refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              if (controller.errorMessage.isNotEmpty)
                _ErrorCard(message: controller.errorMessage.value),
              Container(
                decoration: _taxiCardDecoration(context),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _taxiTint(context),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_taxi_outlined,
                              color: _taxiAccent, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('어디로 가시나요?',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              Text('같은 방향의 택시팟을 찾아보세요',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(children: [
                      Expanded(
                        child: _LocationDropdown(
                          label: '출발지',
                          value: controller.departureLocationId.value,
                          locations: controller.locations,
                          onChanged: controller.setDeparture,
                        ),
                      ),
                      IconButton(
                        tooltip: '출발지와 도착지 바꾸기',
                        onPressed: controller.swapLocations,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 22),
                        color: _taxiAccentText(context),
                      ),
                      Expanded(
                        child: _LocationDropdown(
                          label: '도착지',
                          value: controller.destinationLocationId.value,
                          locations: controller.locations,
                          onChanged: controller.setDestination,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _DateSelector(controller: controller),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text('택시팟 목록',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Text('마감된 방 보기', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 4),
                  Switch.adaptive(
                    activeTrackColor: _taxiAccent,
                    activeThumbColor: const Color(0xFF30210A),
                    value: controller.includeUnavailable.value,
                    onChanged: controller.toggleUnavailable,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (controller.isLoading.value && controller.parties.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                        child: CircularProgressIndicator(
                      color: _taxiAccent,
                    )))
              else if (controller.parties.isEmpty)
                const _EmptyParties()
              else
                ...controller.parties.map((party) => _TaxiPartyCard(
                      party: party,
                      onTap: () => onPartyTap(party),
                    )),
            ],
          ),
        ));
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.controller});

  final TaxiHomeViewModel controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedDate.value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(selected.year, selected.month, selected.day);
    final last = today.add(const Duration(days: 7));
    return Container(
      decoration: BoxDecoration(
        color: _taxiTint(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '이전 날짜',
            onPressed:
                date.isAfter(today) ? () => controller.changeDate(-1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              '${DateFormat('M월 d일 (E)', 'ko').format(selected)}${date == today ? ' · 오늘' : ''}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _taxiAccentText(context),
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          IconButton(
            tooltip: '다음 날짜',
            onPressed:
                date.isBefore(last) ? () => controller.changeDate(1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyParties extends StatelessWidget {
  const _EmptyParties();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: _taxiCardDecoration(context),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: _taxiTint(context), shape: BoxShape.circle),
            child: const Icon(Icons.local_taxi_outlined,
                size: 32, color: _taxiAccent),
          ),
          const SizedBox(height: 16),
          Text('조건에 맞는 택시팟이 없어요',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('다른 경로나 날짜를 선택하거나\n새로운 택시팟을 만들어보세요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.6)),
        ],
      ),
    );
  }
}

class _TaxiPartyHistoryView extends StatelessWidget {
  const _TaxiPartyHistoryView({
    required this.controller,
    required this.onPartyTap,
  });

  final TaxiHomeViewModel controller;
  final Future<void> Function(TaxiPartySummary party) onPartyTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('파티 이용 기록'), centerTitle: true),
      body: Obx(() => RefreshIndicator(
            color: _taxiAccentText(context),
            onRefresh: controller.refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (controller.history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: Text('최근 이용한 택시팟이 없습니다.')),
                  )
                else
                  ...controller.history.map((party) => _TaxiPartyCard(
                        party: party,
                        isHistory: true,
                        onTap: () => onPartyTap(party),
                      )),
              ],
            ),
          )),
    );
  }
}

class _TaxiPartyCard extends StatelessWidget {
  const _TaxiPartyCard({
    required this.party,
    required this.onTap,
    this.isHistory = false,
  });

  final TaxiPartySummary party;
  final VoidCallback onTap;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const labels = {
      'recruiting': '모집 중',
      'full': '정원 마감',
      'closed': '모집 마감',
      'in_progress': '이동 중',
      'completed': '이용 완료',
      'cancelled': '취소',
    };
    final statusLabel = isHistory && party.status != 'cancelled'
        ? '이용 완료'
        : labels[party.status] ?? party.status;
    final isCancelled = party.status == 'cancelled';
    final isRecruiting = !isHistory && party.status == 'recruiting';
    final statusBackground = isCancelled
        ? colors.errorContainer
        : isRecruiting
            ? _taxiTint(context)
            : colors.onSurface.withValues(alpha: 0.06);
    final statusForeground = isCancelled
        ? colors.onErrorContainer
        : isRecruiting
            ? _taxiAccentText(context)
            : colors.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _taxiCardDecoration(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${DateFormat('HH:mm').format(party.departureAt)} 출발',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: statusForeground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.route_rounded,
                        size: 20, color: _taxiAccentText(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${party.departureLocation.name} → ${party.destinationLocation.name}',
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600, height: 1.4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: colors.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 17,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                        child: Text(
                      DateFormat('M월 d일 (E)', 'ko').format(party.departureAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                    if (party.meetingCode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _taxiTint(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          party.meetingCode!,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _taxiAccentText(context),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                      height: 1,
                      color: colors.onSurface.withValues(alpha: 0.08)),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        party.departureSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (!isHistory) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.people_outline_rounded,
                          size: 17, color: colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${party.currentMembers}/${party.maxMembers}명',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaxiBottomAction extends StatelessWidget {
  const _TaxiBottomAction({
    required this.party,
    required this.additionalPartyCount,
    required this.onCreate,
    required this.onPartyTap,
  });

  final TaxiPartySummary? party;
  final int additionalPartyCount;
  final VoidCallback onCreate;
  final Future<void> Function(TaxiPartySummary party) onPartyTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 0,
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: party == null
              ? SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _taxiAccent,
                      foregroundColor: const Color(0xFF30210A),
                      textStyle: theme.textTheme.labelLarge
                          ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('택시팟 만들기'),
                  ),
                )
              : _CurrentPartyCard(
                  party: party!,
                  additionalPartyCount: additionalPartyCount,
                  onTap: () => onPartyTap(party!),
                ),
        ),
      ),
    );
  }
}

class _CurrentPartyCard extends StatelessWidget {
  const _CurrentPartyCard({
    required this.party,
    required this.additionalPartyCount,
    required this.onTap,
  });

  final TaxiPartySummary party;
  final int additionalPartyCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: _taxiTint(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _taxiAccent.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _taxiAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_taxi_outlined,
                  color: Color(0xFF30210A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          party.isOwner ? '내가 만든 택시팟' : '현재 참여 중인 택시팟',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _taxiAccentText(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (additionalPartyCount > 0) ...[
                          Text(
                            '외 $additionalPartyCount개',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _taxiAccentText(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('M/d HH:mm').format(party.departureAt)} · '
                      '${party.departureLocation.name} → ${party.destinationLocation.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (party.meetingCode != null) ...[
                const SizedBox(width: 8),
                Text(
                  party.meetingCode!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _taxiAccentText(context),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
              if (party.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Badge(
                  backgroundColor: _taxiAccent,
                  textColor: const Color(0xFF30210A),
                  label: Text('${party.unreadCount}'),
                ),
              ],
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                color: _taxiAccentText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown(
      {required this.label,
      required this.value,
      required this.locations,
      required this.onChanged});
  final String label;
  final int? value;
  final List<TaxiLocation> locations;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int?>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded, size: 20),
        borderRadius: BorderRadius.circular(16),
        dropdownColor: Theme.of(context).cardColor,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelStyle: TextStyle(color: _taxiAccentText(context)),
          filled: true,
          fillColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _taxiAccent, width: 1.5)),
        ),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('전체')),
          ...locations.map((location) => DropdownMenuItem<int?>(
              value: location.id,
              child: Text(location.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: onChanged,
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12)),
        child: Text(message),
      );
}
