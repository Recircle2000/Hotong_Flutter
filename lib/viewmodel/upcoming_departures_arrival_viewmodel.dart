import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/shuttle_models.dart';
import '../repository/shuttle_repository.dart';
import '../utils/env_config.dart';
import 'settings_viewmodel.dart';

enum ArrivalBranchMode {
  fallbackDefaultWidget,
  asanLocationArrival,
  cheonanLocationArrival,
  noNearbyStop,
}

class NearbyShuttleStop {
  const NearbyShuttleStop({
    required this.station,
    required this.distanceMeters,
  });

  final ShuttleStation station;
  final double distanceMeters;
}

class BusStopCandidate {
  const BusStopCandidate({
    required this.routeKey,
    required this.routeName,
    required this.stopName,
    required this.nodeId,
    required this.nodeNumber,
    required this.nodeOrder,
    required this.latitude,
    required this.longitude,
  });

  final String routeKey;
  final String routeName;
  final String stopName;
  final String nodeId;
  final String nodeNumber;
  final int nodeOrder;
  final double latitude;
  final double longitude;
}

class NearbyBusStop {
  const NearbyBusStop({
    required this.displayName,
    required this.distanceMeters,
    required this.latitude,
    required this.longitude,
    required this.routeStops,
  });

  final String displayName;
  final double distanceMeters;
  final double latitude;
  final double longitude;
  final Map<String, BusStopCandidate> routeStops;
}

class AsanShuttleArrival {
  const AsanShuttleArrival({
    required this.routeId,
    required this.routeName,
    required this.stationName,
    required this.arrivalTime,
    required this.minutesLeft,
    required this.scheduleId,
    required this.isLastBus,
  });

  final int routeId;
  final String routeName;
  final String stationName;
  final DateTime arrivalTime;
  final int minutesLeft;
  final int scheduleId;
  final bool isLastBus;
}

class AsanRealtimeBusArrival {
  const AsanRealtimeBusArrival({
    required this.routeKey,
    required this.routeName,
    required this.targetStopName,
    required this.currentNodeName,
    required this.vehicleNumber,
    required this.stopsAway,
    required this.badgeText,
  });

  final String routeKey;
  final String routeName;
  final String targetStopName;
  final String currentNodeName;
  final String vehicleNumber;
  final int stopsAway;
  final String badgeText;
}

