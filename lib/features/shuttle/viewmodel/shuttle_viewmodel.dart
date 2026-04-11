import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:hsro/core/services/preferences_service.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/repository/shuttle_repository.dart';

class ShuttleViewModel extends GetxController {
  ShuttleViewModel({
    ShuttleRepository? shuttleRepository,
    PreferencesService? preferencesService,
  })  : _shuttleRepository = shuttleRepository ?? ShuttleRepository(),
        _preferencesService = preferencesService ?? PreferencesService();

  final ShuttleRepository _shuttleRepository;
  final PreferencesService _preferencesService;

  // 셔틀 화면 전반에서 공유하는 데이터 목록
  final RxList<ShuttleRoute> routes = <ShuttleRoute>[].obs;
  final RxList<Schedule> schedules = <Schedule>[].obs;
  final RxList<ScheduleStop> scheduleStops = <ScheduleStop>[].obs;
  final RxList<ShuttleStation> stations = <ShuttleStation>[].obs;

  // 현재 선택 상태
  final RxInt selectedRouteId = (-1).obs;
  final RxString selectedDate = ''.obs;
  final RxInt selectedScheduleId = (-1).obs;
  final RxString scheduleTypeName = ''.obs; // 응답에서 받은 스케줄 타입 이름

  // 화면별 로딩 상태
  final RxBool isLoadingRoutes = false.obs;
  final RxBool isLoadingSchedules = false.obs;
  final RxBool isLoadingStops = false.obs;
  final RxBool isLoadingStations = false.obs;
  final RxBool isLoadingScheduleType = false.obs;
  final RxnString errorMessage = RxnString();

  // 운행 유형 표시명 매핑
  final Map<String, String> scheduleTypeNames = {
    'Weekday': '평일',
    'Saturday': '토요일',
    'Holiday': '일요일/공휴일'
  };

  // 기본값 자동 적용 여부
  final RxBool useDefaultValues = true.obs;
  String _latestScheduleTypeRequestDate = '';

  @override
  void onInit() {
    super.onInit();
    fetchRoutes().then((_) {
      // 노선 로드 후 기본 날짜와 기본 노선 적용
      if (useDefaultValues.value) {
        setDefaultValues();
      }
    });
  }

  // 기본값 설정
  void setDefaultValues() {
    try {
      // 오늘 날짜를 기본 선택값으로 설정
      setDefaultDate();

      // 첫 번째 노선을 기본 선택값으로 설정
      if (routes.isNotEmpty && selectedRouteId.value == -1) {
        selectedRouteId.value = routes.first.id;
      }
    } catch (e) {
      print('기본값 설정 중 오류 발생: $e');
    }
  }

  // 현재 날짜를 기본값으로 설정
  void setDefaultDate() {
    try {
      final now = DateTime.now();
      final defaultDate = DateFormat('yyyy-MM-dd').format(now);

      // 날짜가 비어 있을 때만 기본값 적용
      if (selectedDate.value.isEmpty) {
        selectedDate.value = defaultDate;
        fetchScheduleTypeByDate(defaultDate);
      }
    } catch (e) {
      print('기본 날짜 설정 중 오류 발생: $e');
      // 오류가 나도 오늘 날짜로 fallback
      if (selectedDate.value.isEmpty) {
        final now = DateTime.now();
        final defaultDate = DateFormat('yyyy-MM-dd').format(now);
        selectedDate.value = defaultDate;
        fetchScheduleTypeByDate(defaultDate);
      }
    }
  }

  // 기본값 사용 여부 설정
  void setUseDefaultValues(bool value) {
    useDefaultValues.value = value;
    if (value) {
      setDefaultValues();
    }
  }

  void clearErrorMessage() {
    errorMessage.value = null;
  }

  void _emitError(String message) {
    // 동일 메시지도 다시 표시되게 한 번 비웠다가 재설정
    errorMessage.value = null;
    errorMessage.value = message;
  }

