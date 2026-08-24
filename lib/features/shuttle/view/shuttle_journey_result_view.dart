import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';
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
  static const double _journeyCardExtent = 112;
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
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _isToday(_result.date)) setState(() {});
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
            _buildHeaderTransition(context),
            Expanded(
              child: _result.journeys.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _reload,
                      color: _shuttleColor,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [_buildEmptyState(context)],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final bottomPadding =
                            constraints.maxHeight > _journeyCardExtent
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
                              0,
                              16,
                              bottomPadding,
                            ),
                            itemCount: _result.journeys.length,
                            itemBuilder: (context, index) => _buildJourneyCard(
                              context,
                              _result.journeys[index],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTransition(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cardColor,
            cardColor.withValues(alpha: 0.75),
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
                        child: Text(
                          journey.routeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                  const SizedBox(height: 2),
                  Text(
                    '${journey.intermediateStopCount}개 정류장 경유',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _shortTime(journey.originArrivalTime),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(9, 0, 9, 2),
                        child: Icon(
                          Icons.arrow_forward,
                          color: _shuttleColor,
                          size: 19,
                        ),
                      ),
                      Text(
                        _shortTime(journey.destinationArrivalTime),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '(${journey.durationMinutes}분)',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
          TextButton(onPressed: _selectDate, child: const Text('다른 날짜 선택')),
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
      final target = _initialJourneyScrollOffset().clamp(
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
    final now = DateTime.now();
    final minimumDate = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 365));
    final maximumDate =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 365));
    DateTime? selected;
    if (Platform.isIOS) {
      var candidate = current;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (sheetContext) => Container(
          height: 300,
          color: Theme.of(context).cardColor,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    onPressed: () {
                      selected = candidate;
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('완료'),
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: current,
                    minimumDate: minimumDate,
                    maximumDate: maximumDate,
                    onDateTimeChanged: (date) => candidate = date,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      selected = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: minimumDate,
        lastDate: maximumDate,
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: _shuttleColor),
          ),
          child: child!,
        ),
      );
    }
    if (selected == null) return;
    _viewModel.selectDate(DateFormat('yyyy-MM-dd').format(selected!));
    await _reload();
  }
}
