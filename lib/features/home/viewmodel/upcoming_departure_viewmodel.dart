import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // rootBundle 사용
import 'package:get/get.dart';
import 'package:hsro/core/utils/bus_times_loader.dart';
import 'package:hsro/features/notice/viewmodel/notice_viewmodel.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:hsro/features/shuttle/repository/shuttle_repository.dart';
import 'package:intl/intl.dart';

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

  // 위젯의 카운트다운 UI와 동기화할 콜백
  Function? _onRefreshCallback;

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

  // 천안 실시간 버스 계산용 정류장 순서 캐시
  List<String> _ce24DownStops = [];
  List<String> _ce81DownStops = [];

  // 천안 캠퍼스 실시간 버스 표시 목록
  final RxList<BusDeparture> ceRealtimeBuses = <BusDeparture>[].obs;

  // 천안 캠퍼스용 임시 시내버스 데이터 저장 (깜박임 방지)
  List<BusDeparture>? _tempCityBuses;
  bool? _tempCityBusServiceEnded;
  List<BusDeparture>? _tempRealtimeBuses;
  Worker? _campusWorker;
  Worker? _activeWorker;
  Worker? _homePageWorker;
  bool _isDisposed = false;

  void setRefreshCallback(Function callback) {
    _onRefreshCallback = callback;
  }

  void clearRefreshCallback() {
    _onRefreshCallback = null;
  }

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
    _onRefreshCallback = null;
    // 생명주기 옵저버 해제 및 타이머 정리
    WidgetsBinding.instance.removeObserver(this);
    _stopRefreshTimer();
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

    // 천안은 더 짧은 주기로 갱신
    final refreshInterval =
        currentCampus == '천안' ? Duration(seconds: 5) : Duration(seconds: 30);

    // loadData 완료 후 다시 예약하는 단발성 타이머 구조
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
      final isCean = currentCampus == '천안';

      // 천안은 실시간 버스와 시간표 버스를 함께 준비 후 한 번에 반영
      if (isCean) {
        // 정류장 순서 캐시가 없으면 먼저 로드
        if (_ce24DownStops.isEmpty || _ce81DownStops.isEmpty) {
          await loadCeanStopSequences();
          if (_isDisposed) {
            return;
          }
          print(
              '[DEBUG] 정류장 시퀀스 로드 완료 - 24_DOWN: ${_ce24DownStops.length}개, 81_DOWN: ${_ce81DownStops.length}개');
        }

        // UI 깜박임 방지를 위해 임시 버퍼에 먼저 적재
        await loadCityBusData(updateUI: false);
        if (_isDisposed) {
          return;
        }
        await loadShuttleData();
        if (_isDisposed) {
          return;
        }
        await fetchCeanRealtimeBuses(updateUI: false);
        if (_isDisposed) {
          return;
        }

        // 준비 완료 후 한 번에 UI 반영
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
        // 아산은 순차 갱신으로 충분
        await loadCityBusData();
        if (_isDisposed) {
          return;
        }
        await loadShuttleData();
        if (_isDisposed) {
          return;
        }
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

        // 로딩 완료 후 UI 카운트다운 리셋
        _onRefreshCallback?.call();

        // 활성 상태일 때만 다음 자동 새로고침 예약
        if (enableAutoRefresh && isActive.value && isOnHomePage.value) {
          _startRefreshTimer();
        }
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
    }
  }

  Future<void> loadCityBusData({bool updateUI = true}) async {
    try {
      // 현재 캠퍼스 기준 출발지 필터 결정
      final currentCampus = this.currentCampus;
      final Map<String, dynamic> busData = await BusTimesLoader.loadBusTimes();
      final Map<String, DateTime> realLastBusTimePerRoute =
          {};
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final upcomingBuses = <BusDeparture>[];
      final String departurePlace =
          currentCampus == '천안' ? '각원사 회차지' : '호서대학교 기점';
      bool lastBusDeparted = true;
      // 노선별 실제 막차 시각 먼저 계산
      busData.forEach((routeKey, routeData) {
        if (routeKey == 'version') return; // version 필드는 무시
        final List<dynamic> timeList = routeData['시간표'];
        if (timeList.isEmpty) return;
        final lastTimeStr = timeList.last;
        final parts = lastTimeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final lastDt = DateTime(now.year, now.month, now.day, hour, minute, 0);
        realLastBusTimePerRoute[routeKey] = lastDt;
      });
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
      // 천안은 임시 버퍼, 그 외는 즉시 UI 갱신
      if (updateUI) {
        upcomingCityBuses.value = upcomingBuses.take(3).toList();
        isCityBusServiceEnded.value = lastBusDeparted;
      } else {
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
      // 오늘 운행 스케줄이 없으면 바로 종료 상태 반영
      if (schedulesData.isEmpty) {
        isShuttleServiceEnded.value = true;
        isShuttleServiceNotOperated.value = true;
        upcomingShuttles.clear();
        return;
      } else {
        isShuttleServiceNotOperated.value = false;
      }
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
              routeKey: 'shuttle_route_ $routeId',
            ));
            lastShuttleDeparted = false;
          }
          if (difference.inSeconds > 0) {
            lastShuttleDeparted = false;
          }
        }
      }
      // 각 노선의 마지막 스케줄이면 막차 표시
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
            routeKey: s.routeKey,
          );
        }
      }
      // 출발 임박 순으로 최대 3개 표시
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
    // 천안 하행 노선 정류장 순서 로드
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
