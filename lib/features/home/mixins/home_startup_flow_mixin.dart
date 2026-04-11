import 'package:app_version_update/app_version_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:hsro/core/services/preferences_service.dart';
import 'package:hsro/core/utils/platform_utils.dart';

mixin HomeStartupFlowMixin<T extends StatefulWidget> on State<T> {
  // 구현하는 화면에서 주입받아 사용할 의존성/상태
  PreferencesService get preferencesService;
  GlobalKey<ScaffoldState> get scaffoldKey;
  GlobalKey get guideKey;
  ScrollController get homeScrollController;
  GlobalKey get upcomingWidgetKey;
  GlobalKey get transportMenuGroupKey;
  bool get isHomeTourRunning;
  set isHomeTourRunning(bool value);
  bool get runDeepExperienceFlow;
  set runDeepExperienceFlow(bool value);

  Future<void> startShuttleExperienceFlow();
  Future<void> startCityBusExperienceFlow();

  Future<void> handleStartupFlow() async {
    // 첫 실행 여부 확인
    final isFirstRun =
        await preferencesService.getBoolOrDefault('first_run', true);
    if (!mounted) return;

    if (isFirstRun) {
      // 최초 실행 시 플랫폼 안내 다이얼로그 먼저 표시
      await PlatformUtils.showPlatformDisclaimerDialog(context);
      await preferencesService.setBool('first_run', false);
      if (!mounted) return;
    }

    // 가이드 튜토리얼 노출 여부 확인
    final hasSeenGuide =
        await preferencesService.getBoolOrDefault('has_seen_guide', false);
    if (!mounted) return;

    if (!hasSeenGuide) {
      // 가이드 메뉴를 강조하기 위해 드로어를 먼저 연 뒤 튜토리얼 시작
      scaffoldKey.currentState?.openDrawer();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      showGuideTutorial();
      return;
    }

    await checkAppVersionUpdate();
  }

  void showGuideTutorial() {
    // 드로어 안 가이드 메뉴 위치 강조 튜토리얼
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'guide_key',
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
                      '호통 이용 가이드',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        '이곳에서 앱 사용 방법과 버스 이용 가이드를 확인해보세요!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: controller.next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text('확인'),
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
      onFinish: completeGuideTutorial,
      onClickTarget: (_) => completeGuideTutorial(),
      onClickOverlay: (_) => completeGuideTutorial(),
    ).show(context: context);
  }

  Future<void> completeGuideTutorial() async {
    // 한 번 본 가이드는 다시 자동 노출하지 않도록 저장
    await preferencesService.setBool('has_seen_guide', true);

    if (scaffoldKey.currentState?.isDrawerOpen ?? false) {
      // 튜토리얼 종료 후 열려 있는 드로어 닫기
      Navigator.of(context).pop();
    }

    await checkAppVersionUpdate();
  }

  Future<void> checkAppVersionUpdate() async {
    // 앱스토어/플레이스토어 최신 버전 확인
    final result = await AppVersionUpdate.checkForUpdates(
      appleId: dotenv.env['APPLE_APP_ID'] ?? '',
      playStoreId: dotenv.env['PLAY_STORE_ID'] ?? '',
      country: 'kr',
    );

    if (!mounted || result.canUpdate != true) {
      return;
    }

    // 업데이트 가능 시 권장 업데이트 다이얼로그 표시
    await AppVersionUpdate.showAlertUpdate(
      appVersionResult: result,
      context: context,
      backgroundColor: Colors.white,
      title: '새로운 버전이 있습니다',
      titleTextStyle: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      content: '최신 버전으로 업데이트를 권장합니다.',
      contentTextStyle: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.normal,
        fontSize: 16,
      ),
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

  Future<void> startHomeExperienceTourFromGuide() async {
    // 홈 튜토리얼 이후 셔틀/시내버스 체험 흐름까지 이어지도록 표시
    runDeepExperienceFlow = true;

    if (scaffoldKey.currentState?.isDrawerOpen ?? false) {
      // 홈 화면 튜토리얼 시작 전 드로어 닫기
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (homeScrollController.hasClients) {
      // 홈 상단 요소를 바로 보이게 스크롤 위치 초기화
      await homeScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    showHomeExperienceTutorial();
  }

  void showHomeExperienceTutorial() {
    // 중복 실행 방지
    if (isHomeTourRunning) return;
    isHomeTourRunning = true;

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'upcoming_widget',
          keyTarget: upcomingWidgetKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => buildTourContent(
                controller: controller,
                title: '곧 출발',
                description: '셔틀/시내버스 임박 운행 정보를 빠르게 확인할 수 있습니다.',
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'transport_menu_group',
          keyTarget: transportMenuGroupKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) => buildTourContent(
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
        isHomeTourRunning = false;
        if (runDeepExperienceFlow) {
          // 홈 튜토리얼 종료 후 셔틀 체험으로 이어짐
          runDeepExperienceFlow = false;
          startShuttleExperienceFlow();
        }
      },
      onSkip: () {
        // 건너뛰면 연속 체험 흐름도 함께 종료
        isHomeTourRunning = false;
        runDeepExperienceFlow = false;
        return true;
      },
      onClickOverlay: (_) {},
    ).show(context: context);
  }

  Widget buildTourContent({
    required dynamic controller,
    required String title,
    required String description,
    bool isLast = false,
  }) {
    // 공통 튜토리얼 말풍선 UI
    return ConstrainedBox(
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
                onPressed: controller.skip,
                child: const Text(
                  '건너뛰기',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: controller.next,
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
}
