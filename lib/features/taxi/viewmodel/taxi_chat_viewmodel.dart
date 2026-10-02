import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/utils/taxi_ids.dart';

class TaxiChatViewModel extends GetxController with WidgetsBindingObserver {
  TaxiChatViewModel({
    required this.partyId,
    required DateTime readOnlyAt,
    required DateTime expiresAt,
    required bool initiallyReadOnly,
    required bool initiallyExpired,
    required TaxiRepository repository,
    required TaxiRealtimeService realtime,
  }) : writableUntil = readOnlyAt.obs,
       visibleUntil = expiresAt.obs,
       isReadOnly = initiallyReadOnly.obs,
       isExpired = initiallyExpired.obs,
       _repository = repository,
       _realtime = realtime;

  final String partyId;
  final Rx<DateTime> writableUntil;
  final Rx<DateTime> visibleUntil;
  final TaxiRepository _repository;
  final TaxiRealtimeService _realtime;
  final messages = <TaxiMessage>[].obs;

  /// 보냈지만 아직 서버 확인을 받지 못한 내 메시지. 목록 맨 아래에 이어서 보여준다.
  final pending = <TaxiPendingMessage>[].obs;
  final _pendingTimers = <String, Timer>{};
  static const _sendTimeout = Duration(seconds: 10);
  final RxBool isReadOnly;
  final RxBool isExpired;
  final isLoading = false.obs;

  /// 첫 불러오기가 실패해 보여줄 메시지가 없을 때. 화면에서 다시 시도를 띄운다.
  final loadFailed = false.obs;

