import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:hsro/core/utils/bus_times_loader.dart';
import 'package:hsro/features/city_bus/view/bus_map_view.dart';
import 'package:hsro/features/city_bus/viewmodel/busmap_viewmodel.dart';
import 'package:hsro/features/notice/models/emergency_notice_model.dart';
import 'package:hsro/features/notice/widgets/emergency_notice_banner.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:hsro/shared/widgets/auto_scroll_text.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

class CityBusGroupedView extends StatefulWidget {
  final String? forcedCampus;
  final bool startExperienceTour;

  const CityBusGroupedView({
    Key? key,
    this.forcedCampus,
    this.startExperienceTour = false,
  }) : super(key: key);

  @override
  State<CityBusGroupedView> createState() => _CityBusGroupedViewState();
}

class _CityBusGroupedViewState extends State<CityBusGroupedView> {
  final settingsViewModel = Get.find<SettingsViewModel>();
  late final BusMapViewModel busMapViewModel;
  // 체험하기 튜토리얼 첫 번째 포커스 대상
  final GlobalKey _firstRouteKey = GlobalKey();
  bool _isExperienceTourRunning = false;

  // 아산캠퍼스 노선 그룹핑 정보
  final List<Map<String, dynamic>> groupedRoutesAsan = [
    {
      'title': '천안아산역 · 지중해마을 방면',
      'subtitle': '아산캠퍼스 ↔ 천안아산역',
      'subGroups': [
        {
          'title': '아캠 출발',
          'icon': Icons.logout,
          'routes': [
            {
              'routeKey': '순환5_DOWN',
              'label': '순환5 (천안아산역 방면)',
            },
            {
              'routeKey': '1000_DOWN',
              'label': '1000 (지중해마을 방면)',
            },
          ],
        },
        {
          'title': '아캠 도착',
          'icon': Icons.login,
          'routes': [
            {
              'routeKey': '순환5_UP',
              'label': '순환5 (아산캠퍼스 방면)',
            },
            {
              'routeKey': '1000_UP',
              'label': '1000 (아산캠퍼스 방면)',
            },
          ],
        },
      ],
    },
    {
      'title': '아산터미널 방면',
      'subtitle': '아산캠퍼스 ↔ 아산터미널',
      'subGroups': [
        {
          'title': '아캠 출발',
          'icon': Icons.logout,
          'routes': [
            {
              'routeKey': '810_DOWN',
              'label': '810 (아산터미널 방면)',
            },
            {
              'routeKey': '820_DOWN',
              'label': '820 (아산터미널 방면)',
            },
            {
              'routeKey': '821_DOWN',
              'label': '821 (아산터미널 방면)',
            },
            {
              'routeKey': '822_DOWN',
              'label': '822 (아산터미널 방면)',
            },
          ],
        },
        {
          'title': '아캠 도착',
          'icon': Icons.login,
          'routes': [
            {
              'routeKey': '810_UP',
              'label': '810 (아산캠퍼스 방면)',
            },
            {
              'routeKey': '820_UP',
              'label': '820 (아산캠퍼스 방면)',
            },
            {
              'routeKey': '821_UP',
              'label': '821 (아산캠퍼스 방면)',
            },
            {
              'routeKey': '822_UP',
              'label': '822 (아산캠퍼스 방면)',
            },
          ],
        },
      ],
    },
  ];

  // 천안캠퍼스 노선 그룹핑 정보
  final List<Map<String, dynamic>> groupedRoutesCheonan = [
    {
      'title': '동우아파트 방면',
      'subtitle': '천안캠퍼스 ↔ 동우아파트',
      'subGroups': [
        {
          'title': '천캠 출발',
          'icon': Icons.logout,
          'routes': [
            {
              'routeKey': '24_DOWN',
              'label': '24 (동우아파트 방면)',
            },
          ],
        },
        {
          'title': '천캠 도착',
          'icon': Icons.login,
          'routes': [
            {
              'routeKey': '24_UP',
              'label': '24 (천안캠퍼스 방면)',
            },
          ],
        },
      ],
    },
    {
      'title': '차암2통 방면',
      'subtitle': '천안캠퍼스 ↔ 차암2통',
      'subGroups': [
        {
          'title': '천캠 출발',
          'icon': Icons.logout,
          'routes': [
            {
              'routeKey': '81_DOWN',
              'label': '81 (차암2통 방면)',
            },
          ],
        },
        {
          'title': '천캠 도착',
          'icon': Icons.login,
          'routes': [
            {
              'routeKey': '81_UP',
              'label': '81 (천안캠퍼스 방면)',
            },
          ],
        },
      ],
    },
  ];

  // 모든 노선의 다음 출발시간을 한 번에 관리
  final RxMap<String, String> allNextDepartureTimes = <String, String>{}.obs;
  bool _busTimesLoaded = false;

