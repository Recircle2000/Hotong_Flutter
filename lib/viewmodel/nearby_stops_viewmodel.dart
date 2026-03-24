import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/shuttle_models.dart';
import '../repository/shuttle_repository.dart';
import '../services/preferences_service.dart';

class NearbyStopsUiMessage {
  final String title;
  final String message;

  const NearbyStopsUiMessage({
    required this.title,
    required this.message,
  });
}

class NearbyStopsViewModel extends GetxController {
  NearbyStopsViewModel({
    ShuttleRepository? shuttleRepository,
    PreferencesService? preferencesService,
  })  : _shuttleRepository = shuttleRepository ?? ShuttleRepository(),
        _preferencesService = preferencesService ?? PreferencesService();

  final ShuttleRepository _shuttleRepository;
  final PreferencesService _preferencesService;

  final RxList<ShuttleStation> stations = <ShuttleStation>[].obs;
  final RxList<ShuttleStation> sortedStations = <ShuttleStation>[].obs;
  final RxList<StationSchedule> stationSchedules = <StationSchedule>[].obs;
  final RxList<StationSchedule> filteredSchedules = <StationSchedule>[].obs;
  final RxList<ShuttleRoute> routes = <ShuttleRoute>[].obs;

  final RxBool isLoadingStations = false.obs;
  final RxBool isLoadingSchedules = false.obs;
  final RxBool isLoadingLocation = false.obs;
  final RxBool isLoadingRoutes = false.obs;
  final Rxn<NearbyStopsUiMessage> uiMessage = Rxn<NearbyStopsUiMessage>();

  final Rx<Position?> currentPosition = Rx<Position?>(null);
  final RxInt selectedStationId = (-1).obs;
  final RxString selectedScheduleType = 'Weekday'.obs;
  final RxString selectedDate = ''.obs;
  final RxString scheduleTypeName = ''.obs;

  // 운행 일자 타입 목록
  final List<String> scheduleTypes = ['Weekday', 'Saturday', 'Holiday'];

  // 운행 일자 타입 한글 매핑
  final Map<String, String> scheduleTypeNames = {
    'Weekday': '평일',
    'Saturday': '토요일',
    'Holiday': '일요일/공휴일'
  };

  void _emitUiMessage(
    String title,
    String message, {
    dynamic snackPosition,
    dynamic backgroundColor,
    dynamic colorText,
    Duration? duration,
  }) {
    uiMessage.value = null;
    uiMessage.value = NearbyStopsUiMessage(title: title, message: message);
  }

  void clearUiMessage() {
    uiMessage.value = null;
  }

  @override
  void onInit() {
    super.onInit();
    setDefaultDate();
    fetchStations();
    checkLocationPermission();
  }

  // 권한 확인 및 자동 요청
  Future<void> checkLocationPermission() async {
    try {
      // 위치 서비스가 활성화되어 있는지 확인
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _emitUiMessage(
          '위치 서비스 비활성화',
          '위치 서비스를 활성화해주세요',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.1),
          colorText: Colors.orange,
          duration: Duration(seconds: 3),
        );
        return;
      }

      // 위치 권한 상태 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // 권한이 거부된 경우
          _emitUiMessage(
            '권한 거부',
            '위치 권한이 거부되었습니다. 가까운 정류장 찾기 기능을 사용할 수 없습니다.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
            duration: Duration(seconds: 3),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // 권한이 영구적으로 거부된 경우
        _emitUiMessage(
          '권한 설정 필요',
          '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: Duration(seconds: 5),
        );
        return;
      }

