import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/view/taxi_chat_view.dart';
import 'package:hsro/features/taxi/view/taxi_party_edit_view.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_party_detail_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_action_sheet.dart';
import 'package:hsro/features/taxi/widgets/taxi_app_bar_leading.dart';
import 'package:hsro/features/taxi/widgets/taxi_confirm_dialog.dart';
import 'package:hsro/features/taxi/widgets/taxi_report_sheet.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';
import 'package:hsro/shared/widgets/scale_button.dart';
import 'package:intl/intl.dart';

class TaxiPartyDetailView extends StatefulWidget {
  const TaxiPartyDetailView({
    super.key,
    required this.partyId,
    required this.locations,
    required this.repository,
    required this.realtime,
    this.embedded = false,
    this.showAppBar = true,
    this.canJoin,
    this.onJoined,
    this.onMembershipChanged,
    this.onChatRead,
    this.onShowCurrent,
    this.joinAllowed,
    this.joinBlockedLabel,
    this.summary,
    this.onBack,
  });

  final String partyId;
  final List<TaxiLocation> locations;
  final TaxiRepository repository;
  final TaxiRealtimeService realtime;
  final bool embedded;
  final bool showAppBar;
  final Future<bool> Function()? canJoin;
  final Future<void> Function(TaxiPartyDetail)? onJoined;
  final Future<void> Function()? onMembershipChanged;

  /// 채팅을 보고 돌아왔을 때 호출된다. 홈 화면의 안 읽음 배지를 지우는 데 쓴다.
  final VoidCallback? onChatRead;
  final VoidCallback? onShowCurrent;
  final bool Function()? joinAllowed;

  /// 참여를 막는 사유가 현재팟이 아닐 때(이용 제한 등) 버튼에 대신 보여줄 문구.
  final String? Function()? joinBlockedLabel;
  final TaxiPartySummary? summary;
  final VoidCallback? onBack;

  @override
  State<TaxiPartyDetailView> createState() => TaxiPartyDetailViewState();
}

enum TaxiPartyOwnerAction { edit, recruitment, cancel }

bool canManageTaxiParty(TaxiPartySummary party) {
  final ended =
      party.recruitmentStatus == 'cancelled' ||
      party.recruitmentStatus == 'ended';
  return party.isOwner && party.departureAt.isAfter(DateTime.now()) && !ended;
}

class TaxiPartyOwnerMenuButton extends StatelessWidget {
  const TaxiPartyOwnerMenuButton({
    super.key,
    required this.party,
    required this.onSelected,
  });

  final TaxiPartySummary party;
  final ValueChanged<TaxiPartyOwnerAction> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<TaxiPartyOwnerAction>(
    tooltip: '택시팟 관리',
    icon: const Icon(Icons.more_vert),
    onSelected: onSelected,
    itemBuilder: (context) => [
      const PopupMenuItem(
        value: TaxiPartyOwnerAction.edit,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.edit_outlined),
          title: Text('택시팟 정보 수정'),
        ),
      ),
      PopupMenuItem(
        value: TaxiPartyOwnerAction.recruitment,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            party.status == 'closed'
                ? Icons.lock_open_outlined
                : Icons.lock_outline,
          ),
          title: Text(party.status == 'closed' ? '모집 다시 열기' : '모집 마감하기'),
        ),
      ),
      PopupMenuItem(
        value: TaxiPartyOwnerAction.cancel,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            '택시팟 취소',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    ],
  );
}

class TaxiPartyDetailViewState extends State<TaxiPartyDetailView> {
  late final String _tag;
  late final TaxiPartyDetailViewModel controller;

