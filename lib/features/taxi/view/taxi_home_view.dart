import 'package:flutter/material.dart';
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

class TaxiHomeView extends StatefulWidget {
  const TaxiHomeView({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<TaxiHomeView> createState() => _TaxiHomeViewState();
}

class _TaxiHomeViewState extends State<TaxiHomeView> {
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
    final action = await showModalBottomSheet<_TaxiMenuAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => _TaxiMenuSheet(
        email: authService.currentUserEmail,
        historyCount: controller.history.length,
      ),
    );
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
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                const Text('Supabase 이메일 인증 완료'),
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
        actions: [
          IconButton(
            tooltip: '택시팟 메뉴',
            onPressed: _showMenu,
            icon: const Icon(Icons.menu),
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '택시팟 메뉴',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('로그인 정보'),
              subtitle: Text(
                email ?? '인증된 사용자',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(_TaxiMenuAction.loginInfo),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('파티 이용 기록'),
              subtitle: Text('최근 30일 · $historyCount건'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(_TaxiMenuAction.history),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text(
                '로그아웃',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop(_TaxiMenuAction.logout),
            ),
          ],
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
    return Obx(() => RefreshIndicator(
          onRefresh: controller.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (controller.errorMessage.isNotEmpty)
                _ErrorCard(message: controller.errorMessage.value),
              Row(children: [
                Expanded(
                    child: _LocationDropdown(
                  label: '출발지',
                  value: controller.departureLocationId.value,
                  locations: controller.locations,
                  onChanged: controller.setDeparture,
                )),
                IconButton(
                    onPressed: controller.swapLocations,
                    icon: const Icon(Icons.swap_horiz)),
                Expanded(
                    child: _LocationDropdown(
                  label: '도착지',
                  value: controller.destinationLocationId.value,
                  locations: controller.locations,
                  onChanged: controller.setDestination,
                )),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                    onPressed: () => controller.changeDate(-1),
                    icon: const Icon(Icons.chevron_left)),
                Text(
                    DateFormat('M월 d일 (E)', 'ko')
                        .format(controller.selectedDate.value),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () => controller.changeDate(1),
                    icon: const Icon(Icons.chevron_right)),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('마감된 방 보기'),
                value: controller.includeUnavailable.value,
                onChanged: controller.toggleUnavailable,
              ),
              if (controller.isLoading.value && controller.parties.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()))
              else if (controller.parties.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: Text('조건에 맞는 택시팟이 없습니다.')))
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
      appBar: AppBar(title: const Text('파티 이용 기록')),
      body: Obx(() => RefreshIndicator(
            onRefresh: controller.refreshAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
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
    final isRecruiting = party.status == 'recruiting';
    final statusBackground = isCancelled
        ? colors.errorContainer
        : isRecruiting
            ? colors.primaryContainer
            : colors.secondaryContainer;
    final statusForeground = isCancelled
        ? colors.onErrorContainer
        : isRecruiting
            ? colors.onPrimaryContainer
            : colors.onSecondaryContainer;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(25),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${party.departureLocation.name} → '
                        '${party.destinationLocation.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
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
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 17,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      DateFormat('M월 d일 (E) HH:mm', 'ko')
                          .format(party.departureAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (party.meetingCode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          party.meetingCode!,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 11),
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
      elevation: 12,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: party == null
              ? SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('방 만들기'),
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
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_taxi_outlined,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          party.isOwner ? '내가 만든 택시팟' : '현재 참여 중인 택시팟',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (additionalPartyCount > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '외 $additionalPartyCount개',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
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
                        color: theme.colorScheme.onPrimaryContainer,
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
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
              if (party.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Badge(label: Text('${party.unreadCount}')),
              ],
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onPrimaryContainer,
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
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('전체')),
          ...locations.map((location) => DropdownMenuItem<int?>(
              value: location.id, child: Text(location.name))),
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
