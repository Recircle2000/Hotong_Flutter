// lib/viewmodel/settings_viewmodel.dart
import 'package:get/get.dart';
import '../services/preferences_service.dart';

class SettingsViewModel extends GetxController {
  SettingsViewModel({PreferencesService? preferencesService})
      : _preferencesService = preferencesService ?? PreferencesService();

  final PreferencesService _preferencesService;

  var selectedCampus = '아산'.obs;
  var selectedSubwayStation = '천안'.obs;
  var isLocationBasedDepartureWidgetEnabled = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    selectedCampus.value =
        await _preferencesService.getStringOrDefault('campus', '아산');
    selectedSubwayStation.value =
        await _preferencesService.getStringOrDefault('subwayStation', '천안');
    isLocationBasedDepartureWidgetEnabled.value =
        await _preferencesService.getBoolOrDefault(
            'isLocationBasedDepartureWidgetEnabled', false);
  }

  Future<void> setCampus(String campus) async {
    await _preferencesService.setString('campus', campus);
    selectedCampus.value = campus;
  }

  Future<void> setSubwayStation(String station) async {
    await _preferencesService.setString('subwayStation', station);
    selectedSubwayStation.value = station;
  }

  Future<void> setLocationBasedDepartureWidgetEnabled(bool enabled) async {
    await _preferencesService.setBool('isLocationBasedDepartureWidgetEnabled', enabled);
    isLocationBasedDepartureWidgetEnabled.value = enabled;
  }
}
