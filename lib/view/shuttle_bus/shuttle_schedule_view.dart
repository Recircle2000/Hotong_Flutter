import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/shuttle_models.dart';
import '../../utils/responsive_layout.dart';
import '../../viewmodel/shuttle_viewmodel.dart';
import '../components/auto_scroll_text.dart';
import 'naver_map_station_detail_view.dart';

class ShuttleScheduleView extends StatefulWidget {
  final int routeId;
  final String date;
  final String routeName;

  const ShuttleScheduleView({
    super.key,
    required this.routeId,
    required this.date,
    required this.routeName,
  });

  @override
  State<ShuttleScheduleView> createState() => _ShuttleScheduleViewState();
}

class _ShuttleScheduleViewState extends State<ShuttleScheduleView> {
  static const shuttleColor = Color(0xFFB83227);

  final ShuttleViewModel viewModel = Get.find<ShuttleViewModel>();
  final ScrollController _scheduleScrollController = ScrollController();
  final Map<int, GlobalKey> _scheduleRowKeys = <int, GlobalKey>{};

  int? _expandedScheduleId;
  int? _highlightedScheduleId;
  bool _isInlineLoading = false;
  final Map<int, List<ScheduleStop>> _inlineStopsCache =
      <int, List<ScheduleStop>>{};
  final Set<int> _noStopsScheduleIds = <int>{};
  int _lastRequestToken = 0;
  int _lastScrollToken = 0;

  @override
  void initState() {
    super.initState();
    if (viewModel.schedules.isEmpty) {
      viewModel.fetchSchedules(widget.routeId, widget.date);
    }
  }

  @override
  void dispose() {
    _scheduleScrollController.dispose();
    super.dispose();
  }

  GlobalKey _getScheduleRowKey(int scheduleId) {
    return _scheduleRowKeys.putIfAbsent(scheduleId, () => GlobalKey());
  }