class UpcomingDeparturesArrivalViewModel extends GetxController
    with WidgetsBindingObserver {
  UpcomingDeparturesArrivalViewModel({
    ShuttleRepository? shuttleRepository,
  }) : _shuttleRepository = shuttleRepository ?? ShuttleRepository();

  static const List<int> _asanShuttleStationIds = <int>[
    1,
    3,
    9,
    10,
    11,
    12,
    14,
    15,
    18,
    19,
    20,
    21,
  ];

  static const List<String> _asanBusRouteKeys = <String>[
    '810_UP',
    '820_UP',
    '821_UP',
    '822_UP',
    '1000_UP',
    '1001_UP',
    '순환5_UP',
  ];

  final ShuttleRepository _shuttleRepository;
  final SettingsViewModel settingsViewModel = Get.find<SettingsViewModel>();

  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isWidgetEnabled = true.obs;
  final RxBool isLocationReady = false.obs;
  final RxBool isLocationPermissionGranted = false.obs;
  final RxString error = ''.obs;
  final RxString statusMessage = '위치를 확인하는 중입니다.'.obs;
  final RxString selectedCampus = ''.obs;
  final Rx<ArrivalBranchMode> branchMode =
      ArrivalBranchMode.noNearbyStop.obs;
  final RxnString fallbackCampus = RxnString();
  final RxBool shouldShowFallbackUpcomingWidget = false.obs;
  final Rxn<Position> currentPosition = Rxn<Position>();
  final Rxn<NearbyShuttleStop> nearbyShuttleStop = Rxn<NearbyShuttleStop>();
  final Rxn<NearbyBusStop> nearbyBusStop = Rxn<NearbyBusStop>();
  final RxList<AsanShuttleArrival> shuttleArrivals =
      <AsanShuttleArrival>[].obs;
  final RxList<AsanRealtimeBusArrival> busArrivals =
      <AsanRealtimeBusArrival>[].obs;
  final RxString shuttleEmptyMessage = '주변 정류장 없음'.obs;
  final RxString busEmptyMessage = '주변 정류장 없음'.obs;

  final Map<int, ShuttleStation> _shuttleStationsById =
      <int, ShuttleStation>{};
  final Map<String, List<BusStopCandidate>> _busStopCache =
      <String, List<BusStopCandidate>>{};
  final Map<int, String> _routeNameCache = <int, String>{};

  Worker? _campusWorker;
  StreamSubscription<Position>? _positionSubscription;
  WebSocketChannel? _webSocketChannel;
  StreamSubscription<dynamic>? _webSocketSubscription;
  Timer? _refreshTimer;
  Function? _onRefreshCallback;

  DateTime? _lastShuttleRefreshAt;
  Map<String, dynamic>? _latestRealtimePayload;

  bool get shouldUseRefreshCountdown =>
      branchMode.value == ArrivalBranchMode.asanLocationArrival &&
      !shouldShowFallbackUpcomingWidget.value &&
      isWidgetEnabled.value;

  int get refreshIntervalSeconds => 30;

  String get campusDescription {
    switch (branchMode.value) {
      case ArrivalBranchMode.fallbackDefaultWidget:
        return '캠퍼스 내부로 인식되어 기본 출발 위젯을 사용합니다.';
      case ArrivalBranchMode.asanLocationArrival:
        return '현재 위치 기준 아산 주변 셔틀 및 시내버스 도착 정보를 표시합니다.';
      case ArrivalBranchMode.cheonanLocationArrival:
        return '천안 위치기반 분기는 아직 준비 중입니다.';
      case ArrivalBranchMode.noNearbyStop:
        return '위치 확인 또는 주변 정류장 탐색 결과를 기다리는 중입니다.';
    }
  }

  void setRefreshCallback(Function callback) {
    _onRefreshCallback = callback;
  }

  void clearRefreshCallback() {
    _onRefreshCallback = null;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    selectedCampus.value = settingsViewModel.selectedCampus.value;

    _campusWorker = ever<String>(settingsViewModel.selectedCampus, (campus) {
      selectedCampus.value = campus;
      if (isWidgetEnabled.value) {
        loadData(
          silent: true,
          forceNetworkRefresh: true,
        );
      }
    });

    if (settingsViewModel.isLocationBasedDepartureWidgetEnabled.value) {
      Future<void>.microtask(_activate);
    } else {
      isWidgetEnabled.value = false;
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _campusWorker?.dispose();
    _stopRefreshTimer();
    _disconnectBusWebSocket();
    _cancelPositionStream();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopRefreshTimer();
      _disconnectBusWebSocket();
      return;
    }

    if (state == AppLifecycleState.resumed && isWidgetEnabled.value) {
      loadData(
        silent: true,
        forceNetworkRefresh: true,
      );
    }
  }

  Future<void> setWidgetEnabled(bool enabled) async {
    if (enabled == isWidgetEnabled.value) {
      return;
    }

    isWidgetEnabled.value = enabled;

    if (enabled) {
      await _activate();
      return;
    }

    _stopRefreshTimer();
    _disconnectBusWebSocket();
    await _cancelPositionStream();
  }

  Future<void> refreshLocation() {
    return loadData(
      forceNetworkRefresh: true,
      forceLocationRefresh: true,
    );
  }

  Future<void> loadData({
    bool silent = false,
    bool forceNetworkRefresh = false,
    bool forceLocationRefresh = false,
  }) async {
    if (!isWidgetEnabled.value) {
      return;
    }

    _stopRefreshTimer();

    if (!silent) {
      isLoading.value = true;
    }
    isRefreshing.value = true;
    error.value = '';

    try {
      await _loadShuttleStationsIfNeeded();

      final bool canUseLocation = await _ensureLocationPermission();
      if (!canUseLocation) {
        branchMode.value = ArrivalBranchMode.noNearbyStop;
        return;
      }

      await _ensurePositionStream();

      Position position;
      if (forceLocationRefresh || currentPosition.value == null) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        currentPosition.value = position;
      } else {
        position = currentPosition.value!;
      }

      await _evaluateBranchForPosition(
        position,
        forceNetworkRefresh: forceNetworkRefresh,
      );
    } catch (e) {
      error.value = '위치 기반 정보를 불러오지 못했습니다.';
      statusMessage.value = '위치 기반 정보를 갱신하는 중 문제가 발생했습니다.';
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
      _onRefreshCallback?.call();
      _restartRefreshTimerIfNeeded();
    }
  }

  Future<void> _activate() async {
    if (!isWidgetEnabled.value) {
      isWidgetEnabled.value = true;
    }

    await loadData(
      forceNetworkRefresh: true,
      forceLocationRefresh: true,
    );
  }

  Future<void> _ensurePositionStream() async {
    if (_positionSubscription != null) {
      return;
    }

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (Position position) async {
        currentPosition.value = position;
        if (!isWidgetEnabled.value) {
          return;
        }

        await _evaluateBranchForPosition(
          position,
          forceNetworkRefresh: false,
        );
      },
      onError: (Object _) {
        statusMessage.value = '현재 위치를 추적하지 못했습니다.';
        isLocationReady.value = false;
      },
    );
  }

  Future<void> _cancelPositionStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<bool> _ensureLocationPermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      isLocationReady.value = false;
      isLocationPermissionGranted.value = false;
      statusMessage.value = '위치 서비스를 켜야 위치기반 위젯을 사용할 수 있습니다.';
      _clearLocationBranchData();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final bool granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    isLocationPermissionGranted.value = granted;
    isLocationReady.value = granted;

    if (!granted) {
      statusMessage.value = permission == LocationPermission.deniedForever
          ? '위치 권한이 영구적으로 거부되었습니다.'
          : '위치 권한을 허용해 주세요.';
      _clearLocationBranchData();
      return false;
    }

    return true;
  }

  Future<void> _loadShuttleStationsIfNeeded() async {
    if (_shuttleStationsById.isNotEmpty) {
      return;
    }

    final List<ShuttleStation> stations = await _shuttleRepository.fetchStations();
    for (final ShuttleStation station in stations) {
      _shuttleStationsById[station.id] = station;
    }
  }

  Future<void> _evaluateBranchForPosition(
    Position position, {
    required bool forceNetworkRefresh,
  }) async {
    currentPosition.value = position;

    final ShuttleStation? asanCampusStation = _shuttleStationsById[1];
    if (asanCampusStation != null) {
      final double asanDistance = _distanceMeters(
        position.latitude,
        position.longitude,
        asanCampusStation.latitude,
        asanCampusStation.longitude,
      );
      if (asanDistance <= 1000) {
        _applyFallbackBranch(
          campus: '아산',
          message: '현재 위치가 아산 캠퍼스로 인식되어 기본 출발 위젯을 표시합니다.',
        );
        return;
      }
    }

    final ShuttleStation? cheonanCampusStation = _shuttleStationsById[14];
    if (cheonanCampusStation != null) {
      final double cheonanDistance = _distanceMeters(
        position.latitude,
        position.longitude,
        cheonanCampusStation.latitude,
        cheonanCampusStation.longitude,
      );
      if (cheonanDistance <= 500) {
        _applyFallbackBranch(
          campus: '천안',
          message: '현재 위치가 천안 캠퍼스로 인식되어 기본 출발 위젯을 표시합니다.',
        );
        return;
      }
    }

    shouldShowFallbackUpcomingWidget.value = false;
    fallbackCampus.value = null;

    if (selectedCampus.value == '아산') {
      branchMode.value = ArrivalBranchMode.asanLocationArrival;
      await _updateAsanBranch(position, forceNetworkRefresh: forceNetworkRefresh);
      return;
    }

    if (selectedCampus.value == '천안') {
      branchMode.value = ArrivalBranchMode.cheonanLocationArrival;
      _disconnectBusWebSocket();
      shuttleArrivals.clear();
      busArrivals.clear();
      nearbyShuttleStop.value = null;
      nearbyBusStop.value = null;
      shuttleEmptyMessage.value = '천안 위치기반 분기 준비 중';
      busEmptyMessage.value = '천안 위치기반 분기 준비 중';
      statusMessage.value = '천안 위치기반 분기는 다음 단계에서 구현됩니다.';
      return;
    }

    branchMode.value = ArrivalBranchMode.noNearbyStop;
    statusMessage.value = '캠퍼스 설정을 확인해 주세요.';
    _clearArrivalResults();
  }

  Future<void> _updateAsanBranch(
    Position position, {
    required bool forceNetworkRefresh,
  }) async {
    final NearbyShuttleStop? nextShuttleStop = _findNearbyShuttleStop(position);
    final NearbyBusStop? nextBusStop = await _findNearbyBusStop(position);

    final int? previousShuttleStationId = nearbyShuttleStop.value?.station.id;
    final String? previousBusStopName = nearbyBusStop.value?.displayName;

    nearbyShuttleStop.value = nextShuttleStop;
    nearbyBusStop.value = nextBusStop;

    if (nextShuttleStop == null) {
      shuttleArrivals.clear();
      shuttleEmptyMessage.value = '주변 정류장 없음';
      _lastShuttleRefreshAt = null;
    } else if (forceNetworkRefresh ||
        previousShuttleStationId != nextShuttleStop.station.id ||
        _shouldRefreshShuttleData()) {
      await _refreshNearbyShuttleArrivals(nextShuttleStop);
    }

    if (nextBusStop == null) {
      _disconnectBusWebSocket();
      busArrivals.clear();
      busEmptyMessage.value = '주변 정류장 없음';
    } else {
      _ensureBusWebSocketConnected();
      if (previousBusStopName != nextBusStop.displayName) {
        _updateRealtimeBusArrivals();
      }
    }

    _updateAsanStatusMessage();
  }

  void _applyFallbackBranch({
    required String campus,
    required String message,
  }) {
    branchMode.value = ArrivalBranchMode.fallbackDefaultWidget;
    shouldShowFallbackUpcomingWidget.value = true;
    fallbackCampus.value = campus;
    statusMessage.value = message;
    _stopRefreshTimer();
    _disconnectBusWebSocket();
  }

  NearbyShuttleStop? _findNearbyShuttleStop(Position position) {
    NearbyShuttleStop? nearestStop;

    for (final int stationId in _asanShuttleStationIds) {
      final ShuttleStation? station = _shuttleStationsById[stationId];
      if (station == null) {
        continue;
      }

      final double distance = _distanceMeters(
        position.latitude,
        position.longitude,
        station.latitude,
        station.longitude,
      );
      if (distance > 200) {
        continue;
      }

      if (nearestStop == null || distance < nearestStop.distanceMeters) {
        nearestStop = NearbyShuttleStop(
          station: station,
          distanceMeters: distance,
        );
      }
    }

    return nearestStop;
  }

  Future<void> _refreshNearbyShuttleArrivals(NearbyShuttleStop shuttleStop) async {
    final DateTime now = DateTime.now();
    final String date = DateFormat('yyyy-MM-dd').format(now);
    final Map<String, dynamic> response =
        await _shuttleRepository.fetchStationSchedulesByDate(
      stationId: shuttleStop.station.id,
      date: date,
    );

    final List<dynamic> rawSchedules =
        List<dynamic>.from(response['schedules'] as List<dynamic>? ?? <dynamic>[]);

    final List<StationSchedule> schedules = rawSchedules
        .map((dynamic item) =>
            StationSchedule.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    if (schedules.isEmpty) {
      shuttleArrivals.clear();
      shuttleEmptyMessage.value = '주변 정류장 없음';
      _lastShuttleRefreshAt = now;
      return;
    }

    final Map<int, DateTime> lastArrivalPerRoute = <int, DateTime>{};
    for (final StationSchedule schedule in schedules) {
      final DateTime arrivalTime = _parseTimeToday(schedule.arrivalTime);
      final DateTime? currentLast = lastArrivalPerRoute[schedule.routeId];
      if (currentLast == null || arrivalTime.isAfter(currentLast)) {
        lastArrivalPerRoute[schedule.routeId] = arrivalTime;
      }
    }

    final List<StationSchedule> upcomingSchedules = schedules.where((schedule) {
      final DateTime arrivalTime = _parseTimeToday(schedule.arrivalTime);
      final Duration difference = arrivalTime.difference(now);
      return difference.inSeconds >= 0 && difference.inMinutes <= 90;
    }).toList()
      ..sort((a, b) => _parseTimeToday(a.arrivalTime)
          .compareTo(_parseTimeToday(b.arrivalTime)));

    if (upcomingSchedules.isEmpty) {
      shuttleArrivals.clear();
      shuttleEmptyMessage.value = '90분 내 도착 셔틀 없음';
      _lastShuttleRefreshAt = now;
      return;
    }

    final List<StationSchedule> topSchedules = upcomingSchedules.take(3).toList();
    final List<AsanShuttleArrival> arrivals = <AsanShuttleArrival>[];

    for (final StationSchedule schedule in topSchedules) {
      final DateTime arrivalTime = _parseTimeToday(schedule.arrivalTime);
      final String routeName = await _resolveRouteName(schedule.routeId);
      arrivals.add(
        AsanShuttleArrival(
          routeId: schedule.routeId,
          routeName: routeName,
          stationName: shuttleStop.station.name,
          arrivalTime: arrivalTime,
          minutesLeft: _minutesLeft(arrivalTime, now),
          scheduleId: schedule.scheduleId,
          isLastBus: lastArrivalPerRoute[schedule.routeId] == arrivalTime,
        ),
      );
    }

    shuttleArrivals.assignAll(arrivals);
    shuttleEmptyMessage.value = arrivals.isEmpty ? '90분 내 도착 셔틀 없음' : '';
    _lastShuttleRefreshAt = now;
  }

  Future<String> _resolveRouteName(int routeId) async {
    final String? cached = _routeNameCache[routeId];
    if (cached != null) {
      return cached;
    }

    final String routeName =
        await _shuttleRepository.fetchRouteName(routeId) ?? '셔틀버스';
    _routeNameCache[routeId] = routeName;
    return routeName;
  }

  bool _shouldRefreshShuttleData() {
    if (_lastShuttleRefreshAt == null) {
      return true;
    }
    return DateTime.now().difference(_lastShuttleRefreshAt!).inSeconds >=
        refreshIntervalSeconds;
  }

  Future<NearbyBusStop?> _findNearbyBusStop(Position position) async {
    BusStopCandidate? anchorStop;
    double anchorDistance = double.infinity;

    for (final String routeKey in _asanBusRouteKeys) {
      final List<BusStopCandidate> candidates = await _loadBusStopCandidates(routeKey);
      for (final BusStopCandidate candidate in candidates) {
        final double distance = _distanceMeters(
          position.latitude,
          position.longitude,
          candidate.latitude,
          candidate.longitude,
        );

        if (distance > 100) {
          continue;
        }

        if (distance < anchorDistance) {
          anchorStop = candidate;
          anchorDistance = distance;
        }
      }
    }

    if (anchorStop == null) {
      return null;
    }

    final Map<String, BusStopCandidate> routeStops = <String, BusStopCandidate>{};
    for (final String routeKey in _asanBusRouteKeys) {
      final List<BusStopCandidate> candidates = await _loadBusStopCandidates(routeKey);
      BusStopCandidate? bestMatch;
      double bestDistance = double.infinity;

      for (final BusStopCandidate candidate in candidates) {
        if (!_isSamePhysicalStop(anchorStop, candidate)) {
          continue;
        }

        final double distance = _distanceMeters(
          anchorStop.latitude,
          anchorStop.longitude,
          candidate.latitude,
          candidate.longitude,
        );
        if (distance < bestDistance) {
          bestDistance = distance;
          bestMatch = candidate;
        }
      }

      if (bestMatch != null) {
        routeStops[routeKey] = bestMatch;
      }
    }

    if (routeStops.isEmpty) {
      return null;
    }

    return NearbyBusStop(
      displayName: anchorStop.stopName,
      distanceMeters: anchorDistance,
      latitude: anchorStop.latitude,
      longitude: anchorStop.longitude,
      routeStops: routeStops,
    );
  }

  Future<List<BusStopCandidate>> _loadBusStopCandidates(String routeKey) async {
    final List<BusStopCandidate>? cached = _busStopCache[routeKey];
    if (cached != null) {
      return cached;
    }

    final String jsonText = await rootBundle.loadString(
      'assets/bus_stops/$routeKey.json',
    );
    final Map<String, dynamic> decoded =
        jsonDecode(jsonText) as Map<String, dynamic>;
    final List<dynamic> rawItems = List<dynamic>.from(
      decoded['response']?['body']?['items']?['item'] as List<dynamic>? ??
          <dynamic>[],
    );

    final List<BusStopCandidate> candidates = rawItems.map((dynamic item) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map);
      return BusStopCandidate(
        routeKey: routeKey,
        routeName: _simpleRouteName(routeKey),
        stopName: map['nodenm']?.toString() ?? '정류장',
        nodeId: map['nodeid']?.toString() ?? '',
        nodeNumber: map['nodeno']?.toString() ?? '',
        nodeOrder: _toInt(map['nodeord']),
        latitude: _toDouble(map['gpslati']),
        longitude: _toDouble(map['gpslong']),
      );
    }).where((BusStopCandidate candidate) {
      return candidate.latitude != 0 && candidate.longitude != 0;
    }).toList();

    _busStopCache[routeKey] = candidates;
    return candidates;
  }

  bool _isSamePhysicalStop(BusStopCandidate anchor, BusStopCandidate target) {
    final String normalizedAnchor = _normalizeStopName(anchor.stopName);
    final String normalizedTarget = _normalizeStopName(target.stopName);
    if (normalizedAnchor.isNotEmpty && normalizedAnchor == normalizedTarget) {
      return true;
    }

    final double distance = _distanceMeters(
      anchor.latitude,
      anchor.longitude,
      target.latitude,
      target.longitude,
    );
    return distance <= 60;
  }

  void _ensureBusWebSocketConnected() {
    if (_webSocketChannel != null) {
      return;
    }

    final Uri uri = _buildAsanBusWebSocketUri();
    _webSocketChannel = WebSocketChannel.connect(uri);
    _webSocketSubscription = _webSocketChannel!.stream.listen(
      (dynamic event) {
        try {
          final Map<String, dynamic> payload =
              Map<String, dynamic>.from(jsonDecode(event.toString()) as Map);
          _latestRealtimePayload = payload;
          _updateRealtimeBusArrivals();
        } catch (_) {
          busEmptyMessage.value = '실시간 버스 정보를 해석하지 못했습니다.';
        }
      },
      onError: (Object _) {
        _disconnectBusWebSocket();
        if (nearbyBusStop.value != null) {
          busEmptyMessage.value = '실시간 버스 연결에 실패했습니다.';
        }
      },
      onDone: () {
        _disconnectBusWebSocket();
      },
      cancelOnError: true,
    );
  }

  void _disconnectBusWebSocket() {
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    _webSocketChannel?.sink.close();
    _webSocketChannel = null;
    _latestRealtimePayload = null;
  }

  void _updateRealtimeBusArrivals() {
    final NearbyBusStop? stop = nearbyBusStop.value;
    if (stop == null) {
      busArrivals.clear();
      busEmptyMessage.value = '주변 정류장 없음';
      return;
    }

    final Map<String, dynamic>? payload = _latestRealtimePayload;
    if (payload == null) {
      busArrivals.clear();
      busEmptyMessage.value = '운행 중인 버스 없음';
      return;
    }

    final List<AsanRealtimeBusArrival> arrivals = <AsanRealtimeBusArrival>[];

    for (final MapEntry<String, BusStopCandidate> entry in stop.routeStops.entries) {
      final String routeKey = entry.key;
      final BusStopCandidate targetStop = entry.value;
      final dynamic rawVehicles = payload[routeKey];
      if (rawVehicles is! List) {
        continue;
      }

      for (final dynamic vehicleEntry in rawVehicles) {
        final Map<String, dynamic> vehicle =
            Map<String, dynamic>.from(vehicleEntry as Map);
        final int vehicleNodeOrder = _toInt(vehicle['nodeord']);
        final int stopsAway = targetStop.nodeOrder - vehicleNodeOrder;
        if (stopsAway <= 0) {
          continue;
        }

        arrivals.add(
          AsanRealtimeBusArrival(
            routeKey: routeKey,
            routeName: targetStop.routeName,
            targetStopName: targetStop.stopName,
            currentNodeName: vehicle['nodenm']?.toString() ?? '현재 위치 확인 중',
            vehicleNumber: vehicle['vehicleno']?.toString() ?? '',
            stopsAway: stopsAway,
            badgeText: _formatStopsAway(stopsAway),
          ),
        );
      }
    }

    arrivals.sort((a, b) {
      final int byStops = a.stopsAway.compareTo(b.stopsAway);
      if (byStops != 0) {
        return byStops;
      }
      return a.routeName.compareTo(b.routeName);
    });

    busArrivals.assignAll(arrivals.take(3).toList());
    busEmptyMessage.value = busArrivals.isEmpty ? '운행 중인 버스 없음' : '';
  }

  Uri _buildAsanBusWebSocketUri() {
    final Uri baseUri = Uri.parse(EnvConfig.baseUrl);
    final String scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return baseUri.replace(
      scheme: scheme,
      path: '/ws/bus/asan/up',
      queryParameters: null,
      fragment: null,
    );
  }

  void _updateAsanStatusMessage() {
    final NearbyShuttleStop? shuttleStop = nearbyShuttleStop.value;
    final NearbyBusStop? busStop = nearbyBusStop.value;

    if (shuttleStop != null && busStop != null) {
      statusMessage.value =
          '${shuttleStop.station.name} / ${busStop.displayName} 주변 정류장을 기준으로 표시합니다.';
      return;
    }

    if (shuttleStop != null) {
      statusMessage.value =
          '${shuttleStop.station.name} 셔틀 정류장 기준으로 표시합니다.';
      return;
    }

    if (busStop != null) {
      statusMessage.value =
          '${busStop.displayName} 시내버스 정류장 기준으로 표시합니다.';
      return;
    }

    statusMessage.value = '주변 정류장을 찾지 못했습니다.';
  }

  void _clearLocationBranchData() {
    shouldShowFallbackUpcomingWidget.value = false;
    fallbackCampus.value = null;
    branchMode.value = ArrivalBranchMode.noNearbyStop;
    _stopRefreshTimer();
    _disconnectBusWebSocket();
    _clearArrivalResults();
  }

  void _clearArrivalResults() {
    nearbyShuttleStop.value = null;
    nearbyBusStop.value = null;
    shuttleArrivals.clear();
    busArrivals.clear();
    shuttleEmptyMessage.value = '주변 정류장 없음';
    busEmptyMessage.value = '주변 정류장 없음';
  }

  void _restartRefreshTimerIfNeeded() {
    if (!shouldUseRefreshCountdown) {
      _stopRefreshTimer();
      return;
    }

    _refreshTimer = Timer(
      Duration(seconds: refreshIntervalSeconds),
      () {
        loadData(
          silent: true,
          forceNetworkRefresh: true,
        );
      },
    );
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  DateTime _parseTimeToday(String hhmmss) {
    final List<String> parts = hhmmss.split(':');
    final DateTime now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    );
  }

  int _minutesLeft(DateTime arrivalTime, DateTime now) {
    final int seconds = arrivalTime.difference(now).inSeconds;
    if (seconds <= 0) {
      return 0;
    }
    return (seconds / 60).ceil();
  }

  double _distanceMeters(
    double latitude,
    double longitude,
    double targetLatitude,
    double targetLongitude,
  ) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      targetLatitude,
      targetLongitude,
    );
  }

  int _toInt(dynamic value) {
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _simpleRouteName(String routeKey) {
    final int separator = routeKey.indexOf('_');
    return separator == -1 ? routeKey : routeKey.substring(0, separator);
  }

  String _formatStopsAway(int stopsAway) {
    if (stopsAway <= 1) {
      return '전';
    }
    if (stopsAway == 2) {
      return '전전';
    }
    return '$stopsAway전';
  }

  String _normalizeStopName(String name) {
    return name
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('.', '')
        .toLowerCase();
  }
}
