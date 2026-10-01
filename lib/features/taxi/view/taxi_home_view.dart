import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hsro/core/network/authenticated_api_client.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/auth/repository/auth_repository.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_push_service.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/view/tabs/taxi_create_tab.dart';
import 'package:hsro/features/taxi/view/tabs/taxi_current_tab.dart';
import 'package:hsro/features/taxi/view/tabs/taxi_find_tab.dart';
import 'package:hsro/features/taxi/view/tabs/taxi_profile_tab.dart';
import 'package:hsro/features/taxi/view/taxi_chat_view.dart';
import 'package:hsro/features/taxi/view/taxi_party_create_view.dart';
import 'package:hsro/features/taxi/view/taxi_party_detail_view.dart';
import 'package:hsro/features/taxi/view/taxi_party_history_view.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_app_bar_leading.dart';
import 'package:hsro/features/taxi/widgets/taxi_confirm_dialog.dart';
import 'package:hsro/features/taxi/widgets/taxi_sanction_notice.dart';
import 'package:hsro/features/taxi/widgets/taxi_tab_bar.dart';

class TaxiHomeView extends StatefulWidget {
  const TaxiHomeView({
    super.key,
    required this.onLogout,
    this.onDeleteAccount,
    this.viewModel,
  });

  final Future<void> Function() onLogout;

