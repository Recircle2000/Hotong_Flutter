import 'dart:async';

import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/utils/taxi_ids.dart';

class TaxiChatViewModel extends GetxController {
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
  final RxBool isReadOnly;
  final RxBool isExpired;
  final isLoading = false.obs;
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
    _events = _realtime.events
        .where((event) => event.partyId == partyId)
        .listen((event) {
          final message = event.message;
          if (message != null && !isExpired.value) {
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
    _reconnects = _realtime.onConnected.listen((_) => unawaited(_resync()));
    _scheduleLifecycleTimers();
    unawaited(load());
  }

  /// 화면을 비우지 않고 서버의 메시지를 받아 빠진 것만 채운다.
  Future<void> _resync() async {
    if (isExpired.value || isLoading.value) return;
    try {
      final latest = await _repository.getMessages(partyId);
      if (isExpired.value) return;
      final known = {for (final item in messages) item.id};
      final missing = latest.where((item) => !known.contains(item.id)).toList();
      if (missing.isNotEmpty) {
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

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      messages.assignAll(await _repository.getMessages(partyId));
      await markLatestRead();
    } on TaxiApiException catch (error) {
      if (error.code == 'CHAT_EXPIRED') _expire();
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = '채팅을 불러오지 못했습니다.';
    } finally {
      isLoading.value = false;
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
    try {
      _realtime.sendMessage(
        partyId: partyId,
        clientMessageId: newTaxiUuid(),
        content: content,
      );
      // 연결 안내가 떠 있었다면 전송에 성공했으니 지운다.
      errorMessage.value = '';
      return true;
    } catch (_) {
      errorMessage.value = '채팅 서버에 연결하는 중입니다. 잠시 후 다시 시도해주세요.';
      return false;
    }
  }

  void _scheduleMarkRead() {
    _readDebounce?.cancel();
    _readDebounce = Timer(
      const Duration(seconds: 1),
      () => unawaited(markLatestRead()),
    );
  }

  Future<void> markLatestRead() async {
    _readDebounce?.cancel();
    if (messages.isEmpty) return;
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
    errorMessage.value = '';
  }

  @override
  void onClose() {
    // 모아 두던 읽음 처리가 남아 있으면 나가기 전에 보내 배지가 남지 않게 한다.
    if (_readDebounce?.isActive ?? false) unawaited(markLatestRead());
    _readDebounce?.cancel();
    _events?.cancel();
    _reconnects?.cancel();
    _readOnlyTimer?.cancel();
    _expiryTimer?.cancel();
    super.onClose();
  }
}
