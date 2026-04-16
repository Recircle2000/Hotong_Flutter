import 'package:get/get.dart';
import 'package:hsro/features/subway/models/subway_schedule_model.dart';
import 'package:hsro/features/subway/repository/subway_repository.dart';

class SubwayScheduleViewModel extends GetxController {
  final SubwayRepository _repository = SubwayRepository();

  SubwayScheduleViewModel({String? initialStation}) {
    if (initialStation != null) {
      selectedStation.value = initialStation;
    }
  }

  // 시간표 화면 상태
  final RxString selectedStation = '천안'.obs;
  final RxString selectedDayType = '평일'.obs;
  final Rx<SubwaySchedule?> scheduleData = Rx<SubwaySchedule?>(null);
  final RxBool isLoading = true.obs;
  final RxString error = ''.obs;

  final RxBool isUpExpanded = true.obs;
  final RxBool isDownExpanded = false.obs;

  @override
  void onInit() {
    super.onInit();
    // 현재 요일에 맞춰 평일/주말 기본값 설정
    final now = DateTime.now();
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      selectedDayType.value = '주말';
    } else {
      selectedDayType.value = '평일';
    }
    fetchSchedule();
  }

  void changeStation(String station) {
    // 역이 바뀌면 시간표 다시 조회
    if (selectedStation.value != station) {
      selectedStation.value = station;
      fetchSchedule();
    }
  }

  void changeDayType(String dayType) {
    // 평일/주말 유형이 바뀌면 시간표 다시 조회
    if (selectedDayType.value != dayType) {
      selectedDayType.value = dayType;
      fetchSchedule();
    }
  }

  Future<void> fetchSchedule() async {
    final targetStation = selectedStation.value;
    final targetDayType = selectedDayType.value;

    // 현재 선택 기준으로 시간표 조회 시작
    isLoading.value = true;
    error.value = '';

    try {
      final schedule = await _repository.fetchSchedule(
        targetStation,
        targetDayType,
      );

      // 요청 도중 선택값이 바뀌면 이전 결과는 무시
      if (selectedStation.value == targetStation &&
          selectedDayType.value == targetDayType) {
        scheduleData.value = schedule;
      }
    } catch (e) {
      print('Error fetching schedule: $e');
      if (selectedStation.value == targetStation &&
          selectedDayType.value == targetDayType) {
        // 현재 선택과 일치하는 경우에만 오류 표시
        error.value = '시간표를 불러오는데 실패했습니다.';
      }
    } finally {
      if (selectedStation.value == targetStation &&
          selectedDayType.value == targetDayType) {
        isLoading.value = false;
      }
    }
  }
}
