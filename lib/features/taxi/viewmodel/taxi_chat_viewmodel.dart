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
  Timer? _readOnlyTimer;
  Timer? _expiryTimer;

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
            unawaited(markLatestRead());
          }
          if (event.type == 'party.updated') {
            unawaited(refreshStatus());
          }
        });
    _scheduleLifecycleTimers();
    unawaited(load());
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
      return true;
    } catch (_) {
      errorMessage.value = '채팅 서버에 연결하는 중입니다. 잠시 후 다시 시도해주세요.';
      return false;
    }
  }

  Future<void> markLatestRead() async {
    if (messages.isEmpty) return;
    try {
      await _repository.markRead(partyId, messages.last.id);
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
    _events?.cancel();
    _readOnlyTimer?.cancel();
    _expiryTimer?.cancel();
    super.onClose();
  }
}
