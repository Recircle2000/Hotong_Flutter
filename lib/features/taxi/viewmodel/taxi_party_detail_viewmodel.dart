import 'dart:async';

import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';

class TaxiPartyDetailViewModel extends GetxController {
  TaxiPartyDetailViewModel({
    required this.partyId,
    required TaxiRepository repository,
    required TaxiRealtimeService realtime,
    TaxiPartyDetail? initial,
  }) : _repository = repository,
       _realtime = realtime,
       party = Rxn<TaxiPartyDetail>(initial);

  final String partyId;
  final TaxiRepository _repository;
  final TaxiRealtimeService _realtime;
  // 홈 화면이 이미 받은 상세가 있으면 그것으로 시작해 첫 조회를 생략한다.
  final Rxn<TaxiPartyDetail> party;
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  StreamSubscription<TaxiRealtimeEvent>? _events;
  // 이 뷰모델이 이미 다시 조회하기 시작한 실시간 요약. 같은 요약이 화면으로
  // 전달돼 [syncSummary]가 한 번 더 조회하는 것을 막는다.
  TaxiPartySummary? _handledSummary;

  @override
  void onInit() {
    super.onInit();
    _events = _realtime.events
        .where((event) => event.partyId == partyId)
        .listen((event) {
          if (event.type == 'party.updated') {
            final updated = event.party;
            _handledSummary = updated;
            // 서버가 상세를 실어 보내면 다시 조회하지 않는다.
            if (updated is TaxiPartyDetail) {
              party.value = updated;
            } else {
              unawaited(load());
            }
            return;
          }
          if (event.type == 'message.created') {
            final current = party.value;
            if (current == null) return;
            final unread = event.party?.unreadCount;
            if (unread != null) {
              party.value = current.copyWith(unreadCount: unread);
            } else if (event.message?.isMine == false) {
              party.value = current.copyWith(
                unreadCount: current.unreadCount + 1,
              );
            }
          }
        });
    if (party.value == null) unawaited(load());
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      party.value = await _repository.getParty(partyId);
    } on TaxiApiException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = '택시팟 정보를 불러오지 못했습니다.';
    } finally {
      isLoading.value = false;
    }
  }

  /// 홈 화면이 가진 요약과 맞춘다. 안 읽음 수는 조회 없이 반영하고,
  /// 인원·상태처럼 상세가 달라졌을 때만 다시 받는다.
  void syncSummary(TaxiPartySummary? summary) {
    final current = party.value;
    if (summary == null || current == null) return;
    if (identical(summary, _handledSummary)) return;
    if (!current.sameStateAs(summary)) {
      // 홈이 이미 상세를 받아 왔으면 그대로 쓰고, 요약뿐이면 다시 조회한다.
      if (summary is TaxiPartyDetail) {
        party.value = summary;
      } else {
        unawaited(load());
      }
    } else if (current.unreadCount != summary.unreadCount) {
      party.value = current.copyWith(unreadCount: summary.unreadCount);
    }
  }

  /// 채팅을 읽고 나왔을 때 배지를 바로 지운다.
  void markRead() {
    final current = party.value;
    if (current != null && current.unreadCount != 0) {
      party.value = current.copyWith(unreadCount: 0);
    }
  }

  Future<bool> join() =>
      _run(() async => party.value = await _repository.joinParty(partyId));
  Future<bool> leave() => _run(() async {
    await _repository.leaveParty(partyId);
    await load();
  });
  Future<bool> cancel() => _run(() async {
    await _repository.cancelParty(partyId);
    await load();
  });
  Future<bool> setRecruitment(bool open) => _run(() async {
    await _repository.setRecruitment(partyId, open);
    await load();
  });
  Future<bool> updateDetails({
    required String departureSummary,
    String? destinationSummary,
    String? memberNote,
    int? departureLocationId,
    int? destinationLocationId,
    DateTime? departureAt,
    int? maxMembers,
  }) => _run(() async {
    party.value = await _repository.updateParty(
      partyId,
      departureSummary: departureSummary,
      destinationSummary: destinationSummary,
      memberNote: memberNote,
      departureLocationId: departureLocationId,
      destinationLocationId: destinationLocationId,
      departureAt: departureAt,
      maxMembers: maxMembers,
    );
  });

  Future<bool> _run(Future<void> Function() action) async {
    if (isLoading.value) return false;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await action();
      return true;
    } on TaxiApiException catch (error) {
      errorMessage.value = error.message;
      return false;
    } catch (_) {
      errorMessage.value = '요청을 처리하지 못했습니다.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _events?.cancel();
    super.onClose();
  }
}