  Future<void> _scrollExpandedSectionIntoView(
    int scheduleId, {
    required int scrollToken,
    Duration delay = Duration.zero,
  }) async {
    if (!mounted) return;
    if (scrollToken != _lastScrollToken || _expandedScheduleId != scheduleId) {
      return;
    }

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
      if (!mounted) return;
      if (scrollToken != _lastScrollToken ||
          _expandedScheduleId != scheduleId) {
        return;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scheduleScrollController.hasClients) return;
      if (scrollToken != _lastScrollToken ||
          _expandedScheduleId != scheduleId) {
        return;
      }

      final rowContext = _scheduleRowKeys[scheduleId]?.currentContext;
      if (rowContext == null) return;

      const topPadding = 8.0;
      final position = _scheduleScrollController.position;
      final rowRenderObject = rowContext.findRenderObject();
      if (rowRenderObject == null) return;

      final viewport = RenderAbstractViewport.of(rowRenderObject);
      final rowTopOffset =
          viewport.getOffsetToReveal(rowRenderObject, 0.0).offset;
      final currentOffset = position.pixels;
      final targetOffset = rowTopOffset - topPadding;
      final clampedTarget = targetOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();

      if ((clampedTarget - currentOffset).abs() < 1.0) return;

      await _scheduleScrollController.animateTo(
        clampedTarget,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _onScheduleTap(Schedule schedule) async {
    HapticFeedback.lightImpact();
    final scheduleId = schedule.id;
    final requestToken = ++_lastRequestToken;
    final scrollToken = ++_lastScrollToken;

    if (_expandedScheduleId == scheduleId) {
      setState(() {
        _expandedScheduleId = null;
        _highlightedScheduleId = null;
        _isInlineLoading = false;
      });
      return;
    }

    final hasCached = _inlineStopsCache.containsKey(scheduleId);
    final hasNoStops = _noStopsScheduleIds.contains(scheduleId);

    setState(() {
      _expandedScheduleId = scheduleId;
      _highlightedScheduleId = scheduleId;
      _isInlineLoading = !hasCached && !hasNoStops;
    });

    if (hasCached || hasNoStops) {
      _scrollExpandedSectionIntoView(
        scheduleId,
        scrollToken: scrollToken,
        delay: const Duration(milliseconds: 220),
      );
      return;
    }

    final stops = await viewModel.fetchScheduleStopsForInline(scheduleId);
    if (!mounted) return;

    if (requestToken != _lastRequestToken ||
        _expandedScheduleId != scheduleId) {
      return;
    }

    setState(() {
      _isInlineLoading = false;
      if (stops == null || stops.isEmpty) {
        _noStopsScheduleIds.add(scheduleId);
      } else {
        _inlineStopsCache[scheduleId] = stops;
        _noStopsScheduleIds.remove(scheduleId);
      }
    });

    _scrollExpandedSectionIntoView(
      scheduleId,
      scrollToken: scrollToken,
      delay: const Duration(milliseconds: 120),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppResponsive.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '운행 시간표',
          style:
              TextStyle(fontSize: layout.font(20), fontWeight: FontWeight.w700),
        ),
      ),
      body: AppPageFrame(
        child: Padding(
          padding: EdgeInsets.all(layout.space(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderInfo(context),
              SizedBox(height: layout.space(20)),
              Expanded(child: _buildScheduleList(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context) {
    final layout = AppResponsive.of(context);
    final brightness = Theme.of(context).brightness;
    final backgroundColor = brightness == Brightness.dark
        ? shuttleColor.withOpacity(0.2)
        : shuttleColor.withOpacity(0.1);
    final primaryTextColor =
        brightness == Brightness.dark ? Colors.redAccent : shuttleColor;
    final secondaryTextColor = primaryTextColor.withOpacity(0.78);

    return Container(
      padding: EdgeInsets.all(layout.space(16)),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(layout.radius(25)),
      ),
      child: Obx(() {
        final scheduleType = viewModel.scheduleTypeName.value.trim();
        final typeText = scheduleType.isNotEmpty ? scheduleType : '유형 정보 없음';

        var firstBusTime = '--:--';
        var lastBusTime = '--:--';
        if (viewModel.schedules.isNotEmpty) {
          firstBusTime =
              DateFormat('HH:mm').format(viewModel.schedules.first.startTime);
          lastBusTime =
              DateFormat('HH:mm').format(viewModel.schedules.last.startTime);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_bus_rounded,
                  color: shuttleColor,
                  size: layout.icon(22),
                ),
                SizedBox(width: layout.space(8)),
                Expanded(
                  child: AutoScrollText(
                    text: widget.routeName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: layout.font(22, maxScale: 1.12),
                      height: 1.1,
                      color: primaryTextColor,
                    ),
                    height: layout.space(28, maxScale: 1.10),
                  ),
                ),
                SizedBox(width: layout.space(8)),
                Text(
                  _formatDateWithoutYear(widget.date),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: layout.font(14),
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: layout.space(10)),
            Padding(
              padding: EdgeInsets.only(left: layout.space(30)),
              child: Text(
                typeText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: layout.font(15),
                  color: primaryTextColor,
                ),
              ),
            ),
            SizedBox(height: layout.space(8)),
            Padding(
              padding: EdgeInsets.only(left: layout.space(30)),
              child: Text(
                '첫차 $firstBusTime  ·  막차 $lastBusTime',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: layout.font(13),
                  color: secondaryTextColor,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  String _formatDateWithoutYear(String dateStr) {
    try {
      final date = DateFormat('yyyy-MM-dd').parseStrict(dateStr);
      return DateFormat('MM월 dd일').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildScheduleList(BuildContext context) {
    final layout = AppResponsive.of(context);
    final isIOS = Platform.isIOS;

    return Obx(() {
      if (viewModel.isLoadingSchedules.value) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }

      if (viewModel.schedules.isEmpty) {
        return Center(
          child: Text(
            '선택된 노선과 일자에 해당하는 운행 정보가 없습니다',
            style: TextStyle(fontSize: layout.font(14)),
          ),
        );
      }

      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(layout.radius(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: layout.space(10, maxScale: 1.08),
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                vertical: layout.space(12),
                horizontal: layout.space(16),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).cardColor.withOpacity(0.5)
                    : Theme.of(context)
                        .scaffoldBackgroundColor
                        .withOpacity(0.8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(layout.radius(25)),
                  topRight: Radius.circular(layout.radius(25)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      '회차',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: layout.font(13),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '출발 시간',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: layout.font(13),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '상세',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: layout.font(13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.withOpacity(0.3),
            ),
            Expanded(
              child: ClipRect(
                child: isIOS
                    ? ListView.builder(
                        controller: _scheduleScrollController,
                        itemCount: viewModel.schedules.length,
                        itemBuilder: _buildScheduleItem,
                      )
                    : Scrollbar(
                        interactive: true,
                        thumbVisibility: true,
                        controller: _scheduleScrollController,
                        child: ListView.builder(
                          controller: _scheduleScrollController,
                          itemCount: viewModel.schedules.length,
                          itemBuilder: _buildScheduleItem,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildScheduleItem(BuildContext context, int index) {
    final layout = AppResponsive.of(context);
    final schedule = viewModel.schedules[index];
    final isExpanded = _expandedScheduleId == schedule.id;
    final isHighlightActive = _highlightedScheduleId == schedule.id;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final expandedRowColor = isDarkMode
        ? Theme.of(context).colorScheme.primary.withOpacity(0.14)
        : const Color(0xFFFFF1EF);
    final actionColor = isExpanded
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).hintColor;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onScheduleTap(schedule),
            child: ClipRect(
              child: Container(
                key: _getScheduleRowKey(schedule.id),
                color: (isExpanded && isHighlightActive)
                    ? expandedRowColor
                    : Colors.transparent,
                padding: EdgeInsets.symmetric(
                  vertical: layout.space(12),
                  horizontal: layout.space(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${schedule.round}',
                        style: TextStyle(fontSize: layout.font(14)),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat('HH:mm').format(schedule.startTime),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: layout.font(14),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          isExpanded
                              ? (Platform.isIOS
                                  ? CupertinoIcons.chevron_up
                                  : Icons.keyboard_arrow_up)
                              : (Platform.isIOS
                                  ? CupertinoIcons.chevron_down
                                  : Icons.keyboard_arrow_down),
                          size: layout.icon(18),
                          color: actionColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? _buildInlineStopsSection(context, schedule.id)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStopsSection(BuildContext context, int scheduleId) {
    final layout = AppResponsive.of(context);

    if (_isInlineLoading && _expandedScheduleId == scheduleId) {
      return _buildInlineCardShell(
        context,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: layout.space(14),
            horizontal: layout.space(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: layout.space(18, maxScale: 1.10),
                height: layout.space(18, maxScale: 1.10),
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: layout.border(2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(width: layout.space(10)),
              Text(
                '상세 정류장 정보를 불러오는 중입니다...',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: layout.font(13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final stops = _inlineStopsCache[scheduleId];
    final isNoStops = _noStopsScheduleIds.contains(scheduleId);
    if (isNoStops || stops == null || stops.isEmpty) {
      return _buildInlineCardShell(
        context,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: layout.space(14),
            horizontal: layout.space(14),
          ),
          child: Row(
            children: [
              Icon(
                Platform.isIOS
                    ? CupertinoIcons.info_circle
                    : Icons.info_outline,
                size: layout.icon(16),
                color: Theme.of(context).hintColor,
              ),
              SizedBox(width: layout.space(8)),
              Text(
                '정류장 정보가 없습니다.',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: layout.font(13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildInlineCardShell(
      context,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              vertical: layout.space(10),
              horizontal: layout.space(14),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.14)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(layout.radius(16)),
                topRight: Radius.circular(layout.radius(16)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.alt_route,
                  size: layout.icon(16),
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: layout.space(6, maxScale: 1.08)),
                Text(
                  '상세 정류장 정보',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: layout.font(13),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.space(8),
                    vertical: layout.space(4, maxScale: 1.08),
                  ),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(layout.radius(999)),
                  ),
                  child: Text(
                    '총 ${stops.length}개',
                    style: TextStyle(
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.withOpacity(0.25),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              vertical: layout.space(10),
              horizontal: layout.space(16),
            ),
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).cardColor.withOpacity(0.6)
                : Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    '순서',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: layout.font(12),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '정류장',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: layout.font(12),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '도착 시간',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: layout.font(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stops.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.withOpacity(0.2),
            ),
            itemBuilder: (context, index) =>
                _buildInlineStopItem(context, stops[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineCardShell(BuildContext context, {required Widget child}) {
    final layout = AppResponsive.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        layout.space(12),
        layout.space(4, maxScale: 1.05),
        layout.space(12),
        layout.space(12),
      ),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Theme.of(context).colorScheme.surface.withOpacity(0.72)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(layout.radius(16)),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.18 : 0.08),
            blurRadius: layout.space(8, maxScale: 1.08),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildInlineStopItem(BuildContext context, ScheduleStop stop) {
    final layout = AppResponsive.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: layout.space(10),
        horizontal: layout.space(16),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '${stop.stopOrder}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: layout.font(14),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => _openStationDetail(stop),
              child: Text(
                stop.stationName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: layout.font(14),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => _openStationDetail(stop),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatArrivalTime(stop.arrivalTime),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: layout.font(14),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: layout.space(4, maxScale: 1.05)),
                    Icon(
                      Platform.isIOS
                          ? CupertinoIcons.info_circle_fill
                          : Icons.info_outline,
                      size: layout.icon(14),
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatArrivalTime(String arrivalTime) {
    if (arrivalTime.length >= 5) {
      return arrivalTime.substring(0, 5);
    }
    return arrivalTime;
  }

  void _openStationDetail(ScheduleStop stop) {
    HapticFeedback.lightImpact();
    if (stop.stationId != null) {
      Get.to(() => NaverMapStationDetailView(stationId: stop.stationId!));
      return;
    }
    _showNoStationDetailAlert(context);
  }

  void _showNoStationDetailAlert(BuildContext context) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('정보 없음'),
          content: const Text('이 정류장의 상세 정보가 없습니다.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정보 없음'),
        content: const Text('이 정류장의 상세 정보가 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