  /// 회원 탈퇴. 서버가 거절하면 [AppAuthApiException]을 던진다.
  final Future<void> Function()? onDeleteAccount;
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
  Worker? _restrictionWorker;
  bool _showingNotice = false;
  TaxiPushService? _push;
  Worker? _pushWorker;

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
    controller.setSearchVisible(_index == 1);
    // 확인하지 않은 제재가 있으면 택시 화면에 들어올 때 한 번 안내한다.
    _restrictionWorker = ever(controller.restriction, (_) => _showNotice());
    final push = Get.isRegistered<TaxiPushService>()
        ? Get.find<TaxiPushService>()
        : null;
    if (push != null) {
      _push = push;
      push.attachHome();
      unawaited(push.sync());
      // 알림을 눌러 들어왔으면 그 팟의 채팅을 연다.
      _pushWorker = ever(push.pendingPartyId, (_) => _openPendingChat());
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingChat());
    }
  }

  @override
  void dispose() {
    _pushWorker?.dispose();
    _push?.detachHome();
    _restrictionWorker?.dispose();
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
    // 검색 탭이 보일 때만 실시간 목록 변경 알림으로 다시 조회한다.
    controller.setSearchVisible(index == 1);
    // 다른 탭에 있는 동안 놓친 변경이 보이도록 검색 탭 진입 시 목록만 갱신한다.
    if (index == 1) unawaited(controller.refreshParties());
    // 이용 기록은 내정보 탭에서만 보이므로 이때 불러온다.
    if (index == 3) unawaited(controller.loadHistory());
  }

  void _showCurrentParty() {
    if (!mounted || _busy) return;
    setState(() => _currentSection = 0);
    unawaited(_select(2));
  }

  TaxiPartySummary? get _selectedCurrentParty =>
      selectTaxiCurrentParty(controller.myParties, _selectedPartyId);

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

  Future<void> _showNotice() async {
    final notice = controller.restriction.value?.notice;
    if (notice == null || _showingNotice || !mounted) return;
    _showingNotice = true;
    try {
      await showTaxiSanctionNotice(
        context,
        notice,
        userKey: controller.userKey,
      );
      await controller.acknowledgeNotice(notice);
    } finally {
      _showingNotice = false;
    }
  }

  Future<bool> _canSubmit() async {
    await Future.wait([
      controller.refreshAll(),
      controller.refreshRestriction(),
    ]);
    if (!mounted) return false;
    final allowed = controller.canCreateOrJoin;
    if (!allowed) {
      final suspension = controller.suspension;
      _message(
        suspension != null
            ? taxiSuspensionMessage(suspension)
            : controller.errorMessage.isNotEmpty
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
    await _askPush();
  }

  /// 처음 팟을 만들거나 참여했을 때 알림을 받을지 한 번만 묻는다.
  Future<void> _askPush() async {
    final push = _push;
    if (push == null || !push.shouldAsk || !mounted) return;
    push.markAsked();
    final accepted = await showTaxiConfirm(
      context,
      title: '알림을 받을까요?',
      message: '새 메시지가 오거나 팟이 취소·변경되면 알려드려요. 내정보에서 언제든 끌 수 있어요.',
      action: '알림 받기',
      cancelTitle: '나중에',
    );
    if (!accepted || !mounted) return;
    await _setPush(true);
  }

  Future<void> _setPush(bool value) async {
    final push = _push;
    if (push == null) return;
    if (!value) {
      await push.disable();
      return;
    }
    if (await push.enable() || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('기기 설정에서 알림을 허용해주세요.'),
          action: SnackBarAction(
            label: '설정 열기',
            onPressed: () => unawaited(Geolocator.openAppSettings()),
          ),
        ),
      );
  }

  Future<void> _openPendingChat() async {
    final partyId = _push?.takePending();
    if (partyId == null || !mounted) return;
    await _openChat(partyId);
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
        joinBlockedLabel: () =>
            controller.suspension == null ? null : '이용 제한 중이라 참여할 수 없어요',
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
          await _askPush();
        },
      ),
    );
    await controller.refreshAll();
  }

  Future<void> _openRecentChat(TaxiPartySummary party) => _openChat(party.id);

  Future<void> _openChat(String partyId) async {
    try {
      final detail = await controller.repository.getParty(partyId);
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
          TaxiPartyHistoryView(controller: controller, onPartyTap: _openParty),
    );
    await controller.refreshAll();
  }

  Future<void> _deleteAccount() async {
    final deleteAccount = widget.onDeleteAccount;
    if (deleteAccount == null) return;
    final confirmed = await showTaxiDestructiveConfirm(
      context,
      title: '탈퇴할까요?',
      message:
          '학교 이메일 인증 정보와 택시팟 참여 기록이 삭제돼요. '
          '신고·이용 제한 기록은 운영 정책에 따라 일정 기간 보관돼요.',
      action: '탈퇴',
      cancelTitle: '취소',
      nativeIOS: true,
    );
    if (!confirmed || !mounted) return;
    // 탈퇴하면 이 화면이 사라지므로 앱 전체의 메신저와 내비게이터를 미리 잡아 둔다.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    var deleted = false;
    try {
      // 로그인이 살아 있을 때 이 기기를 알림 대상에서 뺀다.
      await _push?.unregister();
      await deleteAccount();
      deleted = true;
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('탈퇴가 완료됐어요.')));
    } on AppAuthApiException catch (error) {
      _message(error.message ?? '탈퇴하지 못했습니다. 다시 시도해주세요.');
    } catch (_) {
      _message('탈퇴하지 못했습니다. 다시 시도해주세요.');
    } finally {
      // 탈퇴가 거절되면 계정이 남아 있으므로 알림을 다시 등록한다.
      if (!deleted) unawaited(_push?.sync());
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    // 다시 쓰려면 학교 이메일 인증을 새로 해야 하므로 한 번 더 확인한다.
    final confirmed = await showTaxiDestructiveConfirm(
      context,
      title: '로그아웃할까요?',
      message: '다시 이용하려면 학교 이메일 인증이 필요해요.',
      action: '로그아웃',
      cancelTitle: '취소',
      nativeIOS: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      // 로그인이 살아 있을 때 이 기기를 알림 대상에서 뺀다.
      await _push?.unregister();
      await widget.onLogout();
    } catch (_) {
      _message('로그아웃하지 못했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
          leadingWidth: TaxiAppBarLeading.width,
          leading: TaxiAppBarLeading(
            enabled: !_busy,
            back: IconButton(
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
                        0 => TaxiCreateTab(
                          controller: controller,
                          createKey: _createKey,
                          busy: _busy,
                          onCreated: _created,
                          canSubmit: _canSubmit,
                          onBusyChanged: (busy) {
                            if (mounted) setState(() => _busy = busy);
                          },
                          onStepChanged: () {
                            if (mounted) setState(() {});
                          },
                          onShowCurrent: _showCurrentParty,
                          onAppeal: openTaxiAppeal,
                        ),
                        1 => TaxiFindPartiesTab(
                          controller: controller,
                          onPartyTap: _openParty,
                        ),
                        2 => TaxiCurrentTab(
                          controller: controller,
                          section: _currentSection,
                          selectedPartyId: _selectedPartyId,
                          detailKeyFor: (id) => _detailKeys.putIfAbsent(
                            id,
                            GlobalKey<TaxiPartyDetailViewState>.new,
                          ),
                          onSectionChanged: (section) =>
                              setState(() => _currentSection = section),
                          onPartySelected: (id) =>
                              setState(() => _selectedPartyId = id),
                          onOpenRecentChat: _openRecentChat,
                          onSearch: () => _select(1),
                          onCreate: () => _select(0),
                        ),
                        _ => TaxiProfileTab(
                          controller: controller,
                          onAppeal: openTaxiAppeal,
                          email: authService.currentUserEmail,
                          onHistory: _history,
                          onLogout: _busy ? null : _logout,
                          push: _push,
                          onPushChanged: _busy ? null : _setPush,
                          onDeleteAccount:
                              _busy || widget.onDeleteAccount == null
                              ? null
                              : _deleteAccount,
                        ),
                      },
              ),
          ],
        ),
        // 키보드가 뜰 때 탭 바를 빼면 본문 높이가 갑자기 바뀌어 화면이 흔들린다.
        // 탭 바는 항상 두고, Scaffold가 본문을 키보드 위로 줄이면서 탭 바는
        // 키보드 아래에 가려지게 둔다.
        bottomNavigationBar: TaxiTabBar(
          index: _index,
          onSelected: _select,
          unread: controller.totalUnread,
          enabled: !_busy,
        ),
      ),
    ),
  );
}
