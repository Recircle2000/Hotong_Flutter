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
  }) : _repository = repository,
       _realtime = realtime;

  final String partyId;
  final TaxiRepository _repository;
  final TaxiRealtimeService _realtime;
  final party = Rxn<TaxiPartyDetail>();
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  StreamSubscription<TaxiRealtimeEvent>? _events;

  @override
  void onInit() {
    super.onInit();
    _events = _realtime.events
        .where((event) => event.partyId == partyId)
        .listen((event) {
          if (event.type == 'party.updated') {
            unawaited(load());
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
    unawaited(load());
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
