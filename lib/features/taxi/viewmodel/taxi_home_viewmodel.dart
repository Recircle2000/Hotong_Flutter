import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';

class TaxiHomeViewModel extends GetxController with WidgetsBindingObserver {
  TaxiHomeViewModel(
      {required TaxiRepository repository,
      required TaxiRealtimeService realtime})
      : _repository = repository,
        _realtime = realtime;

  final TaxiRepository _repository;
  final TaxiRealtimeService _realtime;
  final locations = <TaxiLocation>[].obs;
  final parties = <TaxiPartySummary>[].obs;
  final myParties = <TaxiPartySummary>[].obs;
  final history = <TaxiPartySummary>[].obs;
  final selectedDate = DateTime.now().obs;
  final departureLocationId = RxnInt();
  final destinationLocationId = RxnInt();
  final includeUnavailable = false.obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  StreamSubscription<TaxiRealtimeEvent>? _events;
  Timer? _refreshDebounce;
  bool _refreshPending = false;

  int get totalUnread =>
      myParties.fold(0, (sum, party) => sum + party.unreadCount);

  TaxiPartySummary? get currentParty =>
      myParties.isEmpty ? null : myParties.first;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _events = _realtime.events.listen((event) {
      if (event.type == 'message.created' || event.type == 'party.updated') {
        _refreshDebounce?.cancel();
        _refreshDebounce = Timer(const Duration(milliseconds: 250), refreshAll);
      }
    });
    unawaited(_realtime.connect());
    unawaited(refreshAll());
  }

  Future<void> refreshAll() async {
    if (isLoading.value) {
      _refreshPending = true;
      return;
    }
    isLoading.value = true;
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
        _repository.getMyParties(history: true),
      ]);
      locations.assignAll(results[0] as List<TaxiLocation>);
      parties.assignAll(results[1] as List<TaxiPartySummary>);
      myParties.assignAll(results[2] as List<TaxiPartySummary>);
      history.assignAll(results[3] as List<TaxiPartySummary>);
    } on TaxiApiException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = '택시팟 정보를 불러오지 못했습니다.';
    } finally {
      isLoading.value = false;
      if (_refreshPending && !isClosed) {
        _refreshPending = false;
        unawaited(refreshAll());
      }
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
    final next = DateTime(selectedDate.value.year, selectedDate.value.month,
        selectedDate.value.day + days);
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
    _refreshDebounce?.cancel();
    _events?.cancel();
    unawaited(_realtime.dispose());
    _repository.close();
    super.onClose();
  }

  TaxiRepository get repository => _repository;
  TaxiRealtimeService get realtime => _realtime;
}
