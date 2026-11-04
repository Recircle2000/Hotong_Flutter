import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/core/utils/bus_static_data_loader.dart';
import 'package:hsro/core/utils/bus_times_loader.dart';
import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/notice/viewmodel/notice_viewmodel.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:hsro/features/shuttle/repository/shuttle_repository.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// 곧 출발 카드에 사용하는 공통 출발 정보 모델
class BusDeparture {
  final String routeName;
  final String destination;
  final dynamic departureTime; // DateTime 또는 String
  final int minutesLeft;
  final int? scheduleId;
  final bool isLastBus;
  final String routeKey; // 추가 (실제 json의 key 그대로)
  BusDeparture({
    required this.routeName,
    required this.destination,
    required this.departureTime, // DateTime 또는 String
    required this.minutesLeft,
    this.scheduleId,
    this.isLastBus = false,
    required this.routeKey, // 추가
  });

  bool get isRealtimeBus =>
      destination == '호서대천캠' &&
      (routeKey == '24_DOWN' || routeKey == '81_DOWN') &&
      departureTime is String;
}

// 90분 안에 출발하는 차가 없을 때 안내할 다음 출발 정보
class NextDepartureHint {
  const NextDepartureHint({
    required this.time,
    required this.isFirstOfDay,
    this.routeLabel,
  });

  final DateTime time;
  // true면 오늘 아직 한 대도 출발하지 않은 상태(첫차 전)
  final bool isFirstOfDay;
  // 시내버스 노선 번호처럼 시각 앞에 붙일 이름
  final String? routeLabel;
}

/// 천캠 실시간 웹소켓 메시지(`{노선: [버스...]}`)를 홈 카드 목록으로 바꾼다.
///
/// [stops24]·[stops81]은 각원사~호서대(천안) 구간의 정류장 순번(nodeord)이다.
/// 구간 밖이거나 이미 호서대에 도착한 버스는 빼고, 남은 정거장이 적은 순으로 정렬한다.
List<BusDeparture> buildCeanRealtimeBuses(
  Map<String, dynamic> payload,
  List<String> stops24,
  List<String> stops81,
) {
  final list = <BusDeparture>[];
  for (final (routeKey, routeName, stops) in [
    ('24_DOWN', '24', stops24),
    ('81_DOWN', '81', stops81),
  ]) {
    final buses = payload[routeKey];
    if (buses is! List) {
      continue; // 지금 운행 중인 차가 없는 노선은 키가 빠져 있다.
    }
    for (final bus in buses) {
      if (bus is! Map) {
        continue;
      }
      final idx = stops.indexOf(bus['nodeord'].toString());
      if (idx == -1 || idx >= stops.length - 1) {
        continue;
      }
      list.add(
        BusDeparture(
          routeName: routeName,
          destination: '호서대천캠',
          departureTime: bus['nodenm'],
          minutesLeft: stops.length - 1 - idx,
          routeKey: routeKey,
        ),
      );
    }
  }
  list.sort((a, b) => a.minutesLeft.compareTo(b.minutesLeft));
  return list;
}

