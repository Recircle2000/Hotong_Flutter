import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // rootBundle 사용
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'settings_viewmodel.dart';
import 'notice_viewmodel.dart';
import 'package:hsro/utils/bus_times_loader.dart';
import '../repository/shuttle_repository.dart';

// BusDeparture에 routeKey 추가 (노선+방향 포함 식별자, 예: '1000_DOWN')
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

  String get currentCampus => campusOverride == null
      ? settingsViewModel.selectedCampus.value
      : currentCampusRx.value;

  // NoticeViewModel 참조 (지연 초기화)
  NoticeViewModel? get noticeViewModel {
    try {
      return Get.find<NoticeViewModel>();
    } catch (e) {
      return null; // NoticeViewModel이 아직 초기화되지 않은 경우
    }
  }

  // 데이터 관련 변수들
  var isLoading = true.obs;
  var isRefreshing = false.obs; // 실시간/자동 새로고침 로딩 상태 (UI 전체 로딩이 아닌 상단 인디케이터용)
  var error = ''.obs;
  var _isInitialLoad = true.obs; // 첫 로딩 여부 추적

  // 곧 출발 데이터
  final upcomingCityBuses = <BusDeparture>[].obs;
  final upcomingShuttles = <BusDeparture>[].obs;

  // 로딩 타이머
  Timer? _refreshTimer;

  // 새로고침 콜백 - UI와 동기화하기 위함
  Function? _onRefreshCallback;

  // 활성 상태 추적
  final isActive = true.obs;
  final isOnHomePage = true.obs;

  // 셔틀 데이터 캐시를 위한 변수들
  Map<String, dynamic>? _cachedShuttleData;
  Map<int, String>? _cachedRouteNames; // 노선 정보 캐시 추가
  int? _previousStationId;

  // 셔틀 노선 상세 페이지 이동을 위한 변수들
  final RxInt selectedScheduleId = (-1).obs; // 선택된 스케줄 ID
  final RxString scheduleTypeName =
      ''.obs; // 현재 스케줄 타입 이름 (Weekday, Saturday, Holiday)

  // 오늘 시내버스 운행 종료 여부 플래그
  final isCityBusServiceEnded = false.obs;

  // 오늘 셔틀버스 운행 종료 여부 플래그
  final isShuttleServiceEnded = false.obs;
  // 오늘 셔틀버스 운행 없음 플래그 (schedules가 아예 비어있을 때)
  final isShuttleServiceNotOperated = false.obs;

  // 추가: 천안 24_DOWN, 81_DOWN 노선 호서대(천안) 인근정류장 순서(회차지 제외)
  List<String> _ce24DownStops = [];
  List<String> _ce81DownStops = [];

  // 각 노선별 실시간 위치에서, 호서대(천안)까지 남은 정류장 수 계산용 버스 표시 목록
  final RxList<BusDeparture> ceRealtimeBuses = <BusDeparture>[].obs;

  // 천안 캠퍼스용 임시 시내버스 데이터 저장 (깜박임 방지)
  List<BusDeparture>? _tempCityBuses;
  bool? _tempCityBusServiceEnded;
  List<BusDeparture>? _tempRealtimeBuses;

  void setRefreshCallback(Function callback) {
    _onRefreshCallback = callback;
  }

  void clearRefreshCallback() {
    _onRefreshCallback = null;
  }

  @override
  void onInit() {
    super.onInit();
    // 앱 상태 감지를 위한 옵저버 등록
    WidgetsBinding.instance.addObserver(this);
    currentCampusRx.value =
        campusOverride ?? settingsViewModel.selectedCampus.value;

    // 활성 상태 추적 변수 설정
    isActive.value = true;
    isOnHomePage.value = true;

    // 캠퍼스 설정이 변경되면 데이터 다시 로드 및 타이머 재시작
    if (campusOverride == null) {
      ever(settingsViewModel.selectedCampus, (_) {
      _isInitialLoad.value = true; // 캠퍼스 변경 시 첫 로딩으로 처리
      loadData();
      // loadData 내부에서 타이머 관리하므로 _startRefreshTimer() 호출 불필요
      });
    }

    // 활성 상태 변경 리스너 (앱 포그라운드/백그라운드)
    ever(isActive, (active) {
      if (active && isOnHomePage.value) {
        print('앱이 활성화됨 -> 즉시 새로고침');
        // 공지사항도 함께 새로고침
        noticeViewModel?.fetchLatestNotice();
        // 데이터 로드 (완료 후 타이머 시작 및 UI 리셋은 loadData 내부에서 처리)
        loadData();
      } else {
        print('앱이 비활성화됨 -> 타이머 중지');
        _stopRefreshTimer();
      }
    });

    // 페이지 상태 변경 리스너 (홈 페이지/다른 페이지)
    ever(isOnHomePage, (onHomePage) {
      if (onHomePage && isActive.value) {
        print('홈페이지로 돌아옴 -> 즉시 새로고침');
        // 공지사항도 함께 새로고침
        noticeViewModel?.fetchLatestNotice();
        // 데이터 로드 (완료 후 타이머 시작 및 UI 리셋은 loadData 내부에서 처리)
        loadData();
      } else {
        print('다른 페이지로 이동 -> 타이머 중지');
        _stopRefreshTimer();
      }
    });

    // 초기 데이터 로드 및 타이머 시작 (프레임이 완전히 렌더링된 후 실행)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('위젯 렌더링 완료 후 초기 데이터 로드');
      loadData();
    });
  }

  // 페이지 상태 업데이트 함수
  void setHomePageState(bool isOnHome) {
    isOnHomePage.value = isOnHome;
  }

  @override
  void onClose() {
    // 앱 상태 감지 옵저버 제거
    WidgetsBinding.instance.removeObserver(this);
    _stopRefreshTimer();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    if (!enableAutoRefresh) {
      _stopRefreshTimer();
      return;
    }

    // 기존 타이머 취소 (중복 실행 방지)
    _stopRefreshTimer();

    // 천안 캠퍼스는 5초, 나머지는 30초 후 업데이트 (단발성 Timer)
    final refreshInterval = currentCampus == '천안'
        ? Duration(seconds: 5)
        : Duration(seconds: 30);

    // Timer.periodic 대신 Timer 사용 -> loadData 완료 후 다시 예약하는 재귀적 구조
    _refreshTimer = Timer(refreshInterval, () {
      print('자동 새로고침 시작');
      loadData(silent: true);
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> loadData({bool silent = false}) async {
    // 로딩 중에는 타이머가 돌 필요 없으므로 취소
    _stopRefreshTimer();

    print('데이터 로드 시작 (silent: $silent)');
    // silent가 false이면 항상 로딩 인디케이터 표시 (수동 새로고침 또는 첫 로딩)
    if (!silent) {
      isLoading.value = true;
    }
    isRefreshing.value = true; // 로딩 시작
    error.value = '';

    try {
      final isCean = currentCampus == '천안';

      // 천안 캠퍼스인 경우: 모든 데이터를 준비한 후 한 번에 업데이트 (깜박임 방지)
      if (isCean) {
        // 정류장 시퀀스가 비어있으면 먼저 로드
        if (_ce24DownStops.isEmpty || _ce81DownStops.isEmpty) {
          await loadCeanStopSequences();
          print(
              '[DEBUG] 정류장 시퀀스 로드 완료 - 24_DOWN: ${_ce24DownStops.length}개, 81_DOWN: ${_ce81DownStops.length}개');
        }

        // 모든 데이터를 먼저 준비 (UI 업데이트 없이)
        await loadCityBusData(updateUI: false);
        await loadShuttleData();
        await fetchCeanRealtimeBuses(updateUI: false);

        // 모든 데이터가 준비된 후 한 번에 UI 업데이트 (실시간 버스 먼저, 시간표 버스 나중에)
        if (_tempRealtimeBuses != null) {
          ceRealtimeBuses.clear();
          ceRealtimeBuses.assignAll(_tempRealtimeBuses!);
          _tempRealtimeBuses = null;
        }
        if (_tempCityBuses != null) {
          upcomingCityBuses.value = _tempCityBuses!.take(3).toList();
          if (_tempCityBusServiceEnded != null) {
            isCityBusServiceEnded.value = _tempCityBusServiceEnded!;
          }
          _tempCityBuses = null;
          _tempCityBusServiceEnded = null;
        }
      } else {
        // 아산 캠퍼스인 경우: 기존대로 순차적으로 업데이트
        await loadCityBusData();
        await loadShuttleData();
      }

      print('데이터 로드 완료');
      _isInitialLoad.value = false; // 첫 로딩 완료 표시
    } catch (e) {
      print('데이터 로드 중 오류: $e');
      error.value = '데이터 로드 중 오류가 발생했습니다: $e';
      // 에러 발생 시에도 첫 로딩 완료 처리 (무한 로딩 방지)
      _isInitialLoad.value = false;
    } finally {
      isLoading.value = false;
      isRefreshing.value = false; // 로딩 종료

      // 로딩 완료 후 (성공/실패 무관)
      // 1. UI 타이머 리셋
      _onRefreshCallback?.call();

      // 2. 다음 자동 새로고침 예약 (활성 상태이고 홈일 때만)
      if (enableAutoRefresh && isActive.value && isOnHomePage.value) {
        _startRefreshTimer();
      }
    }
  }

  void setWidgetEnabled(bool enabled) {
    if (enabled == isActive.value) return;
    isActive.value = enabled;
    if (enabled) {
      loadData();
    } else {
      _stopRefreshTimer();
    }
  }

  Future<void> loadCityBusData({bool updateUI = true}) async {
    try {
      // 현재 캠퍼스 확인
      final currentCampus = this.currentCampus;
      // bus_times.json 파일 읽기
      final Map<String, dynamic> busData = await BusTimesLoader.loadBusTimes();
      final Map<String, DateTime> realLastBusTimePerRoute =
          {}; // 한 번만 선언, 모든 곳에서 이 변수 이용
      // 현재 시간 및 오늘 날짜
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // 곧 출발하는 버스 리스트
      final upcomingBuses = <BusDeparture>[];
      // 캠퍼스에 따라 다른 출발지 설정
      final String departurePlace =
          currentCampus == '천안' ? '각원사 회차지' : '호서대학교 기점';
      // 오늘 운행 종료 플래그 초기화
      bool lastBusDeparted = true;
      busData.forEach((routeKey, routeData) {
        if (routeKey == 'version') return; // version 필드는 무시
        final List<dynamic> timeList = routeData['시간표'];
        if (timeList.isEmpty) return;
        final lastTimeStr = timeList.last;
        final parts = lastTimeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final lastDt = DateTime(now.year, now.month, now.day, hour, minute, 0);
        // routeKey(노선+방향)로 저장!
        realLastBusTimePerRoute[routeKey] = lastDt;
      });
      // 곧 출발하는 버스 리스트
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
            final departureTime =
                DateTime(now.year, now.month, now.day, hour, minute, second);
            if (departureTime.year == today.year &&
                departureTime.month == today.month &&
                departureTime.day == today.day) {
              final difference = departureTime.difference(now);
              final minutesLeft = (difference.inSeconds / 60).ceil();
              if (difference.inSeconds > 0 && difference.inMinutes <= 90) {
                final busDep = BusDeparture(
                  routeName: routeKey.split('_')[0],
                  destination: destination,
                  departureTime: departureTime,
                  minutesLeft: minutesLeft == 0 ? 1 : minutesLeft,
                  routeKey: routeKey, // 실제 키 전달
                );
                upcomingBuses.add(busDep);
              }
            }
          }
        }
      });
      // 출발시간 기준 정렬
      upcomingBuses.sort((a, b) => a.minutesLeft.compareTo(b.minutesLeft));
      // 막차 표기 (routeKey와 출발시각 모두 해당 노선+방향 실제 막차와 일치할 때만 true)
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
      // updateUI가 true일 때만 UI 업데이트 (천안 캠퍼스에서 깜박임 방지)
      if (updateUI) {
        // 최대 3개만 표시
        upcomingCityBuses.value = upcomingBuses.take(3).toList();
        // 운행 종료 플래그 업데이트
        isCityBusServiceEnded.value = lastBusDeparted;
      } else {
        // updateUI가 false면 임시 변수에 저장 (천안 캠퍼스 전용)
        _tempCityBuses = upcomingBuses;
        _tempCityBusServiceEnded = lastBusDeparted;
      }
    } catch (e) {
      print('시내버스 데이터 로드 중 오류: $e');
      if (updateUI) {
        upcomingCityBuses.clear();
        isCityBusServiceEnded.value = false; // 오류 시 false로 초기화
      }
    }
  }

  Future<void> loadShuttleData() async {
    print('셔틀버스 데이터 로드 시작');
    try {
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
      scheduleTypeName.value = responseData['schedule_type_name'] ??
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
      if (schedulesData.isEmpty) {
        isShuttleServiceEnded.value = true;
        isShuttleServiceNotOperated.value = true;
        upcomingShuttles.clear();
        return;
      } else {
        isShuttleServiceNotOperated.value = false;
      }
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
        final departureTime =
            DateTime(now.year, now.month, now.day, hour, minute, second);
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
            upcomingShuttleList.add(BusDeparture(
              routeName: '셔틀',
              destination: routeNames[routeId] ?? '알 수 없음',
              departureTime: departureTime,
              minutesLeft: minutesLeft == 0 ? 1 : minutesLeft,
              scheduleId: scheduleId,
              isLastBus: false,
              routeKey: 'shuttle_route_ $routeId', // 고유 셔틀노선 식별자로!
            ));
            lastShuttleDeparted = false;
          }
          if (difference.inSeconds > 0) {
            lastShuttleDeparted = false;
          }
        }
      }
      // 2차: upcomingShuttleList(90분 내)에 대입 (아래 for문 내 중복 생성 방지, 기존 for문 교체)
      for (int i = 0; i < upcomingShuttleList.length; i++) {
        final s = upcomingShuttleList[i];
        final routeId = schedulesData.firstWhere(
            (e) => e['schedule_id'] == s.scheduleId,
            orElse: () => null)?['route_id'];
        if (routeId != null &&
            lastShuttleTimePerRoute[routeId] == s.departureTime) {
          upcomingShuttleList[i] = BusDeparture(
            routeName: s.routeName,
            destination: s.destination,
            departureTime: s.departureTime,
            minutesLeft: s.minutesLeft,
            scheduleId: s.scheduleId,
            isLastBus: true,
            routeKey: s.routeKey, // BusDeparture내 값 계승
          );
        }
      }
      upcomingShuttleList
          .sort((a, b) => a.minutesLeft.compareTo(b.minutesLeft));
      upcomingShuttles.value = upcomingShuttleList.take(3).toList();
      isShuttleServiceEnded.value = lastShuttleDeparted;
      if (upcomingShuttles.isNotEmpty &&
          upcomingShuttles[0].scheduleId != null) {
        selectedScheduleId.value = upcomingShuttles[0].scheduleId!;
      }
    } catch (e) {
      print('셔틀버스 데이터 로드 중 오류: $e');
      upcomingShuttles.clear();
      isShuttleServiceEnded.value = false;
    }
  }

  Future<void> loadCeanStopSequences() async {
    // 24_DOWN
    final stopFile24 =
        await rootBundle.loadString('assets/bus_stops/24_DOWN.json');
    final stops24 =
        (json.decode(stopFile24)['response']['body']['items']['item'] as List)
            .map<String>((e) => e['nodeord'].toString())
            .toList();
    // 81_DOWN
    final stopFile81 =
        await rootBundle.loadString('assets/bus_stops/81_DOWN.json');
    final stops81 =
        (json.decode(stopFile81)['response']['body']['items']['item'] as List)
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

  Future<void> fetchCeanRealtimeBuses({bool updateUI = true}) async {
    // 실시간 위치 불러오기
    final data = await _shuttleRepository.fetchRealtimeBuses();
    if (data == null) {
      if (updateUI) {
        ceRealtimeBuses.clear();
      } else {
        _tempRealtimeBuses = [];
      }
      return;
    }
    var list = <BusDeparture>[];
    // 24_DOWN
    if (data['buses']['24_DOWN'] is List) {
      for (var bus in data['buses']['24_DOWN']) {
        final cur = bus['nodeord'].toString();
        final idx = _ce24DownStops.indexOf(cur);
        if (idx == -1) {
          continue; // 각원사~호서대(천안) 범위 밖
        }
        if (idx < _ce24DownStops.length - 1) {
          int left = _ce24DownStops.length - 1 - idx;
          list.add(BusDeparture(
            routeName: '24',
            destination: '호서대천캠',
            departureTime: bus['nodenm'],
            minutesLeft: left,
            routeKey: '24_DOWN',
            isLastBus: false,
          ));
        }
      }
    }
    // 81_DOWN
    if (data['buses']['81_DOWN'] is List) {
      for (var bus in data['buses']['81_DOWN']) {
        final cur = bus['nodeord'].toString();
        final idx = _ce81DownStops.indexOf(cur);
        if (idx == -1) {
          continue; // 각원사~호서대(천안) 범위 밖
        }
        if (idx < _ce81DownStops.length - 1) {
          int left = _ce81DownStops.length - 1 - idx;
          list.add(BusDeparture(
            routeName: '81',
            destination: '호서대천캠',
            departureTime: bus['nodenm'],
            minutesLeft: left,
            routeKey: '81_DOWN',
            isLastBus: false,
          ));
        }
      }
    }
    // updateUI에 따라 즉시 업데이트 또는 임시 저장
    // 정류장 위치가 '전', '전전', 'n전'일수록 더 위에 오도록 정렬 (남은 정거장 수 오름차순)
    list.sort((a, b) => a.minutesLeft.compareTo(b.minutesLeft));
    if (updateUI) {
      ceRealtimeBuses.clear();
      ceRealtimeBuses.assignAll(list);
    } else {
      _tempRealtimeBuses = list;
    }
  }
}