  @override
  void initState() {
    super.initState();
    _tag = 'taxi-detail-${widget.partyId}-${identityHashCode(this)}';
    controller = Get.put(
      TaxiPartyDetailViewModel(
        partyId: widget.partyId,
        repository: widget.repository,
        realtime: widget.realtime,
        initial: switch (widget.summary) {
          final TaxiPartyDetail detail => detail,
          _ => null,
        },
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<TaxiPartyDetailViewModel>(tag: _tag);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TaxiPartyDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.summary, widget.summary)) {
      // 메시지가 올 때마다 요약이 새로 오지만, 대부분 안 읽음 수만 바뀐다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.syncSummary(widget.summary);
      });
    }
  }

  Future<bool> _confirm(
    String title,
    String message,
    String action, {
    bool nativeIOS = false,
  }) => showTaxiDestructiveConfirm(
    context,
    title: title,
    message: message,
    action: action,
    nativeIOS: nativeIOS,
  );

  Future<void> _edit(TaxiPartyDetail party) async {
    final updated = await Get.to<bool>(
      () => TaxiPartyEditView(
        party: party,
        locations: widget.locations,
        controller: controller,
      ),
    );
    if (updated == true) {
      await controller.load();
      await widget.onMembershipChanged?.call();
    }
  }

  bool _canManage(TaxiPartyDetail party) {
    return canManageTaxiParty(party);
  }

  Future<void> handleOwnerAction(TaxiPartyOwnerAction action) async {
    var party = controller.party.value;
    if (party == null) {
      await controller.load();
      party = controller.party.value;
    }
    if (party == null || !_canManage(party)) return;
    switch (action) {
      case TaxiPartyOwnerAction.edit:
        await _edit(party);
      case TaxiPartyOwnerAction.recruitment:
        await controller.setRecruitment(party.status == 'closed');
        await widget.onMembershipChanged?.call();
      case TaxiPartyOwnerAction.cancel:
        final confirmed = await _confirm(
          '택시팟 취소',
          '참여자 모두에게 취소 상태가 표시됩니다.',
          '취소하기',
        );
        if (confirmed && await controller.cancel()) {
          await widget.onMembershipChanged?.call();
        }
    }
  }

  bool _leaving = false;

  Future<void> _leaveParty() async {
    if (_leaving) return;
    _leaving = true;
    try {
      final confirmed = await _confirm(
        '택시팟 나가기',
        '나간 뒤 다시 참여하면 기존 익명 번호가 유지됩니다.',
        '나가기',
        nativeIOS: true,
      );
      if (!mounted) return;
      if (confirmed && await controller.leave()) {
        await widget.onMembershipChanged?.call();
      }
    } finally {
      _leaving = false;
    }
  }

  Future<void> _openChat(TaxiPartyDetail party) async {
    await Get.to(
      () => TaxiChatView(
        party: party,
        repository: widget.repository,
        realtime: widget.realtime,
      ),
    );
    // 채팅 화면이 읽음 처리를 보냈으므로 다시 조회하지 않고 배지만 지운다.
    controller.markRead();
    widget.onChatRead?.call();
  }

  Future<void> _showMemberActions(
    TaxiPartyDetail party,
    TaxiMember member,
  ) async {
    final action = await showTaxiActionSheet<String>(
      context,
      title: member.label,
      actions: const [
        TaxiSheetAction(
          value: 'report',
          label: '신고하기',
          icon: Icons.flag_outlined,
          destructive: true,
        ),
      ],
    );
    if (action != 'report' || !mounted) return;
    await reportTaxiMember(
      context,
      repository: widget.repository,
      partyId: party.id,
      targetLabel: member.label,
    );
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final party = controller.party.value;
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              leadingWidth: TaxiAppBarLeading.width,
              leading: TaxiAppBarLeading(
                back: widget.embedded
                    ? IconButton(
                        tooltip: '팟 검색',
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back_ios_new),
                      )
                    : null,
              ),
              title: Text(widget.embedded ? '현재팟' : '택시팟 상세'),
              actions: [
                if (party != null && _canManage(party))
                  TaxiPartyOwnerMenuButton(
                    party: party,
                    onSelected: handleOwnerAction,
                  ),
              ],
            )
          : null,
      body: _buildBody(party),
      bottomNavigationBar: party == null ? null : _buildActionDock(party),
    );
  });

  Widget _buildBody(TaxiPartyDetail? party) {
    if (party == null && controller.isLoading.value) {
      return const Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(taxiAccent),
        ),
      );
    }
    if (party == null) {
      return _LoadFailure(
        message: controller.errorMessage.value,
        onRetry: controller.load,
      );
    }
    return RefreshIndicator(
      color: taxiAccent,
      onRefresh: controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (controller.errorMessage.isNotEmpty)
            _ErrorBanner(message: controller.errorMessage.value),
          _RouteOverviewCard(party: party),
          const SizedBox(height: 16),
          _MembersCard(
            party: party,
            // 참여 중인 사람만 다른 참여자를 신고할 수 있다.
            onMemberTap: party.isMember
                ? (member) => _showMemberActions(party, member)
                : null,
          ),
          if (party.cancellationReason?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: '취소 사유: ${party.cancellationReason}'),
          ],
          const SizedBox(height: 16),
          const _SafetyNotice(),
          // 채팅 버튼 옆에서 잘못 누르지 않도록 화면 맨 아래에 둔다.
          if (_canLeave(party)) ...[
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: const ValueKey('leave-party'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: controller.isLoading.value ? null : _leaveParty,
                icon: const Icon(Icons.logout),
                label: const Text('택시팟 나가기'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _canLeave(TaxiPartyDetail party) =>
      party.isMember &&
      !party.isOwner &&
      party.departureAt.isAfter(DateTime.now()) &&
      party.recruitmentStatus != 'cancelled' &&
      party.recruitmentStatus != 'ended';

  bool _joining = false;
  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      if (widget.canJoin != null && !await widget.canJoin!()) return;
      if (!mounted) return;
      final joined = await controller.join();
      if (!mounted) return;
      if (joined && controller.party.value != null) {
        await widget.onJoined?.call(controller.party.value!);
      } else {
        await widget.onMembershipChanged?.call();
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Widget? _buildActionDock(TaxiPartyDetail party) {
    final canJoin = !party.isMember && party.status == 'recruiting';
    if ((!party.isMember && !canJoin) || party.chatStatus == 'expired') {
      return null;
    }
    final blockedLabel = canJoin ? widget.joinBlockedLabel?.call() : null;

    // 탭 안에 들어갈 때는 아래 탭 바가 하단 영역을 맡으므로,
    // 그림자와 별도 표면색 없이 화면 배경에 자연스럽게 이어지게 한다.
    final VoidCallback? primaryAction =
        controller.isLoading.value ||
            _joining ||
            blockedLabel != null ||
            (canJoin && !(widget.joinAllowed?.call() ?? true))
        ? null
        : canJoin
        ? _join
        : () => _openChat(party);

    return Material(
      elevation: widget.embedded ? 0 : 14,
      color: widget.embedded
          ? Theme.of(context).scaffoldBackgroundColor
          : Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        bottom: !widget.embedded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (blockedLabel == null &&
                  canJoin &&
                  !(widget.joinAllowed?.call() ?? true))
                TextButton(
                  onPressed: widget.onShowCurrent,
                  child: const Text('현재팟 확인하기'),
                ),
              ScaleButton(
                onTap: primaryAction,
                child: AbsorbPointer(
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: taxiAccent,
                        foregroundColor: taxiAccentForeground,
                        disabledBackgroundColor: taxiAccent.withValues(
                          alpha: 0.45,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: primaryAction,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            canJoin
                                ? Icons.group_add_outlined
                                : Icons.chat_bubble_outline,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            canJoin
                                ? blockedLabel ??
                                      ((widget.joinAllowed?.call() ?? true)
                                          ? '택시팟 참여하기'
                                          : '현재팟 확인 후 참여할 수 있어요')
                                : party.chatStatus == 'read_only'
                                ? '채팅 기록 보기'
                                : '채팅하기',
                          ),
                          if (!canJoin && party.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Badge(
                              backgroundColor: taxiAccentForeground,
                              textColor: Colors.white,
                              label: Text('${party.unreadCount}'),
                            ),
                          ],
                        ],
                      ),
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

/// 모집 상태 칩. 참여자 카드 제목 옆에 둔다.
class _RecruitmentStatusChip extends StatelessWidget {
  const _RecruitmentStatusChip({required this.status});

  final String status;

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
    final active = status == 'recruiting';
    final cancelled = status == 'cancelled';
    final chipColor = cancelled
        ? colors.errorContainer
        : active
        ? taxiTint(context)
        : colors.onSurface.withValues(alpha: 0.06);
    final chipForeground = cancelled
        ? colors.onErrorContainer
        : active
        ? taxiAccentText(context)
        : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: chipForeground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            labels[status] ?? status,
            style: theme.textTheme.labelSmall?.copyWith(
              color: chipForeground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 만나서 서로 확인하는 만남 코드. 출발 장소 바로 아래에 크게 보여준다.
class _MeetingCode extends StatelessWidget {
  const _MeetingCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('meeting-code'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: taxiTint(context, 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '만남 코드',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: taxiAccentText(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '만나면 서로 코드를 확인하세요',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            code,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteOverviewCard extends StatefulWidget {
  const _RouteOverviewCard({required this.party});

  final TaxiPartyDetail party;

  @override
  State<_RouteOverviewCard> createState() => _RouteOverviewCardState();
}

class _RouteOverviewCardState extends State<_RouteOverviewCard> {
  // 화면을 켜 둔 채 기다려도 "출발 n분 전"이 실제 시간과 어긋나지 않게 다시 그린다.
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _departureState(DateTime now) {
    final party = widget.party;
    if (party.recruitmentStatus == 'cancelled') return '취소된 팟';
    final difference = party.departureAt.difference(now);
    if (!party.departureAt.isAfter(now)) return '출발 시간 지남';
    final minutes = difference.inMinutes;
    if (minutes < 60) return '출발 ${minutes < 1 ? 1 : minutes}분 전';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours < 24) {
      return remainingMinutes == 0
          ? '출발 $hours시간 전'
          : '출발 $hours시간 $remainingMinutes분 전';
    }
    return '출발 ${difference.inDays}일 전';
  }

  String _dayLabel(DateTime now) {
    final departure = widget.party.departureAt;
    final days = DateTime(
      departure.year,
      departure.month,
      departure.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final date = DateFormat('M월 d일 (E)', 'ko').format(departure);
    return switch (days) {
      0 => '오늘 · $date',
      1 => '내일 · $date',
      _ => date,
    };
  }

  @override
  Widget build(BuildContext context) {
    final party = widget.party;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final upcoming =
        party.recruitmentStatus != 'cancelled' &&
        party.departureAt.isAfter(now);
    // 10분 안으로 다가오면 색을 채워 더 눈에 띄게 한다.
    final imminent =
        upcoming &&
        party.departureAt.difference(now) < const Duration(minutes: 10);

    return _HotongCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dayLabel(now),
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '${DateFormat('HH:mm').format(party.departureAt)} 출발',
                  key: const ValueKey('departure-clock'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                key: const ValueKey('departure-countdown'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: imminent
                      ? taxiAccent
                      : upcoming
                      ? taxiTint(context, 0.12)
                      : colors.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _departureState(now),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: imminent
                        ? taxiAccentForeground
                        : upcoming
                        ? taxiAccentText(context)
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          _RoutePoint(
            label: '출발',
            location: party.departureLocation.name,
            detail: party.departureSummary,
            continues: true,
            emphasizeDetail: true,
          ),
          _RoutePoint(
            label: '도착',
            location: party.destinationLocation.name,
            detail: party.destinationSummary,
          ),
          if (party.meetingCode != null) ...[
            const SizedBox(height: 20),
            _MeetingCode(code: party.meetingCode!),
          ],
          if (party.isMember && party.memberNote?.isNotEmpty == true) ...[
            const Divider(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, size: 18, color: taxiAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '참여자 안내',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(party.memberNote!),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).cardColor, width: 3),
    ),
  );
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.label,
    required this.location,
    this.detail,
    this.continues = false,
    this.emphasizeDetail = false,
  });

  final String label;
  final String location;
  final String? detail;
  final bool continues;
  // 만날 위치는 사람을 찾는 데 쓰이므로 거점 이름 못지않게 잘 보이게 한다.
  final bool emphasizeDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = detail?.trim() ?? '';
    final showDetail = description.isNotEmpty && description != location.trim();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                const SizedBox(height: 3),
                _RouteDot(
                  color: continues
                      ? taxiAccent
                      : theme.colorScheme.onSurfaceVariant,
                ),
                if (continues)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 6, bottom: 3),
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: continues ? 24 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (showDetail) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: emphasizeDetail
                          ? theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            )
                          : theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.party, this.onMemberTap});

  final TaxiPartyDetail party;
  final ValueChanged<TaxiMember>? onMemberTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _HotongCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '참여자',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              _RecruitmentStatusChip(status: party.recruitmentStatus),
              const Spacer(),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${party.currentMembers}',
                      style: TextStyle(color: taxiAccentText(context)),
                    ),
                    TextSpan(text: ' / ${party.maxMembers}명'),
                  ],
                ),
                key: const ValueKey('member-count'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '출발 전까지 미정원 시 참여자 합의 후 출발합니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final itemWidth = (constraints.maxWidth - gap) / 2;
              final members = <Widget>[
                ...party.members.map(
                  (member) => _MemberTile(
                    member: member,
                    width: itemWidth,
                    onTap: member.isMe || onMemberTap == null
                        ? null
                        : () => onMemberTap!(member),
                  ),
                ),
                ...List.generate(
                  party.remainingSeats,
                  (_) => _EmptyMemberTile(width: itemWidth),
                ),
              ];
              return Wrap(spacing: gap, runSpacing: gap, children: members);
            },
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.width, this.onTap});

  final TaxiMember member;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: colors.outlineVariant),
    );
    return SizedBox(
      width: width,
      child: Material(
        color: colors.surfaceContainerLowest,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: member.isOwner
                      ? taxiAccent
                      : colors.onSurfaceVariant,
                  foregroundColor: member.isOwner
                      ? taxiAccentForeground
                      : colors.surface,
                  child: Icon(
                    member.isOwner ? Icons.star_outline : Icons.person_outline,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (member.isMe)
                        Text(
                          '나',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: taxiAccentText(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMemberTile extends StatelessWidget {
  const _EmptyMemberTile({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
    return Container(
      width: width,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            foregroundColor: color,
            child: const Icon(Icons.person_add_alt_1_outlined, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '참여 대기 중',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotongCard extends StatelessWidget {
  const _HotongCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(25),
    ),
    child: child,
  );
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  // 신고 사유(노쇼, 정산 문제, 욕설·비매너)와 짝을 맞춘 이용 수칙
  static const _rules = [
    (title: '시간 지키기', body: '약속 시간까지 약속한 출발 장소에 도착해 주세요.'),
    (title: '못 가면 미리 알리기', body: '참여가 어려워지면 채팅으로 알리고 팟에서 나가 주세요.'),
    (
      title: '요금은 똑같이 나누기',
      body: '택시비는 탑승 인원이 똑같이 나눠 내고, 내린 뒤 바로 정산해 주세요.',
    ),
    (
      title: '서로 존중하기',
      body: '욕설이나 불쾌한 언행, 노쇼, 정산 거부는 신고 대상이며 이용이 제한될 수 있어요.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(height: 1.5);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 7),
              Text(
                '택시팟 이용 수칙',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final rule in _rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: bodyStyle),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${rule.title}  ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: rule.body),
                        ],
                      ),
                      style: bodyStyle,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '호통은 팟을 연결만 하며, 탑승·결제·정산은 참여자끼리 직접 진행합니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(message),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message.isEmpty ? '택시팟 정보를 불러오지 못했습니다.' : message),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: taxiAccent,
            foregroundColor: taxiAccentForeground,
          ),
          child: const Text('다시 시도'),
        ),
      ],
    ),
  );
}
