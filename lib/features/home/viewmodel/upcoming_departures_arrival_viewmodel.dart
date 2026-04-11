import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hsro/core/utils/bus_times_loader.dart';
import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/repository/shuttle_repository.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ArrivalBranchMode {
  // 캠퍼스 내부에서는 기존 출발 위젯으로 fallback
  fallbackDefaultWidget,
  asanLocationArrival,
  cheonanLocationArrival,
  noNearbyStop,
}

// 캠퍼스별 위치 기반 도착 정보 설정값
class CampusLocationConfig {
  const CampusLocationConfig({
    required this.campusName,
    required this.branchMode,
    required this.shuttleStationIds,
    required this.busRouteKeys,
    required this.busWebSocketPath,
  });

  final String campusName;
  final ArrivalBranchMode branchMode;
  final List<int> shuttleStationIds;
  final List<String> busRouteKeys;
  final String busWebSocketPath;
}

// 현재 위치 기준 가장 가까운 셔틀 정류장 정보
class NearbyShuttleStop {
  const NearbyShuttleStop({
    required this.station,
    required this.distanceMeters,
  });

  final ShuttleStation station;
  final double distanceMeters;
}

// 노선별 버스 정류장 원본 후보 정보
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

// 여러 노선이 겹치는 주변 버스 정류장 묶음 정보
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

class _NearbyBusStopAnchor {
  const _NearbyBusStopAnchor({
    required this.stop,
    required this.distanceMeters,
  });

  final BusStopCandidate stop;
  final double distanceMeters;
}

