import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';
import 'package:hsro/shared/widgets/ios_platform_fields.dart';
import 'package:intl/intl.dart';

class ShuttleJourneyResultView extends StatefulWidget {
  final ShuttleJourneySearchResult initialResult;

  const ShuttleJourneyResultView({
    super.key,
    required this.initialResult,
  });

  @override
  State<ShuttleJourneyResultView> createState() =>
      _ShuttleJourneyResultViewState();
}

class _ShuttleJourneyResultViewState extends State<ShuttleJourneyResultView> {
  static const Color _shuttleColor = Color(0xFFB83227);
  static const double _journeyCardExtent = 104;
  static const double _headerTransitionHeight = 32;
  final ShuttleViewModel _viewModel = Get.find<ShuttleViewModel>();
  late ShuttleJourneySearchResult _result;
  late final ScrollController _journeyScrollController;
  final Map<int, GlobalKey> _journeyCardKeys = <int, GlobalKey>{};
  final Map<int, List<ScheduleStop>> _scheduleStopsCache =
      <int, List<ScheduleStop>>{};
  final Set<int> _loadingScheduleIds = <int>{};
  final Set<int> _noScheduleStopIds = <int>{};
  int? _expandedScheduleId;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
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
    _journeyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '${_result.originStationName}  →  ${_result.destinationStationName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          Obx(
            () => IconButton(
              tooltip:
                  _viewModel.isSelectedJourneyFavorite ? '즐겨찾기 해제' : '즐겨찾기 저장',
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
                  _result.journeys.isEmpty
                      ? RefreshIndicator(
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
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final allJourneysCompleted =
                                _areAllJourneysCompletedToday;
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
                                itemCount: _result.journeys.length +
                                    (allJourneysCompleted ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _result.journeys.length) {
                                    return _buildAllJourneysEnded(context);
                                  }
                                  return _buildJourneyCard(
                                    context,
                                    _result.journeys[index],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child:
                        IgnorePointer(child: _buildHeaderTransition(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTransition(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
              const Spacer(),
              Text(
                '총 ${_result.journeys.length}회 운행',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Divider(height: 10),
          if (Platform.isIOS)
            _buildIOSDateSelector(context)
          else
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _selectDate,
              child: SizedBox(
                height: 28,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 7),
                    Text(
                      _formatDate(_result.date),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIOSDateSelector(BuildContext context) {
    final current = DateFormat('yyyy-MM-dd').parse(_result.date);
    final minimumDate = _minimumSelectableDate();
    final maximumDate = _maximumSelectableDate();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Icon(Icons.calendar_today, size: 16),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 136,
                child: IOSCompactDatePickerField(
                  key: ValueKey('journey_date_${_result.date}'),
                  initialDate: current,
                  minimumDate: minimumDate,
                  maximumDate: maximumDate,
                  onDateChanged: _applySelectedDate,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '(${weekdays[current.weekday - 1]})',
                style: const TextStyle(
                  color: _shuttleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyCard(
    BuildContext context,
    ShuttleJourney journey,
  ) {
    final nextScheduleId = _nextJourney()?.scheduleId;
    final departed = _hasDeparted(journey);
    final isNext = journey.scheduleId == nextScheduleId;
    final isExpanded = _expandedScheduleId == journey.scheduleId;
    final cardKey = _journeyCardKeys.putIfAbsent(
      journey.scheduleId,
      GlobalKey.new,
    );
    return KeyedSubtree(
      key: cardKey,
      child: Opacity(
        opacity: departed ? 0.45 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleJourneyExpansion(journey),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: _journeyCardExtent - 10,
              ),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: isNext
                    ? Border.all(color: _shuttleColor.withOpacity(0.35))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _shuttleColor,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  journey.routeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '·',
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${journey.intermediateStopCount}개 정류장 경유',
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isNext) _buildStatusChip('다음 셔틀', _shuttleColor),
                      if (departed) _buildStatusChip('운행 종료', Colors.grey),
                      const SizedBox(width: 2),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 19,
                        color: Theme.of(context).hintColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildJourneyTime(
                        context,
                        time: journey.originArrivalTime,
                        stationName: _result.originStationName,
                        fontSize: 22,
                      ),
                      const SizedBox(width: 9),
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: SizedBox(
                          height: 26,
                          child: Center(
                            child: Icon(
                              Icons.arrow_forward,
                              color: _shuttleColor,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _buildJourneyTime(
                          context,
                          time: journey.destinationArrivalTime,
                          stationName: _result.destinationStationName,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(width: 7),
                      SizedBox(
                        height: 26,
                        child: Center(
                          child: Text(
                            '(${journey.durationMinutes}분)',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isExpanded) _buildExpandedSchedule(context, journey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJourneyTime(
    BuildContext context, {
    required String time,
    required String stationName,
    required double fontSize,
  }) {
    final timeStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );
    final formattedTime = _shortTime(time);
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
          Text(
            formattedTime,
            maxLines: 1,
            softWrap: false,
            style: timeStyle,
          ),
          const SizedBox(height: 1),
          Text(
            stationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedSchedule(
    BuildContext context,
    ShuttleJourney journey,
  ) {
    final isLoading = _loadingScheduleIds.contains(journey.scheduleId);
    final stops = _scheduleStopsCache[journey.scheduleId];
    final hasNoStops = _noScheduleStopIds.contains(journey.scheduleId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 22),
        const Text(
          '전체 정류장 시간표',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            ),
          )
        else if (hasNoStops || stops == null || stops.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '정류장별 시간표가 없습니다.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          )
        else
          ...stops.map((stop) => _buildScheduleStopRow(context, stop)),
      ],
    );
  }

  Widget _buildScheduleStopRow(BuildContext context, ScheduleStop stop) {
    final isOrigin = stop.stationId == _result.originStationId ||
        _viewModel.logicalStationName(stop.stationName) ==
            _result.originStationName;
    final isDestination = stop.stationId == _result.destinationStationId ||
        _viewModel.logicalStationName(stop.stationName) ==
            _result.destinationStationName;
    final isJourneyStop = isOrigin || isDestination;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            isJourneyStop ? Icons.circle : Icons.circle_outlined,
            size: isJourneyStop ? 10 : 8,
            color: isJourneyStop ? _shuttleColor : Theme.of(context).hintColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stop.stationName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isJourneyStop ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            _shortTime(stop.arrivalTime),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isJourneyStop ? FontWeight.bold : FontWeight.w600,
              color: isJourneyStop ? _shuttleColor : null,
            ),
          ),
        ],
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
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
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
          const Text(
            '선택한 날짜에 운행하는 셔틀이 없습니다.',
            textAlign: TextAlign.center,
          ),
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
            TextButton(
              onPressed: _selectDate,
              child: const Text('다른 날짜 선택'),
            ),
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
          TextButton(
            onPressed: _searchNextDate,
            child: const Text('조회하기'),
          ),
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
    final index =
        _result.journeys.indexWhere((journey) => !_hasDeparted(journey));
    return index < 0 ? 0 : index;
  }

  double _initialJourneyScrollOffset() {
    return _nextJourneyIndex() * _journeyCardExtent;
  }

  void _scrollToNextJourney() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_journeyScrollController.hasClients) return;
      final target = (_areAllJourneysCompletedToday
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

  String _formatDate(String value) {
    final date = DateFormat('yyyy-MM-dd').parse(value);
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${DateFormat('yyyy년 MM월 dd일').format(date)} '
        '(${weekdays[date.weekday - 1]})';
  }

  Future<void> _reload() async {
    final result = await _viewModel.searchJourneys();
    if (result != null && mounted) {
      setState(() => _result = result);
      _scrollToNextJourney();
    }
  }

  Future<void> _selectDate() async {
    final current = DateFormat('yyyy-MM-dd').parse(_result.date);
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
    _viewModel.selectDate(DateFormat('yyyy-MM-dd').format(selected));
    await _reload();
  }

  Future<void> _searchNextDate() async {
    final current = DateFormat('yyyy-MM-dd').parse(_result.date);
    await _applySelectedDate(current.add(const Duration(days: 1)));
  }
}
