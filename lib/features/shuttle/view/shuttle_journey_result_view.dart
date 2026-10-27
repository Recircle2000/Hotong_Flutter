import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/view/naver_map_station_detail_view.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';
import 'package:hsro/shared/widgets/ios_platform_fields.dart';
import 'package:intl/intl.dart';
import 'package:hsro/core/services/link_share_service.dart';
import 'package:hsro/core/utils/transport_share_links.dart';
import 'package:hsro/shared/widgets/link_share_button.dart';
import 'package:hsro/shared/widgets/skeleton.dart';

class ShuttleJourneyResultView extends StatefulWidget {
  final ShuttleJourneySearchResult initialResult;

  const ShuttleJourneyResultView({super.key, required this.initialResult});

  @override
  State<ShuttleJourneyResultView> createState() =>
      _ShuttleJourneyResultViewState();
}

class _ShuttleJourneyResultViewState extends State<ShuttleJourneyResultView> {
  static const Color _shuttleColor = Color(0xFFB83227);
  static const double _journeyCardExtent = 104;
  static const double _headerTransitionHeight = 12;
  final ShuttleViewModel _viewModel = Get.find<ShuttleViewModel>();
  late ShuttleJourneySearchResult _result;
  // 날짜 표시는 고르는 즉시 바꾸고, 목록은 불러온 뒤 _result로 바꾼다.
  late String _displayDate;
  late final ScrollController _journeyScrollController;
  final Map<int, GlobalKey> _journeyCardKeys = <int, GlobalKey>{};
  final Map<int, List<ScheduleStop>> _scheduleStopsCache =
      <int, List<ScheduleStop>>{};
  final Set<int> _loadingScheduleIds = <int>{};
  final Set<int> _noScheduleStopIds = <int>{};
  int? _expandedScheduleId;
  Timer? _clockTimer;
  int _pendingReloads = 0;
  // 날짜를 바꿔 다시 불러오는 동안만 스켈레톤 카드를 보여준다.
  int _dateReloads = 0;
  bool _showSkeleton = false;
  Timer? _skeletonDelayTimer;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    _displayDate = _result.date;
    _journeyScrollController = ScrollController(
      initialScrollOffset: _initialJourneyScrollOffset(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNextJourney());
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !_isToday(_result.date)) return;
      setState(() {});
      if (_areAllJourneysCompletedToday) _scrollToNextJourney();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _skeletonDelayTimer?.cancel();
    _journeyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label:
              '${_result.originStationName}에서 '
              '${_result.destinationStationName}',
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: _result.originStationName),
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded, size: 16),
                  ),
                ),
                TextSpan(text: _result.destinationStationName),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        actions: [
          LinkShareButton(
            enabled: _pendingReloads == 0,
            content: () => LinkShareContent(
              title:
                  '${_result.originStationName} → '
                  '${_result.destinationStationName} 셔틀 시간표',
              uri: TransportShareLinks.shuttleJourney(
                originStationId: _result.originStationId,
                destinationStationId: _result.destinationStationId,
                date: _result.date,
              ),
            ),
          ),
          Obx(
            () => IconButton(
              tooltip: _viewModel.isSelectedJourneyFavorite
                  ? '즐겨찾기 해제'
                  : '즐겨찾기 저장',
              onPressed: _viewModel.toggleSelectedJourneyFavorite,
              icon: Icon(
                _viewModel.isSelectedJourneyFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: _viewModel.isSelectedJourneyFavorite
                    ? Colors.amber.shade700
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildJourneyHeader(context),
            Expanded(
              child: Stack(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _showSkeleton
                        ? _buildSkeletonList(context)
                        : KeyedSubtree(
                            key: ValueKey('journeys_${_result.date}'),
                            child: _buildJourneyList(context),
                          ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: _buildHeaderTransition(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyList(BuildContext context) {
    if (_result.journeys.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        color: _shuttleColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            _headerTransitionHeight,
            16,
            16,
          ),
          children: [_buildEmptyState(context)],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final allJourneysCompleted = _areAllJourneysCompletedToday;
        final bottomPadding = allJourneysCompleted
            ? 16.0
            : constraints.maxHeight > _journeyCardExtent
            ? constraints.maxHeight - _journeyCardExtent
            : 16.0;
        return RefreshIndicator(
          onRefresh: _reload,
          color: _shuttleColor,
          child: ListView.builder(
            controller: _journeyScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              _headerTransitionHeight,
              16,
              bottomPadding,
            ),
            itemCount: _result.journeys.length + (allJourneysCompleted ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _result.journeys.length) {
                return _buildAllJourneysEnded(context);
              }
              return _buildJourneyCard(context, _result.journeys[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildSkeletonList(BuildContext context) {
    return Semantics(
      key: const ValueKey('journeys_skeleton'),
      label: '시간표 불러오는 중',
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            _headerTransitionHeight,
            16,
            16,
          ),
          itemCount: 8,
          itemBuilder: (context, _) => _buildSkeletonCard(context),
        ),
      ),
    );
  }

  // 실제 시간 카드와 같은 크기·배치로 막대만 그려, 불러온 뒤 자리가 흔들리지 않게 한다.
  Widget _buildSkeletonCard(BuildContext context) {
    return Container(
      height: _journeyCardExtent - 10,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const SkeletonShimmer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 76, height: 20),
            SizedBox(height: 7),
            Row(
              children: [
                SkeletonBox(width: 72, height: 26),
                SizedBox(width: 30),
                SkeletonBox(width: 72, height: 26),
                SizedBox(width: 8),
                SkeletonBox(width: 30, height: 14),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                SkeletonBox(width: 58, height: 12, radius: 4),
                SizedBox(width: 44),
                SkeletonBox(width: 58, height: 12, radius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTransition(BuildContext context) {
    final cardColor = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      height: _headerTransitionHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cardColor,
            cardColor.withValues(alpha: 0.8),
            cardColor.withValues(alpha: 0.25),
            cardColor.withValues(alpha: 0),
          ],
          stops: const [0, 0.25, 0.75, 1],
        ),
      ),
    );
  }

  Widget _buildJourneyHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Platform.isIOS
                  ? _buildIOSDateSelector(context)
                  : _buildAndroidDateSelector(context),
            ),
          ),
          const SizedBox(width: 8),
          if (_showSkeleton)
            const SkeletonShimmer(
              child: Row(
                children: [
                  SkeletonBox(width: 92, height: 16, radius: 4),
                  SizedBox(width: 8),
                  SkeletonBox(width: 42, height: 16, radius: 4),
                ],
              ),
            )
          else ...[
            // 운행 유형 표시는 기존 모양 그대로 둔다.
            const Icon(Icons.schedule, color: _shuttleColor, size: 16),
            const SizedBox(width: 6),
            Text(
              _result.scheduleTypeName,
              style: const TextStyle(
                color: _shuttleColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '총 ${_result.journeys.length}회',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAndroidDateSelector(BuildContext context) {
    final date = DateFormat('yyyy-MM-dd').parse(_displayDate);
    final hintColor = Theme.of(context).hintColor;
    return Semantics(
      button: true,
      label: '탑승일 ${_formatDate(_displayDate)}, 날짜 변경',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _selectDate,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined, size: 18, color: hintColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: DateFormat('M월 d일 ').format(date),
                      children: [
                        TextSpan(
                          text: '(${_weekday(date)})',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: hintColor,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more_rounded, size: 18, color: hintColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIOSDateSelector(BuildContext context) {
    final current = DateFormat('yyyy-MM-dd').parse(_displayDate);
    final hintColor = Theme.of(context).hintColor;
    const dateStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    // 네이티브 라벨은 가운데 정렬이라, 날짜 글자 폭에 맞춰야 요일과 붙어 보인다.
    final datePainter = TextPainter(
      text: TextSpan(
        text: DateFormat('M월 d일').format(current),
        style: dateStyle,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final dateWidth = datePainter.width.ceilToDouble() + 4;
    datePainter.dispose();

    return SizedBox(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 6),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: hintColor,
            ),
          ),
          SizedBox(
            width: dateWidth,
            child: IOSCompactDatePickerField(
              key: ValueKey('journey_date_${_displayDate}'),
              initialDate: current,
              minimumDate: _minimumSelectableDate(),
              maximumDate: _maximumSelectableDate(),
              onDateChanged: _applySelectedDate,
              displayFormat: 'M월 d일',
              fontSize: dateStyle.fontSize,
              bold: true,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${_weekday(current)})',
            style: TextStyle(
              color: hintColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 18, color: hintColor),
        ],
      ),
    );
  }

  Widget _buildJourneyCard(BuildContext context, ShuttleJourney journey) {
    final nextScheduleId = _nextJourney()?.scheduleId;
    final departed = _hasDeparted(journey);
    final isNext = journey.scheduleId == nextScheduleId;
    final isExpanded = _expandedScheduleId == journey.scheduleId;
    final hintColor = Theme.of(context).hintColor;
    final cardKey = _journeyCardKeys.putIfAbsent(
      journey.scheduleId,
      GlobalKey.new,
    );
    return KeyedSubtree(
      key: cardKey,
      child: Opacity(
        opacity: departed ? 0.45 : 1,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: isNext
                  ? Border.all(color: _shuttleColor.withValues(alpha: 0.35))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  button: true,
                  expanded: isExpanded,
                  label:
                      '${journey.routeName} 노선, '
                      '${_spokenTime(journey.originArrivalTime)} '
                      '${_result.originStationName} 출발, '
                      '${_spokenTime(journey.destinationArrivalTime)} '
                      '${_result.destinationStationName} 도착, '
                      '${journey.durationMinutes}분 소요'
                      '${isNext ? ', 다음 셔틀' : ''}'
                      '${departed ? ', 운행 종료' : ''}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleJourneyExpansion(journey),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: _journeyCardExtent - 10,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: _buildRouteBadge(journey),
                                      ),
                                      if (isNext)
                                        _buildStatusChip(
                                          '다음 셔틀',
                                          _shuttleColor,
                                        ),
                                      if (departed)
                                        _buildStatusChip('운행 종료', Colors.grey),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  size: 20,
                                  color: hintColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildJourneyTime(
                                  context,
                                  time: journey.originArrivalTime,
                                  stationName: _result.originStationName,
                                ),
                                const SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: Center(
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      color: _shuttleColor,
                                      size: 17,
                                    ),
                                  ),
                                ),
                                _buildJourneyTime(
                                  context,
                                  time: journey.destinationArrivalTime,
                                  stationName: _result.destinationStationName,
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 30,
                                  child: Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        '${journey.durationMinutes}분',
                                        style: TextStyle(
                                          color: hintColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (isExpanded) _buildExpandedSchedule(context, journey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 순환 노선(KTX 순환 등)은 테두리 배지로 구분해, 같은 정류장에 노선이 섞여도
  // 한눈에 알아보게 한다.
  Widget _buildRouteBadge(ShuttleJourney journey) {
    final isLoop = journey.routeName.contains('순환');
    final loopColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF7FA6FF)
        : const Color(0xFF1D4ED8);
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: EdgeInsets.symmetric(
        horizontal: isLoop ? 6 : 7,
        vertical: isLoop ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: isLoop ? Theme.of(context).cardColor : _shuttleColor,
        borderRadius: BorderRadius.circular(6),
        border: isLoop ? Border.all(color: loopColor, width: 1.5) : null,
      ),
      child: Text(
        journey.routeName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isLoop ? loopColor : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildJourneyTime(
    BuildContext context, {
    required String time,
    required String stationName,
  }) {
    const timeStyle = TextStyle(
      fontSize: 26,
      height: 1.15,
      fontWeight: FontWeight.w800,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    final formattedTime = _shortTime(time);
    // 정류장 이름이 길어도 시각 폭을 넘지 않도록 시각 너비에 맞춘다.
    final timePainter = TextPainter(
      text: TextSpan(text: formattedTime, style: timeStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final timeWidth = timePainter.width.ceilToDouble() + 1;
    timePainter.dispose();

    return SizedBox(
      width: timeWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formattedTime, maxLines: 1, softWrap: false, style: timeStyle),
          Text(
            stationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedSchedule(BuildContext context, ShuttleJourney journey) {
    final isLoading = _loadingScheduleIds.contains(journey.scheduleId);
    final stops = _scheduleStopsCache[journey.scheduleId];
    final hasNoStops = _noScheduleStopIds.contains(journey.scheduleId);

    Widget body;
    if (isLoading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      );
    } else if (hasNoStops || stops == null || stops.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          '정류장별 시간표가 없습니다.',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    } else {
      final (originIndex, destinationIndex) = _journeyStopIndexes(
        journey,
        stops,
      );
      body = Column(
        children: [
          for (var index = 0; index < stops.length; index++)
            _buildScheduleStopRow(
              context,
              stops[index],
              index: index,
              lastIndex: stops.length - 1,
              originIndex: originIndex,
              destinationIndex: destinationIndex,
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 12, 12), child: body),
      ],
    );
  }

  // 정류장 목록에서 이번 여정의 승차·하차 위치를 찾는다. 같은 정류장을 두 번
  // 지나는 노선이 있어 순번을 먼저 보고, 순번이 없으면 이름으로 찾는다.
  (int, int) _journeyStopIndexes(
    ShuttleJourney journey,
    List<ScheduleStop> stops,
  ) {
    var originIndex = stops.indexWhere(
      (stop) => stop.stopOrder == journey.originStopOrder,
    );
    var destinationIndex = stops.indexWhere(
      (stop) => stop.stopOrder == journey.destinationStopOrder,
    );
    if (originIndex < 0) {
      originIndex = stops.indexWhere(
        (stop) =>
            stop.stationId == _result.originStationId ||
            _viewModel.logicalStationName(stop.stationName) ==
                _result.originStationName,
      );
    }
    if (destinationIndex < 0) {
      destinationIndex = stops.lastIndexWhere(
        (stop) =>
            stop.stationId == _result.destinationStationId ||
            _viewModel.logicalStationName(stop.stationName) ==
                _result.destinationStationName,
      );
    }
    return (originIndex, destinationIndex);
  }

  Widget _buildScheduleStopRow(
    BuildContext context,
    ScheduleStop stop, {
    required int index,
    required int lastIndex,
    required int originIndex,
    required int destinationIndex,
  }) {
    final isOrigin = index == originIndex;
    final isDestination = index == destinationIndex;
    final isJourneyStop = isOrigin || isDestination;
    final isTerminal = index == lastIndex && !isJourneyStop;
    final onRide = originIndex >= 0 && destinationIndex > originIndex;
    final hintColor = Theme.of(context).hintColor;
    final mutedLine = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    // 승차~하차 구간의 선만 셔틀 색으로 칠한다.
    final topLineColor = index == 0
        ? null
        : (onRide && index > originIndex && index <= destinationIndex
              ? _shuttleColor
              : mutedLine);
    final bottomLineColor = index == lastIndex
        ? null
        : (onRide && index >= originIndex && index < destinationIndex
              ? _shuttleColor
              : mutedLine);
    final stationId = stop.stationId;
    final time = _shortTime(stop.arrivalTime);
    final role = isOrigin
        ? '승차'
        : isDestination
        ? '하차'
        : isTerminal
        ? '종점'
        : null;

    // 정류장을 누르면 정류장 정보(지도·사진) 화면으로 이동
    return Semantics(
      button: stationId != null,
      label:
          '${stop.stationName}${role == null ? '' : ', $role'}, '
          '${_spokenTime(stop.arrivalTime)}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: stationId == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                Get.to(() => NaverMapStationDetailView(stationId: stationId));
              },
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              SizedBox(
                width: 12,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 2,
                        color: topLineColor ?? Colors.transparent,
                      ),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isJourneyStop
                            ? _shuttleColor
                            : Theme.of(context).cardColor,
                        border: isJourneyStop
                            ? null
                            : Border.all(
                                color: hintColor.withValues(alpha: 0.5),
                                width: 2,
                              ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: bottomLineColor ?? Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        stop.stationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isJourneyStop ? 16 : 15,
                          fontWeight: isJourneyStop
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isJourneyStop ? null : hintColor,
                        ),
                      ),
                    ),
                    if (role != null) ...[
                      const SizedBox(width: 6),
                      _buildStopRoleChip(
                        context,
                        role,
                        emphasized: !isTerminal,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: TextStyle(
                  fontSize: isJourneyStop ? 16 : 15,
                  fontWeight: isJourneyStop ? FontWeight.w800 : FontWeight.w700,
                  color: isJourneyStop ? _shuttleColor : hintColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(
                width: 20,
                child: stationId == null
                    ? null
                    : Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: hintColor.withValues(alpha: 0.6),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopRoleChip(
    BuildContext context,
    String label, {
    required bool emphasized,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: emphasized
            ? _shuttleColor.withValues(alpha: isDark ? 0.25 : 0.1)
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: emphasized
              ? (isDark ? Colors.redAccent : _shuttleColor)
              : Theme.of(context).hintColor,
        ),
      ),
    );
  }

  Future<void> _toggleJourneyExpansion(ShuttleJourney journey) async {
    final scheduleId = journey.scheduleId;
    if (_expandedScheduleId == scheduleId) {
      setState(() => _expandedScheduleId = null);
      return;
    }

    setState(() => _expandedScheduleId = scheduleId);
    _ensureExpandedCardVisible(scheduleId);
    if (_scheduleStopsCache.containsKey(scheduleId) ||
        _noScheduleStopIds.contains(scheduleId) ||
        _loadingScheduleIds.contains(scheduleId)) {
      return;
    }

    setState(() => _loadingScheduleIds.add(scheduleId));
    final stops = await _viewModel.fetchScheduleStopsForInline(scheduleId);
    if (!mounted) return;
    setState(() {
      _loadingScheduleIds.remove(scheduleId);
      if (stops == null || stops.isEmpty) {
        _noScheduleStopIds.add(scheduleId);
      } else {
        _scheduleStopsCache[scheduleId] = stops;
      }
    });
    _ensureExpandedCardVisible(scheduleId);
  }

  void _ensureExpandedCardVisible(int scheduleId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _expandedScheduleId != scheduleId) return;
      final cardContext = _journeyCardKeys[scheduleId]?.currentContext;
      if (cardContext == null) return;
      Scrollable.ensureVisible(
        cardContext,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 44, color: Theme.of(context).hintColor),
          const SizedBox(height: 12),
          const Text('선택한 날짜에 운행하는 셔틀이 없습니다.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (Platform.isIOS)
            Text(
              '상단에서 다른 날짜를 선택해주세요.',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            )
          else
            TextButton(onPressed: _selectDate, child: const Text('다른 날짜 선택')),
        ],
      ),
    );
  }

  Widget _buildAllJourneysEnded(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        children: [
          Text(
            '오늘은 모든 셔틀의 운행이 종료되었어요.\n다음 날짜를 조회할까요?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: _searchNextDate, child: const Text('조회하기')),
        ],
      ),
    );
  }

  ShuttleJourney? _nextJourney() {
    if (!_isToday(_result.date)) return null;
    for (final journey in _result.journeys) {
      if (!_hasDeparted(journey)) return journey;
    }
    return null;
  }

  bool get _areAllJourneysCompletedToday =>
      _isToday(_result.date) &&
      _result.journeys.isNotEmpty &&
      _result.journeys.every(_hasDeparted);

  int _nextJourneyIndex() {
    if (!_isToday(_result.date)) return 0;
    final index = _result.journeys.indexWhere(
      (journey) => !_hasDeparted(journey),
    );
    return index < 0 ? 0 : index;
  }

  double _initialJourneyScrollOffset() {
    return _nextJourneyIndex() * _journeyCardExtent;
  }

  void _scrollToNextJourney() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_journeyScrollController.hasClients) return;
      final target =
          (_areAllJourneysCompletedToday
                  ? _journeyScrollController.position.maxScrollExtent
                  : _initialJourneyScrollOffset())
              .clamp(
                _journeyScrollController.position.minScrollExtent,
                _journeyScrollController.position.maxScrollExtent,
              );
      _journeyScrollController.jumpTo(target);
    });
  }

  bool _hasDeparted(ShuttleJourney journey) {
    if (!_isToday(_result.date)) return false;
    final now = DateTime.now();
    final parts = journey.originArrivalTime.split(':');
    final departure = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
      parts.length > 2 ? int.parse(parts[2].split('.').first) : 0,
    );
    return !departure.isAfter(now);
  }

  bool _isToday(String date) {
    final parsed = DateFormat('yyyy-MM-dd').parse(date);
    final now = DateTime.now();
    return parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
  }

  String _shortTime(String value) {
    final parts = value.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : value;
  }

  String _weekday(DateTime date) =>
      const ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1];

  // 화면 읽기 프로그램이 "09:15"를 시각으로 읽도록 바꾼다.
  String _spokenTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return value;
    return '${int.tryParse(parts[0]) ?? parts[0]}시 '
        '${int.tryParse(parts[1]) ?? parts[1]}분';
  }

  String _formatDate(String value) {
    final date = DateFormat('yyyy-MM-dd').parse(value);
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${DateFormat('yyyy년 MM월 dd일').format(date)} '
        '(${weekdays[date.weekday - 1]})';
  }

  // [showSkeleton]은 날짜를 바꿀 때만 켠다. 당겨서 새로고침은 기존 표시만 쓴다.
  Future<void> _reload({bool showSkeleton = false}) async {
    setState(() {
      _pendingReloads++;
      if (showSkeleton) _dateReloads++;
    });
    if (showSkeleton) {
      // 응답이 아주 빠르면 스켈레톤이 깜빡이기만 하므로 잠시 기다렸다 띄운다.
      _skeletonDelayTimer?.cancel();
      _skeletonDelayTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted && _dateReloads > 0) setState(() => _showSkeleton = true);
      });
    }
    try {
      final result = await _viewModel.searchJourneys();
      if (result != null && mounted) {
        setState(() => _result = result);
        _scrollToNextJourney();
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingReloads--;
          if (showSkeleton) _dateReloads--;
          if (_dateReloads == 0) {
            _skeletonDelayTimer?.cancel();
            _showSkeleton = false;
            // 불러오지 못했으면 날짜 표시도 지금 보이는 목록의 날짜로 되돌린다.
            _displayDate = _result.date;
          }
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final current = DateFormat('yyyy-MM-dd').parse(_displayDate);
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: _minimumSelectableDate(),
      lastDate: _maximumSelectableDate(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _shuttleColor),
        ),
        child: child!,
      ),
    );
    if (selected == null) return;
    await _applySelectedDate(selected);
  }

  DateTime _minimumSelectableDate() {
    final date = DateTime.now().subtract(const Duration(days: 365));
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _maximumSelectableDate() {
    final date = DateTime.now().add(const Duration(days: 365));
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _applySelectedDate(DateTime selected) async {
    final date = DateFormat('yyyy-MM-dd').format(selected);
    setState(() => _displayDate = date);
    _viewModel.selectDate(date);
    await _reload(showSkeleton: true);
  }

  Future<void> _searchNextDate() async {
    final current = DateFormat('yyyy-MM-dd').parse(_displayDate);
    await _applySelectedDate(current.add(const Duration(days: 1)));
  }
}
