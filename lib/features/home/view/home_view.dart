import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hsro/core/services/preferences_service.dart';
import 'package:hsro/core/utils/platform_utils.dart';
import 'package:hsro/features/city_bus/view/grouped_bus_view.dart';
import 'package:hsro/features/home/mixins/home_startup_flow_mixin.dart';
import 'package:hsro/features/home/viewmodel/upcoming_departure_viewmodel.dart';
import 'package:hsro/features/home/viewmodel/upcoming_departures_arrival_viewmodel.dart';
import 'package:hsro/features/home/widgets/home_campus_toggle.dart';
import 'package:hsro/features/home/widgets/home_notice_section.dart';
import 'package:hsro/features/home/widgets/home_transport_menu_section.dart';
import 'package:hsro/features/home/widgets/upcoming_departures_arrival_widget.dart';
import 'package:hsro/features/home/widgets/upcoming_departures_widget.dart';
import 'package:hsro/features/notice/viewmodel/notice_viewmodel.dart';
import 'package:hsro/features/settings/view/settings_view.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:hsro/features/shuttle/view/shuttle_route_selection_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with HomeStartupFlowMixin<HomeView> {
  // 홈 화면에서 공통으로 사용하는 ViewModel/서비스
  final NoticeViewModel noticeViewModel = Get.put(NoticeViewModel());
  final SettingsViewModel _settingsViewModel = Get.find<SettingsViewModel>();
  final PreferencesService _preferencesService = PreferencesService();
  late final Worker _departureWidgetSettingWorker;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _guideKey = GlobalKey();
  final ScrollController _homeScrollController = ScrollController();
  final GlobalKey _upcomingWidgetKey = GlobalKey();
  final GlobalKey _transportMenuGroupKey = GlobalKey();

  bool _isHomeTourRunning = false;
  bool _runDeepExperienceFlow = false;
  DateTime? _lastBackPressedTime;

  @override
  PreferencesService get preferencesService => _preferencesService;

  @override
  GlobalKey<ScaffoldState> get scaffoldKey => _scaffoldKey;

  @override
  GlobalKey get guideKey => _guideKey;

  @override
  ScrollController get homeScrollController => _homeScrollController;

  @override
  GlobalKey get upcomingWidgetKey => _upcomingWidgetKey;

  @override
  GlobalKey get transportMenuGroupKey => _transportMenuGroupKey;

  @override
  bool get isHomeTourRunning => _isHomeTourRunning;

  @override
  set isHomeTourRunning(bool value) => _isHomeTourRunning = value;

  @override
  bool get runDeepExperienceFlow => _runDeepExperienceFlow;

  @override
  set runDeepExperienceFlow(bool value) => _runDeepExperienceFlow = value;

  @override
  void initState() {
    super.initState();
    // 설정값에 따라 곧 출발 위젯 표시 모드 동기화
    _departureWidgetSettingWorker = ever<bool>(
      _settingsViewModel.isLocationBasedDepartureWidgetEnabled,
      _applyDepartureWidgetMode,
    );

    // 첫 프레임 이후 시작 플로우 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handleStartupFlow();
    });

    _applyDepartureWidgetMode(
      _settingsViewModel.isLocationBasedDepartureWidgetEnabled.value,
    );
  }

  void _applyDepartureWidgetMode(bool isLocationBasedEnabled) {
    // 두 위젯이 동시에 동작하지 않도록 활성 상태 분리
    if (Get.isRegistered<UpcomingDepartureViewModel>()) {
      Get.find<UpcomingDepartureViewModel>()
          .setWidgetEnabled(!isLocationBasedEnabled);
    }
    if (Get.isRegistered<UpcomingDeparturesArrivalViewModel>()) {
      Get.find<UpcomingDeparturesArrivalViewModel>()
          .setWidgetEnabled(isLocationBasedEnabled);
    }
  }

  @override
  Future<void> startShuttleExperienceFlow() async {
    if (!mounted) return;
    // 셔틀 체험 종료 결과에 따라 시내버스 체험으로 연결
    final shouldContinue = await Get.to(
      () => const ShuttleRouteSelectionView(startExperienceTour: true),
    );
    if (shouldContinue == true) {
      await startCityBusExperienceFlow();
    }
  }

  @override
  Future<void> startCityBusExperienceFlow() async {
    if (!mounted) return;
    await Get.to(() => const CityBusGroupedView(startExperienceTour: true));
  }

  @override
  void dispose() {
    _departureWidgetSettingWorker.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return WillPopScope(
      onWillPop: () async {
        // Android 홈 화면에서만 두 번 뒤로가기 종료 처리
        if (!Platform.isAndroid) return true;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          return true;
        }

        final currentTime = DateTime.now();
        if (_lastBackPressedTime == null ||
            currentTime.difference(_lastBackPressedTime!) >
                const Duration(seconds: 2)) {
          _lastBackPressedTime = currentTime;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('한 번 더 누르면 종료됩니다'),
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        }

        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: SettingsView(
          guideKey: _guideKey,
          onRequestHomeExperienceTour: startHomeExperienceTourFromGuide,
        ),
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            '호통',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.menu_outlined, size: 24),
            onPressed: () {
              HapticFeedback.lightImpact();
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          actions: [
            HomeCampusToggle(settingsViewModel: _settingsViewModel),
          ],
        ),
        body: SingleChildScrollView(
          controller: _homeScrollController,
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // 최신 공지 영역
              HomeNoticeSection(noticeViewModel: noticeViewModel),
              const SizedBox(height: 12),
              Container(
                key: _upcomingWidgetKey,
                child: Obx(
                  // 설정에 따라 기본 출발 위젯과 위치 기반 도착 위젯 전환
                  () => _settingsViewModel
                          .isLocationBasedDepartureWidgetEnabled.value
                      ? const UpcomingDeparturesArrivalWidget()
                      : UpcomingDeparturesWidget(),
                ),
              ),
              const SizedBox(height: 12),
              // 교통 메뉴 바로가기 영역
              HomeTransportMenuSection(
                sectionKey: _transportMenuGroupKey,
                settingsViewModel: _settingsViewModel,
              ),
              const SizedBox(height: 12),
              // 플랫폼별 안내 문구와 상세 보기 버튼
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 20,
                  left: 20,
                  right: 20,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        PlatformUtils.shortDisclaimer,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        PlatformUtils.showPlatformDisclaimerDialog(context);
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '자세히 보기',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
