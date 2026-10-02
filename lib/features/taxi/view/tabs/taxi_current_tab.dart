import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/view/taxi_party_detail_view.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_notice.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';
import 'package:intl/intl.dart';

/// 참여 중인 팟 가운데 [selectedId]인 팟. 없으면 첫 번째 팟을 고른다.
TaxiPartySummary? selectTaxiCurrentParty(
  List<TaxiPartySummary> parties,
  String? selectedId,
) {
  if (parties.isEmpty) return null;
  return parties.firstWhere(
    (party) => party.id == selectedId,
    orElse: () => parties.first,
  );
}

/// 택시팟 홈의 현재팟 탭. 참여 중인 팟 상세와 최근 채팅 목록을 전환한다.
class TaxiCurrentTab extends StatelessWidget {
  const TaxiCurrentTab({
    super.key,
    required this.controller,
    required this.section,
    required this.selectedPartyId,
    required this.detailKeyFor,
    required this.onSectionChanged,
    required this.onPartySelected,
    required this.onOpenRecentChat,
    required this.onSearch,
    required this.onCreate,
  });

  final TaxiHomeViewModel controller;

  /// 0: 현재 파티, 1: 최근 채팅
  final int section;
  final String? selectedPartyId;
  final GlobalKey<TaxiPartyDetailViewState> Function(String partyId)
  detailKeyFor;
  final ValueChanged<int> onSectionChanged;
  final ValueChanged<String?> onPartySelected;
  final Future<void> Function(TaxiPartySummary party) onOpenRecentChat;
  final VoidCallback onSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Obx(
    () => Column(
      children: [
        _CurrentSectionSelector(
          selectedIndex: section,
          currentCount: controller.myParties.length,
          recentCount: controller.recentChats.length,
          recentUnread: controller.recentChats.fold<int>(
            0,
            (sum, party) => sum + party.unreadCount,
          ),
          onSelected: (index) {
            if (section != index) onSectionChanged(index);
          },
        ),
        Expanded(
          child: IndexedStack(
            index: section,
            children: [_currentPartyPane(context), _recentChatsPane(context)],
          ),
        ),
      ],
    ),
  );

  Widget _currentPartyPane(BuildContext context) {
    final parties = controller.myParties;
    if (parties.isEmpty) {
      if (controller.isLoading.value ||
          !controller.hasLoaded.value && controller.errorMessage.isEmpty) {
        return const Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation<Color>(taxiAccent),
          ),
        );
      }
      if (controller.errorMessage.isNotEmpty) {
        return TaxiNotice(
          message: controller.errorMessage.value,
          showRetry: true,
          onRetry: controller.isLoading.value ? null : controller.refreshAll,
        );
      }
      return RefreshIndicator(
        onRefresh: controller.refreshAll,
        color: taxiAccent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          children: [
            const Icon(Icons.local_taxi_outlined, size: 48, color: taxiAccent),
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
                FilledButton(onPressed: onSearch, child: const Text('팟 검색')),
                const SizedBox(width: 8),
                TextButton(onPressed: onCreate, child: const Text('팟 생성')),
              ],
            ),
          ],
        ),
      );
    }
    final selected = selectTaxiCurrentParty(parties, selectedPartyId)!;
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
              onChanged: onPartySelected,
            ),
          ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(selected.id),
            child: TaxiPartyDetailView(
              key: detailKeyFor(selected.id),
              embedded: true,
              showAppBar: false,
              summary: selected,
              partyId: selected.id,
              locations: controller.locations.toList(),
              repository: controller.repository,
              realtime: controller.realtime,
              onMembershipChanged: controller.refreshAll,
              onChatRead: () => controller.markPartyRead(selected.id),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recentChatsPane(BuildContext context) {
    final chats = controller.recentChats;
    return RefreshIndicator(
      color: taxiAccent,
      onRefresh: controller.refreshAll,
      child: ListView(
        key: const ValueKey('recent-chats-pane'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (controller.errorMessage.isNotEmpty)
            TaxiErrorCard(message: controller.errorMessage.value),
          if (controller.isLoading.value && chats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 72),
              child: Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(taxiAccent),
                ),
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
                onTap: () => onOpenRecentChat(party),
              ),
            ),
          ],
        ],
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
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(13),
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
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? taxiAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: taxiAccent.withValues(alpha: 0.24),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: foreground),
                const SizedBox(width: 6),
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
                          : taxiAccent.withValues(alpha: 0.16),
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
            color: taxiAccent,
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