  // 노선 목록 조회
  Future<void> fetchRoutes() async {
    isLoadingRoutes.value = true;
    try {
      var routeList = await _shuttleRepository.fetchRoutes();

      // 천안 설정이면 노선 순서만 사용자 기준에 맞게 조정
      final campusSetting =
          await _preferencesService.getStringOrDefault('campus', '아산');
      if (campusSetting == '천안') {
        routeList = _reorderRoutesForCheonan(routeList);
      }

      routes.value = routeList;
    } catch (e) {
      print('노선 목록을 불러오는데 실패했습니다: $e');
      _emitError('노선 정보를 불러오는데 실패했습니다.');
    } finally {
      isLoadingRoutes.value = false;
    }
  }

  // 천안 설정일 때 노선 순서 조정
  List<ShuttleRoute> _reorderRoutesForCheonan(
      List<ShuttleRoute> originalRoutes) {
    List<ShuttleRoute> reorderedRoutes = List.from(originalRoutes);

    // 양방향 대표 노선 위치 찾기
    int asanToCheonanIndex = -1;
    int cheonanToAsanIndex = -1;

    for (int i = 0; i < reorderedRoutes.length; i++) {
      if (reorderedRoutes[i].routeName.contains('아캠 → 천캠')) {
        asanToCheonanIndex = i;
      } else if (reorderedRoutes[i].routeName.contains('천캠 → 아캠')) {
        cheonanToAsanIndex = i;
      }
    }

    // 천안 기준에서 더 자주 쓰는 방향이 먼저 보이도록 재정렬
    if (asanToCheonanIndex != -1 &&
        cheonanToAsanIndex != -1 &&
        cheonanToAsanIndex > asanToCheonanIndex) {
      // 천안→아산 노선을 아산→천안 노선 앞으로 이동
      ShuttleRoute cheonanToAsanRoute =
          reorderedRoutes.removeAt(cheonanToAsanIndex);
      reorderedRoutes.insert(asanToCheonanIndex, cheonanToAsanRoute);
    }

    return reorderedRoutes;
  }

  // 노선/날짜 기준 시간표 조회
  Future<bool> fetchSchedules(int routeId, String date) async {
    isLoadingSchedules.value = true;
    schedules.clear();
    selectedScheduleId.value = -1;
    scheduleStops.clear();
    String scheduleTypeName = '';

    try {
      final data = await _shuttleRepository.fetchSchedulesByDate(
        routeId: routeId,
        date: date,
      );

      if (data == null) {
        print('해당 날짜에 운행하는 셔틀노선이 없습니다 (404)');
        return false;
      }

      // 응답에 운행 유형명이 있으면 같이 저장
      if (data.containsKey('schedule_type_name')) {
        scheduleTypeName = data['schedule_type_name'];
        this.scheduleTypeName.value = scheduleTypeName;
      } else {
        this.scheduleTypeName.value = '';
      }

      // 시작 시각 기준으로 정렬 후 회차 번호 다시 매김
      final List<dynamic> scheduleData = data['schedules'];
      scheduleData.sort((a, b) {
        final aTime = a['start_time'];
        final bTime = b['start_time'];
        return aTime.compareTo(bTime);
      });

      for (int i = 0; i < scheduleData.length; i++) {
        scheduleData[i]['round'] = i + 1;
      }

      schedules.value =
          scheduleData.map((item) => Schedule.fromJson(item)).toList();

      if (useDefaultValues.value && schedules.isNotEmpty) {
        //selectNearestSchedule();
      }
      return true;
    } catch (e) {
      print('시간표를 불러오는데 실패했습니다: $e');
      _emitError('시간표를 불러오는데 실패했습니다.');
      return false;
    } finally {
      isLoadingSchedules.value = false;
    }
  }