      // 권한이 허용된 경우 위치 가져오기
      await getCurrentLocation();
    } catch (e) {
      print('위치 권한 확인 중 오류 발생: $e');
    }
  }

  // 모든 정류장 정보 조회
  Future<void> fetchStations() async {
    isLoadingStations.value = true;

    try {
      stations.value = await _shuttleRepository.fetchStations();

      // 위치 정보가 있다면 정류장을 거리순으로 정렬
      if (currentPosition.value != null) {
        sortStationsByDistance();
      }
    } catch (e) {
      print('정류장 목록을 불러오는데 실패했습니다: $e');
      _emitUiMessage(
        '오류',
        '정류장 정보를 불러오는데 실패했습니다',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
        duration: Duration(seconds: 3),
      );
    } finally {
      isLoadingStations.value = false;
    }
  }

  // 현재 위치 정보 조회
  Future<bool> getCurrentLocation() async {
    isLoadingLocation.value = true;
    bool success = false;

    try {
      // 위치 서비스 사용 가능 여부 확인
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _emitUiMessage(
          '위치 서비스 비활성화',
          '위치 서비스를 활성화해주세요',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.1),
          colorText: Colors.orange,
          duration: Duration(seconds: 3),
        );
        return false;
      }

      // Geolocator를 통해 직접 위치 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _emitUiMessage(
            '권한 거부',
            '위치 권한이 거부되었습니다',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
            duration: Duration(seconds: 3),
          );
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _emitUiMessage(
          '권한 설정 필요',
          '설정에서 위치 권한을 허용해주세요',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: Duration(seconds: 3),
        );
        return false;
      }

      // 위치 정보 가져오기
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );

      currentPosition.value = position;

      // 위치 정보 이용해 정류장 정렬
      sortStationsByDistance();
      success = true;

      // 디버깅용 - 위치 정보 확인
      print('현재 위치: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('위치 정보를 가져오는데 실패했습니다: $e');
      _emitUiMessage(
        '오류',
        '위치 정보를 가져오는데 실패했습니다',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
        duration: Duration(seconds: 3),
      );
    } finally {
      isLoadingLocation.value = false;
    }

    return success;
  }

  // 정류장을 현재 위치부터의 거리순으로 정렬
  void sortStationsByDistance() async {
    if (currentPosition.value == null || stations.isEmpty) return;

    final position = currentPosition.value!;

    sortedStations.value = List.from(stations);
    sortedStations.sort((a, b) {
      final distanceA = Geolocator.distanceBetween(
          position.latitude, position.longitude, a.latitude, a.longitude);

      final distanceB = Geolocator.distanceBetween(
          position.latitude, position.longitude, b.latitude, b.longitude);

      return distanceA.compareTo(distanceB);
    });

    // 캠퍼스 설정에 따라 주요 정류장(천안아산역, 롯데캐슬, 천안역) 순서 조정
    await _reorderMajorStations();

    // 도착 정류장이 출발 정류장보다 앞에 있는 경우 순서 조정
    _reorderDepartureArrivalStations();

    // 가장 가까운 정류장을 자동 선택
    if (sortedStations.isNotEmpty && selectedStationId.value == -1) {
      selectedStationId.value = sortedStations.first.id;
      fetchStationSchedules(sortedStations.first.id);
    }
  }

  // 캠퍼스 설정에 따라 주요 정류장(천안아산역, 롯데캐슬, 천안역) 순서 조정
  Future<void> _reorderMajorStations() async {
    try {
      final campusSetting =
          await _preferencesService.getStringOrDefault('campus', '아산');

      // 정류장별 이름 및 방향 키워드 정의
      final List<Map<String, dynamic>> stationConfigs = [
        {
          'keyword': '천안아산역',
          'asan': ['아캠방향', '아산방향'],
          'cheonan': ['천캠방향', '천안방향'],
        },
        {
          'keyword': '롯데캐슬',
          'asan': ['아캠방향', '아산방향'],
          'cheonan': ['천캠방향', '천안방향'],
        },
        {
          'keyword': '천안터미널',
          'asan': ['아캠방향', '아산방향'],
          'cheonan': ['천캠방향', '천안방향'],
        },
        {
          'keyword': '천안역',
          'asan': ['아캠방향', '아산방향'],
          'cheonan': ['천캠방향', '천안방향'],
        },
      ];

      for (final config in stationConfigs) {
        int asanDirectionIndex = -1;
        int cheonanDirectionIndex = -1;
        for (int i = 0; i < sortedStations.length; i++) {
          final stationName = sortedStations[i].name;
          if (stationName.contains(config['keyword'])) {
            if (config['asan'].any((k) => stationName.contains(k))) {
              asanDirectionIndex = i;
            } else if (config['cheonan'].any((k) => stationName.contains(k))) {
              cheonanDirectionIndex = i;
            }
          }
        }
        // 두 정류장이 모두 존재하는 경우 설정에 따라 순서 조정
        if (asanDirectionIndex != -1 && cheonanDirectionIndex != -1) {
          if (campusSetting == '천안') {
            // 천안 설정: 천안방향이 앞에 있어야 함
            if (asanDirectionIndex < cheonanDirectionIndex) {
              final cheonanStation =
                  sortedStations.removeAt(cheonanDirectionIndex);
              sortedStations.insert(asanDirectionIndex, cheonanStation);
            }
          } else {
            // 아산 설정: 아산방향이 앞에 있어야 함
            if (cheonanDirectionIndex < asanDirectionIndex) {
              final asanStation = sortedStations.removeAt(asanDirectionIndex);
              sortedStations.insert(cheonanDirectionIndex, asanStation);
            }
          }
        }
      }
    } catch (e) {
      print('주요 정류장 순서 조정 중 오류 발생: $e');
    }
  }

  // 도착 정류장이 출발 정류장보다 앞에 있는 경우 순서 조정
  void _reorderDepartureArrivalStations() {
    try {
      // 아산캠퍼스 출발/도착 정류장 찾기
      int asanDepartureIndex = -1;
      int asanArrivalIndex = -1;

      // 천안캠퍼스 출발/도착 정류장 찾기
      int cheonanDepartureIndex = -1;
      int cheonanArrivalIndex = -1;

      for (int i = 0; i < sortedStations.length; i++) {
        final stationName = sortedStations[i].name;

        // 아산캠퍼스 정류장 확인
        if (stationName.contains('아산캠퍼스')) {
          if (stationName.contains('출발')) {
            asanDepartureIndex = i;
          } else if (stationName.contains('도착')) {
            asanArrivalIndex = i;
          }
        }

        // 천안캠퍼스 정류장 확인
        if (stationName.contains('천안캠퍼스')) {
          if (stationName.contains('출발')) {
            cheonanDepartureIndex = i;
          } else if (stationName.contains('도착')) {
            cheonanArrivalIndex = i;
          }
        }
      }

      // 아산캠퍼스: 도착이 출발보다 앞에 있으면 순서 변경
      if (asanDepartureIndex != -1 &&
          asanArrivalIndex != -1 &&
          asanArrivalIndex < asanDepartureIndex) {
        final departureStation = sortedStations.removeAt(asanDepartureIndex);
        sortedStations.insert(asanArrivalIndex, departureStation);
      }

      // 천안캠퍼스: 도착이 출발보다 앞에 있으면 순서 변경
      if (cheonanDepartureIndex != -1 &&
          cheonanArrivalIndex != -1 &&
          cheonanArrivalIndex < cheonanDepartureIndex) {
        final departureStation = sortedStations.removeAt(cheonanDepartureIndex);
        sortedStations.insert(cheonanArrivalIndex, departureStation);
      }
    } catch (e) {
      print('출발/도착 정류장 순서 조정 중 오류 발생: $e');
    }
  }

  // 날짜 선택 메서드
  void selectDate(String date) {
    selectedDate.value = date;
    if (selectedStationId.value != -1) {
      fetchStationSchedulesByDate(selectedStationId.value, date);
    }
  }

  // 오늘 날짜로 초기화
  void setDefaultDate() {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    selectedDate.value = formattedDate;

    // 현재 요일에 맞는 스케줄 타입 설정
    final currentDay = now.weekday; // 1-월요일, 7-일요일

    if (currentDay == 6) {
      selectedScheduleType.value = 'Saturday';
    } else if (currentDay == 7) {
      selectedScheduleType.value = 'Holiday';
    } else {
      selectedScheduleType.value = 'Weekday';
    }
  }

  // 특정 정류장의 시간표 조회 (날짜로 조회)
  Future<void> fetchStationSchedulesByDate(int stationId, String date) async {
    selectedStationId.value = stationId;
    isLoadingSchedules.value = true;
    stationSchedules.clear();

    try {
      final data = await _shuttleRepository.fetchStationSchedulesByDate(
        stationId: stationId,
        date: date,
      );

      // 스케줄 타입과 타입명 가져오기
      selectedScheduleType.value = data['schedule_type'] ?? 'Weekday';
      scheduleTypeName.value = data['schedule_type_name'] ??
          scheduleTypeNames[selectedScheduleType.value] ??
          '알 수 없음';

      // 스케줄 목록 파싱
      if (data.containsKey('schedules') && data['schedules'] is List) {
        final List<dynamic> schedules = data['schedules'];
        stationSchedules.value =
            schedules.map((item) => StationSchedule.fromJson(item)).toList();
      }

      // 모든 노선 정보 가져오기 (필터링 위해)
      await fetchRoutes();

      // 기본 일정 유형으로 필터링
      filteredSchedules.value = List.from(stationSchedules);

      // 도착 시간 순으로 정렬
      filteredSchedules.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
    } catch (e) {
      print('정류장 시간표를 불러오는데 실패했습니다: $e');
    } finally {
      isLoadingSchedules.value = false;
    }
  }

  // 기존 시간표 조회 메서드 (하위 호환성 유지)
  Future<void> fetchStationSchedules(int stationId) async {
    if (selectedDate.value.isNotEmpty) {
      fetchStationSchedulesByDate(stationId, selectedDate.value);
    } else {
      // 날짜가 없는 경우, 기존 방식으로 조회 (레거시 지원)
      selectedStationId.value = stationId;
      isLoadingSchedules.value = true;
      stationSchedules.clear();

      try {
        stationSchedules.value =
            await _shuttleRepository.fetchStationSchedules(stationId);

        // 모든 노선 정보 가져오기 (필터링 위해)
        await fetchRoutes();

        // 기본 일정 유형으로 필터링
        filterSchedulesByType(selectedScheduleType.value);
      } catch (e) {
        print('정류장 시간표를 불러오는데 실패했습니다: $e');
      } finally {
        isLoadingSchedules.value = false;
      }
    }
  }

  // 운행 일자별 필터링
  void filterSchedulesByType(String scheduleType) {
    selectedScheduleType.value = scheduleType;

    if (scheduleType == 'All') {
      // 모든 일정 보기
      filteredSchedules.value = List.from(stationSchedules);
    } else {
      // 선택한 일정 유형만 필터링
      filteredSchedules.value = stationSchedules
          .where((schedule) => schedule.scheduleType == scheduleType)
          .toList();
    }

    // 도착 시간 순으로 정렬
    filteredSchedules.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
  }

  // 모든 노선 정보 조회
  Future<void> fetchRoutes() async {
    isLoadingRoutes.value = true;

    try {
      routes.value = await _shuttleRepository.fetchRoutes();
    } catch (e) {
      print('노선 목록을 불러오는데 실패했습니다: $e');
    } finally {
      isLoadingRoutes.value = false;
    }
  }

  // 노선 이름 가져오기
  String getRouteName(int routeId) {
    try {
      final route = routes.firstWhere((r) => r.id == routeId);
      return route.routeName;
    } catch (e) {
      return '알 수 없는 노선';
    }
  }

  // 정류장 이름 가져오기
  String getStationName(int stationId) {
    try {
      final station = stations.firstWhere((s) => s.id == stationId);
      return station.name;
    } catch (e) {
      return '알 수 없는 정류장';
    }
  }

  // 현재 위치부터 정류장까지의 거리 가져오기
  String getDistanceToStation(ShuttleStation station) {
    if (currentPosition.value == null) return '거리 측정 불가';

    final position = currentPosition.value!;
    final distance = Geolocator.distanceBetween(position.latitude,
        position.longitude, station.latitude, station.longitude);

    // 1km 이상이면 km 단위로 표시
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    } else {
      return '${distance.toInt()}m';
    }
  }
}
