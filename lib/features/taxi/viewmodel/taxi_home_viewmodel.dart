import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';

class TaxiHomeViewModel extends GetxController with WidgetsBindingObserver {
  TaxiHomeViewModel({
    required TaxiRepository repository,
    required TaxiRealtimeService realtime,
  }) : _repository = repository,
       _realtime = realtime;

  final TaxiRepository _repository;
  final TaxiRealtimeService _realtime;
  final locations = <TaxiLocation>[].obs;
  final parties = <TaxiPartySummary>[].obs;
  final myParties = <TaxiPartySummary>[].obs;
  final recentChats = <TaxiPartySummary>[].obs;
  final history = <TaxiPartySummary>[].obs;
  final selectedDate = DateTime.now().obs;
  final departureLocationId = RxnInt();
  final destinationLocationId = RxnInt();
  final includeUnavailable = false.obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  StreamSubscription<TaxiRealtimeEvent>? _events;
  final Map<String, Timer> _partyRefreshDebounces = {};
  bool _refreshPending = false;
  Completer<void>? _refreshCompletion;
  Timer? _expiryTimer;
  final hasLoaded = false.obs;

  bool get canCreateOrJoin =>
      hasLoaded.value &&
      !isLoading.value &&
      errorMessage.value.isEmpty &&
      myParties.isEmpty;

  void acceptParty(TaxiPartyDetail party) {
    myParties.removeWhere((item) => item.id == party.id);
    recentChats.removeWhere((item) => item.id == party.id);
    myParties.insert(0, party);
    hasLoaded.value = true;
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final now = DateTime.now();
    final deadlines =
        [...myParties, ...recentChats]
            .expand(
              (party) => [
                party.departureAt,
                party.chatWritableUntil,
                party.chatVisibleUntil,
              ],
            )
            .where((time) => time.isAfter(now))
            .toList()
          ..sort();
    if (deadlines.isNotEmpty) {
      _expiryTimer = Timer(
        deadlines.first.difference(now) + const Duration(seconds: 1),
        refreshAll,
      );
    }
  }

  int get totalUnread => [
    ...myParties,
    ...recentChats,
  ].fold(0, (sum, party) => sum + party.unreadCount);

