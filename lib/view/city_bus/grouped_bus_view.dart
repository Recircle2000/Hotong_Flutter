import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../city_bus/bus_map_view.dart';
import '../../models/emergency_notice_model.dart';
import '../../viewmodel/busmap_viewmodel.dart';
import '../../viewmodel/settings_viewmodel.dart';
import '../../utils/bus_times_loader.dart';
import '../components/emergency_notice_banner.dart';
import '../components/auto_scroll_text.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

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
    if (_busTimesLoaded) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final busTimes = await BusTimesLoader.loadBusTimes();
    // 모든 노선에 대해 계산
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
    // BusMapViewModel 인스턴스 생성 및 초기화 (Shared Instance)
    busMapViewModel = Get.put(BusMapViewModel());
    _loadAllNextDepartureTimes();
    if (widget.startExperienceTour) {
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
                description: '원하는 노선 항목을 눌러 실시간 상세 화면으로 이동할 수 있습니다.',
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
    // ViewModel에서 해당 노선의 버스 데이터 확인
    if (busMapViewModel.allRoutesBusData.containsKey(routeKey)) {
      final buses = busMapViewModel.allRoutesBusData[routeKey]!;

      if (buses.isNotEmpty) {
        if (buses.length == 1) {
          return '${buses.first.stationName}';
        } else {
          return '운행중 ${buses.length}대 (${buses.first.stationName} 외)';
        }
      }
    }

    return '현재 운행 없음';
  }

  /// 특정 노선의 다음 출발시간 정보를 가져오는 함수
  String _getNextDepartureTime(String routeKey) {
    // 모든 노선에 대해 출발시간 표시 (UP, DOWN 구분 없이)
    return allNextDepartureTimes[routeKey] ?? '로딩...';
  }

  EmergencyNoticeCategory _getCityBusNoticeCategory(String campus) {
    return campus == '천안'
        ? EmergencyNoticeCategory.cheonanCitybus
        : EmergencyNoticeCategory.asanCitybus;
  }

  Widget _buildBodyWithEmergencyNotice(String campus) {
    return Column(
      children: [
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
          style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildRouteList(String campus) {
    final groupedRoutes =
        campus == '천안' ? groupedRoutesCheonan : groupedRoutesAsan;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
      itemCount: groupedRoutes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, groupIdx) {
        final group = groupedRoutes[groupIdx];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 메인 그룹 타이틀 (예: 천안아산역 · 지중해마을 방면)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_bus,
                        color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group['subtitle'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 서브 그룹들 (출발/도착)
            Container(
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
              child: Column(
                children:
                    List.generate(group['subGroups'].length, (subGroupIdx) {
                  final subGroup = group['subGroups'][subGroupIdx];
                  final isLastSubGroup =
                      subGroupIdx == group['subGroups'].length - 1;

                  return Column(
                    children: [
                      // 서브 그룹 헤더 (아캠 출발 / 도착)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: subGroupIdx == 0
                              ? Colors.blue.withOpacity(0.05)
                              : Colors.orange.withOpacity(0.05),
                          borderRadius: subGroupIdx == 0
                              ? const BorderRadius.vertical(
                                  top: Radius.circular(25))
                              : (isLastSubGroup && subGroup['routes'].isEmpty
                                  ? const BorderRadius.vertical(
                                      bottom: Radius.circular(25))
                                  : BorderRadius.zero),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              subGroup['icon'],
                              size: 16,
                              color: subGroupIdx == 0
                                  ? Colors.blue
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              subGroup['title'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: subGroupIdx == 0
                                    ? Colors.blue
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 노선 리스트
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: subGroup['routes'].length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.grey.withOpacity(0.1),
                          indent: 20,
                          endIndent: 20,
                        ),
                        itemBuilder: (context, routeIdx) {
                          final route = subGroup['routes'][routeIdx];
                          final routeKey = route['routeKey'];
                          // label에서 번호만 추출
                          final fullLabel = route['label'] as String;
                          final splitIndex = fullLabel.indexOf(' (');
                          final busNumber = splitIndex != -1
                              ? fullLabel.substring(0, splitIndex)
                              : fullLabel;
                          final direction = splitIndex != -1
                              ? fullLabel.substring(
                                  splitIndex + 2, fullLabel.length - 1)
                              : '';
                          final isFirstExperienceRoute = groupIdx == 0 &&
                              subGroupIdx == 0 &&
                              routeIdx == 0;

                          return Obx(() {
                            final busLocationStatus =
                                _getBusLocationStatus(routeKey);
                            final nextDepartureTime =
                                _getNextDepartureTime(routeKey);
                            final isOperating = nextDepartureTime != '운행 종료' &&
                                nextDepartureTime != '로딩...';

                            return InkWell(
                              key: isFirstExperienceRoute
                                  ? _firstRouteKey
                                  : null,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Get.to(
                                    () => BusMapView(initialRoute: routeKey));
                              },
                              borderRadius: isLastSubGroup &&
                                      routeIdx == subGroup['routes'].length - 1
                                  ? const BorderRadius.vertical(
                                      bottom: Radius.circular(25))
                                  : BorderRadius.zero,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: Row(
                                  children: [
                                    // 버스 번호 및 방면
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.baseline,
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                            children: [
                                              Text(
                                                busNumber,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              if (direction.isNotEmpty)
                                                Expanded(
                                                  child: Text(
                                                    direction,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[600],
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              // 버스 위치 상태
                                              if (busLocationStatus !=
                                                  '현재 운행 없음') ...[
                                                const Icon(Icons.location_on,
                                                    size: 12,
                                                    color: Colors.blue),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: AutoScrollText(
                                                    text: busLocationStatus,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    height: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 1,
                                                  height: 10,
                                                  color: Colors.grey[300],
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              // 다음 출발 시간
                                              Text(
                                                nextDepartureTime.replaceAll(
                                                    '출발: ', ''),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isOperating
                                                      ? const Color(0xFFE65100)
                                                      : Colors.grey,
                                                  fontWeight: isOperating
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                              if (isOperating) ...[
                                                const SizedBox(width: 4),
                                                const Text(
                                                  '출발',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 화살표 아이콘
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey[300],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          });
                        },
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}
