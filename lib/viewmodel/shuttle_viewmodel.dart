import 'package:get/get.dart';
import '../models/shuttle_models.dart';
import 'package:intl/intl.dart';
import '../repository/shuttle_repository.dart';
import '../services/preferences_service.dart';

class ShuttleViewModel extends GetxController {
  ShuttleViewModel({
    ShuttleRepository? shuttleRepository,
    PreferencesService? preferencesService,
  })  : _shuttleRepository = shuttleRepository ?? ShuttleRepository(),
        _preferencesService = preferencesService ?? PreferencesService();

  final ShuttleRepository _shuttleRepository;
  final PreferencesService _preferencesService;

  final RxList<ShuttleRoute> routes = <ShuttleRoute>[].obs;
  final RxList<Schedule> schedules = <Schedule>[].obs;
  final RxList<ScheduleStop> scheduleStops = <ScheduleStop>[].obs;
  final RxList<ShuttleStation> stations = <ShuttleStation>[].obs;

  // 선택된 아이템 관리
  final RxInt selectedRouteId = (-1).obs;
  final RxString selectedDate = ''.obs;
  final RxInt selectedScheduleId = (-1).obs;
  final RxString scheduleTypeName = ''.obs; // 응답에서 받은 스케줄 타입 이름

  // 로딩 상태 관리
  final RxBool isLoadingRoutes = false.obs;
  final RxBool isLoadingSchedules = false.obs;
  final RxBool isLoadingStops = false.obs;
  final RxBool isLoadingStations = false.obs;
  final RxBool isLoadingScheduleType = false.obs;
  final RxnString errorMessage = RxnString();

  // 운행 일자 타입 정보 - 응답에서만 사용
  final Map<String, String> scheduleTypeNames = {
    'Weekday': '평일',
    'Saturday': '토요일',
    'Holiday': '일요일/공휴일'
  };

  // 기본값 설정
  final RxBool useDefaultValues = true.obs;
  String _latestScheduleTypeRequestDate = '';

  @override
  void onInit() {
    super.onInit();
    fetchRoutes().then((_) {
      // 라우트 로딩이 완료된 후 기본값 설정
      if (useDefaultValues.value) {
        setDefaultValues();
      }
    });
  }

  // 기본값 설정 함수
  void setDefaultValues() {
    try {
      // 현재 날짜를 기본값으로 설정
      setDefaultDate();

      // 첫 번째 라우트를 기본값으로 설정 (API 호출 없이)
      if (routes.isNotEmpty && selectedRouteId.value == -1) {
        // selectRoute가 API를 호출하지 않도록 직접 값만 설정
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

      // 기본값 설정 (selectedDate가 빈 문자열인 경우에만)
      if (selectedDate.value.isEmpty) {
        selectedDate.value = defaultDate;
        fetchScheduleTypeByDate(defaultDate);
      }
    } catch (e) {
      print('기본 날짜 설정 중 오류 발생: $e');
      // 오류 발생 시 기본값으로 오늘 날짜 설정
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
    errorMessage.value = null;
    errorMessage.value = message;
  }

  // 노선 목록 조회
  Future<void> fetchRoutes() async {
    isLoadingRoutes.value = true;
    try {
      var routeList = await _shuttleRepository.fetchRoutes();

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

    // "아산캠퍼스 → 천안캠퍼스"와 "천안캠퍼스 → 아산캠퍼스" 노선 찾기
    int asanToCheonanIndex = -1;
    int cheonanToAsanIndex = -1;

    for (int i = 0; i < reorderedRoutes.length; i++) {
      if (reorderedRoutes[i].routeName.contains('아캠 → 천캠')) {
        asanToCheonanIndex = i;
      } else if (reorderedRoutes[i].routeName.contains('천캠 → 아캠')) {
        cheonanToAsanIndex = i;
      }
    }

    // 두 노선이 모두 존재하고 천안→아산이 아산→천안보다 뒤에 있는 경우 순서 변경
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

  // 시간표 조회
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

      if (data.containsKey('schedule_type_name')) {
        scheduleTypeName = data['schedule_type_name'];
        this.scheduleTypeName.value = scheduleTypeName;
      } else {
        this.scheduleTypeName.value = '';
      }

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

      // 현재 시간 이후의 가장 가까운 스케줄 찾기
      final futureSchedules = schedules
          .where((schedule) => schedule.startTime.isAfter(now))
          .toList();

      if (futureSchedules.isNotEmpty) {
        // 시간 기준으로 정렬
        futureSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));
        selectSchedule(futureSchedules.first.id);
      } else if (schedules.isNotEmpty) {
        // 이후 스케줄이 없다면 마지막 스케줄 선택
        selectSchedule(schedules.last.id);
      }
    } catch (e) {
      print('가장 가까운 스케줄 선택 중 오류 발생: $e');
    }
  }

  // 정류장 정보 조회
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

  // 인라인 상세 조회용 정류장 정보 조회 (전역 상태 미변경)
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

    // 자동 API 호출 제거
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

      // 빠르게 날짜를 바꾼 경우 이전 요청 결과는 무시
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

  // 시간표 선택 처리
  void selectSchedule(int scheduleId) {
    selectedScheduleId.value = scheduleId;
    fetchScheduleStops(scheduleId);
  }

  // 특정 정류장의 상세 정보 조회
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
