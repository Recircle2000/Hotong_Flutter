import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import '../viewmodel/notice_viewmodel.dart';
import '../viewmodel/settings_viewmodel.dart';
import 'notice_detail_view.dart';
import 'notice_list_view.dart';
import 'shuttle_bus/shuttle_route_selection_view.dart';
import 'settings_view.dart';
import 'components/upcoming_departures_widget.dart';
import 'components/auto_scroll_text.dart';
import '../utils/platform_utils.dart';
import 'city_bus/grouped_bus_view.dart';
import 'subway/subway_view.dart';
import 'package:hsro/view/components/scale_button.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:app_version_update/app_version_update.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/preferences_service.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final noticeViewModel = Get.put(NoticeViewModel());
  final PreferencesService _preferencesService = PreferencesService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey guideKey = GlobalKey();
  final ScrollController _homeScrollController = ScrollController();

  // 체험형 홈 투어 타깃
  final GlobalKey _upcomingWidgetKey = GlobalKey();
  final GlobalKey _transportMenuGroupKey = GlobalKey();

  bool _isHomeTourRunning = false;
  bool _runDeepExperienceFlow = false;

  // 뒤로가기 시간 저장
  DateTime? _lastBackPressedTime;

  @override
  void initState() {
    super.initState();
    // 화면이 그려진 후 초기화 로직 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleStartupFlow();
    });
  }

  Future<void> _handleStartupFlow() async {
    // 1. 면책 문구 확인 (최초 실행 시)
    final bool isFirstRun =
        await _preferencesService.getBoolOrDefault('first_run', true);
    if (isFirstRun) {
      await PlatformUtils.showPlatformDisclaimerDialog(context);
      await _preferencesService.setBool('first_run', false);
    }

    // 2. 가이드 확인
    final hasSeenGuide =
        await _preferencesService.getBoolOrDefault('has_seen_guide', false);
    if (!hasSeenGuide) {
      // 드로어 열기
      _scaffoldKey.currentState?.openDrawer();

      // 드로어 애니메이션 대기
      await Future.delayed(const Duration(milliseconds: 500));

      // 튜토리얼 표시
      _showTutorial();
    } else {
      // 가이드를 이미 본 경우 바로 버전 확인
      _checkAppVersionUpdate();
    }
  }

  void _showTutorial() {
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: "guide_key",
          keyTarget: guideKey,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "호통 이용 가이드",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 10.0),
                      child: Text(
                        "이곳에서 앱 사용 방법과 버스 이용 가이드를 확인해보세요!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          controller.next();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text("확인"),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          shape: ShapeLightFocus.RRect,
          radius: 15,
        ),
      ],
      colorShadow: Colors.black,
      hideSkip: true,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () => _completeTutorial(),
      onClickTarget: (target) => _completeTutorial(),
      onClickOverlay: (target) => _completeTutorial(),
    ).show(context: context);
  }

  Future<void> _completeTutorial() async {
    await _preferencesService.setBool('has_seen_guide', true);

    // 튜토리얼 종료 시 드로어 닫기
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    // 3. 가이드 종료 후 버전 확인
    _checkAppVersionUpdate();
  }

  Future<void> _checkAppVersionUpdate() async {
    final result = await AppVersionUpdate.checkForUpdates(
      appleId: dotenv.env['APPLE_APP_ID'] ?? '',
      playStoreId: dotenv.env['PLAY_STORE_ID'] ?? '',
      country: 'kr',
    );
    if (result.canUpdate == true) {
      await AppVersionUpdate.showAlertUpdate(
        appVersionResult: result,
        context: context,
        backgroundColor: Colors.white,
        title: '새로운 버전이 있습니다',
        titleTextStyle: const TextStyle(
            color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        content: '최신 버전으로 업데이트를 권장합니다.',
        contentTextStyle: const TextStyle(
            color: Colors.black, fontWeight: FontWeight.normal, fontSize: 16),
        updateButtonText: '업데이트',
        updateButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.lightBlueAccent),
        ),
        updateTextStyle: const TextStyle(color: Colors.black),
        cancelButtonText: '나중에',
        cancelTextStyle: const TextStyle(color: Colors.white),
        cancelButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.black54),
        ),
      );
    }
  }

  Future<void> _startHomeExperienceTourFromGuide() async {
    _runDeepExperienceFlow = true;

    // Drawer가 열려 있으면 먼저 닫고 투어 시작
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 250));
    }

    // 타깃들이 안정적으로 그려진 뒤 시작
    if (_homeScrollController.hasClients) {
      await _homeScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _showHomeExperienceTutorial();
  }

  Future<void> _startShuttleExperienceFlow() async {
    if (!mounted) return;
    final shouldContinue = await Get.to(
      () => const ShuttleRouteSelectionView(startExperienceTour: true),
    );
    if (shouldContinue == true) {
      await _startCityBusExperienceFlow();
    }
  }

  Future<void> _startCityBusExperienceFlow() async {
    if (!mounted) return;
    await Get.to(
      () => const CityBusGroupedView(startExperienceTour: true),
    );
  }

  void _showHomeExperienceTutorial() {
    if (_isHomeTourRunning) return;
    _isHomeTourRunning = true;

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: "upcoming_widget",
          keyTarget: _upcomingWidgetKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildTourContent(
                controller: controller,
                title: '곧 출발',
                description: '셔틀/시내버스 임박 운행 정보를 빠르게 확인할 수 있습니다.',
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: "transport_menu_group",
          keyTarget: _transportMenuGroupKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) => _buildTourContent(
                controller: controller,
                title: '교통 메뉴 바로가기',
                description: '셔틀버스, 시내버스, 지하철 중 원하는 메뉴로 바로 이동할 수 있습니다.',
                isLast: true,
              ),
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      hideSkip: true,
      paddingFocus: 8,
      opacityShadow: 0.8,
      onFinish: () {
        _isHomeTourRunning = false;
        if (_runDeepExperienceFlow) {
          _runDeepExperienceFlow = false;
          _startShuttleExperienceFlow();
        }
      },
      onSkip: () {
        _isHomeTourRunning = false;
        _runDeepExperienceFlow = false;
        return true;
      },
      onClickOverlay: (target) {},
    ).show(context: context);
  }

  Widget _buildTourContent({
    required dynamic controller,
    required String title,
    required String description,
    bool isLast = false,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: () => controller.skip(),
                child: const Text(
                  '건너뛰기',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (isLast) {
                    controller.next();
                    return;
                  }
                  controller.next();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(isLast ? '셔틀버스 이동' : '다음'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 다크모드 감지
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return WillPopScope(
      // 뒤로가기 처리
      onWillPop: () async {
        // Android에서만 동작
        if (!Platform.isAndroid) return true;

        // Drawer가 열려있으면 뒤로가기 시 Drawer 닫기 (기본 동작 허용)
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          return true;
        }

        // 현재 시간
        final currentTime = DateTime.now();

        // 처음 뒤로가기를 누른 경우 또는 마지막으로 누른 지 3초가 지난 경우
        if (_lastBackPressedTime == null ||
            currentTime.difference(_lastBackPressedTime!) >
                const Duration(seconds: 2)) {
          // 현재 시간 저장
          _lastBackPressedTime = currentTime;

          // 뒤로가기 안내 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('한 번 더 누르면 종료됩니다'),
              duration: Duration(seconds: 2),
            ),
          );

          return false; // 앱 종료 방지
        }

        return true; // 두 번째 누른 경우 앱 종료
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: SettingsView(
          guideKey: guideKey,
          onRequestHomeExperienceTour: _startHomeExperienceTourFromGuide,
        ),
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor, // 앱바도 배경과 같은 색상
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
            Obx(() {
              final controller = Get.find<SettingsViewModel>();
              final isAsan = controller.selectedCampus.value == '아산';
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToggleButton(context, '아캠', isAsan, () {
                          HapticFeedback.lightImpact();
                          controller.setCampus('아산');
                        }),
                        // const SizedBox(width: 2), // 공간 없이 붙여서 자연스럽게
                        _buildToggleButton(context, '천캠', !isAsan, () {
                          HapticFeedback.lightImpact();
                          controller.setCampus('천안');
                        }),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        body: SingleChildScrollView(
          controller: _homeScrollController,
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // 공지사항
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '공지사항',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        noticeViewModel.fetchAllNotices();
                        Get.to(() => const NoticeListView());
                      },
                      child: Text(
                        '전체보기',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  child: ScaleButton(
                    onTap: () {
                      //HapticFeedback.lightImpact();
                      final notice = noticeViewModel.notice.value;
                      if (notice != null) {
                        Get.to(() => NoticeDetailView(notice: notice));
                      } else {
                        noticeViewModel.fetchLatestNotice();
                        Get.to(
                            () => const NoticeListView()); // 데이터 없을 땐 리스트로 이동
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.campaign,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Obx(() {
                              if (noticeViewModel.isLoading.value) {
                                return const Text(
                                  '서버에 연결 중...',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                );
                              }

                              final notice = noticeViewModel.notice.value;
                              return AutoScrollText(
                                text: notice?.title ?? '새로운 공지사항이 없습니다',
                                style: const TextStyle(
                                  fontSize: 14,
                                  //fontWeight: FontWeight.w600,
                                ),
                                scrollDuration: const Duration(seconds: 5),
                              );
                            }),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey,
                          ),
                          //const SizedBox(width: 15),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 곧 출발 섹션
              Container(
                key: _upcomingWidgetKey,
                child: UpcomingDeparturesWidget(),
              ),

              // const SizedBox(height: 16),
              // 메뉴
              Container(
                key: _transportMenuGroupKey,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  child: _buildMenuCard(
                                    context,
                                    title: '셔틀버스',
                                    icon: Icons.airport_shuttle,
                                    color: Color(0xFFB83227),
                                    onTap: () {
                                      //HapticFeedback.mediumImpact(); // 햅틱 피드백
                                      Get.to(() => ShuttleRouteSelectionView());
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  child: _buildMenuCard(
                                    context,
                                    title: '시내버스',
                                    icon: Icons.directions_bus,
                                    color: Colors.blue,
                                    onTap: () {
                                      //HapticFeedback.mediumImpact(); // 햅틱 피드백
                                      Get.to(() => CityBusGroupedView());
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 지하철 메뉴
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        child: _buildMenuCard(
                          context,
                          title: '지하철',
                          icon: Icons.subway_outlined,
                          color: const Color(0xFF0052A4), // 1호선 색상
                          onTap: () {
                            //HapticFeedback.mediumImpact();
                            final settingsViewModel =
                                Get.find<SettingsViewModel>();
                            Get.to(() => SubwayView(
                                stationName: settingsViewModel
                                    .selectedSubwayStation.value));
                          },
                          height: 80, // 높이를 줄여서 표시
                          isHorizontal: true, // 가로 배치 모드
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 면책 문구
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double? height,
    bool isHorizontal = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return ScaleButton(
      onTap: onTap,
      child: Container(
        height: height ?? 180,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: isHorizontal
              ? Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isHorizontal ? 8 : 16),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 32,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '실시간 도착 정보 / 시간표',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 48,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildNoticeBadge(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    // 24시간 이내인 경우에만 NEW 배지 표시
    if (difference.inHours < 24) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 4,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: const Text(
          'NEW',
          style: TextStyle(
            fontSize: 8,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    // 24시간 이상인 경우 빈 위젯 반환
    return const SizedBox();
  }

  String _getTimeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays < 1) {
      return '오늘';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}주 전';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}개월 전';
    } else {
      return '${(difference.inDays / 365).floor()}년 전';
    }
  }

  Widget _buildToggleButton(
    BuildContext context,
    String text,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? colorScheme.onPrimary
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}
