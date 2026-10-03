import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/utils/taxi_departure_time.dart';

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
  // 필터를 바꿔 검색 목록만 다시 받는 중.
  final isSearching = false.obs;
  final errorMessage = ''.obs;
  StreamSubscription<TaxiRealtimeEvent>? _events;
  final Map<String, Timer> _partyRefreshDebounces = {};
  bool _refreshPending = false;
  Completer<void>? _refreshCompletion;
  Timer? _expiryTimer;
  bool _wasBackgrounded = false;
  final hasLoaded = false.obs;
  // 관리자 제재 상태. 전체 새로고침(진입·복귀·생성/참여 직전) 때 함께 받는다.
  final restriction = Rxn<TaxiRestriction>();
  // 검색 탭이 보이는 동안에만 실시간 목록 변경 알림으로 다시 조회한다.
  bool _searchVisible = false;
  // 거점은 거의 바뀌지 않으므로 잠시 재사용해 새로고침 요청 수를 줄인다.
  static const _locationsMaxAge = Duration(minutes: 10);
  DateTime? _locationsFetchedAt;
  // 이용 기록은 내정보 탭에서만 쓰므로 필요할 때만 불러온다.
  bool _historyNeeded = false;
  Timer? _searchRefreshDebounce;
  int _searchRequestId = 0;

  bool get canCreateOrJoin =>
      hasLoaded.value &&
      !isLoading.value &&
      errorMessage.value.isEmpty &&
      myParties.isEmpty &&
      suspension == null;

  TaxiSanction? get suspension => restriction.value?.suspension;

  String? get userKey => restriction.value?.userKey;

  bool get termsRequired => restriction.value?.termsRequired ?? false;

  /// 이용약관 동의를 서버에 기록한 뒤 호출한다. 다음 새로고침 전에도 바로 반영한다.
  void markTermsAgreed() {
    final current = restriction.value;
    if (current == null || !current.termsRequired) return;
    restriction.value = TaxiRestriction(
      userKey: current.userKey,
      suspension: current.suspension,
      notice: current.notice,
    );
  }

  /// 안내를 확인한 제재는 다시 띄우지 않는다.
  Future<void> acknowledgeNotice(TaxiSanction notice) async {
    final current = restriction.value;
    if (current?.notice?.id == notice.id) {
      restriction.value = TaxiRestriction(
        userKey: current!.userKey,
        suspension: current.suspension,
        termsRequired: current.termsRequired,
      );
    }
    try {
      await _repository.acknowledgeSanction(notice.id);
    } catch (_) {
      // 전송에 실패하면 다음 진입 때 한 번 더 안내된다.
    }
  }

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
    _scheduleRecentPartyExpiry();
  }

  // 출발·취소로 현재팟에서 빠진 팟을 잠시 카드로 남겨 둔다.
  static const departedPartyCardWindow = Duration(hours: 2);
  static const cancelledPartyCardWindow = Duration(hours: 1);
  // 카드 표시 기한이 지나면 값이 바뀌어 화면을 다시 그린다. 서버 요청은 없다.
  final _recentPartyTick = 0.obs;
  Timer? _recentPartyTimer;

  /// 출발 후 2시간, 취소 후 1시간이 지나지 않은 팟 가운데 가장 최근 것.
  TaxiPartySummary? get recentEndedParty {
    _recentPartyTick.value;
    return _recentEndedParty(DateTime.now());
  }

  TaxiPartySummary? _recentEndedParty(DateTime now) {
    TaxiPartySummary? latest;
    for (final party in recentChats) {
      final until = _recentPartyCardUntil(party);
      if (until == null || !until.isAfter(now)) continue;
      if (latest == null ||
          _partyEndedAt(party).isAfter(_partyEndedAt(latest))) {
        latest = party;
      }
    }
    return latest;
  }

  // 취소된 팟은 채팅 작성 기한이 취소 시각이다(서버 chat_deadlines).
  static DateTime _partyEndedAt(TaxiPartySummary party) =>
      party.recruitmentStatus == 'cancelled'
      ? party.chatWritableUntil
      : party.departureAt;

  static DateTime? _recentPartyCardUntil(TaxiPartySummary party) =>
      switch (party.recruitmentStatus) {
        'cancelled' => party.chatWritableUntil.add(cancelledPartyCardWindow),
        'ended' => party.departureAt.add(departedPartyCardWindow),
        _ => null,
      };

  void _scheduleRecentPartyExpiry() {
    _recentPartyTimer?.cancel();
    final party = _recentEndedParty(DateTime.now());
    if (party == null) return;
    _recentPartyTimer = Timer(
      _recentPartyCardUntil(party)!.difference(DateTime.now()) +
          const Duration(seconds: 1),
      () {
        _recentPartyTick.value++;
        _scheduleRecentPartyExpiry();
      },
    );
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

  /// 내정보 탭이나 이용 기록 화면에 들어갈 때 호출한다. 이후 새로고침부터는 함께 갱신한다.
  Future<void> loadHistory() async {
    _historyNeeded = true;
    if (isClosed) return;
    try {
      final result = await _repository.getMyParties(scope: 'history');
      if (!isClosed) history.assignAll(result);
    } catch (_) {
      // 기록은 보조 정보라 실패해도 다른 화면은 그대로 둔다.
    }
  }

  void setSearchVisible(bool visible) {
    _searchVisible = visible;
    if (!visible) _searchRefreshDebounce?.cancel();
  }

  /// 팟 검색 목록만 현재 필터로 다시 받는다. 다른 목록은 실시간 이벤트로 맞춰진다.
  Future<void> refreshParties() async {
    if (isClosed) return;
    _searchRefreshDebounce?.cancel();
    final requestId = ++_searchRequestId;
    try {
      final result = await _repository.getParties(
        date: selectedDate.value,
        departureLocationId: departureLocationId.value,
        destinationLocationId: destinationLocationId.value,
        includeUnavailable: includeUnavailable.value,
      );
      // 필터를 바꾸는 사이 늦게 도착한 이전 응답은 버린다.
      if (isClosed || requestId != _searchRequestId) return;
      parties.assignAll(result);
    } catch (_) {
      // 목록 보정 실패는 다음 알림이나 탭 진입 때 다시 맞춘다.
    }
  }

  /// 필터·날짜를 바꿨을 때. 내 팟 목록은 그대로이므로 검색 목록만 다시 받는다.
  Future<void> _search() async {
    // 첫 로드 전이거나 직전 전체 조회가 실패했으면 전부 다시 받아 복구한다.
    if (!hasLoaded.value || errorMessage.isNotEmpty || isLoading.value) {
      return refreshAll();
    }
    if (isClosed) return;
    _searchRefreshDebounce?.cancel();
    final requestId = ++_searchRequestId;
    isSearching.value = true;
    try {
      final result = await _repository.getParties(
        date: selectedDate.value,
        departureLocationId: departureLocationId.value,
        destinationLocationId: destinationLocationId.value,
        includeUnavailable: includeUnavailable.value,
      );
      if (isClosed || requestId != _searchRequestId) return;
      parties.assignAll(result);
    } on TaxiApiException catch (error) {
      if (!isClosed && requestId == _searchRequestId) {
        errorMessage.value = error.message;
      }
    } catch (_) {
      if (!isClosed && requestId == _searchRequestId) {
        errorMessage.value = '택시팟 정보를 불러오지 못했습니다.';
      }
    } finally {
      if (!isClosed && requestId == _searchRequestId) {
        isSearching.value = false;
      }
    }
  }

  void _scheduleSearchRefresh() {
    // 숨겨진 동안의 변경은 검색 탭에 다시 들어올 때 한 번에 갱신한다.
    if (!_searchVisible || isClosed) return;
    // 팟 생성·참여가 몰려도 접속자 전원이 매번 재조회하지 않도록 잠시 모아서 한 번만 받는다.
    _searchRefreshDebounce?.cancel();
    _searchRefreshDebounce = Timer(
      const Duration(seconds: 2),
      () => unawaited(refreshParties()),
    );
  }

  void handleRealtimeEvent(TaxiRealtimeEvent event) {
    if (event.type == 'parties.changed') {
      _scheduleSearchRefresh();
      return;
    }
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

  void _applyRealtimeParty(TaxiPartySummary incoming) {
    // 메시지 알림의 요약에는 참여자 목록이 없다. 상태가 같으면 이미 가진 상세를
    // 그대로 두고 안 읽음 수만 맞춰, 현재팟 화면이 다시 조회하지 않게 한다.
    final known = knownParty(incoming.id);
    final party =
        incoming is! TaxiPartyDetail &&
            known is TaxiPartyDetail &&
            known.sameStateAs(incoming)
        ? known.copyWith(unreadCount: incoming.unreadCount)
        : incoming;
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

  /// 이미 받아 둔 내 팟(현재·최근 채팅) 요약. 없으면 null.
  TaxiPartySummary? knownParty(String partyId) =>
      [...myParties, ...recentChats].firstWhereOrNull((p) => p.id == partyId);

  /// 채팅을 읽고 나왔을 때 서버에 다시 묻지 않고 배지만 지운다.
  void markPartyRead(String partyId) {
    for (final target in [myParties, recentChats]) {
      final index = target.indexWhere((party) => party.id == partyId);
      if (index >= 0 && target[index].unreadCount != 0) {
        target[index] = target[index].copyWith(unreadCount: 0);
      }
    }
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
    // 전체 갱신이 목록도 새로 받으므로, 이전 필터로 보낸 목록 전용 요청 결과는 버린다.
    _searchRefreshDebounce?.cancel();
    _searchRequestId++;
    isSearching.value = false;
    isLoading.value = true;
    try {
      do {
        _refreshPending = false;
        errorMessage.value = '';
        try {
          final fetchedAt = _locationsFetchedAt;
          final reuseLocations =
              locations.isNotEmpty &&
              fetchedAt != null &&
              DateTime.now().difference(fetchedAt) < _locationsMaxAge;
          final home = await _repository.getHome(
            date: selectedDate.value,
            departureLocationId: departureLocationId.value,
            destinationLocationId: destinationLocationId.value,
            includeUnavailable: includeUnavailable.value,
            includeLocations: !reuseLocations,
            includeHistory: _historyNeeded,
          );
          if (isClosed) return;
          if (home.locations case final fetched?) {
            _locationsFetchedAt = DateTime.now();
            locations.assignAll(fetched);
          }
          parties.assignAll(home.parties);
          myParties.assignAll(home.myParties);
          recentChats.assignAll(home.recentChats);
          if (home.history case final fetched?) history.assignAll(fetched);
          restriction.value = home.restriction;
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
    unawaited(_search());
  }

  void setDestination(int? id) {
    destinationLocationId.value = id;
    if (id != null && departureLocationId.value == id) {
      departureLocationId.value = null;
    }
    unawaited(_search());
  }

  void swapLocations() {
    final departure = departureLocationId.value;
    departureLocationId.value = destinationLocationId.value;
    destinationLocationId.value = departure;
    unawaited(_search());
  }

  void changeDate(int days) {
    final next = DateTime(
      selectedDate.value.year,
      selectedDate.value.month,
      selectedDate.value.day + days,
    );
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final last = taxiLastSelectableDay(now: today);
    if (next.isBefore(first) || next.isAfter(last)) return;
    selectedDate.value = next;
    unawaited(_search());
  }

  void toggleUnavailable(bool value) {
    includeUnavailable.value = value;
    unawaited(_search());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      // 실제로 백그라운드에 다녀온 경우에만 끊겼을 수 있는 소켓을 새로 연결한다.
      // 제어 센터나 권한 팝업처럼 잠깐 비활성화된 경우는 기존 연결을 유지한다.
      if (_wasBackgrounded) {
        _wasBackgrounded = false;
        unawaited(_realtime.reconnect());
      } else {
        unawaited(_realtime.connect());
      }
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
    _searchRefreshDebounce?.cancel();
    _expiryTimer?.cancel();
    _recentPartyTimer?.cancel();
    _events?.cancel();
    unawaited(_realtime.dispose());
    _repository.close();
    super.onClose();
  }

  TaxiRepository get repository => _repository;
  TaxiRealtimeService get realtime => _realtime;
}
