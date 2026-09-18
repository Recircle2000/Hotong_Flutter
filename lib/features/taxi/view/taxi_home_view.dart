import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/widgets/taxi_tab_bar.dart';
import 'package:get/get.dart';
import 'package:hsro/core/network/authenticated_api_client.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/view/taxi_party_create_view.dart';
import 'package:hsro/features/taxi/view/taxi_party_detail_view.dart';
import 'package:hsro/features/taxi/view/taxi_chat_view.dart';
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
  const TaxiHomeView({super.key, required this.onLogout, this.viewModel});

  final Future<void> Function() onLogout;
  final TaxiHomeViewModel? viewModel;

  @override
  State<TaxiHomeView> createState() => _TaxiHomeViewState();
}

class _TaxiHomeViewState extends State<TaxiHomeView> {
  late final String _tag;
  late final AuthService authService;
  late final TaxiHomeViewModel controller;
  int _index = 1;
  int _currentSection = 0;
  final _visited = <int>{1};
  bool _busy = false;
  String? _selectedPartyId;
  GlobalKey<TaxiPartyCreateViewState> _createKey = GlobalKey();
  final Map<String, GlobalKey<TaxiPartyDetailViewState>> _detailKeys = {};

  @override
  void initState() {
    super.initState();
    _tag = 'taxi-home-${identityHashCode(this)}';
    authService = Get.find<AuthService>();
    controller = Get.put(
      widget.viewModel ??
          TaxiHomeViewModel(
            repository: TaxiRepository(
              client: AuthenticatedApiClient(authService: authService),
            ),
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

  Future<void> _select(int index) async {
    if (!mounted || _busy || _index == index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    // Update selection synchronously: the native tab bar rolls rejected
    // selections back on the next frame. These are IndexedStack changes, not
    // route transitions: keep the native bar mounted and visible. Global glass
    // suppression here fades the entire bar out/in on every tab selection.
    // Popup suppression remains the navigator observer's responsibility.
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  void _showCurrentParty() {
    if (!mounted || _busy) return;
    setState(() => _currentSection = 0);
    unawaited(_select(2));
  }

  TaxiPartySummary? get _selectedCurrentParty {
    final parties = controller.myParties;
    if (parties.isEmpty) return null;
    return parties.firstWhere(
      (party) => party.id == _selectedPartyId,
      orElse: () => parties.first,
    );
  }

  List<Widget> _headerActions() {
    if (_index != 2 || _currentSection != 0) return const [];
    final party = _selectedCurrentParty;
    if (party == null || !canManageTaxiParty(party)) return const [];
    return [
      TaxiPartyOwnerMenuButton(
        party: party,
        onSelected: (action) {
          final detail = _detailKeys[party.id]?.currentState;
          if (detail != null) unawaited(detail.handleOwnerAction(action));
        },
      ),
    ];
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        action: SnackBarAction(label: '현재팟', onPressed: _showCurrentParty),
      ),
    );
  }

  Future<bool> _canSubmit() async {
    await controller.refreshAll();
    if (!mounted) return false;
    final allowed = controller.canCreateOrJoin;
    if (!allowed) {
      _message(
        controller.errorMessage.isNotEmpty
            ? controller.errorMessage.value
            : '이미 참여 중인 택시팟이 있습니다.',
      );
    }
    return allowed;
  }

  Future<void> _created(TaxiPartyDetail party) async {
    controller.acceptParty(party);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _createKey = GlobalKey();
      _selectedPartyId = party.id;
      _currentSection = 0;
    });
    await _select(2);
    await controller.refreshAll();
  }

  Future<void> _openParty(TaxiPartySummary party) async {
    await Get.to(
      () => TaxiPartyDetailView(
        partyId: party.id,
        locations: controller.locations.toList(),
        repository: controller.repository,
        realtime: controller.realtime,
        canJoin: _canSubmit,
        joinAllowed: () => controller.canCreateOrJoin,
        onMembershipChanged: controller.refreshAll,
        onShowCurrent: () {
          Get.back();
          _showCurrentParty();
        },
        onJoined: (joined) async {
          controller.acceptParty(joined);
          _selectedPartyId = joined.id;
          _currentSection = 0;
          Get.back();
          await _select(2);
        },
      ),
    );
    await controller.refreshAll();
  }

  Future<void> _openRecentChat(TaxiPartySummary party) async {
    try {
      final detail = await controller.repository.getParty(party.id);
      if (!mounted || detail.chatStatus == 'expired') {
        await controller.refreshAll();
        return;
      }
      await Get.to(
        () => TaxiChatView(
          party: detail,
          repository: controller.repository,
          realtime: controller.realtime,
        ),
      );
      await controller.refreshAll();
    } on TaxiApiException catch (error) {
      _message(error.message);
      await controller.refreshAll();
    }
  }

  Future<void> _history() async {
    await Get.to(
      () =>
          _TaxiPartyHistoryView(controller: controller, onPartyTap: _openParty),
    );
    await controller.refreshAll();
  }

  Widget _notice(
    String message, {
    bool retry = false,
    bool current = false,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_taxi_outlined, size: 48, color: _taxiAccent),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (retry)
            FilledButton(
              onPressed: controller.isLoading.value
                  ? null
                  : controller.refreshAll,
              child: const Text('다시 시도'),
            ),
          if (current)
            FilledButton(
              onPressed: _showCurrentParty,
              child: const Text('현재팟 보기'),
            ),
          if (!retry && !current) ...[
            FilledButton(
              onPressed: () => _select(1),
              child: const Text('팟 검색'),
            ),
            TextButton(onPressed: () => _select(0), child: const Text('팟 생성')),
          ],
        ],
      ),
    ),
  );

  Widget _createTab() {
    final ready =
        controller.hasLoaded.value && controller.locations.length >= 2;
    String? blocked;
    if (controller.myParties.isNotEmpty) {
      blocked = '이미 모집 중인 택시팟이 있어요.\n모집 종료 후 새로운 팟을 만들 수 있습니다.';
    } else if (controller.errorMessage.isNotEmpty) {
      blocked = controller.errorMessage.value;
    } else if (!controller.hasLoaded.value || controller.isLoading.value) {
      blocked = '택시팟 정보를 확인하고 있어요.';
    } else if (!ready) {
      blocked = '등록된 택시 거점이 부족합니다.';
    }
    return Stack(
      children: [
        if (ready)
          TaxiPartyCreateView(
            key: _createKey,
            embedded: true,
            locations: controller.locations.toList(),
            repository: controller.repository,
            onCreated: _created,
            canSubmit: _canSubmit,
            onConflict: controller.refreshAll,
            onBusyChanged: (busy) {
              if (mounted) setState(() => _busy = busy);
            },
            onStepChanged: () {
              if (mounted) setState(() {});
            },
          ),
        if (blocked != null && !_busy)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: controller.isLoading.value && controller.myParties.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: _taxiAccent),
                    )
                  : _notice(
                      blocked,
                      current: controller.myParties.isNotEmpty,
                      retry: controller.myParties.isEmpty,
                    ),
            ),
          ),
      ],
    );
  }

  Widget _currentPartyPane() {
    final parties = controller.myParties;
    if (parties.isEmpty) {
      if (controller.isLoading.value ||
          !controller.hasLoaded.value && controller.errorMessage.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: _taxiAccent),
        );
      }
      if (controller.errorMessage.isNotEmpty) {
        return _notice(controller.errorMessage.value, retry: true);
      }
      return RefreshIndicator(
        onRefresh: controller.refreshAll,
        color: _taxiAccent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          children: [
            const Icon(Icons.local_taxi_outlined, size: 48, color: _taxiAccent),
            const SizedBox(height: 14),
            Text(
              '모집 중인 팟이 없어요',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: () => _select(1),
                  child: const Text('팟 검색'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _select(0),
                  child: const Text('팟 생성'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final selected = _selectedCurrentParty!;
    final detailKey = _detailKeys.putIfAbsent(
      selected.id,
      GlobalKey<TaxiPartyDetailViewState>.new,
    );
    return Column(
      key: const ValueKey('current-party-pane'),
      children: [
        if (parties.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: DropdownButtonFormField<String>(
              initialValue: selected.id,
              decoration: const InputDecoration(labelText: '기존 참여 팟 선택'),
              isExpanded: true,
              items: parties
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.departureLocation.name} → ${p.destinationLocation.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) => setState(() => _selectedPartyId = id),
            ),
          ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(selected.id),
            child: TaxiPartyDetailView(
              key: detailKey,
              embedded: true,
              showAppBar: false,
              summary: selected,
              partyId: selected.id,
              locations: controller.locations.toList(),
              repository: controller.repository,
              realtime: controller.realtime,
              onMembershipChanged: controller.refreshAll,
            ),
          ),
        ),
      ],
    );
  }

  Widget _recentChatsPane() {
    final chats = controller.recentChats;
    return RefreshIndicator(
      color: _taxiAccent,
      onRefresh: controller.refreshAll,
      child: ListView(
        key: const ValueKey('recent-chats-pane'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (controller.errorMessage.isNotEmpty)
            _ErrorCard(message: controller.errorMessage.value),
          if (controller.isLoading.value && chats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 72),
              child: Center(
                child: CircularProgressIndicator(color: _taxiAccent),
              ),
            )
          else if (chats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 58),
              child: Column(
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '최근 채팅이 없어요',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '모집이 종료된 팟의 채팅을\n열람 기한 동안 확인할 수 있어요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
              child: Text(
                '모집 종료 후에도 열람 기한 동안 채팅을 확인할 수 있어요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...chats.map(
              (party) => _RecentChatTile(
                party: party,
                onTap: () => _openRecentChat(party),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _currentTab() => Column(
    children: [
      _CurrentSectionSelector(
        selectedIndex: _currentSection,
        currentCount: controller.myParties.length,
        recentCount: controller.recentChats.length,
        recentUnread: controller.recentChats.fold<int>(
          0,
          (sum, party) => sum + party.unreadCount,
        ),
        onSelected: (index) {
          if (_currentSection == index) return;
          setState(() => _currentSection = index);
        },
      ),
      Expanded(
        child: IndexedStack(
          index: _currentSection,
          children: [_currentPartyPane(), _recentChatsPane()],
        ),
      ),
    ],
  );

  Widget _profileTab() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        decoration: _taxiCardDecoration(context),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 42,
              color: _taxiAccent,
            ),
            const SizedBox(height: 16),
            SelectableText(
              authService.currentUserEmail ?? '인증된 사용자',
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
          leading: const Icon(Icons.history, color: _taxiAccent),
          title: const Text('참여 기록'),
          subtitle: Text('최근 30일 · ${controller.history.length}건'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _history,
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
          onTap: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await widget.onLogout();
                  } catch (_) {
                    _message('로그아웃하지 못했습니다. 다시 시도해주세요.');
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Obx(
    () => PopScope(
      canPop: _index == 1 && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        if (_index == 0 &&
            (_createKey.currentState?.canGoBack ?? false) &&
            controller.myParties.isEmpty) {
          _createKey.currentState!.previousStep();
        } else {
          _select(1);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(TaxiTabBar.labels[_index]),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: _busy
                ? null
                : () {
                    if (_index == 1) {
                      Navigator.of(context).pop();
                    } else if (_index == 0 &&
                        (_createKey.currentState?.canGoBack ?? false) &&
                        controller.myParties.isEmpty) {
                      _createKey.currentState!.previousStep();
                    } else {
                      _select(1);
                    }
                  },
          ),
          actions: _headerActions(),
        ),
        body: IndexedStack(
          index: _index,
          children: [
            for (var index = 0; index < 4; index++)
              TickerMode(
                enabled: index == _index,
                child: !_visited.contains(index)
                    ? const SizedBox.shrink()
                    : switch (index) {
                        0 => _createTab(),
                        1 => _FindParties(
                          controller: controller,
                          onPartyTap: _openParty,
                        ),
                        2 => _currentTab(),
                        _ => _profileTab(),
                      },
              ),
          ],
        ),
        bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : TaxiTabBar(
                index: _index,
                onSelected: _select,
                unread: controller.totalUnread,
                enabled: !_busy,
              ),
      ),
    ),
  );
}

class _FindParties extends StatelessWidget {
  const _FindParties({required this.controller, required this.onPartyTap});
  final TaxiHomeViewModel controller;
  final Future<void> Function(TaxiPartySummary party) onPartyTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(
      () => RefreshIndicator(
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
                        child: const Icon(
                          Icons.local_taxi_outlined,
                          color: _taxiAccent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '어디로 가시나요?',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '같은 방향의 택시팟을 찾아보세요',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DateSelector(controller: controller),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '택시팟 목록',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  child: CircularProgressIndicator(color: _taxiAccent),
                ),
              )
            else if (controller.parties.isEmpty)
              const _EmptyParties()
            else
              ...controller.parties.map(
                (party) => _TaxiPartyCard(
                  party: party,
                  onTap: () => onPartyTap(party),
                ),
              ),
          ],
        ),
      ),
    );
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
            onPressed: date.isAfter(today)
                ? () => controller.changeDate(-1)
                : null,
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
            onPressed: date.isBefore(last)
                ? () => controller.changeDate(1)
                : null,
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
              color: _taxiTint(context),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_taxi_outlined,
              size: 32,
              color: _taxiAccent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '조건에 맞는 택시팟이 없어요',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다른 경로나 날짜를 선택하거나\n새로운 택시팟을 만들어보세요.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
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
      body: Obx(
        () => RefreshIndicator(
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
                ...controller.history.map(
                  (party) => _TaxiPartyCard(
                    party: party,
                    isHistory: true,
                    onTap: () => onPartyTap(party),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentSectionSelector extends StatelessWidget {
  const _CurrentSectionSelector({
    required this.selectedIndex,
    required this.currentCount,
    required this.recentCount,
    required this.recentUnread,
    required this.onSelected,
  });

  final int selectedIndex;
  final int currentCount;
  final int recentCount;
  final int recentUnread;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: _CurrentSectionButton(
                key: const ValueKey('current-party-segment'),
                label: '현재 파티',
                icon: Icons.local_taxi_outlined,
                selected: selectedIndex == 0,
                count: currentCount,
                onTap: () => onSelected(0),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _CurrentSectionButton(
                key: const ValueKey('recent-chat-segment'),
                label: '최근 채팅',
                icon: Icons.forum_outlined,
                selected: selectedIndex == 1,
                count: recentCount,
                unread: recentUnread,
                onTap: () => onSelected(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentSectionButton extends StatelessWidget {
  const _CurrentSectionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.count,
    required this.onTap,
    this.unread = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final int count;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? const Color(0xFF30210A)
        : theme.colorScheme.onSurfaceVariant;
    final countLabel = unread > 0
        ? (unread > 99 ? '99+' : '$unread')
        : count > 0
        ? '$count'
        : null;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? _taxiAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _taxiAccent.withValues(alpha: 0.24),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: foreground),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (countLabel != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF30210A).withValues(alpha: 0.12)
                          : _taxiAccent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      countLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentChatTile extends StatelessWidget {
  const _RecentChatTile({required this.party, required this.onTap});

  final TaxiPartySummary party;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final writable = party.chatStatus == 'writable';
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Badge(
          isLabelVisible: party.unreadCount > 0,
          label: Text(party.unreadCount > 99 ? '99+' : '${party.unreadCount}'),
          child: Icon(
            writable ? Icons.chat_bubble_outline : Icons.history_rounded,
            color: _taxiAccent,
          ),
        ),
        title: Text(
          '${party.departureLocation.name} → ${party.destinationLocation.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${DateFormat('M월 d일 HH:mm').format(party.departureAt)} · '
          '${writable ? '채팅 가능' : '읽기 전용'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
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
      'ended': '모집 종료',
      'cancelled': '취소',
    };
    final displayStatus = party.recruitmentStatus;
    final statusLabel = labels[displayStatus] ?? displayStatus;
    final isCancelled = displayStatus == 'cancelled';
    final isRecruiting = !isHistory && displayStatus == 'recruiting';
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
                    Icon(
                      Icons.route_rounded,
                      size: 20,
                      color: _taxiAccentText(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${party.departureLocation.name} → ${party.destinationLocation.name}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
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
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    color: colors.onSurface.withValues(alpha: 0.08),
                  ),
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
                      Icon(
                        Icons.people_outline_rounded,
                        size: 17,
                        color: colors.onSurfaceVariant,
                      ),
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

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    required this.label,
    required this.value,
    required this.locations,
    required this.onChanged,
  });
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
      color: Theme.of(context).colorScheme.onSurface,
    ),
    decoration: InputDecoration(
      labelText: label,
      floatingLabelStyle: TextStyle(color: _taxiAccentText(context)),
      filled: true,
      fillColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _taxiAccent, width: 1.5),
      ),
    ),
    items: [
      const DropdownMenuItem<int?>(value: null, child: Text('전체')),
      ...locations.map(
        (location) => DropdownMenuItem<int?>(
          value: location.id,
          child: Text(
            location.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
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
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message),
  );
}