  // 현재 시간에 가장 가까운 스케줄 선택
  void selectNearestSchedule() {
    try {
      final now = DateTime.now();

      // 현재 시각 이후 회차만 후보로 사용
      final futureSchedules = schedules
          .where((schedule) => schedule.startTime.isAfter(now))
          .toList();

      if (futureSchedules.isNotEmpty) {
        // 가장 이른 회차를 선택
        futureSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));
        selectSchedule(futureSchedules.first.id);
      } else {
        selectedScheduleId.value = -1;
      }
    } catch (e) {
      print('가장 가까운 스케줄 선택 중 오류 발생: $e');
    }
  }

  // 회차별 정류장 목록 조회
  Future<bool> fetchScheduleStops(int scheduleId) async {
    isLoadingStops.value = true;
    scheduleStops.clear();

    try {
      final data = await _shuttleRepository.fetchScheduleStops(scheduleId);
      if (data == null) {
        print('해당 스케줄의 정류장 정보가 없습니다 (404)');
        return false;
      }

      scheduleStops.value = data;
      return true;
    } catch (e) {
      print('정류장 정보를 불러오는데 실패했습니다: $e');

      return false;
    } finally {
      isLoadingStops.value = false;
    }
  }

  // 인라인 확장용 정류장 목록 조회
  Future<List<ScheduleStop>?> fetchScheduleStopsForInline(
      int scheduleId) async {
    try {
      final data = await _shuttleRepository.fetchScheduleStops(scheduleId);
      if (data == null) {
        print('해당 스케줄의 정류장 정보가 없습니다 (404)');
        return null;
      }
      return data;
    } catch (e) {
      print('인라인 정류장 정보를 불러오는데 실패했습니다: $e');
      return null;
    }
  }

  // 정류장 목록 조회
  Future<void> fetchStations() async {
    isLoadingStations.value = true;
    try {
      stations.value = await _shuttleRepository.fetchStations();
    } catch (e) {
      print('정류장 목록을 불러오는데 실패했습니다: $e');
      _emitError('정류장 목록을 불러오는데 실패했습니다.');
    } finally {
      isLoadingStations.value = false;
    }
  }

  // 노선 선택 처리
  void selectRoute(int routeId) {
    if (selectedRouteId.value == routeId) return;

    selectedRouteId.value = routeId;
    schedules.clear();
    selectedScheduleId.value = -1;
    scheduleStops.clear();

    // 조회 버튼을 누를 때만 API 호출
    // if (selectedScheduleType.value.isNotEmpty) {
    //   fetchSchedules(routeId, selectedScheduleType.value);
    // }
  }

  // 날짜 선택 처리
  void selectDate(String date) {
    if (selectedDate.value == date) return;

    selectedDate.value = date;
    schedules.clear();
    selectedScheduleId.value = -1;
    scheduleStops.clear();
    fetchScheduleTypeByDate(date);
  }

  // 날짜 기준 운행 유형 조회
  Future<void> fetchScheduleTypeByDate(String date) async {
    if (date.isEmpty) {
      scheduleTypeName.value = '';
      return;
    }

    _latestScheduleTypeRequestDate = date;
    isLoadingScheduleType.value = true;

    try {
      final data = await _shuttleRepository.fetchScheduleTypeByDate(date);

      // 빠르게 날짜를 바꾼 경우 이전 응답은 무시
      if (_latestScheduleTypeRequestDate != date) {
        return;
      }

      scheduleTypeName.value = data?['schedule_type_name'] ?? '';
    } catch (e) {
      print('날짜별 운행 유형을 불러오는데 실패했습니다: $e');
      if (_latestScheduleTypeRequestDate == date) {
        scheduleTypeName.value = '';
      }
    } finally {
      if (_latestScheduleTypeRequestDate == date) {
        isLoadingScheduleType.value = false;
      }
    }
  }

  // 시간표 선택 시 정류장 목록도 함께 조회
  void selectSchedule(int scheduleId) {
    selectedScheduleId.value = scheduleId;
    fetchScheduleStops(scheduleId);
  }

  // 특정 정류장 상세 정보 조회
  Future<ShuttleStation?> fetchStationDetail(int stationId) async {
    try {
      final stationList = await _shuttleRepository.fetchStations(
        stationId: stationId,
      );
      if (stationList.isNotEmpty) {
        return stationList.first;
      }
      throw Exception('정류장 정보가 없습니다.');
    } catch (e) {
      print('정류장 정보를 불러오는데 실패했습니다: $e');
      _emitError('정류장 정보를 불러오는데 실패했습니다.');
      return null;
    }
  }
}