/// 노선별로 막차로 표시할 출발 시각(오늘 [day] 기준)을 구한다.
///
/// 출발지와 종점이 같은 노선은 사용자에게 같은 버스이므로 묶어서 가장 늦은 한 대만 막차로 본다.
/// 예: 810·820·821·822번 하행은 모두 호서대학교 기점 → 아산고속버스터미널이라
/// 그날 마지막으로 터미널에 가는 한 대만 막차가 된다.
Map<String, DateTime> lastBusTimeByRoute(
  Map<String, dynamic> busData,
  DateTime day,
) {
  final groupOf = <String, String>{};
  final lastPerGroup = <String, DateTime>{};
  busData.forEach((routeKey, routeData) {
    if (routeKey == 'version' || routeData is! Map) return;
    final List<dynamic> timeList = routeData['시간표'] ?? const [];
    if (timeList.isEmpty) return;
    final group = '${routeData['출발지']}→${routeData['종점']}';
    groupOf[routeKey] = group;
    for (final time in timeList) {
      final parts = time.toString().split(':');
      final departure = DateTime(
        day.year,
        day.month,
        day.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      final last = lastPerGroup[group];
      if (last == null || departure.isAfter(last)) {
        lastPerGroup[group] = departure;
      }
    }
  });
  return {
    for (final entry in groupOf.entries) entry.key: lastPerGroup[entry.value]!,
  };
}

class UpcomingDepartureViewModel extends GetxController
    with WidgetsBindingObserver {
  UpcomingDepartureViewModel({
    ShuttleRepository? shuttleRepository,
    this.campusOverride,
    this.enableAutoRefresh = true,
  }) : _shuttleRepository = shuttleRepository ?? ShuttleRepository();

  final ShuttleRepository _shuttleRepository;
  final String? campusOverride;
  final bool enableAutoRefresh;
  final settingsViewModel = Get.find<SettingsViewModel>();
  final RxString currentCampusRx = ''.obs;

  String get currentCampus =>
      campusOverride == null
          ? settingsViewModel.selectedCampus.value
          : currentCampusRx.value;

  // 홈 공지 새로고침 연동용 NoticeViewModel 지연 조회
  NoticeViewModel? get noticeViewModel {
    try {
      return Get.find<NoticeViewModel>();
    } catch (e) {
      return null; // NoticeViewModel이 아직 초기화되지 않은 경우
    }
  }

  // 데이터 로딩 상태
  var isLoading = true.obs;
  var isRefreshing = false.obs; // 실시간/자동 새로고침 로딩 상태 (UI 전체 로딩이 아닌 상단 인디케이터용)
  var error = ''.obs;
  var _isInitialLoad = true.obs; // 첫 로딩 여부 추적

  // 홈 카드에 표시할 곧 출발 데이터
  final upcomingCityBuses = <BusDeparture>[].obs;
  final upcomingShuttles = <BusDeparture>[].obs;

  // 자동 새로고침 타이머
  Timer? _refreshTimer;

  // 앱/페이지 활성 상태 추적
  final isActive = true.obs;
  final isOnHomePage = true.obs;

  // 셔틀 API 응답 캐시
  Map<String, dynamic>? _cachedShuttleData;
  Map<int, String>? _cachedRouteNames; // 노선 정보 캐시 추가
  int? _previousStationId;

  // 셔틀 상세 화면 진입 시 사용할 값
  final RxInt selectedScheduleId = (-1).obs; // 선택된 스케줄 ID
  final RxString scheduleTypeName =
      ''.obs; // 현재 스케줄 타입 이름 (Weekday, Saturday, Holiday)

  // 오늘 시내버스 운행 종료 여부 플래그
  final isCityBusServiceEnded = false.obs;

  // 오늘 셔틀버스 운행 종료 여부 플래그
  final isShuttleServiceEnded = false.obs;
  // 오늘 셔틀버스 운행 없음 플래그 (schedules가 아예 비어있을 때)
  final isShuttleServiceNotOperated = false.obs;

  // 90분 안에 출발하는 차가 없을 때 보여줄 오늘의 다음 출발(첫차 포함)
  final nextShuttleDeparture = Rxn<NextDepartureHint>();
  // 시내버스는 주요 노선별로 한 줄씩 안내한다.
  final nextCityBusDepartures = <NextDepartureHint>[].obs;

  // 천안 실시간 버스 계산용 정류장 순서 캐시
  List<String> _ce24DownStops = [];
  List<String> _ce81DownStops = [];

  // 천안 캠퍼스 실시간 버스 표시 목록
  final RxList<BusDeparture> ceRealtimeBuses = <BusDeparture>[].obs;

  // 천안 캠퍼스 실시간 위치 웹소켓. 서버가 5초마다 보내고, 접속하면 데워 둔 위치를 바로 보낸다.
  static const String _ceanBusWebSocketPath = '/ws/bus/cheonan/down';
  // 끊긴 뒤 다시 연결할 때 기다리는 시간: 3초부터 두 배씩, 최대 30초
  static const int _ceanReconnectBaseSeconds = 3;
  static const int _ceanReconnectMaxSeconds = 30;
  WebSocketChannel? _ceanChannel;
  StreamSubscription<dynamic>? _ceanSubscription;
  Timer? _ceanReconnectTimer;
  int _ceanReconnectAttempts = 0;
  Map<String, dynamic>? _latestCeanPayload;
  // 헤더의 "● 실시간" 점 표시용. 메시지를 받고 있으면 true
  final isRealtimeConnected = false.obs;

  Worker? _campusWorker;
  Worker? _activeWorker;
  Worker? _homePageWorker;
  bool _isDisposed = false;

  @override
  void onInit() {
    super.onInit();
    // 앱 생명주기 감지 등록
    WidgetsBinding.instance.addObserver(this);
    currentCampusRx.value =
        campusOverride ?? settingsViewModel.selectedCampus.value;

    // 초기 활성 상태 설정
    isActive.value = true;
    isOnHomePage.value = true;

    // 캠퍼스 변경 시 데이터 다시 로드
    if (campusOverride == null) {
      _campusWorker = ever(settingsViewModel.selectedCampus, (_) {
        if (_isDisposed) {
          return;
        }
        _isInitialLoad.value = true; // 캠퍼스 변경 시 첫 로딩처럼 처리
        loadData();
      });
    }

    // 앱 포그라운드/백그라운드 전환 감지
    _activeWorker = ever(isActive, (active) {
      if (_isDisposed) {
        return;
      }
      if (active && isOnHomePage.value) {
        print('앱이 활성화됨 -> 즉시 새로고침');
        // 홈 공지와 출발 정보를 함께 갱신
        noticeViewModel?.fetchLatestNotice();
        loadData();
      } else {
        print('앱이 비활성화됨 -> 타이머 중지');
        _stopRefreshTimer();
        _syncCeanRealtimeConnection();
      }
    });

    // 현재 라우트가 홈인지 여부 감지
    _homePageWorker = ever(isOnHomePage, (onHomePage) {
      if (_isDisposed) {
        return;
      }
      if (onHomePage && isActive.value) {
        print('홈페이지로 돌아옴 -> 즉시 새로고침');
        // 홈으로 복귀하면 공지와 출발 정보 다시 갱신
        noticeViewModel?.fetchLatestNotice();
        loadData();
      } else {
        print('다른 페이지로 이동 -> 타이머 중지');
        _stopRefreshTimer();
        _syncCeanRealtimeConnection();
      }
    });

    // 첫 렌더링 이후 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) {
        return;
      }
      print('위젯 렌더링 완료 후 초기 데이터 로드');
      loadData();
    });
  }

  // 홈 페이지 진입/이탈 상태 업데이트
  void setHomePageState(bool isOnHome) {
    if (_isDisposed) {
      return;
    }
    isOnHomePage.value = isOnHome;
  }

  @override
  void onClose() {
    _isDisposed = true;
    _campusWorker?.dispose();
    _activeWorker?.dispose();
    _homePageWorker?.dispose();
    isActive.value = false;
    isOnHomePage.value = false;
    // 생명주기 옵저버 해제 및 타이머·웹소켓 정리
    WidgetsBinding.instance.removeObserver(this);
    _stopRefreshTimer();
    _disconnectCeanRealtime();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // 앱이 백그라운드로 갔을 때
      isActive.value = false;
    } else if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아왔을 때
      isActive.value = true;
    }
  }

  void _startRefreshTimer() {
    if (_isDisposed || !enableAutoRefresh) {
      _stopRefreshTimer();
      return;
    }

    // 기존 타이머 취소 후 새로 예약
    _stopRefreshTimer();

    // 셔틀(하루 캐시)·시내버스(기기 파일)는 시간표라 남은 분이 바뀌는 분 정각에만 다시 계산한다.
    // 천안 24·81번 실시간 위치는 웹소켓이 따로 갱신한다.
    // loadData 완료 후 다시 예약하는 단발성 타이머 구조
    _refreshTimer = Timer(_durationUntilNextMinute(), () {
      print('자동 새로고침 시작');
      loadData(silent: true);
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // 정각 직전에 깨어나 같은 분으로 계산하지 않도록 조금 늦게 예약한다.
  Duration _durationUntilNextMinute() {
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    return nextMinute.difference(now) + const Duration(milliseconds: 200);
  }

  Future<void> loadData({bool silent = false}) async {
    if (_isDisposed) {
      return;
    }

    // 로딩 중 중복 갱신 방지
    _stopRefreshTimer();

    print('데이터 로드 시작 (silent: $silent)');
    // 수동 새로고침이나 첫 로딩 시 전체 로딩 표시
    if (!silent) {
      isLoading.value = true;
    }
    isRefreshing.value = true; // 로딩 시작
    error.value = '';

    try {
      // 천안은 실시간 위치의 남은 정거장 계산에 정류장 순서가 필요하다.
      if (currentCampus == '천안' &&
          (_ce24DownStops.isEmpty || _ce81DownStops.isEmpty)) {
        await loadCeanStopSequences();
        if (_isDisposed) {
          return;
        }
        // 정류장 순서보다 웹소켓 메시지가 먼저 왔으면 지금 반영한다.
        _applyCeanRealtime();
      }

      await loadCityBusData();
      if (_isDisposed) {
        return;
      }
      await loadShuttleData();
      if (_isDisposed) {
        return;
      }

      print('데이터 로드 완료');
      _isInitialLoad.value = false; // 첫 로딩 완료 표시
    } catch (e) {
      print('데이터 로드 중 오류: $e');
      error.value = '데이터 로드 중 오류가 발생했습니다: $e';
      // 에러가 나도 무한 로딩 방지
      _isInitialLoad.value = false;
    } finally {
      if (!_isDisposed) {
        isLoading.value = false;
        isRefreshing.value = false; // 로딩 종료

        // 활성 상태일 때만 다음 자동 새로고침 예약
        if (enableAutoRefresh && isActive.value && isOnHomePage.value) {
          _startRefreshTimer();
        }
        // 캠퍼스·활성 상태에 맞춰 천캠 실시간 연결을 맺거나 끊는다.
        _syncCeanRealtimeConnection();
      }
    }
  }

  void setWidgetEnabled(bool enabled) {
    if (_isDisposed) {
      return;
    }
    if (enabled == isActive.value) return;
    isActive.value = enabled;
    if (enabled) {
      // 다시 활성화되면 즉시 데이터 갱신
      loadData();
    } else {
      _stopRefreshTimer();
      _syncCeanRealtimeConnection();
    }
  }

  Future<void> loadCityBusData() async {
    try {
      // 현재 캠퍼스 기준 출발지 필터 결정
      final currentCampus = this.currentCampus;
      final Map<String, dynamic> busData = await BusTimesLoader.loadBusTimes();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final realLastBusTimePerRoute = lastBusTimeByRoute(busData, today);
      final upcomingBuses = <BusDeparture>[];
      final String departurePlace =
          currentCampus == '천안' ? '각원사 회차지' : '호서대학교 기점';
      bool lastBusDeparted = true;
      bool anyBusDeparted = false;
      DateTime? nextBusTime;
      String? nextBusRoute;
      // 노선 번호별 오늘 남은 가장 이른 출발
      final Map<String, DateTime> nextBusPerRoute = {};
      // 90분 이내 출발 버스만 추출
      busData.forEach((routeKey, routeData) {
        if (routeKey == 'version') return;
        if (routeData['출발지'] == departurePlace) {
          final List<dynamic> timeList = routeData['시간표'];
          final String destination = routeData['종점'];
          for (final timeStr in timeList) {
            final parts = timeStr.split(':');
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            final second = 0;
            final departureTime = DateTime(
              now.year,
              now.month,
              now.day,
              hour,
              minute,
              second,
            );
            if (departureTime.year == today.year &&
                departureTime.month == today.month &&
                departureTime.day == today.day) {
              final difference = departureTime.difference(now);
              final minutesLeft = (difference.inSeconds / 60).ceil();
              // 오늘 아직 출발하지 않은 버스가 하나라도 있으면 운행 종료가 아니다.
              if (difference.inSeconds > 0) {
                lastBusDeparted = false;
                final routeNumber = routeKey.split('_')[0];
                if (nextBusTime == null ||
                    departureTime.isBefore(nextBusTime!)) {
                  nextBusTime = departureTime;
                  nextBusRoute = routeNumber;
                }
                final routeNext = nextBusPerRoute[routeNumber];
                if (routeNext == null || departureTime.isBefore(routeNext)) {
                  nextBusPerRoute[routeNumber] = departureTime;
                }
              } else {
                anyBusDeparted = true;
              }
              if (difference.inSeconds > 0 && difference.inMinutes <= 90) {
                final busDep = BusDeparture(
                  routeName: routeKey.split('_')[0],
                  destination: destination,
                  departureTime: departureTime,
                  minutesLeft: minutesLeft == 0 ? 1 : minutesLeft,
                  routeKey: routeKey,
                );
                upcomingBuses.add(busDep);
              }
            }
          }
        }
      });
      // 출발 임박 순 정렬
      upcomingBuses.sort((a, b) => a.minutesLeft.compareTo(b.minutesLeft));
      // 실제 막차 시각과 일치하는 항목에 막차 표시
      for (int i = 0; i < upcomingBuses.length; i++) {
        final bus = upcomingBuses[i];
        final realLastDt = realLastBusTimePerRoute[bus.routeKey];
        //print('[막차 디버깅] 노선(routeKey): ${bus.routeKey}, 출발: ${bus.departureTime}, 실막차: $realLastDt, isLastBus: ${(realLastDt != null) && (bus.departureTime == realLastDt)}');
        final isLast =
            (realLastDt != null) && (bus.departureTime == realLastDt);
        upcomingBuses[i] = BusDeparture(
          routeName: bus.routeName,
          destination: bus.destination,
          departureTime: bus.departureTime,
          minutesLeft: bus.minutesLeft,
          scheduleId: bus.scheduleId,
          isLastBus: isLast,
          routeKey: bus.routeKey,
        );
      }
      // 주요 노선(아캠 순환5·1000, 천캠 24·81)은 노선마다 다음 출발을 보여주고,
      // 주요 노선이 모두 끝났으면 남은 노선 중 가장 이른 한 대를 보여준다.
      final mainRoutes =
          currentCampus == '천안' ? const ['24', '81'] : const ['순환5', '1000'];
      final nextBuses = [
        for (final route in mainRoutes)
          if (nextBusPerRoute[route] != null)
            NextDepartureHint(
              time: nextBusPerRoute[route]!,
              isFirstOfDay: !anyBusDeparted,
              routeLabel: route,
            ),
      ]..sort((a, b) => a.time.compareTo(b.time));
      if (nextBuses.isEmpty && nextBusTime != null) {
        nextBuses.add(
          NextDepartureHint(
            time: nextBusTime!,
            isFirstOfDay: !anyBusDeparted,
            routeLabel: nextBusRoute,
          ),
        );
      }
      upcomingCityBuses.value = upcomingBuses.take(3).toList();
      isCityBusServiceEnded.value = lastBusDeparted;
      nextCityBusDepartures.assignAll(nextBuses);
    } catch (e) {
      print('시내버스 데이터 로드 중 오류: $e');
      upcomingCityBuses.clear();
      isCityBusServiceEnded.value = false; // 오류 시 false로 초기화
      nextCityBusDepartures.clear();
    }
  }

  Future<void> loadShuttleData() async {
    print('셔틀버스 데이터 로드 시작');
    try {
      // 캠퍼스별 대표 정류장 기준 시간표 조회
      final currentCampus = this.currentCampus;
      final int stationId = (currentCampus == '천안') ? 14 : 1;
      if (_previousStationId != stationId) {
        _cachedShuttleData = null;
        _cachedRouteNames = null;
        _previousStationId = stationId;
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final String dateStr = DateFormat('yyyy-MM-dd').format(now);
      Map<String, dynamic> responseData;
      // 날짜가 바뀌면 캐시 초기화
      if (_cachedShuttleData != null) {
        if (_cachedShuttleData!['date'] != dateStr) {
          print('캐시된 데이터가 오늘 날짜가 아니므로 캐시 초기화');
          _cachedShuttleData = null;
        } else {
          print('캐시된 데이터가 오늘 날짜이므로 캐시 사용');
        }
      }
      if (_cachedShuttleData == null) {
        responseData = await _shuttleRepository.fetchStationSchedulesByDate(
          stationId: stationId,
          date: dateStr,
        );
        print(responseData);
        _cachedShuttleData = responseData;
      } else {
        responseData = _cachedShuttleData!;
      }
      scheduleTypeName.value =
          responseData['schedule_type_name'] ??
          responseData['schedule_type'] ??
          '';
      final List<dynamic> schedulesData = responseData['schedules'] ?? [];
      final Map<int, String> routeNames = _cachedRouteNames ?? {};
      final upcomingShuttleList = <BusDeparture>[];
      bool lastShuttleDeparted = true;
      Map<int, DateTime> lastShuttleTimePerRoute = {}; // 노선별 막차 시간(전체 기준)
      // 1차: 전체 시간표에서 각 노선별 진짜 막차 시간 구하기
      for (final schedule in schedulesData) {
        final int routeId = schedule['route_id'];
        final arrivalTimeStr = schedule['arrival_time'];
        final timeParts = arrivalTimeStr.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;
        final dt = DateTime(now.year, now.month, now.day, hour, minute, second);
        // 오늘 날짜 체크 생략(이미 서버서 주는 날짜만 오므로)
        if (!lastShuttleTimePerRoute.containsKey(routeId) ||
            lastShuttleTimePerRoute[routeId]!.isBefore(dt)) {
          lastShuttleTimePerRoute[routeId] = dt;
        }
      }
      // schedules가 아예 비어있으면 오늘 운행 없음 플래그 true
      // 오늘 운행 스케줄이 없으면 바로 종료 상태 반영
      if (schedulesData.isEmpty) {
        isShuttleServiceEnded.value = true;
        isShuttleServiceNotOperated.value = true;
        nextShuttleDeparture.value = null;
        upcomingShuttles.clear();
        return;
      } else {
        isShuttleServiceNotOperated.value = false;
      }
      bool anyShuttleDeparted = false;
      DateTime? nextShuttleTime;
      // 노선명 조회와 90분 이내 스케줄 추출
      for (int i = 0; i < schedulesData.length; i++) {
        final schedule = schedulesData[i];
        final int routeId = schedule['route_id'];
        final int scheduleId = schedule['schedule_id'];
        if (!routeNames.containsKey(routeId)) {
          try {
            final routeName = await _shuttleRepository.fetchRouteName(routeId);
            if (routeName != null) {
              routeNames[routeId] = routeName;
              _cachedRouteNames = routeNames;
            }
          } catch (e) {
            print('노선 정보 로드 중 오류: $e');
            routeNames[routeId] = '노선 $routeId';
          }
        }
        final arrivalTimeStr = schedule['arrival_time'];
        final timeParts = arrivalTimeStr.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;
        final departureTime = DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          minute,
          second,
        );
        // 오늘 날짜의 셔틀만 체크
        if (departureTime.year == today.year &&
            departureTime.month == today.month &&
            departureTime.day == today.day) {
          final difference = departureTime.difference(now);
          final minutesLeft = (difference.inSeconds / 60).ceil();
          if (difference.inSeconds > 0 && difference.inMinutes <= 90) {
            // 노선별 출발시간 최신화
            if (!lastShuttleTimePerRoute.containsKey(routeId) ||
                lastShuttleTimePerRoute[routeId]!.isBefore(departureTime)) {
              lastShuttleTimePerRoute[routeId] = departureTime;
            }
            upcomingShuttleList.add(
              BusDeparture(
                routeName: '셔틀',
                destination: routeNames[routeId] ?? '알 수 없음',
                departureTime: departureTime,
                minutesLeft: minutesLeft == 0 ? 1 : minutesLeft,
                scheduleId: scheduleId,
                isLastBus: false,
                routeKey: 'shuttle_route_ $routeId',
              ),
            );
            lastShuttleDeparted = false;
          }
          if (difference.inSeconds > 0) {
            lastShuttleDeparted = false;
            if (nextShuttleTime == null ||
                departureTime.isBefore(nextShuttleTime)) {
              nextShuttleTime = departureTime;
            }
          } else {
            anyShuttleDeparted = true;
          }
        }
      }
      // 각 노선의 마지막 스케줄이면 막차 표시
      for (int i = 0; i < upcomingShuttleList.length; i++) {
        final s = upcomingShuttleList[i];
        final routeId =
            schedulesData.firstWhere(
              (e) => e['schedule_id'] == s.scheduleId,
              orElse: () => null,
            )?['route_id'];
        if (routeId != null &&
            lastShuttleTimePerRoute[routeId] == s.departureTime) {
          upcomingShuttleList[i] = BusDeparture(
            routeName: s.routeName,
            destination: s.destination,
            departureTime: s.departureTime,
            minutesLeft: s.minutesLeft,
            scheduleId: s.scheduleId,
            isLastBus: true,
            routeKey: s.routeKey,
          );
        }
      }
      // 출발 임박 순으로 최대 3개 표시
      upcomingShuttleList.sort(
        (a, b) => a.minutesLeft.compareTo(b.minutesLeft),
      );
      upcomingShuttles.value = upcomingShuttleList.take(3).toList();
      isShuttleServiceEnded.value = lastShuttleDeparted;
      nextShuttleDeparture.value =
          nextShuttleTime == null
              ? null
              : NextDepartureHint(
                time: nextShuttleTime,
                isFirstOfDay: !anyShuttleDeparted,
              );
      if (upcomingShuttles.isNotEmpty &&
          upcomingShuttles[0].scheduleId != null) {
        selectedScheduleId.value = upcomingShuttles[0].scheduleId!;
      }
    } catch (e) {
      print('셔틀버스 데이터 로드 중 오류: $e');
      upcomingShuttles.clear();
      isShuttleServiceEnded.value = false;
      nextShuttleDeparture.value = null;
    }
  }

  Future<void> loadCeanStopSequences() async {
    // 천안 하행 노선 정류장 순서 로드
    final stopData24 = await BusStaticDataLoader.loadStopJson('24_DOWN');
    final stops24 =
        (stopData24['response']['body']['items']['item'] as List)
            .map<String>((e) => e['nodeord'].toString())
            .toList();
    // 81_DOWN
    final stopData81 = await BusStaticDataLoader.loadStopJson('81_DOWN');
    final stops81 =
        (stopData81['response']['body']['items']['item'] as List)
            .map<String>((e) => e['nodeord'].toString())
            .toList();
    // '각원사회차지'(회차지) 제외, '각원사'~'호서대(천안)' 범위만!
    var idx24Start = stops24.indexOf('2');
    var idx24End = stops24.indexOf('7');
    _ce24DownStops = stops24.sublist(idx24Start, idx24End + 1);
    var idx81Start = stops81.indexOf('2');
    var idx81End = stops81.indexOf('4');
    _ce81DownStops = stops81.sublist(idx81Start, idx81End + 1);
  }

  // --- 천캠 실시간 위치 웹소켓 ---------------------------------------------

  bool get _shouldConnectCeanRealtime =>
      !_isDisposed &&
      enableAutoRefresh &&
      currentCampus == '천안' &&
      isActive.value &&
      isOnHomePage.value;

  // 홈 천캠을 보고 있을 때만 연결을 유지한다.
  void _syncCeanRealtimeConnection() {
    if (_shouldConnectCeanRealtime) {
      _connectCeanRealtime();
      return;
    }
    _disconnectCeanRealtime();
    if (currentCampus != '천안') {
      _latestCeanPayload = null;
      ceRealtimeBuses.clear();
    }
  }

  void _connectCeanRealtime() {
    // 이미 연결됐거나 다시 연결을 기다리는 중이면 그대로 둔다.
    if (_ceanChannel != null || _ceanReconnectTimer != null) {
      return;
    }
    final channel = WebSocketChannel.connect(_buildCeanWebSocketUri());
    // 연결 실패는 아래 stream의 onError에서 처리한다. ready를 그냥 두면 처리 안 된 예외로 남는다.
    channel.ready.ignore();
    _ceanChannel = channel;
    _ceanSubscription = channel.stream.listen(
      (dynamic event) {
        final Map<String, dynamic> payload;
        try {
          payload = Map<String, dynamic>.from(
            jsonDecode(event.toString()) as Map,
          );
        } catch (_) {
          return; // pong 같은 다른 메시지
        }
        _ceanReconnectAttempts = 0;
        isRealtimeConnected.value = true;
        _latestCeanPayload = payload;
        _applyCeanRealtime();
      },
      onError: (_) => _handleCeanRealtimeClosed(channel),
      onDone: () => _handleCeanRealtimeClosed(channel),
      cancelOnError: true,
    );
  }

  void _handleCeanRealtimeClosed(WebSocketChannel channel) {
    if (!identical(channel, _ceanChannel)) {
      return; // 이미 정리한 예전 연결
    }
    _closeCeanChannel();
    if (!_shouldConnectCeanRealtime) {
      return;
    }
    final seconds = math.min(
      _ceanReconnectBaseSeconds * (1 << _ceanReconnectAttempts),
      _ceanReconnectMaxSeconds,
    );
    _ceanReconnectAttempts = math.min(_ceanReconnectAttempts + 1, 4);
    print('천캠 실시간 연결 끊김 -> $seconds초 뒤 다시 연결');
    _ceanReconnectTimer = Timer(Duration(seconds: seconds), () {
      _ceanReconnectTimer = null;
      if (_shouldConnectCeanRealtime) {
        _connectCeanRealtime();
      }
    });
  }

  void _closeCeanChannel() {
    _ceanSubscription?.cancel();
    _ceanSubscription = null;
    _ceanChannel?.sink.close();
    _ceanChannel = null;
    isRealtimeConnected.value = false;
  }

  void _disconnectCeanRealtime() {
    _ceanReconnectTimer?.cancel();
    _ceanReconnectTimer = null;
    _ceanReconnectAttempts = 0;
    _closeCeanChannel();
  }

  void _applyCeanRealtime() {
    final payload = _latestCeanPayload;
    if (payload == null || _ce24DownStops.isEmpty || _ce81DownStops.isEmpty) {
      return;
    }
    ceRealtimeBuses.assignAll(
      buildCeanRealtimeBuses(payload, _ce24DownStops, _ce81DownStops),
    );
  }

  Uri _buildCeanWebSocketUri() {
    final Uri baseUri = Uri.parse(EnvConfig.baseUrl);
    final String scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return baseUri.replace(
      scheme: scheme,
      path: _ceanBusWebSocketPath,
      queryParameters: null,
      fragment: null,
    );
  }
}
