import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/subway/models/subway_schedule_model.dart';
import 'package:hsro/features/subway/viewmodel/subway_schedule_viewmodel.dart';
import 'package:hsro/features/subway/widgets/subway_segmented_control.dart';

class SubwayScheduleView extends StatefulWidget {
  final String? initialStationName;

  const SubwayScheduleView({Key? key, this.initialStationName})
      : super(key: key);

  @override
  State<SubwayScheduleView> createState() => _SubwayScheduleViewState();
}

class _SubwayScheduleViewState extends State<SubwayScheduleView> {
  late final SubwayScheduleViewModel controller;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // 화면 재사용 여부에 따라 ViewModel 생성 또는 재사용
    if (!Get.isRegistered<SubwayScheduleViewModel>()) {
      controller = Get.put(
          SubwayScheduleViewModel(initialStation: widget.initialStationName));
    } else {
      controller = Get.find<SubwayScheduleViewModel>();
      // 초기 역명이 있으면 재사용 중인 ViewModel도 맞춰줌
      if (widget.initialStationName != null) {
        controller.changeStation(widget.initialStationName!);
      }
    }

    final initialIndex = controller.selectedStation.value == '아산' ? 1 : 0;
    _pageController = PageController(initialPage: initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    // 좌우 스와이프 시 선택 역 동기화
    final station = index == 0 ? '천안' : '아산';
    controller.changeStation(station);
  }

