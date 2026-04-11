import 'package:get/get.dart';
import 'package:hsro/core/services/preferences_service.dart';

class SettingsViewModel extends GetxController {
  SettingsViewModel({PreferencesService? preferencesService})
      : _preferencesService = preferencesService ?? PreferencesService();

  final PreferencesService _preferencesService;

  // 사용자 설정 상태
  var selectedCampus = '아산'.obs;
  var selectedSubwayStation = '천안'.obs;
  var isLocationBasedDepartureWidgetEnabled = false.obs;

  @override
  void onInit() {
    super.onInit();
    // 저장된 사용자 설정 불러오기
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // SharedPreferences에 저장된 설정값 복원
    selectedCampus.value =
        await _preferencesService.getStringOrDefault('campus', '아산');
    selectedSubwayStation.value =
        await _preferencesService.getStringOrDefault('subwayStation', '천안');
    isLocationBasedDepartureWidgetEnabled.value = await _preferencesService
        .getBoolOrDefault('isLocationBasedDepartureWidgetEnabled', false);
  }

  Future<void> setCampus(String campus) async {
    // 캠퍼스 설정 저장 후 반영
    await _preferencesService.setString('campus', campus);
    selectedCampus.value = campus;
  }

  Future<void> setSubwayStation(String station) async {
    // 기본 지하철역 설정 저장 후 반영
    await _preferencesService.setString('subwayStation', station);
    selectedSubwayStation.value = station;
  }

  Future<void> setLocationBasedDepartureWidgetEnabled(bool enabled) async {
    // 위치 기반 위젯 사용 여부 저장 후 반영
    await _preferencesService.setBool(
        'isLocationBasedDepartureWidgetEnabled', enabled);
    isLocationBasedDepartureWidgetEnabled.value = enabled;
  }
}
