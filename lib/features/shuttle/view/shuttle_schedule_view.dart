import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/view/naver_map_station_detail_view.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';
import 'package:hsro/shared/widgets/auto_scroll_text.dart';
import 'package:intl/intl.dart';

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
  static const double _timeToArrowSpacing = 8.0;
  static const double _timeIndicatorWidth = 18.0;
  static const double _arrowToEndTimeSpacing = 20.0;
  static const double _endTimeFontSize = 13.0;
  static const double _nearestScheduleIconSize = 14.0;

  final ShuttleViewModel viewModel = Get.find<ShuttleViewModel>();
  final ScrollController _scheduleScrollController = ScrollController();
  final Map<int, GlobalKey> _scheduleRowKeys = <int, GlobalKey>{};
  final Map<int, Alignment> _rowSizeAlignments = <int, Alignment>{};
  Timer? _currentTimeRefreshTimer;

  int? _expandedScheduleId;
  int? _highlightedScheduleId;
  bool _isInlineLoading = false;
  final Map<int, List<ScheduleStop>> _inlineStopsCache =
      <int, List<ScheduleStop>>{};
  // 정류장 정보가 없던 회차는 다시 조회하지 않도록 기록
  final Set<int> _noStopsScheduleIds = <int>{};

  @override
  void initState() {
    super.initState();

    // 오늘 날짜를 보고 있으면 현재 시각 강조를 주기적으로 갱신
    _currentTimeRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (!mounted || !_isViewingToday()) {
          return;
        }
        setState(() {});
      },
    );

    // 진입 시 스케줄이 없으면 먼저 조회
    if (viewModel.schedules.isEmpty) {
      viewModel.fetchSchedules(widget.routeId, widget.date);
    }
  }

  @override
  void dispose() {
    _currentTimeRefreshTimer?.cancel();
    _scheduleScrollController.dispose();
    super.dispose();
  }

  GlobalKey _getScheduleRowKey(int scheduleId) {
    // 회차별 행 위치 추적용 키 재사용
    return _scheduleRowKeys.putIfAbsent(scheduleId, () => GlobalKey());
  }

  /// 스케줄 ID로 리스트 내 인덱스 조회
  int _getScheduleIndex(int scheduleId) {
    return viewModel.schedules.indexWhere((s) => s.id == scheduleId);
  }

  Alignment _resolveCollapseAlignment(int scheduleId) {
    // 화면 상/하단 위치에 따라 접히는 방향 계산
    final rowContext = _scheduleRowKeys[scheduleId]?.currentContext;
    if (rowContext == null) {
      return Alignment.topCenter;
    }

    final rowRenderObject = rowContext.findRenderObject();
    if (rowRenderObject is! RenderBox) {
      return Alignment.topCenter;
    }

    final rowTopY = rowRenderObject.localToGlobal(Offset.zero).dy;
    final rowCenterY = rowTopY + (rowRenderObject.size.height / 2);
    final screenCenterY = MediaQuery.of(context).size.height / 2;
    final isInLowerHalf = rowCenterY >= screenCenterY;

    // 하단 항목은 아래 고정, 상단 항목은 위 고정으로 접힘
    return isInLowerHalf ? Alignment.bottomCenter : Alignment.topCenter;
  }

  /// 펼쳐진 항목이 화면 밖이면 부드럽게 스크롤하여 보여주기
  void _ensureExpandedVisible(int scheduleId) {
    if (!mounted || !_scheduleScrollController.hasClients) return;
    if (_expandedScheduleId != scheduleId) return;

    final rowContext = _scheduleRowKeys[scheduleId]?.currentContext;
    if (rowContext == null) return;

    final rb = rowContext.findRenderObject() as RenderBox?;
    if (rb == null || !rb.attached) return;

    final position = _scheduleScrollController.position;
    final viewportHeight = position.viewportDimension;

    // 항목과 뷰포트의 화면 위치 계산
    final rowScreenTop = rb.localToGlobal(Offset.zero).dy;
    final rowHeight = rb.size.height;
    final rowScreenBottom = rowScreenTop + rowHeight;

    // 뷰포트의 화면 상 위치 계산 (AppBar 등 제외)
    final scrollRb =
        position.context.storageContext.findRenderObject() as RenderBox?;
    final viewportScreenTop = scrollRb?.localToGlobal(Offset.zero).dy ?? 0.0;
    final viewportScreenBottom = viewportScreenTop + viewportHeight;

    double scrollDelta = 0.0;

    // 항목 하단이 잘리면 아래로 스크롤
    if (rowScreenBottom > viewportScreenBottom) {
      scrollDelta = rowScreenBottom - viewportScreenBottom + 16.0;
    }

    // 항목 상단이 잘리면 위로 스크롤
    if (rowScreenTop + scrollDelta < viewportScreenTop) {
      scrollDelta = -(viewportScreenTop - rowScreenTop) - 8.0;
    }

    if (scrollDelta.abs() < 1.0) return;

    final targetOffset = (position.pixels + scrollDelta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    _scheduleScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onScheduleTap(Schedule schedule) async {
    HapticFeedback.lightImpact();
    final scheduleId = schedule.id;
    final previousExpandedId = _expandedScheduleId;

    // 같은 항목을 다시 탭하면 접기
    if (_expandedScheduleId == scheduleId) {
      final collapseAlignment = _resolveCollapseAlignment(scheduleId);
      setState(() {
        _rowSizeAlignments[scheduleId] = collapseAlignment;
        _expandedScheduleId = null;
        _highlightedScheduleId = null;
        _isInlineLoading = false;
      });
      return;
    }

    final hasCached = _inlineStopsCache.containsKey(scheduleId);
    final hasNoStops = _noStopsScheduleIds.contains(scheduleId);

    // 이전에 펼친 항목이 있으면 새 항목 위치에 맞춰 접히는 방향 계산
    Alignment previousCollapseAlignment = Alignment.topCenter;
    if (previousExpandedId != null && previousExpandedId != scheduleId) {
      final prevIndex = _getScheduleIndex(previousExpandedId);
      final newIndex = _getScheduleIndex(scheduleId);
      previousCollapseAlignment = (newIndex > prevIndex)
          ? Alignment.bottomCenter // 아래쪽 클릭 → 위 항목이 아래로 닫힘
          : Alignment.topCenter; // 위쪽 클릭 → 아래 항목이 위로 닫힘
    }

    // 펼침 애니메이션 후 튀는 현상 방지용 위치 기록
    double? tappedRowScreenY;
    final tappedRb = _scheduleRowKeys[scheduleId]
        ?.currentContext
        ?.findRenderObject() as RenderBox?;
    if (tappedRb != null && tappedRb.attached) {
      tappedRowScreenY = tappedRb.localToGlobal(Offset.zero).dy;
    }

    setState(() {
      if (previousExpandedId != null && previousExpandedId != scheduleId) {
        _rowSizeAlignments[previousExpandedId] = previousCollapseAlignment;
      }

      // 새로 펼칠 행은 위에서 아래로 열리도록 고정
      _rowSizeAlignments[scheduleId] = Alignment.topCenter;
      _expandedScheduleId = scheduleId;
      _highlightedScheduleId = scheduleId;
      _isInlineLoading = !hasCached && !hasNoStops;
    });

    // 1프레임 뒤 행 위치가 튀면 즉시 보정
    if (tappedRowScreenY != null && previousExpandedId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scheduleScrollController.hasClients) return;
        if (_expandedScheduleId != scheduleId) return;

        final rb = _scheduleRowKeys[scheduleId]
            ?.currentContext
            ?.findRenderObject() as RenderBox?;
        if (rb == null || !rb.attached) return;

        final currentScreenY = rb.localToGlobal(Offset.zero).dy;
        final drift = currentScreenY - tappedRowScreenY!;
        if (drift.abs() > 0.5) {
          final pos = _scheduleScrollController.position;
          _scheduleScrollController.jumpTo(
            (pos.pixels + drift)
                .clamp(pos.minScrollExtent, pos.maxScrollExtent),
          );
        }
      });
    }

    // 펼침 후 가려진 부분이 있으면 스크롤로 노출
    Future<void>.delayed(const Duration(milliseconds: 350)).then((_) {
      if (mounted && _expandedScheduleId == scheduleId) {
        _ensureExpandedVisible(scheduleId);
      }
    });

    if (hasCached || hasNoStops) {
      return;
    }

    final stops = await viewModel.fetchScheduleStopsForInline(scheduleId);
    if (!mounted) {
      return;
    }

    // 비동기 조회 중 다른 항목을 열었으면 결과 무시
    if (_expandedScheduleId != scheduleId) {
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

    // 인라인 목록이 생기면 한 번 더 가시 영역 보정
    Future<void>.delayed(const Duration(milliseconds: 280)).then((_) {
      if (mounted && _expandedScheduleId == scheduleId) {
        _ensureExpandedVisible(scheduleId);
      }
    });
  }

  Widget _buildScheduleTimeSection({
    required Widget startChild,
    required Widget endChild,
    Widget? indicator,
  }) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: startChild,
          ),
        ),
        const SizedBox(width: _timeToArrowSpacing),
        SizedBox(
          width: _timeIndicatorWidth,
          child: Center(child: indicator ?? const SizedBox.shrink()),
        ),
        const SizedBox(width: _arrowToEndTimeSpacing),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: endChild,
          ),
        ),
      ],
    );
  }

  bool _isViewingToday() {
    try {
      final viewedDate = DateFormat('yyyy-MM-dd').parse(widget.date);
      final now = DateTime.now();
      return viewedDate.year == now.year &&
          viewedDate.month == now.month &&
          viewedDate.day == now.day;
    } catch (_) {
      return false;
    }
  }

  int? _getEmphasizedScheduleId() {
    if (!_isViewingToday() || viewModel.schedules.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final futureSchedules = viewModel.schedules
        .where((schedule) => !schedule.startTime.isBefore(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (futureSchedules.isNotEmpty) {
      return futureSchedules.first.id;
    }

    return null;
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
            // 노선명, 운행 유형, 첫차/막차 요약
            _buildHeaderInfo(),
            const SizedBox(height: 20),
            // 회차별 시간표 목록
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
        ? shuttleColor.withValues(alpha: 0.2)
        : shuttleColor.withValues(alpha: 0.1);
    final primaryTextColor =
        brightness == Brightness.dark ? Colors.redAccent : shuttleColor;
    final secondaryTextColor = primaryTextColor.withValues(alpha: 0.78);

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
        const headerContentLeftInset = 30.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.directions_bus_rounded,
                  color: shuttleColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AutoScrollText(
                    text: widget.routeName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.1,
                      color: primaryTextColor,
                    ),
                    height: 28,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDateWithoutYear(widget.date),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: headerContentLeftInset),
              child: Text(
                typeText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: primaryTextColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: headerContentLeftInset),
              child: Text(
                '첫차 $firstBusTime  ·  막차 $lastBusTime',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
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
    // yyyy-MM-dd를 MM월 dd일로 축약
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
        ? shuttleColor.withValues(alpha: 0.2)
        : shuttleColor.withValues(alpha: 0.1);

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

  // 날짜 형식 변환
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
      () {
        final emphasizedScheduleId = _getEmphasizedScheduleId();

        // 로딩/빈 상태/목록 상태 전환
        return viewModel.isLoadingSchedules.value
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
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 표 헤더 행
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? Theme.of(context).cardColor.withValues(alpha: 0.5)
                                : Theme.of(context)
                                    .scaffoldBackgroundColor
                                    .withValues(alpha: 0.8),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(25),
                              topRight: Radius.circular(25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                flex: 1,
                                child: Text(
                                  '회차',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: _buildScheduleTimeSection(
                                  startChild: const Text(
                                    '출발 시간',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  endChild: const Text(
                                    '도착 시간',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: _endTimeFontSize,
                                    ),
                                  ),
                                ),
                              ),
                              const Expanded(
                                flex: 1,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '상세',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        Expanded(
                          child: Container(
                            child: ClipRect(
                              child: isIOS
                                  ? ListView.builder(
                                      controller: _scheduleScrollController,
                                      itemCount: viewModel.schedules.length,
                                      itemBuilder: (context, index) =>
                                          _buildScheduleItem(
                                        context,
                                        index,
                                        emphasizedScheduleId,
                                      ),
                                    )
                                  : Scrollbar(
                                      interactive: true,
                                      thumbVisibility: true,
                                      controller: _scheduleScrollController,
                                      child: ListView.builder(
                                        controller: _scheduleScrollController,
                                        itemCount: viewModel.schedules.length,
                                        itemBuilder: (context, index) =>
                                            _buildScheduleItem(
                                          context,
                                          index,
                                          emphasizedScheduleId,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
      },
    );
  }

  Widget _buildScheduleItem(
    BuildContext context,
    int index,
    int? emphasizedScheduleId,
  ) {
    final schedule = viewModel.schedules[index];
    final isExpanded = _expandedScheduleId == schedule.id;
    final isEmphasized = emphasizedScheduleId == schedule.id;
    final animatedSizeAlignment =
        _rowSizeAlignments[schedule.id] ?? Alignment.topCenter;
    final isHighlightActive = _highlightedScheduleId == schedule.id;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final expandedRowColor = isDarkMode
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
        : const Color(0xFFFFF1EF);
    final emphasizedTextColor = isEmphasized
        ? (isDarkMode ? Colors.redAccent : const Color(0xFFB83227))
        : null;
    final actionColor = isExpanded
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).hintColor;

    // 회차 행과 인라인 상세 영역을 함께 렌더링
    return Container(
      key: _getScheduleRowKey(schedule.id),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.3),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${schedule.round}',
                            style: TextStyle(color: emphasizedTextColor),
                          ),
                          if (isEmphasized) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.access_time_filled_rounded,
                              size: _nearestScheduleIconSize,
                              color: emphasizedTextColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: _buildScheduleTimeSection(
                        startChild: Text(
                          DateFormat('HH:mm').format(schedule.startTime),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: emphasizedTextColor,
                          ),
                        ),
                        indicator: Icon(
                          Icons.arrow_forward_rounded,
                          size: _timeIndicatorWidth,
                          color: Theme.of(context).hintColor,
                        ),
                        endChild: Text(
                          DateFormat('HH:mm').format(schedule.endTime),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: _endTimeFontSize,
                            color: emphasizedTextColor ??
                                Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.78),
                          ),
                        ),
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
            alignment: animatedSizeAlignment,
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
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
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
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
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
            color: Colors.grey.withValues(alpha: 0.25),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).cardColor.withValues(alpha: 0.6)
                : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
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
                      '도착 시간',
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
              color: Colors.grey.withValues(alpha: 0.2),
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
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.72)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.18 : 0.08),
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