  TaxiPartySummary? get currentParty =>
      myParties.isEmpty ? null : myParties.first;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _events = _realtime.events.listen(handleRealtimeEvent);
    unawaited(_realtime.connect());
    unawaited(refreshAll());
  }

  void handleRealtimeEvent(TaxiRealtimeEvent event) {
    if (event.type != 'message.created' && event.type != 'party.updated') {
      return;
    }
    final summary = event.party;
    if (summary != null) {
      _applyRealtimeParty(summary);
      return;
    }

    // 구버전 서버 이벤트에는 party 요약이 없다. 전체 화면 데이터를 다시
    // 받지 않고 해당 파티 하나만 조회해 호환성을 유지한다.
    final partyId = event.partyId;
    if (partyId == null) return;
    if (event.type == 'message.created' && event.message?.isMine == false) {
      _incrementKnownUnread(partyId);
    }
    _partyRefreshDebounces[partyId]?.cancel();
    _partyRefreshDebounces[partyId] = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_refreshParty(partyId)),
    );
  }

  void _applyRealtimeParty(TaxiPartySummary party) {
    _replaceKnownParty(parties, party);
    myParties.removeWhere((item) => item.id == party.id);
    recentChats.removeWhere((item) => item.id == party.id);

    if (party.isMember) {
      final isRecent =
          party.recruitmentStatus == 'ended' ||
          party.recruitmentStatus == 'cancelled';
      if (isRecent && party.chatStatus != 'expired') {
        recentChats.add(party);
        recentChats.sort((a, b) {
          final writable = (a.chatStatus == 'writable' ? 0 : 1).compareTo(
            b.chatStatus == 'writable' ? 0 : 1,
          );
          return writable != 0
              ? writable
              : b.departureAt.compareTo(a.departureAt);
        });
      } else if (!isRecent) {
        myParties.add(party);
        myParties.sort((a, b) => a.departureAt.compareTo(b.departureAt));
      }
    }
    _scheduleExpiry();
  }

  void _replaceKnownParty(
    RxList<TaxiPartySummary> target,
    TaxiPartySummary party,
  ) {
    final index = target.indexWhere((item) => item.id == party.id);
    if (index >= 0) target[index] = party;
  }

  void _incrementKnownUnread(String partyId) {
    for (final target in [myParties, recentChats]) {
      final index = target.indexWhere((party) => party.id == partyId);
      if (index >= 0) {
        final party = target[index];
        target[index] = party.copyWith(unreadCount: party.unreadCount + 1);
      }
    }
  }

  Future<void> _refreshParty(String partyId) async {
    _partyRefreshDebounces.remove(partyId)?.cancel();
    try {
      _applyRealtimeParty(await _repository.getParty(partyId));
    } catch (_) {
      // 실시간 보정 실패는 다음 이벤트이나 앱 복귀 시 다시 동기화한다.
    }
  }

  Future<void> refreshAll() async {
    if (isClosed) return;
    if (_refreshCompletion != null) {
      _refreshPending = true;
      return _refreshCompletion!.future;
    }
    final completion = Completer<void>();
    _refreshCompletion = completion;
    isLoading.value = true;
    try {
      do {
        _refreshPending = false;
        errorMessage.value = '';
        try {
          final results = await Future.wait([
            _repository.getLocations(),
            _repository.getParties(
              date: selectedDate.value,
              departureLocationId: departureLocationId.value,
              destinationLocationId: destinationLocationId.value,
              includeUnavailable: includeUnavailable.value,
            ),
            _repository.getMyParties(),
            _repository.getMyParties(scope: 'recent_chats'),
            _repository.getMyParties(scope: 'history'),
          ]);
          if (isClosed) return;
          locations.assignAll(results[0] as List<TaxiLocation>);
          parties.assignAll(results[1] as List<TaxiPartySummary>);
          myParties.assignAll(results[2] as List<TaxiPartySummary>);
          recentChats.assignAll(results[3] as List<TaxiPartySummary>);
          history.assignAll(results[4] as List<TaxiPartySummary>);
          hasLoaded.value = true;
          _scheduleExpiry();
        } on TaxiApiException catch (error) {
          if (!isClosed) errorMessage.value = error.message;
        } catch (_) {
          if (!isClosed) errorMessage.value = '택시팟 정보를 불러오지 못했습니다.';
        }
      } while (_refreshPending && !isClosed);
    } finally {
      isLoading.value = false;
      _refreshCompletion = null;
      completion.complete();
    }
  }

  void setDeparture(int? id) {
    departureLocationId.value = id;
    if (id != null && destinationLocationId.value == id) {
      destinationLocationId.value = null;
    }
    unawaited(refreshAll());
  }

  void setDestination(int? id) {
    destinationLocationId.value = id;
    if (id != null && departureLocationId.value == id) {
      departureLocationId.value = null;
    }
    unawaited(refreshAll());
  }

  void swapLocations() {
    final departure = departureLocationId.value;
    departureLocationId.value = destinationLocationId.value;
    destinationLocationId.value = departure;
    unawaited(refreshAll());
  }

  void changeDate(int days) {
    final next = DateTime(
      selectedDate.value.year,
      selectedDate.value.month,
      selectedDate.value.day + days,
    );
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final last = first.add(const Duration(days: 7));
    if (next.isBefore(first) || next.isAfter(last)) return;
    selectedDate.value = next;
    unawaited(refreshAll());
  }

  void toggleUnavailable(bool value) {
    includeUnavailable.value = value;
    unawaited(refreshAll());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_realtime.connect());
      unawaited(refreshAll());
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _partyRefreshDebounces.values) {
      timer.cancel();
    }
    _partyRefreshDebounces.clear();
    _expiryTimer?.cancel();
    _events?.cancel();
    unawaited(_realtime.dispose());
    _repository.close();
    super.onClose();
  }

  TaxiRepository get repository => _repository;
  TaxiRealtimeService get realtime => _realtime;
}