// 위치 기반 셔틀 도착 정보 모델
class LocationShuttleArrival {
  const LocationShuttleArrival({
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

enum LocationBusArrivalKind {
  scheduled,
  realtime,
}

// 위치 기반 시내버스 도착 정보 모델
class LocationBusArrival {
  const LocationBusArrival._({
    required this.kind,
    required this.routeKey,
    required this.routeName,
    required this.targetStopName,
    required this.badgeText,
    this.currentNodeName,
    this.vehicleNumber,
    this.stopsAway,
    this.departureTime,
    this.minutesLeft,
  });

  const LocationBusArrival.scheduled({
    required String routeKey,
    required String routeName,
    required String targetStopName,
    required DateTime departureTime,
    required int minutesLeft,
  }) : this._(
          kind: LocationBusArrivalKind.scheduled,
          routeKey: routeKey,
          routeName: routeName,
          targetStopName: targetStopName,
          badgeText: '$minutesLeft분',
          departureTime: departureTime,
          minutesLeft: minutesLeft,
        );

  const LocationBusArrival.realtime({
    required String routeKey,
    required String routeName,
    required String targetStopName,
    required String currentNodeName,
    required String vehicleNumber,
    required int stopsAway,
    required String badgeText,
  }) : this._(
          kind: LocationBusArrivalKind.realtime,
          routeKey: routeKey,
          routeName: routeName,
          targetStopName: targetStopName,
          currentNodeName: currentNodeName,
          vehicleNumber: vehicleNumber,
          stopsAway: stopsAway,
          badgeText: badgeText,
        );

  final LocationBusArrivalKind kind;
  final String routeKey;
  final String routeName;
  final String targetStopName;
  final String badgeText;
  final String? currentNodeName;
  final String? vehicleNumber;
  final int? stopsAway;
  final DateTime? departureTime;
  final int? minutesLeft;
}

class UpcomingDeparturesArrivalViewModel extends GetxController
    with WidgetsBindingObserver {
  UpcomingDeparturesArrivalViewModel({
    ShuttleRepository? shuttleRepository,
  }) : _shuttleRepository = shuttleRepository ?? ShuttleRepository();

  static const CampusLocationConfig _asanConfig = CampusLocationConfig(
    campusName: '아산',
    branchMode: ArrivalBranchMode.asanLocationArrival,
    shuttleStationIds: <int>[1, 3, 9, 10, 11, 12, 14, 15, 18, 19, 20, 21],
    busRouteKeys: <String>[
      '810_UP',
      '820_UP',
      '821_UP',
      '822_UP',
      '1000_UP',
      '1001_UP',
      '순환5_UP',
    ],
    busWebSocketPath: '/ws/bus/asan/up',
  );

  static const CampusLocationConfig _cheonanConfig = CampusLocationConfig(
    campusName: '천안',
    branchMode: ArrivalBranchMode.cheonanLocationArrival,
    shuttleStationIds: <int>[1, 2, 4, 5, 6, 7, 14, 16],
    busRouteKeys: <String>['24_UP', '81_UP'],
    busWebSocketPath: '/ws/bus/cheonan/up',
  );

  final ShuttleRepository _shuttleRepository;
  final SettingsViewModel settingsViewModel = Get.find<SettingsViewModel>();

  // 위치 기반 위젯 상태값
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isWidgetEnabled = true.obs;
  final RxBool isLocationReady = false.obs;
  final RxBool isLocationServiceEnabled = true.obs;
  final RxBool isLocationPermissionGranted = false.obs;
  final RxString error = ''.obs;
  final RxString statusMessage = '위치를 확인하는 중입니다.'.obs;
  final RxString selectedCampus = ''.obs;
  final Rx<ArrivalBranchMode> branchMode = ArrivalBranchMode.noNearbyStop.obs;
  final RxnString fallbackCampus = RxnString();
  final RxBool shouldShowFallbackUpcomingWidget = false.obs;
  final Rxn<Position> currentPosition = Rxn<Position>();
  final Rxn<NearbyShuttleStop> nearbyShuttleStop = Rxn<NearbyShuttleStop>();
  final RxList<NearbyBusStop> nearbyBusStops = <NearbyBusStop>[].obs;
  final Rxn<NearbyBusStop> nearbyBusStop = Rxn<NearbyBusStop>();
  final RxList<LocationShuttleArrival> shuttleArrivals =
      <LocationShuttleArrival>[].obs;
  final RxList<LocationBusArrival> busArrivals = <LocationBusArrival>[].obs;
  final RxString shuttleEmptyMessage = '주변 정류장 없음'.obs;
  final RxString busEmptyMessage = '주변 정류장 없음'.obs;

  final Map<int, ShuttleStation> _shuttleStationsById = <int, ShuttleStation>{};
  final Map<String, List<BusStopCandidate>> _busStopCache =
      <String, List<BusStopCandidate>>{};
  final Map<int, String> _routeNameCache = <int, String>{};
  Map<String, dynamic>? _busTimesCache;

  // 위치, 웹소켓, 자동 새로고침 관련 리소스
  Worker? _campusWorker;
  StreamSubscription<Position>? _positionSubscription;
  WebSocketChannel? _webSocketChannel;
  StreamSubscription<dynamic>? _webSocketSubscription;
  Timer? _refreshTimer;
  Function? _onRefreshCallback;

  DateTime? _lastShuttleRefreshAt;
  Map<String, dynamic>? _latestRealtimePayload;
  String? _connectedBusWebSocketPath;
  bool _isLoadInProgress = false;
  bool _isRequestingLocationPermission = false;

  bool get shouldUseRefreshCountdown =>
      _isLocationBranch(branchMode.value) &&
      !shouldShowFallbackUpcomingWidget.value &&
      isWidgetEnabled.value;

  int get refreshIntervalSeconds => _secondsUntilNextMinute();

  String get campusDescription {
    switch (branchMode.value) {
      case ArrivalBranchMode.fallbackDefaultWidget:
        return '캠퍼스 내부로 인식되어 기본 출발 위젯을 사용합니다.';
      case ArrivalBranchMode.asanLocationArrival:
      case ArrivalBranchMode.cheonanLocationArrival:
        return '현재 위치 기준 $selectedCampus 주변 셔틀 및 시내버스 도착 정보를 표시합니다.';
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

    // 캠퍼스 변경 시 현재 위치 기준으로 도착 정보 다시 계산
    _campusWorker = ever<String>(settingsViewModel.selectedCampus, (campus) {
      selectedCampus.value = campus;
      if (isWidgetEnabled.value) {
        loadData(
          silent: true,
          forceNetworkRefresh: true,
          allowPermissionPrompt: false,
        );
      }
    });

    if (settingsViewModel.isLocationBasedDepartureWidgetEnabled.value) {
      // 설정이 켜져 있으면 바로 활성화
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
    // 백그라운드에서는 위치/웹소켓/타이머 정지
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
        allowPermissionPrompt: false,
      );
    }
  }

  Future<void> setWidgetEnabled(bool enabled) async {
    if (enabled == isWidgetEnabled.value) {
      return;
    }

    isWidgetEnabled.value = enabled;

    if (enabled) {
      // 다시 보이기 시작하면 재활성화
      await _activate(allowPermissionPrompt: false);
      return;
    }

    _stopRefreshTimer();
    _disconnectBusWebSocket();
    await _cancelPositionStream();
  }

  Future<void> refreshLocation() {
    // 수동 새로고침 시 네트워크와 위치 모두 강제 갱신
    return loadData(
      forceNetworkRefresh: true,
      forceLocationRefresh: true,
      allowPermissionPrompt: true,
    );
  }

  Future<void> loadData({
    bool silent = false,
    bool forceNetworkRefresh = false,
    bool forceLocationRefresh = false,
    bool allowPermissionPrompt = true,
  }) async {
    if (!isWidgetEnabled.value || _isLoadInProgress) {
      return;
    }

    // 중복 로드 방지
    _isLoadInProgress = true;
    _stopRefreshTimer();

    if (!silent) {
      isLoading.value = true;
    }
    isRefreshing.value = true;
    error.value = '';

    try {
      await _loadShuttleStationsIfNeeded();

      // 위치 권한/서비스 상태 확인
      final bool canUseLocation = await _ensureLocationPermission(
        allowPermissionPrompt: allowPermissionPrompt,
      );
      if (!canUseLocation) {
        branchMode.value = ArrivalBranchMode.noNearbyStop;
        return;
      }

      // 위치 스트림 연결 보장
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

      // 현재 위치 기준으로 어떤 브랜치를 보여줄지 결정
      await _evaluateBranchForPosition(
        position,
        forceNetworkRefresh: forceNetworkRefresh,
      );
    } catch (_) {
      error.value = '정보를 갱신하는 중 문제가 발생했습니다.';
      statusMessage.value = '위치 기반 정보를 갱신하는 중 문제가 발생했습니다.';
    } finally {
      _isLoadInProgress = false;
      isLoading.value = false;
      isRefreshing.value = false;
      _onRefreshCallback?.call();
      // 활성 상태면 다음 갱신 예약
      _restartRefreshTimerIfNeeded();
    }
  }

  Future<void> _activate({
    bool allowPermissionPrompt = true,
  }) async {
    // 비활성 상태였다면 다시 활성화
    if (!isWidgetEnabled.value) {
      isWidgetEnabled.value = true;
    }

    await loadData(
      forceNetworkRefresh: true,
      forceLocationRefresh: true,
      allowPermissionPrompt: allowPermissionPrompt,
    );
  }

  Future<void> _ensurePositionStream() async {
    if (_positionSubscription != null) {
      return;
    }

    // 일정 거리 이상 이동하면 위치 기반 결과 재평가
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

        // 실시간 위치 변화에 따라 주변 정류장 정보 갱신
        await _evaluateBranchForPosition(
          position,
          forceNetworkRefresh: false,
        );
      },
      onError: (_) {
        statusMessage.value = '현재 위치를 추적하지 못했습니다.';
        isLocationReady.value = false;
      },
    );
  }

  Future<void> _cancelPositionStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<bool> _ensureLocationPermission({
    required bool allowPermissionPrompt,
  }) async {
    // 위치 서비스 활성화 여부 먼저 확인
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    isLocationServiceEnabled.value = serviceEnabled;
    if (!serviceEnabled) {
      isLocationReady.value = false;
      isLocationPermissionGranted.value = false;
      statusMessage.value = '위치 서비스를 켜야 위치기반 위젯을 사용할 수 있습니다.';
      _clearLocationBranchData(
        shuttleMessage: '위치 서비스 꺼짐',
        busMessage: '위치 서비스 꺼짐',
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    // 필요할 때만 권한 요청
    if (permission == LocationPermission.denied &&
        allowPermissionPrompt &&
        !_isRequestingLocationPermission) {
      _isRequestingLocationPermission = true;
      try {
        permission = await Geolocator.requestPermission();
      } finally {
        _isRequestingLocationPermission = false;
      }
    }

    final bool granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    isLocationPermissionGranted.value = granted;
    isLocationReady.value = granted;

    // 권한이 없으면 위치 기반 결과 초기화
    if (!granted) {
      statusMessage.value =
          permission == LocationPermission.deniedForever ? '' : '';
      _clearLocationBranchData(
        shuttleMessage: '위치 권한 허용 안됨',
        busMessage: '위치 권한 허용 안됨',
      );
      return false;
    }

    return true;
  }

  Future<void> _loadShuttleStationsIfNeeded() async {
    if (_shuttleStationsById.isNotEmpty) {
      return;
    }

    // 셔틀 정류장 마스터 데이터 캐시
    final List<ShuttleStation> stations =
        await _shuttleRepository.fetchStations();
    for (final ShuttleStation station in stations) {
      _shuttleStationsById[station.id] = station;
    }
  }

  Future<void> _evaluateBranchForPosition(
    Position position, {
    required bool forceNetworkRefresh,
  }) async {
    currentPosition.value = position;

    // 캠퍼스 내부로 판별되면 기본 출발 위젯으로 fallback
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

    // 캠퍼스 설정에 맞는 위치 기반 브랜치 적용
    final CampusLocationConfig? config = _configForCampus(selectedCampus.value);
    if (config == null) {
      branchMode.value = ArrivalBranchMode.noNearbyStop;
      statusMessage.value = '캠퍼스 설정을 확인해 주세요.';
      _clearArrivalResults();
      return;
    }

    branchMode.value = config.branchMode;
    await _updateLocationBranch(
      position,
      config: config,
      forceNetworkRefresh: forceNetworkRefresh,
    );
  }

  Future<void> _updateLocationBranch(
    Position position, {
    required CampusLocationConfig config,
    required bool forceNetworkRefresh,
  }) async {
    // 주변 셔틀/버스 정류장 각각 탐색
    final NearbyShuttleStop? nextShuttleStop = _findNearbyShuttleStop(
      position,
      config.shuttleStationIds,
    );
    final List<NearbyBusStop> nextBusStops = await _findNearbyBusStops(
      position,
      config.busRouteKeys,
    );
    final NearbyBusStop? nextBusStop =
        nextBusStops.isNotEmpty ? nextBusStops.first : null;

    final int? previousShuttleStationId = nearbyShuttleStop.value?.station.id;
    nearbyShuttleStop.value = nextShuttleStop;
    nearbyBusStops.assignAll(nextBusStops);
    nearbyBusStop.value = nextBusStop;

    // 셔틀 정류장이 바뀌었거나 오래됐으면 다시 조회
    if (nextShuttleStop == null) {
      shuttleArrivals.clear();
      shuttleEmptyMessage.value = '주변 정류장 없음';
      _lastShuttleRefreshAt = null;
    } else if (forceNetworkRefresh ||
        previousShuttleStationId != nextShuttleStop.station.id ||
        _shouldRefreshShuttleData()) {
      await _refreshNearbyShuttleArrivals(nextShuttleStop);
    }

    // 버스 정류장이 없으면 웹소켓 연결 해제
    if (nextBusStop == null) {
      _disconnectBusWebSocket();
    } else {
      _ensureBusWebSocketConnected(config.busWebSocketPath);
    }

    await _updateBusArrivals(config);
    _updateLocationStatusMessage();
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

  NearbyShuttleStop? _findNearbyShuttleStop(
    Position position,
    List<int> allowedStationIds,
  ) {
    NearbyShuttleStop? nearestStop;

    for (final int stationId in allowedStationIds) {
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
      if (distance > 400) {
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

  Future<void> _refreshNearbyShuttleArrivals(
      NearbyShuttleStop shuttleStop) async {
    final DateTime now = DateTime.now();
    final String date = DateFormat('yyyy-MM-dd').format(now);
    final Map<String, dynamic> response =
        await _shuttleRepository.fetchStationSchedulesByDate(
      stationId: shuttleStop.station.id,
      date: date,
    );

    final List<dynamic> rawSchedules = List<dynamic>.from(
      response['schedules'] as List<dynamic>? ?? <dynamic>[],
    );

    final List<StationSchedule> schedules = rawSchedules.map((dynamic item) {
      return StationSchedule.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
    }).toList();

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
      ..sort((a, b) {
        return _parseTimeToday(a.arrivalTime)
            .compareTo(_parseTimeToday(b.arrivalTime));
      });

    if (upcomingSchedules.isEmpty) {
      shuttleArrivals.clear();
      shuttleEmptyMessage.value = '90분 내 도착 셔틀 없음';
      _lastShuttleRefreshAt = now;
      return;
    }

    final List<LocationShuttleArrival> arrivals = <LocationShuttleArrival>[];
    for (final StationSchedule schedule in upcomingSchedules.take(3)) {
      final DateTime arrivalTime = _parseTimeToday(schedule.arrivalTime);
      final String routeName = await _resolveRouteName(schedule.routeId);
      arrivals.add(
        LocationShuttleArrival(
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

  Future<Map<String, dynamic>> _loadBusTimesOnce() async {
    final Map<String, dynamic>? cached = _busTimesCache;
    if (cached != null) {
      return cached;
    }

    final Map<String, dynamic> busTimes = await BusTimesLoader.loadBusTimes();
    _busTimesCache = busTimes;
    return busTimes;
  }

  Future<List<NearbyBusStop>> _findNearbyBusStops(
    Position position,
    List<String> routeKeys,
  ) async {
    final List<_NearbyBusStopAnchor> anchors = <_NearbyBusStopAnchor>[];

    for (final String routeKey in routeKeys) {
      final List<BusStopCandidate> candidates =
          await _loadBusStopCandidates(routeKey);
      for (final BusStopCandidate candidate in candidates) {
        final double distance = _distanceMeters(
          position.latitude,
          position.longitude,
          candidate.latitude,
          candidate.longitude,
        );
        if (distance > 200) {
          continue;
        }

        final int existingIndex = anchors.indexWhere((anchor) {
          return _isSamePhysicalStop(anchor.stop, candidate);
        });

        if (existingIndex == -1) {
          anchors.add(
            _NearbyBusStopAnchor(
              stop: candidate,
              distanceMeters: distance,
            ),
          );
          continue;
        }

        if (distance < anchors[existingIndex].distanceMeters) {
          anchors[existingIndex] = _NearbyBusStopAnchor(
            stop: candidate,
            distanceMeters: distance,
          );
        }
      }
    }

    if (anchors.isEmpty) {
      return <NearbyBusStop>[];
    }

    anchors.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    final List<NearbyBusStop> results = <NearbyBusStop>[];
    for (final _NearbyBusStopAnchor anchor in anchors.take(2)) {
      final NearbyBusStop? nearbyStop = await _buildNearbyBusStopFromAnchor(
        anchor.stop,
        anchor.distanceMeters,
        routeKeys,
      );
      if (nearbyStop != null) {
        results.add(nearbyStop);
      }
    }

    return results;
  }

  Future<NearbyBusStop?> _buildNearbyBusStopFromAnchor(
    BusStopCandidate anchorStop,
    double anchorDistance,
    List<String> routeKeys,
  ) async {
    final Map<String, BusStopCandidate> routeStops =
        <String, BusStopCandidate>{};
    for (final String routeKey in routeKeys) {
      final List<BusStopCandidate> candidates =
          await _loadBusStopCandidates(routeKey);
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

  void _ensureBusWebSocketConnected(String path) {
    if (_webSocketChannel != null && _connectedBusWebSocketPath == path) {
      return;
    }

    _disconnectBusWebSocket();

    final Uri uri = _buildBusWebSocketUri(path);
    _connectedBusWebSocketPath = path;
    _webSocketChannel = WebSocketChannel.connect(uri);
    _webSocketSubscription = _webSocketChannel!.stream.listen(
      (dynamic event) {
        try {
          final Map<String, dynamic> payload =
              Map<String, dynamic>.from(jsonDecode(event.toString()) as Map);
          _latestRealtimePayload = payload;
          final CampusLocationConfig? config =
              _configForCampus(selectedCampus.value);
          if (config != null) {
            unawaited(
              _updateBusArrivals(config).catchError((_) {
                if (busArrivals.isEmpty) {
                  busEmptyMessage.value = nearbyBusStop.value == null
                      ? '주변 정류장 없음'
                      : '버스 정보를 갱신하지 못했습니다.';
                }
              }),
            );
          }
        } catch (_) {
          busEmptyMessage.value = '실시간 버스 정보를 해석하지 못했습니다.';
        }
      },
      onError: (_) {
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
    _connectedBusWebSocketPath = null;
  }

  Future<void> _updateBusArrivals(CampusLocationConfig config) async {
    final bool shouldInsertScheduledSlot =
        config.campusName == _asanConfig.campusName &&
            _isAsanCirculation5FixedSlotLocation();

    LocationBusArrival? scheduledArrival;
    if (shouldInsertScheduledSlot) {
      scheduledArrival = await _buildAsanCirculation5ScheduledArrival();
    }

    final List<LocationBusArrival> realtimeArrivals = _buildRealtimeBusArrivals(
      excludedRouteKey: scheduledArrival != null ? '순환5_UP' : null,
    );

    final List<LocationBusArrival> combinedArrivals = <LocationBusArrival>[
      if (scheduledArrival != null) scheduledArrival,
      ...realtimeArrivals.take(scheduledArrival != null ? 2 : 3),
    ];

    busArrivals.assignAll(combinedArrivals);

    if (combinedArrivals.isNotEmpty) {
      busEmptyMessage.value = '';
      return;
    }

    if (nearbyBusStop.value == null) {
      busEmptyMessage.value = '주변 정류장 없음';
      return;
    }

    busEmptyMessage.value = '운행 중인 버스 없음';
  }

  bool _isAsanCirculation5FixedSlotLocation() {
    if (nearbyShuttleStop.value?.station.id == 15) {
      return true;
    }

    for (final NearbyBusStop stop in nearbyBusStops) {
      final String normalizedStopName = _normalizeStopName(stop.displayName);
      const String normalizedTarget = '천안아산역';
      if (normalizedStopName.contains(normalizedTarget)) {
        return true;
      }
    }

    return false;
  }

  Future<LocationBusArrival?> _buildAsanCirculation5ScheduledArrival() async {
    final Map<String, dynamic> busTimes = await _loadBusTimesOnce();
    final Map<String, dynamic>? routeData =
        busTimes['순환5_UP'] as Map<String, dynamic>?;
    final List<dynamic>? timetable = routeData?['시간표'] as List<dynamic>?;
    if (timetable == null || timetable.isEmpty) {
      return null;
    }

    final DateTime now = DateTime.now();
    DateTime? nextDeparture;

    for (final dynamic rawTime in timetable) {
      final String hhmm = rawTime.toString();
      final DateTime departureTime = _parseTimeToday(hhmm);
      if (!departureTime.isBefore(now)) {
        nextDeparture = departureTime;
        break;
      }
    }

    if (nextDeparture == null) {
      return null;
    }

    return LocationBusArrival.scheduled(
      routeKey: '순환5_UP',
      routeName: '순환5',
      targetStopName: _findNearbyBusStopName('천안아산역') ??
          nearbyBusStop.value?.displayName ??
          nearbyShuttleStop.value?.station.name ??
          '천안아산역(아캠방향)',
      departureTime: nextDeparture,
      minutesLeft: _minutesLeft(nextDeparture, now),
    );
  }

  List<LocationBusArrival> _buildRealtimeBusArrivals({
    String? excludedRouteKey,
  }) {
    final Map<String, dynamic>? payload = _latestRealtimePayload;
    if (payload == null || nearbyBusStops.isEmpty) {
      return <LocationBusArrival>[];
    }

    final Map<String, LocationBusArrival> bestArrivalByRoute =
        <String, LocationBusArrival>{};
    final Map<String, int> bestStopsAwayByRoute = <String, int>{};
    final Map<String, double> bestStopDistanceByRoute = <String, double>{};

    for (final NearbyBusStop stop in nearbyBusStops) {
      for (final MapEntry<String, BusStopCandidate> entry
          in stop.routeStops.entries) {
        final String routeKey = entry.key;
        if (excludedRouteKey != null && routeKey == excludedRouteKey) {
          continue;
        }

        final BusStopCandidate targetStop = entry.value;
        final dynamic rawVehicles = payload[routeKey];
        if (rawVehicles is! List) {
          continue;
        }

        for (final dynamic rawVehicle in rawVehicles) {
          final Map<String, dynamic> vehicle =
              Map<String, dynamic>.from(rawVehicle as Map);
          final int vehicleNodeOrder = _toInt(vehicle['nodeord']);
          final int stopsAway = targetStop.nodeOrder - vehicleNodeOrder;
          if (stopsAway <= 0) {
            continue;
          }

          final int? currentBestStopsAway = bestStopsAwayByRoute[routeKey];
          final double? currentBestStopDistance =
              bestStopDistanceByRoute[routeKey];
          if (!_shouldReplaceRealtimeArrival(
            currentBestStopsAway: currentBestStopsAway,
            currentBestStopDistance: currentBestStopDistance,
            candidateStopsAway: stopsAway,
            candidateStopDistance: stop.distanceMeters,
          )) {
            continue;
          }

          bestArrivalByRoute[routeKey] = LocationBusArrival.realtime(
            routeKey: routeKey,
            routeName: targetStop.routeName,
            targetStopName: targetStop.stopName,
            currentNodeName: vehicle['nodenm']?.toString() ?? '현재 위치 확인 중',
            vehicleNumber: vehicle['vehicleno']?.toString() ?? '',
            stopsAway: stopsAway,
            badgeText: _formatStopsAway(stopsAway),
          );
          bestStopsAwayByRoute[routeKey] = stopsAway;
          bestStopDistanceByRoute[routeKey] = stop.distanceMeters;
        }
      }
    }

    final List<LocationBusArrival> arrivals = bestArrivalByRoute.values.toList()
      ..sort((a, b) {
        final int byStops = (a.stopsAway ?? 999).compareTo(b.stopsAway ?? 999);
        if (byStops != 0) {
          return byStops;
        }
        return a.routeName.compareTo(b.routeName);
      });

    return arrivals;
  }

  bool _shouldReplaceRealtimeArrival({
    required int? currentBestStopsAway,
    required double? currentBestStopDistance,
    required int candidateStopsAway,
    required double candidateStopDistance,
  }) {
    if (currentBestStopsAway == null || currentBestStopDistance == null) {
      return true;
    }

    if (candidateStopsAway < currentBestStopsAway) {
      return true;
    }

    if (candidateStopsAway > currentBestStopsAway) {
      return false;
    }

    return candidateStopDistance < currentBestStopDistance;
  }

  Uri _buildBusWebSocketUri(String path) {
    final Uri baseUri = Uri.parse(EnvConfig.baseUrl);
    final String scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return baseUri.replace(
      scheme: scheme,
      path: path,
      queryParameters: null,
      fragment: null,
    );
  }

  void _updateLocationStatusMessage() {
    final NearbyShuttleStop? shuttleStop = nearbyShuttleStop.value;
    final NearbyBusStop? busStop = nearbyBusStop.value;
    final int nearbyBusStopCount = nearbyBusStops.length;
    final String busStopLabel = nearbyBusStopCount > 1
        ? '${busStop?.displayName} 외 ${nearbyBusStopCount - 1}개'
        : busStop?.displayName ?? '';

    if (shuttleStop != null && busStop != null) {
      statusMessage.value =
          '${shuttleStop.station.name} / $busStopLabel 주변 정류장을 기준으로 표시합니다.';
      return;
    }

    if (shuttleStop != null) {
      statusMessage.value = '${shuttleStop.station.name} 셔틀 정류장 기준으로 표시합니다.';
      return;
    }

    if (busStop != null) {
      statusMessage.value = '$busStopLabel 시내버스 정류장 기준으로 표시합니다.';
      return;
    }

    statusMessage.value = '주변 정류장을 찾지 못했습니다.';
  }

  void _clearLocationBranchData({
    String shuttleMessage = '주변 정류장 없음',
    String busMessage = '주변 정류장 없음',
  }) {
    shouldShowFallbackUpcomingWidget.value = false;
    fallbackCampus.value = null;
    branchMode.value = ArrivalBranchMode.noNearbyStop;
    _stopRefreshTimer();
    _disconnectBusWebSocket();
    _clearArrivalResults(
      shuttleMessage: shuttleMessage,
      busMessage: busMessage,
    );
  }

  void _clearArrivalResults({
    String shuttleMessage = '주변 정류장 없음',
    String busMessage = '주변 정류장 없음',
  }) {
    nearbyShuttleStop.value = null;
    nearbyBusStops.clear();
    nearbyBusStop.value = null;
    shuttleArrivals.clear();
    busArrivals.clear();
    shuttleEmptyMessage.value = shuttleMessage;
    busEmptyMessage.value = busMessage;
  }

  void _restartRefreshTimerIfNeeded() {
    if (!shouldUseRefreshCountdown) {
      _stopRefreshTimer();
      return;
    }

    final int secondsUntilRefresh = refreshIntervalSeconds;
    _refreshTimer = Timer(
      Duration(seconds: secondsUntilRefresh),
      () {
        loadData(
          silent: true,
          forceNetworkRefresh: true,
          allowPermissionPrompt: false,
        );
      },
    );
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  CampusLocationConfig? _configForCampus(String campus) {
    switch (campus) {
      case '아산':
        return _asanConfig;
      case '천안':
        return _cheonanConfig;
      default:
        return null;
    }
  }

  bool _isLocationBranch(ArrivalBranchMode mode) {
    return mode == ArrivalBranchMode.asanLocationArrival ||
        mode == ArrivalBranchMode.cheonanLocationArrival;
  }

  int _secondsUntilNextMinute() {
    final DateTime now = DateTime.now();
    final DateTime nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    final int seconds = nextMinute.difference(now).inSeconds;
    return seconds <= 0 ? 1 : seconds;
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

  String? _findNearbyBusStopName(String keyword) {
    final String normalizedKeyword = _normalizeStopName(keyword);
    for (final NearbyBusStop stop in nearbyBusStops) {
      if (_normalizeStopName(stop.displayName).contains(normalizedKeyword)) {
        return stop.displayName;
      }
    }
    return null;
  }
}