  Future<void> _loadAllNextDepartureTimes() async {
    // 시간표는 한 번만 로드해서 전체 노선 출발 정보 캐싱
    if (_busTimesLoaded) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final busTimes = await BusTimesLoader.loadBusTimes();
    // 그룹에 정의된 모든 노선의 다음 출발 시각 계산
    for (final group in [...groupedRoutesAsan, ...groupedRoutesCheonan]) {
      for (final subGroup in group['subGroups']) {
        for (final route in subGroup['routes']) {
          final routeKey = route['routeKey'];
          final timetable = busTimes[routeKey]?['시간표'] as List<dynamic>?;
          if (timetable == null || timetable.isEmpty) {
            allNextDepartureTimes[routeKey] = '시간표 없음';
            continue;
          }
          final times = timetable.map((t) {
            final parts = t.split(':');
            return DateTime(today.year, today.month, today.day,
                int.parse(parts[0]), int.parse(parts[1]));
          }).toList();
          final next = times.firstWhereOrNull((t) => t.isAfter(now));
          if (next != null) {
            allNextDepartureTimes[routeKey] =
                '출발: ${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
          } else {
            allNextDepartureTimes[routeKey] = '운행 종료';
          }
        }
      }
    }
    _busTimesLoaded = true;
  }

  @override
  void initState() {
    super.initState();
    // 상세 화면과 공유할 BusMapViewModel 등록
    busMapViewModel = Get.put(BusMapViewModel());
    _loadAllNextDepartureTimes();
    if (widget.startExperienceTour) {
      // 첫 프레임 이후 튜토리얼 시작
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startExperienceTour();
      });
    }
  }

  @override
  void dispose() {
    Get.delete<BusMapViewModel>();
    super.dispose();
  }

  Future<void> _startExperienceTour() async {
    if (!mounted || _isExperienceTourRunning) return;
    _isExperienceTourRunning = true;
    // 첫 아이템이 화면에 그려질 시간 확보
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'citybus_route_item',
          keyTarget: _firstRouteKey,
          shape: ShapeLightFocus.RRect,
          radius: 14,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildExperienceContent(
                controller: controller,
                title: '노선 선택',
                description: '노선을 누르면 실시간 버스 위치를 볼 수 있어요',
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
      onFinish: () => _completeExperienceTour(completed: true),
      onSkip: () {
        _completeExperienceTour(completed: false);
        return true;
      },
      onClickOverlay: (target) {},
    ).show(context: context);
  }

  void _completeExperienceTour({required bool completed}) {
    _isExperienceTourRunning = false;
    // 체험하기 진입 화면에서 왔다면 결과 전달 후 닫기
    if (widget.startExperienceTour && mounted) {
      Get.back(result: completed);
    }
  }

  Widget _buildExperienceContent({
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
              fontWeight: FontWeight.w600,
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
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => controller.skip(),
                child: const Text(
                  '종료',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                  controller.next();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(isLast ? '완료' : '다음'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 특정 노선의 현재 버스 위치 정보를 가져오는 함수
  String _getBusLocationStatus(String routeKey) {
    // ViewModel에 수집된 해당 노선 실시간 데이터 확인
    if (busMapViewModel.allRoutesBusData.containsKey(routeKey)) {
      final buses = busMapViewModel.allRoutesBusData[routeKey]!;

      if (buses.isNotEmpty) {
        if (buses.length == 1) {
          return buses.first.stationName;
        } else {
          return '${buses.first.stationName} 외 ${buses.length - 1}대';
        }
      }
    }

    return '현재 운행 없음';
  }

  /// 특정 노선의 다음 출발시간 정보를 가져오는 함수
  String _getNextDepartureTime(String routeKey) {
    // 미리 계산한 다음 출발 시각 사용
    return allNextDepartureTimes[routeKey] ?? '불러오는 중';
  }

  EmergencyNoticeCategory _getCityBusNoticeCategory(String campus) {
    return campus == '천안'
        ? EmergencyNoticeCategory.cheonanCitybus
        : EmergencyNoticeCategory.asanCitybus;
  }

  Widget _buildBodyWithEmergencyNotice(String campus) {
    return Column(
      children: [
        // 캠퍼스별 긴급 공지 배너 우선 노출
        EmergencyNoticeBanner(
          category: _getCityBusNoticeCategory(campus),
        ),
        Expanded(
          child: _buildRouteList(campus),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          '시내버스 노선 정보',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: widget.forcedCampus != null
          ? _buildBodyWithEmergencyNotice(widget.forcedCampus!)
          : Obx(
              () => _buildBodyWithEmergencyNotice(
                settingsViewModel.selectedCampus.value,
              ),
            ),
    );
  }

  // 시내버스 파랑: 라이트는 흰 배경 대비를 맞춘 진한 톤, 다크는 밝은 톤
  Color _cityBusColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF6EA8FF)
          : const Color(0xFF1F5FD1);

  Widget _buildRouteList(String campus) {
    // 캠퍼스에 맞는 노선 그룹 선택
    final groupedRoutes =
        campus == '천안' ? groupedRoutesCheonan : groupedRoutesAsan;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: groupedRoutes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (context, groupIdx) {
        final group = groupedRoutes[groupIdx];
        final subGroups = group['subGroups'] as List;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 메인 그룹 타이틀 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                group['title'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // 출발/도착은 카드를 나누고 방향 제목을 위에 둔다
            for (var subGroupIdx = 0;
                subGroupIdx < subGroups.length;
                subGroupIdx++) ...[
              if (subGroupIdx > 0) const SizedBox(height: 16),
              _buildSubGroupHeader(
                context,
                subGroups[subGroupIdx],
                route: _directionLabel(
                  group['subtitle'] as String,
                  reversed: subGroupIdx > 0,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: _buildRouteRows(
                    context,
                    subGroups[subGroupIdx]['routes'] as List,
                    isFirstBlock: groupIdx == 0 && subGroupIdx == 0,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // "아산캠퍼스 ↔ 천안아산역"을 진행 방향 화살표로 바꾼다
  String _directionLabel(String subtitle, {required bool reversed}) {
    final parts = subtitle.split(' ↔ ');
    if (parts.length != 2) return subtitle;
    return reversed ? '${parts[1]} → ${parts[0]}' : '${parts[0]} → ${parts[1]}';
  }

  // 서브 그룹 헤더 (아캠 출발 / 도착)
  Widget _buildSubGroupHeader(
    BuildContext context,
    Map subGroup, {
    required String route,
  }) {
    final hintColor = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(subGroup['icon'], size: 18, color: hintColor),
          const SizedBox(width: 8),
          Text(
            subGroup['title'],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              route,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: hintColor),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRouteRows(
    BuildContext context,
    List routes, {
    required bool isFirstBlock,
  }) {
    final hairline =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    return [
      for (var routeIdx = 0; routeIdx < routes.length; routeIdx++) ...[
        if (routeIdx > 0)
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: hairline,
          ),
        _buildRouteRow(
          context,
          routes[routeIdx],
          isFirstExperienceRoute: isFirstBlock && routeIdx == 0,
        ),
      ],
    ];
  }

  Widget _buildRouteRow(
    BuildContext context,
    Map route, {
    required bool isFirstExperienceRoute,
  }) {
    final routeKey = route['routeKey'] as String;
    // label에서 번호와 방면 분리
    final fullLabel = route['label'] as String;
    final splitIndex = fullLabel.indexOf(' (');
    final busNumber =
        splitIndex != -1 ? fullLabel.substring(0, splitIndex) : fullLabel;
    final direction = splitIndex != -1
        ? fullLabel.substring(splitIndex + 2, fullLabel.length - 1)
        : '';
    final theme = Theme.of(context);
    final hintColor = theme.hintColor;
    final busColor = _cityBusColor(context);
    const tabular = [FontFeature.tabularFigures()];

    return Obx(() {
      final busLocationStatus = _getBusLocationStatus(routeKey);
      final hasLiveBus = busLocationStatus != '현재 운행 없음';
      final nextDepartureTime = _getNextDepartureTime(routeKey);
      final isOperating = nextDepartureTime.startsWith('출발: ');

      // 앱 공통 누름 효과(살짝 작아짐 + 햅틱)
      return ScaleButton(
        key: isFirstExperienceRoute ? _firstRouteKey : null,
        onTap: () => Get.to(() => BusMapView(initialRoute: routeKey)),
        child: Container(
          // 글자 사이 빈 곳을 눌러도 반응하도록 투명 바탕을 깐다.
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              // 버스 번호·방면과 실시간 위치
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          busNumber,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            fontFeatures: tabular,
                          ),
                        ),
                        if (direction.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              direction,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: hintColor),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 16,
                      child: Row(
                        children: [
                          if (hasLiveBus) ...[
                            // 실시간 위치 표시 점
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: busColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: AutoScrollText(
                                text: busLocationStatus,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: busColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                height: 16,
                              ),
                            ),
                          ] else
                            Text(
                              '운행 중인 버스 없음',
                              style: TextStyle(
                                fontSize: 13,
                                color: hintColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 다음 출발 시각은 오른쪽 한 열에 맞춘다
              if (isOperating)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      nextDepartureTime.replaceAll('출발: ', ''),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFeatures: tabular,
                      ),
                    ),
                    Text(
                      '다음 출발',
                      style: TextStyle(fontSize: 12, color: hintColor),
                    ),
                  ],
                )
              else
                Text(
                  nextDepartureTime,
                  style: TextStyle(fontSize: 13, color: hintColor),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.24),
              ),
            ],
          ),
        ),
      );
    });
  }
}