  void _onStationTapped(String station) {
    // 상단 토글 탭 시 해당 역 페이지로 이동
    if (controller.selectedStation.value == station) return;
    final index = station == '천안' ? 0 : 1;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    controller.changeStation(station);
  }

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // 급행·행선지 구분색: 라이트는 흰 배경 대비를 맞춘 진한 톤, 다크는 밝은 톤
  Color _expressColor(bool dark) =>
      dark ? const Color(0xFFFF7A6E) : const Color(0xFFD23F31);
  Color _guroColor(bool dark) =>
      dark ? const Color(0xFF8FB0FF) : const Color(0xFF2F62D0);
  Color _byeongjeomColor(bool dark) =>
      dark ? const Color(0xFF6FCB8F) : const Color(0xFF27804A);
  Color _cheonanColor(bool dark) =>
      dark ? const Color(0xFFF2B35B) : const Color(0xFFA35F00);

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '지하철 시간표',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                // 역 선택 토글
                Obx(
                  () => SubwaySegmentedControl(
                    labels: const ['천안역', '아산역'],
                    selectedIndex:
                        controller.selectedStation.value == '아산' ? 1 : 0,
                    onChanged: (i) => _onStationTapped(i == 0 ? '천안' : '아산'),
                  ),
                ),
                const SizedBox(height: 12),
                // 평일/주말 선택과 행선지 범례
                _buildDayTypeAndLegendRow(context),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 천안역/아산역 시간표 페이지 전환
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _buildScheduleContent(context, '천안'),
                _buildScheduleContent(context, '아산'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleContent(BuildContext context, String station) {
    final hintColor = Theme.of(context).hintColor;
    return Obx(() {
      // 현재 선택한 역과 일치할 때만 실제 시간표 표시
      if (controller.selectedStation.value != station) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }

      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }
      if (controller.error.value.isNotEmpty) {
        return Center(
          child: Text(controller.error.value,
              style: TextStyle(color: hintColor)),
        );
      }

      final schedule = controller.scheduleData.value;
      if (schedule == null) {
        return Center(
          child: Text('시간표 정보가 없어요', style: TextStyle(color: hintColor)),
        );
      }

      // 상행/하행 섹션으로 나눠 시간표 표시
      return Column(
        children: [
          // 상행 섹션
          _buildSectionContainer(
            context,
            title: '상행',
            subtitle: '서울·병점·천안 방면',
            isExpanded: controller.isUpExpanded.value,
            items: schedule.timetable['상행'] ?? [],
            onTap: () => controller.isUpExpanded.toggle(),
          ),

          // 하행 섹션
          _buildSectionContainer(
            context,
            title: '하행',
            subtitle: '신창·아산 방면',
            isExpanded: controller.isDownExpanded.value,
            items: schedule.timetable['하행'] ?? [],
            onTap: () => controller.isDownExpanded.toggle(),
          ),

          if (!controller.isUpExpanded.value &&
              !controller.isDownExpanded.value)
            Expanded(child: _buildFooter(context)),
          if (controller.isUpExpanded.value || controller.isDownExpanded.value)
            const SizedBox(height: 16),
        ],
      );
    });
  }

  Widget _buildSectionContainer(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isExpanded,
    required List<SubwayScheduleItem> items,
    required VoidCallback onTap,
  }) {
    // 접힘/펼침 가능한 상행/하행 시간표 섹션
    final header =
        _buildSectionHeader(context, title, subtitle, isExpanded, onTap);

    if (!isExpanded) {
      return header;
    }

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTimeTableGrid(context, items),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title,
      String subtitle, bool isExpanded, VoidCallback onTap) {
    final hintColor = Theme.of(context).hintColor;
    // 섹션 헤더 탭 시 펼침 상태 전환
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const SubwayLineMark(),
              const SizedBox(width: 8),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: hintColor),
                ),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayTypeAndLegendRow(BuildContext context) {
    return Row(
      children: [
        // 급행·행선지 범례
        Expanded(
          child: Obx(() {
            final dark = _isDark(context);
            final isCheonanStation = controller.selectedStation.value == '천안';
            return Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                _buildLegendItem(context, '급행', _expressColor(dark)),
                _buildLegendItem(context, '구로행', _guroColor(dark)),
                _buildLegendItem(context, '병점행', _byeongjeomColor(dark)),
                if (!isCheonanStation)
                  _buildLegendItem(context, '천안행', _cheonanColor(dark)),
              ],
            );
          }),
        ),
        const SizedBox(width: 12),
        // 평일/주말 선택
        SizedBox(
          width: 144,
          child: Obx(
            () => SubwaySegmentedControl(
              labels: const ['평일', '토·공휴일'],
              selectedIndex: controller.selectedDayType.value == '평일' ? 0 : 1,
              onChanged: (i) => controller.changeDayType(i == 0 ? '평일' : '주말'),
              height: 36,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
      ],
    );
  }

  Widget _buildTimeTableGrid(
      BuildContext context, List<SubwayScheduleItem> items) {
    final theme = Theme.of(context);
    final hintColor = theme.hintColor;
    final onSurface = theme.colorScheme.onSurface;

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('운행 정보가 없어요', style: TextStyle(color: hintColor)),
        ),
      );
    }

    final Map<int, List<SubwayScheduleItem>> grouped = {};
    for (var item in items) {
      try {
        final parts = item.departureTime.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          if (hour == 0) hour = 25;
          grouped.putIfAbsent(hour, () => []).add(item);
        }
      } catch (e) {
        // ignore parsing error
      }
    }

    final sortedHours = grouped.keys.toList()..sort();
    final dark = _isDark(context);
    final hairline = onSurface.withValues(alpha: 0.06);

    // 보고 있는 요일 종류가 오늘과 같을 때만 지금 시각 행을 표시
    final now = DateTime.now();
    final todayType = now.weekday <= DateTime.friday ? '평일' : '주말';
    final currentHour = controller.selectedDayType.value == todayType
        ? (now.hour == 0 ? 25 : now.hour)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text('시',
                      style: TextStyle(fontSize: 12, color: hintColor)),
                ),
                const SizedBox(width: 16),
                Text('분', style: TextStyle(fontSize: 12, color: hintColor)),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: hairline),
          Expanded(
            child: ListView.separated(
              itemCount: sortedHours.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: hairline,
              ),
              itemBuilder: (context, index) {
                final hour = sortedHours[index];
                final hourItems = grouped[hour]!;
                hourItems
                    .sort((a, b) => a.departureTime.compareTo(b.departureTime));
                final isCurrentHour = hour == currentHour;

                return Container(
                  color: isCurrentHour
                      ? onSurface.withValues(alpha: 0.04)
                      : null,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          (hour == 25 ? 0 : hour).toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isCurrentHour
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isCurrentHour ? onSurface : hintColor,
                            fontFeatures: _tabular,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: hourItems.map((item) {
                            final minute = item.departureTime.split(':')[1];

                            // 행선지를 먼저, 그다음 급행 여부로 색을 정한다
                            Color itemColor;
                            if (item.arrivalStation == '구로') {
                              itemColor = _guroColor(dark);
                            } else if (item.arrivalStation == '병점') {
                              itemColor = _byeongjeomColor(dark);
                            } else if (item.arrivalStation == '천안') {
                              itemColor = _cheonanColor(dark);
                            } else if (item.isExpress) {
                              itemColor = _expressColor(dark);
                            } else {
                              itemColor = onSurface;
                            }

                            return Text(
                              minute,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: item.isExpress
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: itemColor,
                                fontFeatures: _tabular,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Text(
          '철도 운영 상황에 따라 바뀔 수 있어요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
      ),
    );
  }
}
