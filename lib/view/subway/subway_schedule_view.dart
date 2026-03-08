import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/subway_schedule_model.dart';
import '../../utils/responsive_layout.dart';
import '../../viewmodel/subway_schedule_viewmodel.dart';

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
    if (!Get.isRegistered<SubwayScheduleViewModel>()) {
      controller = Get.put(
        SubwayScheduleViewModel(initialStation: widget.initialStationName),
      );
    } else {
      controller = Get.find<SubwayScheduleViewModel>();
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
    final station = index == 0 ? '천안' : '아산';
    controller.changeStation(station);
  }

  void _onStationTapped(String station) {
    if (controller.selectedStation.value == station) return;

    final index = station == '천안' ? 0 : 1;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    controller.changeStation(station);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppResponsive.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
              child: AppPageFrame(
                child: Column(
                  children: [
                    _buildStationSelector(context),
                    SizedBox(height: layout.space(16)),
                    _buildDayTypeAndLegendRow(context),
                    SizedBox(height: layout.space(16)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildScheduleContent(context, '천안'),
                  _buildScheduleContent(context, '아산'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleContent(BuildContext context, String station) {
    final layout = AppResponsive.of(context);

    return Obx(() {
      if (controller.selectedStation.value != station) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }

      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }

      if (controller.error.value.isNotEmpty) {
        return Center(child: Text(controller.error.value));
      }

      final schedule = controller.scheduleData.value;
      if (schedule == null) {
        return const Center(child: Text('데이터가 없습니다.'));
      }

      return AppPageFrame(
        child: Column(
          children: [
            _buildSectionContainer(
              context,
              title: '상행',
              subtitle: '(서울/병점/천안)',
              icon: Icons.arrow_circle_up,
              isExpanded: controller.isUpExpanded.value,
              items: schedule.timetable['상행'] ?? [],
              onTap: () => controller.isUpExpanded.toggle(),
            ),
            _buildSectionContainer(
              context,
              title: '하행',
              subtitle: '(신창/아산)',
              icon: Icons.arrow_circle_down,
              isExpanded: controller.isDownExpanded.value,
              items: schedule.timetable['하행'] ?? [],
              onTap: () => controller.isDownExpanded.toggle(),
            ),
            if (!controller.isUpExpanded.value &&
                !controller.isDownExpanded.value)
              Expanded(child: _buildFooter(context)),
            if (controller.isUpExpanded.value ||
                controller.isDownExpanded.value)
              SizedBox(height: layout.space(16)),
          ],
        ),
      );
    });
  }

  Widget _buildSectionContainer(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isExpanded,
    required List<SubwayScheduleItem> items,
    required VoidCallback onTap,
  }) {
    final layout = AppResponsive.of(context);
    final header =
        _buildSectionHeader(context, title, subtitle, icon, isExpanded, onTap);

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
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
                child: _buildTimeTableGrid(context, items),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool isExpanded,
    VoidCallback onTap,
  ) {
    final layout = AppResponsive.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: EdgeInsets.symmetric(
          horizontal: layout.space(16),
          vertical: layout.space(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: const Color(0xFF0052A4),
                    size: layout.icon(24),
                  ),
                  SizedBox(width: layout.space(8)),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: layout.font(18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: layout.space(4, maxScale: 1.08)),
                  Expanded(
                    child: Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: layout.font(14),
                        fontWeight: FontWeight.normal,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: layout.icon(24),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final layout = AppResponsive.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.space(16),
        layout.space(16),
        layout.space(16),
        layout.space(8),
      ),
      child: AppPageFrame(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => Get.back(),
              icon: Icon(
                Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back,
                color: Theme.of(context).colorScheme.onSurface,
                size: layout.icon(24),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            Text(
              '지하철 시간표',
              style: TextStyle(
                fontSize: layout.font(20),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: layout.space(24)),
          ],
        ),
      ),
    );
  }

  Widget _buildStationSelector(BuildContext context) {
    final layout = AppResponsive.of(context);

    return Obx(() {
      final isCheonan = controller.selectedStation.value == '천안';

      return Container(
        padding: EdgeInsets.all(layout.space(4, maxScale: 1.08)),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(layout.radius(12)),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: layout.space(10, maxScale: 1.08),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                context,
                text: '천안역',
                isSelected: isCheonan,
                onTap: () => _onStationTapped('천안'),
              ),
            ),
            SizedBox(width: layout.space(4, maxScale: 1.08)),
            Expanded(
              child: _buildToggleButton(
                context,
                text: '아산역',
                isSelected: !isCheonan,
                onTap: () => _onStationTapped('아산'),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final layout = AppResponsive.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: layout.space(10)),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0052A4) : Colors.transparent,
          borderRadius: BorderRadius.circular(layout.radius(8)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0052A4).withOpacity(0.3),
                    blurRadius: layout.space(8, maxScale: 1.08),
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: layout.font(14),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildDayTypeAndLegendRow(BuildContext context) {
    final layout = AppResponsive.of(context);

    final legend = Obx(() {
      final isCheonanStation = controller.selectedStation.value == '천안';
      final legendItems = <Widget>[
        _buildLegendItem(context, '급행', Colors.red),
        _buildLegendItem(context, '구로행', Colors.blue),
        _buildLegendItem(context, '병점행', Colors.green),
        if (!isCheonanStation) _buildLegendItem(context, '천안행', Colors.orange),
      ];

      Widget buildLegendRow(List<Widget> items) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: layout.space(6, maxScale: 1.08)),
              items[i],
            ],
          ],
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: layout.space(8),
          vertical: layout.space(4, maxScale: 1.08),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(layout.radius(4)),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
          ),
        ),
        child: legendItems.length == 4
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLegendRow(legendItems.sublist(0, 2)),
                  SizedBox(height: layout.space(4, maxScale: 1.08)),
                  buildLegendRow(legendItems.sublist(2, 4)),
                ],
              )
            : buildLegendRow(legendItems),
      );
    });

    final dayTypeSelector = Obx(() {
      final isWeekday = controller.selectedDayType.value == '평일';

      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(layout.radius(8)),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
        padding: EdgeInsets.all(layout.space(4, maxScale: 1.08)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDayTypeButton(
              context,
              '평일',
              isWeekday,
              () => controller.changeDayType('평일'),
            ),
            _buildDayTypeButton(
              context,
              '토요일/공휴일',
              !isWeekday,
              () => controller.changeDayType('주말'),
            ),
          ],
        ),
      );
    });

    if (layout.isCompactWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          legend,
          SizedBox(height: layout.space(12)),
          Align(
            alignment: Alignment.centerRight,
            child: dayTypeSelector,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: legend),
        SizedBox(width: layout.space(12)),
        dayTypeSelector,
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    final layout = AppResponsive.of(context);

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color,
          radius: layout.space(4, maxScale: 1.08),
        ),
        SizedBox(width: layout.space(4, maxScale: 1.08)),
        Text(
          label,
          style: TextStyle(
            fontSize: layout.font(12),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDayTypeButton(
    BuildContext context,
    String text,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final layout = AppResponsive.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: layout.space(12),
          vertical: layout.space(4, maxScale: 1.08),
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0052A4) : Colors.transparent,
          borderRadius: BorderRadius.circular(layout.radius(6)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: layout.space(2, maxScale: 1.08),
                    offset: const Offset(0, 1),
                  ),
                ]
              : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: layout.font(12),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTableGrid(
    BuildContext context,
    List<SubwayScheduleItem> items,
  ) {
    final layout = AppResponsive.of(context);

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(layout.space(24)),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(layout.radius(16)),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
        child: Center(
          child: Text(
            '운행 정보가 없습니다.',
            style: TextStyle(
              fontSize: layout.font(14),
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
      );
    }

    final grouped = <int, List<SubwayScheduleItem>>{};
    for (final item in items) {
      try {
        final parts = item.departureTime.split(':');
        if (parts.length >= 2) {
          var hour = int.parse(parts[0]);
          if (hour == 0) hour = 25;
          grouped.putIfAbsent(hour, () => []).add(item);
        }
      } catch (_) {
        // Ignore malformed time data.
      }
    }

    final sortedHours = grouped.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(layout.radius(16)),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: layout.space(10, maxScale: 1.08),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              vertical: layout.space(8),
              horizontal: layout.space(16),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]!.withOpacity(0.5)
                  : Colors.grey[50],
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(layout.radius(16)),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: layout.space(40, maxScale: 1.12),
                  child: Text(
                    '시',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: layout.font(12),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
                SizedBox(width: layout.space(16)),
                Text(
                  '분',
                  style: TextStyle(
                    fontSize: layout.font(12),
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: sortedHours.length,
              itemBuilder: (context, index) {
                final hour = sortedHours[index];
                final hourItems = grouped[hour]!
                  ..sort((a, b) => a.departureTime.compareTo(b.departureTime));

                return Container(
                  padding: EdgeInsets.symmetric(
                    vertical: layout.space(12),
                    horizontal: layout.space(16),
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.05),
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: layout.space(40, maxScale: 1.12),
                        child: Text(
                          (hour == 25 ? '00' : hour).toString().padLeft(2, '0'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF0052A4),
                            fontSize: layout.font(14),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: layout.space(16)),
                      Expanded(
                        child: Wrap(
                          spacing: layout.space(12),
                          runSpacing: layout.space(8),
                          children: hourItems.map((item) {
                            final minute = item.departureTime.split(':')[1];

                            Color itemColor;
                            if (item.arrivalStation == '구로') {
                              itemColor = Colors.blue;
                            } else if (item.arrivalStation == '병점') {
                              itemColor = Colors.green;
                            } else if (item.arrivalStation == '천안') {
                              itemColor = Colors.orange;
                            } else if (item.isExpress) {
                              itemColor = Colors.red;
                            } else {
                              itemColor =
                                  Theme.of(context).colorScheme.onSurface;
                            }

                            return Text(
                              minute,
                              style: TextStyle(
                                fontSize: layout.font(14),
                                fontWeight: item.isExpress
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: itemColor,
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
    final layout = AppResponsive.of(context);

    return Center(
      child: Container(
        margin: EdgeInsets.only(top: layout.space(8)),
        padding: EdgeInsets.symmetric(
          horizontal: layout.space(12),
          vertical: layout.space(6, maxScale: 1.08),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(layout.radius(20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: layout.icon(14),
              color: Theme.of(context).hintColor,
            ),
            SizedBox(width: layout.space(6, maxScale: 1.08)),
            Text(
              '도로 사정이나 철도 운영 상황에 따라 변경될 수 있습니다',
              style: TextStyle(
                fontSize: layout.font(10),
                fontWeight: FontWeight.w500,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