  /// 지금 가진 것보다 오래된 메시지가 서버에 남아 있는지.
  final hasOlder = false.obs;
  final isLoadingOlder = false.obs;
  int? _olderBeforeId;
  final errorMessage = ''.obs;
  StreamSubscription<TaxiRealtimeEvent>? _events;
  StreamSubscription<void>? _reconnects;
  Timer? _readOnlyTimer;
  Timer? _expiryTimer;
  // 메시지가 연달아 올 때마다 읽음 처리(DB 쓰기)를 보내지 않도록 잠시 모은다.
  Timer? _readDebounce;
  int? _lastMarkedId;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _events = _realtime.events.listen((event) {
      if (event.type == 'error') {
        // 구버전 서버의 오류에는 party_id가 없어 열려 있는 채팅방의 것으로 본다.
        if (event.partyId == null || event.partyId == partyId) {
          _handleSendError(event);
        }
        return;
      }
      if (event.partyId != partyId) return;
      final message = event.message;
      if (message != null && !isExpired.value) {
        _confirmPending(message);
        if (!messages.any((item) => item.id == message.id)) {
          messages.add(message);
          messages.sort((a, b) => a.id.compareTo(b.id));
        }
        if (message.isMine) {
          // 서버가 보낸 사람을 그 메시지까지 읽은 것으로 처리한다.
          _readDebounce?.cancel();
          if (message.id > (_lastMarkedId ?? 0)) _lastMarkedId = message.id;
        } else {
          _scheduleMarkRead();
        }
      }
      if (event.type == 'party.updated') {
        unawaited(refreshStatus());
      }
    });
    // 재연결되면 끊긴 동안 놓친 메시지를 다시 불러온다.
    // 그다음 아직 확인받지 못한 메시지를 다시 보낸다(서버가 중복을 걸러 준다).
    _reconnects = _realtime.onConnected.listen(
      (_) => unawaited(_resync().then((_) => _flushPending())),
    );
    _scheduleLifecycleTimers();
    unawaited(load());
  }

  /// 화면을 비우지 않고 서버의 메시지를 받아 빠진 것만 채운다.
  Future<void> _resync() async {
    if (isExpired.value || isLoading.value) return;
    // 처음 불러오기에 실패한 상태였다면 재연결을 계기로 처음부터 다시 받는다.
    if (loadFailed.value) return load();
    try {
      final page = await _repository.getMessagePage(partyId);
      if (isExpired.value) return;
      final latest = page.items;
      latest.forEach(_confirmPending);
      final known = {for (final item in messages) item.id};
      final missing = latest.where((item) => !known.contains(item.id)).toList();
      if (messages.isNotEmpty &&
          latest.isNotEmpty &&
          missing.length == latest.length &&
          page.nextBeforeId != null) {
        // 오래 끊겨 한 쪽 넘게 놓쳤다. 이어 붙이면 중간이 비므로 최근 쪽으로 바꾸고,
        // 그 앞은 위로 올릴 때 다시 불러온다.
        messages.assignAll(latest);
        _setOlderCursor(page.nextBeforeId);
      } else if (missing.isNotEmpty) {
        messages.addAll(missing);
        messages.sort((a, b) => a.id.compareTo(b.id));
      }
      errorMessage.value = '';
      await markLatestRead();
      unawaited(refreshStatus());
    } catch (_) {}
  }

  void _scheduleLifecycleTimers() {
    _readOnlyTimer?.cancel();
    _expiryTimer?.cancel();
    final untilReadOnly = writableUntil.value.difference(DateTime.now());
    if (untilReadOnly.isNegative) {
      isReadOnly.value = true;
    } else {
      _readOnlyTimer = Timer(untilReadOnly, () => isReadOnly.value = true);
    }
    final untilExpiry = visibleUntil.value.difference(DateTime.now());
    if (untilExpiry.isNegative) {
      _expire();
    } else {
      _expiryTimer = Timer(untilExpiry, _expire);
    }
  }

  void _setOlderCursor(int? beforeId) {
    _olderBeforeId = beforeId;
    hasOlder.value = beforeId != null;
  }

  Future<void> load() async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final page = await _repository.getMessagePage(partyId);
      page.items.forEach(_confirmPending);
      messages.assignAll(page.items);
      _setOlderCursor(page.nextBeforeId);
      loadFailed.value = false;
      await markLatestRead();
    } on TaxiApiException catch (error) {
      if (error.code == 'CHAT_EXPIRED') _expire();
      errorMessage.value = error.message;
      loadFailed.value = messages.isEmpty && !isExpired.value;
    } catch (_) {
      errorMessage.value = '채팅을 불러오지 못했습니다.';
      loadFailed.value = messages.isEmpty;
    } finally {
      isLoading.value = false;
    }
  }

  /// 지금 가진 가장 오래된 메시지보다 앞의 한 쪽을 불러와 위에 붙인다.
  Future<void> loadOlder() async {
    final beforeId = _olderBeforeId;
    if (beforeId == null || isLoadingOlder.value || isExpired.value) return;
    isLoadingOlder.value = true;
    try {
      final page = await _repository.getMessagePage(
        partyId,
        beforeId: beforeId,
      );
      // 불러오는 사이 목록이 새로 바뀌었으면(재동기화) 맞지 않는 결과는 버린다.
      if (isExpired.value || _olderBeforeId != beforeId) return;
      final known = {for (final item in messages) item.id};
      final older = page.items.where((item) => !known.contains(item.id));
      messages.insertAll(0, older);
      _setOlderCursor(page.nextBeforeId);
    } catch (_) {
      // 실패하면 그대로 두고, 다시 위로 올릴 때 재시도한다.
    } finally {
      isLoadingOlder.value = false;
    }
  }

  bool send(String rawContent) {
    final content = rawContent.trim();
    if (isReadOnly.value ||
        isExpired.value ||
        content.isEmpty ||
        content.length > 500) {
      return false;
    }
    final item = TaxiPendingMessage(
      clientMessageId: newTaxiUuid(),
      content: content,
      createdAt: DateTime.now(),
    );
    pending.add(item);
    errorMessage.value = '';
    _transmit(item);
    return true;
  }

  /// 소켓으로 내보내고, 일정 시간 안에 확인이 없으면 실패로 표시한다.
  /// 연결이 끊긴 상태면 전송 중으로 두었다가 재연결될 때 다시 보낸다.
  void _transmit(TaxiPendingMessage item) {
    _pendingTimers.remove(item.clientMessageId)?.cancel();
    _pendingTimers[item.clientMessageId] = Timer(
      _sendTimeout,
      () => _markFailed(item.clientMessageId, '전송하지 못했어요.'),
    );
    try {
      _realtime.sendMessage(
        partyId: partyId,
        clientMessageId: item.clientMessageId,
        content: item.content,
      );
    } catch (_) {
      // 연결 중. 재연결되면 _flushPending이 다시 보낸다.
    }
  }

  void _flushPending() {
    for (final item in pending.where((item) => !item.isFailed).toList()) {
      _transmit(item);
    }
  }

  /// 서버가 돌려준 내 메시지와 짝이 맞는 전송 중 메시지를 지운다.
  void _confirmPending(TaxiMessage message) {
    if (!message.isMine || pending.isEmpty) return;
    final clientId = message.clientMessageId;
    // 구버전 서버는 client_message_id를 돌려주지 않아 내용으로 짝짓는다.
    final index = clientId != null
        ? pending.indexWhere((item) => item.clientMessageId == clientId)
        : pending.indexWhere((item) => item.content == message.content);
    if (index < 0) return;
    _pendingTimers.remove(pending[index].clientMessageId)?.cancel();
    pending.removeAt(index);
  }

  void _markFailed(String clientMessageId, String error) {
    _pendingTimers.remove(clientMessageId)?.cancel();
    final index = pending.indexWhere(
      (item) => item.clientMessageId == clientMessageId,
    );
    if (index < 0) return;
    pending[index] = pending[index].withStatus(
      TaxiPendingStatus.failed,
      error: error,
    );
  }

  void _handleSendError(TaxiRealtimeEvent event) {
    final message = event.errorMessage ?? '메시지를 보내지 못했어요.';
    // 구버전 서버는 어떤 메시지인지 알려주지 않아 가장 오래 기다린 것으로 본다.
    final target =
        event.clientMessageId ??
        pending.where((item) => !item.isFailed).firstOrNull?.clientMessageId;
    if (target != null &&
        pending.any((item) => item.clientMessageId == target)) {
      _markFailed(target, message);
    } else {
      errorMessage.value = message;
    }
    // 대화가 종료됐거나 팟에서 빠진 경우 입력창 상태를 맞춘다.
    if (event.code == 'CHAT_READ_ONLY' || event.code == 'MEMBERSHIP_REQUIRED') {
      unawaited(refreshStatus());
    }
  }

  /// 실패한 메시지를 같은 식별자로 다시 보낸다. 서버가 중복을 걸러 준다.
  void retryPending(String clientMessageId) {
    final index = pending.indexWhere(
      (item) => item.clientMessageId == clientMessageId,
    );
    if (index < 0 || isReadOnly.value || isExpired.value) return;
    final item = pending[index].withStatus(TaxiPendingStatus.sending);
    pending[index] = item;
    _transmit(item);
  }

  void discardPending(String clientMessageId) {
    _pendingTimers.remove(clientMessageId)?.cancel();
    pending.removeWhere((item) => item.clientMessageId == clientMessageId);
  }

  void _scheduleMarkRead() {
    _readDebounce?.cancel();
    _readDebounce = Timer(
      const Duration(seconds: 1),
      () => unawaited(markLatestRead()),
    );
  }

  /// 앱이 화면에 떠 있을 때만 읽은 것으로 본다. (테스트처럼 상태를 모르면 떠 있는 것으로 본다.)
  bool get _isAppVisible {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드에서 받은 메시지는 돌아왔을 때 읽음 처리한다.
    if (state == AppLifecycleState.resumed) unawaited(markLatestRead());
  }

  Future<void> markLatestRead() async {
    _readDebounce?.cancel();
    if (messages.isEmpty || !_isAppVisible) return;
    final latestId = messages.last.id;
    // 이미 보낸 위치면 다시 보내지 않는다.
    if (_lastMarkedId != null && latestId <= _lastMarkedId!) return;
    try {
      await _repository.markRead(partyId, latestId);
      _lastMarkedId = latestId;
    } catch (_) {}
  }

  Future<void> refreshStatus() async {
    try {
      final party = await _repository.getParty(partyId);
      writableUntil.value = party.chatWritableUntil;
      visibleUntil.value = party.chatVisibleUntil;
      isReadOnly.value = party.chatStatus != 'writable';
      if (party.chatStatus == 'expired') _expire();
      _scheduleLifecycleTimers();
    } catch (_) {}
  }

  void _expire() {
    isExpired.value = true;
    isReadOnly.value = true;
    messages.clear();
    _setOlderCursor(null);
    loadFailed.value = false;
    _clearPending();
    errorMessage.value = '';
  }

  void _clearPending() {
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
    pending.clear();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    // 모아 두던 읽음 처리가 남아 있으면 나가기 전에 보내 배지가 남지 않게 한다.
    if (_readDebounce?.isActive ?? false) unawaited(markLatestRead());
    _readDebounce?.cancel();
    _events?.cancel();
    _reconnects?.cancel();
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
    _readOnlyTimer?.cancel();
    _expiryTimer?.cancel();
    super.onClose();
  }
}
