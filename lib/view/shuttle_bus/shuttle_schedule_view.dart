import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/shuttle_models.dart';
import '../../viewmodel/shuttle_viewmodel.dart';
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
  final ShuttleViewModel viewModel = Get.find<ShuttleViewModel>();
  final ScrollController _scheduleScrollController = ScrollController();
  final GlobalKey _scheduleViewportKey = GlobalKey();
  final Map<int, GlobalKey> _scheduleItemKeys = <int, GlobalKey>{};

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

    // 스케줄이 비어있는 경우 데이터 로드
    if (viewModel.schedules.isEmpty) {
      viewModel.fetchSchedules(widget.routeId, widget.date);
    }
  }

  @override
  void dispose() {
    _scheduleScrollController.dispose();
    super.dispose();
  }

  GlobalKey _getScheduleItemKey(int scheduleId) {
    return _scheduleItemKeys.putIfAbsent(scheduleId, () => GlobalKey());
  }

  Future<void> _scrollExpandedSectionIntoView(
    int scheduleId, {
    bool afterAnimation = true,
    required int scrollToken,
  }) async {
    if (!mounted) return;

    if (afterAnimation) {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
    }

    if (scrollToken != _lastScrollToken || _expandedScheduleId != scheduleId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scheduleScrollController.hasClients) return;
      if (scrollToken != _lastScrollToken ||
          _expandedScheduleId != scheduleId) {
        return;
      }

      final itemContext = _scheduleItemKeys[scheduleId]?.currentContext;
      final viewportContext = _scheduleViewportKey.currentContext;
      if (itemContext == null || viewportContext == null) return;

      final itemBox = itemContext.findRenderObject() as RenderBox?;
      final viewportBox = viewportContext.findRenderObject() as RenderBox?;
      if (itemBox == null || viewportBox == null) return;

      final itemTop =
          itemBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
      final itemBottom = itemTop + itemBox.size.height;
      final viewportHeight = viewportBox.size.height;

      const topPadding = 8.0;
      const bottomPadding = 8.0;
      final availableHeight = viewportHeight - topPadding - bottomPadding;

      double targetOffset = _scheduleScrollController.offset;
      if (itemBox.size.height > availableHeight) {
        // 카드가 화면보다 크면 상단 기준으로 정렬
        targetOffset += (itemTop - topPadding);
      } else {
        // 카드 전체가 보이도록 필요한 만큼만 이동
        if (itemTop < topPadding) {
          targetOffset += (itemTop - topPadding);
        } else if (itemBottom > viewportHeight - bottomPadding) {
          targetOffset += (itemBottom - (viewportHeight - bottomPadding));
        }
      }

      final minOffset = _scheduleScrollController.position.minScrollExtent;
      final maxOffset = _scheduleScrollController.position.maxScrollExtent;
      final clampedTarget = targetOffset.clamp(minOffset, maxOffset).toDouble();
      final distance = (clampedTarget - _scheduleScrollController.offset).abs();

      if (distance < 1.0) {
        _applyHighlightAfterScroll(scheduleId, scrollToken);
        return;
      }

      await _scheduleScrollController.animateTo(
        clampedTarget,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      _applyHighlightAfterScroll(scheduleId, scrollToken);
    });
  }

  void _applyHighlightAfterScroll(int scheduleId, int scrollToken) {
    if (!mounted) return;
    if (scrollToken != _lastScrollToken || _expandedScheduleId != scheduleId) {
      return;
    }
    if (_highlightedScheduleId == scheduleId) {
      return;
    }
    setState(() {
      _highlightedScheduleId = scheduleId;
    });
  }

  Future<void> _onScheduleTap(Schedule schedule) async {
    HapticFeedback.lightImpact();
    final scheduleId = schedule.id;
    final requestToken = ++_lastRequestToken;
    final scrollToken = ++_lastScrollToken;

    // 같은 항목 재탭 시 접기
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

    // 다른 항목 펼치기 (동시에 하나만)
    setState(() {
      _expandedScheduleId = scheduleId;
      _highlightedScheduleId = null;
      _isInlineLoading = !hasCached && !hasNoStops;
    });

    if (hasCached || hasNoStops) {
      _scrollExpandedSectionIntoView(
        scheduleId,
        scrollToken: scrollToken,
      );
      return;
    }

    final stops = await viewModel.fetchScheduleStopsForInline(scheduleId);
    if (!mounted) {
      return;
    }

    // 마지막 탭 요청이 아닌 경우 무시
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운행 시간표'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 선택된 노선 정보
            _buildHeaderInfo(),
            const SizedBox(height: 20),
            // 시간표 목록
            Expanded(
              child: _buildScheduleList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    const shuttleColor = Color(0xFFB83227);
    final brightness = Theme.of(context).brightness;
    final backgroundColor = brightness == Brightness.dark
        ? shuttleColor.withOpacity(0.2)
        : shuttleColor.withOpacity(0.1);
    final primaryTextColor =
        brightness == Brightness.dark ? Colors.redAccent : shuttleColor;
    final secondaryTextColor = primaryTextColor.withOpacity(0.78);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(25),
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(
                  Icons.directions_bus_rounded,
                  color: shuttleColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.routeName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.1,
                      color: primaryTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDateWithoutYear(widget.date),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              typeText,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 15,
                  color: secondaryTextColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '첫차 $firstBusTime  ·  막차 $lastBusTime',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: secondaryTextColor,
                  ),
                ),
              ],
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
    } catch (e) {
      return dateStr;
    }
  }

  // ignore: unused_element
  Widget _buildHeaderInfoLegacy() {
    // 셔틀버스 색상 - 홈 화면과 동일하게 맞춤
    const shuttleColor = Color(0xFFB83227);
    final brightness = Theme.of(context).brightness;
    final backgroundColor = brightness == Brightness.dark
        ? shuttleColor.withOpacity(0.2)
        : shuttleColor.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_bus,
                color: shuttleColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '노선: ${widget.routeName}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: brightness == Brightness.dark
                        ? Colors.redAccent
                        : shuttleColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                color: shuttleColor,
              ),
              const SizedBox(width: 8),
              Text(
                // 날짜 형식 변환 (YYYY-MM-DD -> YYYY년 MM월 DD일)
                '날짜: ${_formatDate(widget.date)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: brightness == Brightness.dark
                      ? Colors.redAccent
                      : shuttleColor,
                ),
              ),
            ],
          ),
          // 요일 타입 정보 표시 (API 응답에서 가져온 경우)
          Obx(
            () => viewModel.scheduleTypeName.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.event,
                            color: shuttleColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '유형: ${viewModel.scheduleTypeName.value}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: brightness == Brightness.dark
                                  ? Colors.redAccent
                                  : shuttleColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          Obx(() {
            // 첫차와 막차 시간 계산
            var firstBusTime = '정보 없음';
            var lastBusTime = '정보 없음';

            // 스케줄이 있는 경우 첫차/막차 정보 설정
            if (viewModel.schedules.isNotEmpty) {
              firstBusTime = DateFormat('HH:mm')
                  .format(viewModel.schedules.first.startTime);
              lastBusTime = DateFormat('HH:mm')
                  .format(viewModel.schedules.last.startTime);
            }

            return Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: shuttleColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '첫차: $firstBusTime  /  막차: $lastBusTime',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: brightness == Brightness.dark
                          ? Colors.redAccent
                          : shuttleColor,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // 날짜 형식 변환 (YYYY-MM-DD -> YYYY년 MM월 DD일)
  String _formatDate(String dateStr) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return DateFormat('yyyy년 MM월 dd일').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildScheduleList() {
    final isIOS = Platform.isIOS;

    return Obx(
      () => viewModel.isLoadingSchedules.value
          ? const Center(
              child: CircularProgressIndicator.adaptive(),
            )
          : viewModel.schedules.isEmpty
              ? const Center(
                  child: Text('선택된 노선과 일자에 해당하는 운행 정보가 없습니다'),
                )
              : Container(
                  clipBehavior: Clip.antiAlias,
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
                    children: [
                      // 헤더 행
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).cardColor.withOpacity(0.5)
                              : Theme.of(context)
                                  .scaffoldBackgroundColor
                                  .withOpacity(0.8),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                '회차',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '출발 시간',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '정류장',
                                  style: TextStyle(fontWeight: FontWeight.bold),
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
                        child: Container(
                          key: _scheduleViewportKey,
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
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildScheduleItem(BuildContext context, int index) {
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
      key: _getScheduleItemKey(schedule.id),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onScheduleTap(schedule),
            child: ClipRect(
              child: Container(
                color: (isExpanded && isHighlightActive)
                    ? expandedRowColor
                    : Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text('${schedule.round}'),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat('HH:mm').format(schedule.startTime),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExpanded
                                  ? (Platform.isIOS
                                      ? CupertinoIcons.chevron_up
                                      : Icons.keyboard_arrow_up)
                                  : (Platform.isIOS
                                      ? CupertinoIcons.chevron_down
                                      : Icons.keyboard_arrow_down),
                              size: 18,
                              color: actionColor,
                            ),
                          ],
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
                ? _buildInlineStopsSection(schedule.id)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStopsSection(int scheduleId) {
    if (_isInlineLoading && _expandedScheduleId == scheduleId) {
      return _buildInlineCardShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '상세 정류장 정보를 불러오는 중입니다...',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 13,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Row(
            children: [
              Icon(
                Platform.isIOS
                    ? CupertinoIcons.info_circle
                    : Icons.info_outline,
                size: 16,
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(width: 8),
              Text(
                '정류장 정보가 없습니다.',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildInlineCardShell(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.14)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.alt_route,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '상세 정류장 정보',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '총 ${stops.length}개',
                    style: TextStyle(
                      fontSize: 11,
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).cardColor.withOpacity(0.6)
                : Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
            child: const Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    '순서',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '정류장',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '도착(경유) 시간',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
            itemBuilder: (context, index) => _buildInlineStopItem(stops[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineCardShell({required Widget child}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Theme.of(context).colorScheme.surface.withOpacity(0.72)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.18 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildInlineStopItem(ScheduleStop stop) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '${stop.stopOrder}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
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
                style: const TextStyle(fontWeight: FontWeight.w500),
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
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Platform.isIOS
                          ? CupertinoIcons.info_circle_fill
                          : Icons.info_outline,
                      size: 14,
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
    } else {
      _showNoStationDetailAlert(context);
    }
  }

  // 정류장 상세 정보가 없을 때 알림 팝업
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
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('정보 없음'),
          content: const Text('이 정류장의 상세 정보가 없습니다.'),
          actions: [
            TextButton(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }
}
