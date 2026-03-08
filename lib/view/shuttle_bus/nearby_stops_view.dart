import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import '../../viewmodel/nearby_stops_viewmodel.dart';
import 'shuttle_route_detail_view.dart'; // 노선 상세 정보 화면 임포트
import 'naver_map_station_detail_view.dart'; // 네이버 지도 정류장 상세 정보 화면 임포트
import '../components/scale_button.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class NearbyStopsView extends StatefulWidget {
  final bool startExperienceTour;

  const NearbyStopsView({
    super.key,
    this.startExperienceTour = false,
  });

  @override
  State<NearbyStopsView> createState() => _NearbyStopsViewState();
}

class _NearbyStopsViewState extends State<NearbyStopsView> {
  // 셔틀버스 색상 - 홈 화면과 동일하게 맞춤
  final Color shuttleColor = Color(0xFFB83227);
  final NearbyStopsViewModel viewModel = Get.put(NearbyStopsViewModel());
  Worker? _uiMessageWorker;
  final GlobalKey _stationSelectorKey = GlobalKey();
  final GlobalKey _scheduleTableKey = GlobalKey();
  bool _isExperienceTourRunning = false;

  @override
  void initState() {
    super.initState();
    _uiMessageWorker =
        ever<NearbyStopsUiMessage?>(viewModel.uiMessage, (message) {
      if (!mounted || message == null) return;
      Get.snackbar(
        message.title,
        message.message,
        snackPosition: SnackPosition.BOTTOM,
      );
      viewModel.clearUiMessage();
    });

    if (widget.startExperienceTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startExperienceTour();
      });
    }
  }

  @override
  void dispose() {
    _uiMessageWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('내 주변 정류장 찾기'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationHeader(context),
              SizedBox(height: 16),
              Container(
                key: _stationSelectorKey,
                child: _buildStationSelector(context),
              ),
              SizedBox(height: 16),
              _buildDateSelector(context),
              SizedBox(height: 8),
              _buildScheduleHeader(context),
              SizedBox(height: 8),
              Expanded(
                child: Container(
                  key: _scheduleTableKey,
                  child: _buildScheduleTable(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startExperienceTour() async {
    if (!mounted || _isExperienceTourRunning) return;
    _isExperienceTourRunning = true;
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'nearby_station_selector',
          keyTarget: _stationSelectorKey,
          shape: ShapeLightFocus.RRect,
          radius: 14,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildExperienceContent(
                controller: controller,
                title: '정류장 선택',
                description: '내 위치 기준 가까운 정류장을 우선으로 선택할 수 있습니다.',
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'nearby_schedule_table',
          keyTarget: _scheduleTableKey,
          shape: ShapeLightFocus.RRect,
          radius: 14,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) => _buildExperienceContent(
                controller: controller,
                title: '시간표 확인',
                description: '선택한 정류장의 도착 시간을 표 형태로 빠르게 확인합니다.',
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
      onFinish: () => _completeExperienceTour(shouldContinue: true),
      onSkip: () {
        _completeExperienceTour(shouldContinue: false);
        return true;
      },
      onClickOverlay: (target) {},
    ).show(context: context);
  }

  void _completeExperienceTour({required bool shouldContinue}) {
    _isExperienceTourRunning = false;
    if (widget.startExperienceTour && mounted) {
      Get.back(result: shouldContinue);
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
                onPressed: () => controller.next(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(isLast ? '시내버스 이동' : '다음'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationHeader(BuildContext context) {
    return Obx(() {
      final isLoading = viewModel.isLoadingLocation.value;
      final hasLocation = viewModel.currentPosition.value != null;

      return Container(
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
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          width: double.infinity,
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.green.shade700,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '내 위치에서 가까운 정류장',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              if (isLoading)
                Container(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              else if (!hasLocation)
                _buildCompactLocationButton(context)
              else
                InkWell(
                  onTap: () => viewModel.getCurrentLocation(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 14,
                        color: Colors.green.shade700,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '위치 새로고침',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCompactLocationButton(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 0,
        child: Text(
          '위치 확인',
          style: TextStyle(
            fontSize: 12,
            color: Colors.green.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () => viewModel.getCurrentLocation(),
      );
    } else {
      return TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          '위치 확인',
          style: TextStyle(
            fontSize: 12,
            color: Colors.green.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () => viewModel.getCurrentLocation(),
      );
    }
  }

  Widget _buildStationSelector(BuildContext context) {
    return Obx(() {
      final isLoading = viewModel.isLoadingStations.value;
      final hasLocation = viewModel.currentPosition.value != null;
      final stations =
          hasLocation ? viewModel.sortedStations : viewModel.stations;

      if (isLoading) {
        return Center(
          child: CircularProgressIndicator.adaptive(),
        );
      }

      if (stations.isEmpty) {
        return Center(
          child: Text('정류장 정보를 불러올 수 없습니다.'),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '정류장 선택',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hasLocation)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    '(자동 정렬됨)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              // border: Border.all(color: Colors.grey.shade300),
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
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: viewModel.selectedStationId.value != -1
                    ? viewModel.selectedStationId.value
                    : stations.first.id,
                isExpanded: true,
                padding: EdgeInsets.symmetric(horizontal: 12),
                borderRadius: BorderRadius.circular(8),
                items: stations.map((station) {
                  final hasDistance =
                      hasLocation && viewModel.currentPosition.value != null;
                  final distance = hasDistance
                      ? viewModel.getDistanceToStation(station)
                      : null;

                  return DropdownMenuItem<int>(
                    value: station.id,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            station.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasDistance)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.shade100),
                            ),
                            child: Text(
                              distance!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    viewModel.fetchStationSchedules(value);
                  }
                },
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildDateSelector(BuildContext context) {
    if (Platform.isIOS) {
      return _buildIOSDateSelector(context);
    } else {
      return _buildAndroidDateSelector(context);
    }
  }

  Widget _buildIOSDateSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '운행 날짜 선택',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        _buildDateSelectorWithArrows(
          context,
          onTapDatePicker: () => _showIOSDatePicker(context),
        ),
      ],
    );
  }

  void _showIOSDatePicker(BuildContext context) {
    DateTime selectedDate =
        _clampDateToSelectableRange(_getSelectedDateOrToday());
    final minimumDate = _getMinimumSelectableDate();
    final maximumDate = _getMaximumSelectableDate();

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              height: 50,
              color: CupertinoColors.systemGrey5.resolveFrom(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Text('취소'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    child: Text('확인'),
                    onPressed: () {
                      final formattedDate =
                          DateFormat('yyyy-MM-dd').format(selectedDate);
                      viewModel.selectDate(formattedDate);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                minimumDate: minimumDate,
                maximumDate: maximumDate,
                onDateTimeChanged: (DateTime date) {
                  selectedDate = date;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidDateSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '운행 날짜 선택',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        _buildDateSelectorWithArrows(
          context,
          onTapDatePicker: () => _showAndroidDatePicker(context),
        ),
      ],
    );
  }

  Widget _buildDateSelectorWithArrows(
    BuildContext context, {
    required VoidCallback onTapDatePicker,
  }) {
    return Obx(() {
      final selectedDate = _getSelectedDateOrToday();
      final minimumDate = _getMinimumSelectableDate();
      final maximumDate = _getMaximumSelectableDate();
      final canMovePrevious = selectedDate.isAfter(minimumDate);
      final canMoveNext = selectedDate.isBefore(maximumDate);
      final hasSelectedDate = viewModel.selectedDate.value.isNotEmpty;

      return Row(
        children: [
          _buildDateArrowButton(
            context: context,
            icon: Icons.chevron_left,
            enabled: canMovePrevious,
            onTap: () => _moveSelectedDateBy(-1),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ScaleButton(
              onTap: onTapDatePicker,
              child: Container(
                height: 50,
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
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getSelectedDateLabel(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasSelectedDate
                              ? null
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    Icon(Icons.calendar_today,
                        color: Theme.of(context).hintColor),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          _buildDateArrowButton(
            context: context,
            icon: Icons.chevron_right,
            enabled: canMoveNext,
            onTap: () => _moveSelectedDateBy(1),
          ),
        ],
      );
    });
  }

  Widget _buildDateArrowButton({
    required BuildContext context,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: ScaleButton(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: enabled
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? Colors.redAccent
                      : shuttleColor)
                  : Theme.of(context).disabledColor,
            ),
          ),
        ),
      ),
    );
  }

  String _getSelectedDateLabel() {
    if (viewModel.selectedDate.value.isEmpty) {
      return '운행 날짜를 선택하세요';
    }
    return _formatDate(viewModel.selectedDate.value);
  }

  DateTime _getSelectedDateOrToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (viewModel.selectedDate.value.isEmpty) {
      return today;
    }

    try {
      final selectedDate =
          DateFormat('yyyy-MM-dd').parse(viewModel.selectedDate.value);
      return DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    } catch (e) {
      return today;
    }
  }

  DateTime _getMinimumSelectableDate() {
    final minimumDate = DateTime.now().subtract(Duration(days: 365));
    return DateTime(minimumDate.year, minimumDate.month, minimumDate.day);
  }

  DateTime _getMaximumSelectableDate() {
    final maximumDate = DateTime.now().add(Duration(days: 365));
    return DateTime(maximumDate.year, maximumDate.month, maximumDate.day);
  }

  DateTime _clampDateToSelectableRange(DateTime date) {
    final minimumDate = _getMinimumSelectableDate();
    final maximumDate = _getMaximumSelectableDate();

    if (date.isBefore(minimumDate)) {
      return minimumDate;
    }
    if (date.isAfter(maximumDate)) {
      return maximumDate;
    }
    return date;
  }

  void _moveSelectedDateBy(int dayOffset) {
    final currentDate = _getSelectedDateOrToday();
    final nextDate = currentDate.add(Duration(days: dayOffset));
    final minimumDate = _getMinimumSelectableDate();
    final maximumDate = _getMaximumSelectableDate();

    if (nextDate.isBefore(minimumDate) || nextDate.isAfter(maximumDate)) {
      return;
    }

    viewModel.selectDate(DateFormat('yyyy-MM-dd').format(nextDate));
  }

  Future<void> _showAndroidDatePicker(BuildContext context) async {
    DateTime selectedDate =
        _clampDateToSelectableRange(_getSelectedDateOrToday());
    final firstDate = _getMinimumSelectableDate();
    final lastDate = _getMaximumSelectableDate();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: shuttleColor, // 셔틀버스 테마 색상
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      viewModel.selectDate(formattedDate);
    }
  }

  String _getDayOfWeekString(DateTime date) {
    final dayOfWeek = date.weekday;
    switch (dayOfWeek) {
      case 1:
        return '월';
      case 2:
        return '화';
      case 3:
        return '수';
      case 4:
        return '목';
      case 5:
        return '금';
      case 6:
        return '토';
      case 7:
        return '일';
      default:
        return '';
    }
  }

  Widget _buildScheduleHeader(BuildContext context) {
    return Obx(() {
      final selectedId = viewModel.selectedStationId.value;
      final stationName =
          selectedId != -1 ? viewModel.getStationName(selectedId) : '';
      final scheduleTypeName = viewModel.scheduleTypeName.value.isNotEmpty
          ? viewModel.scheduleTypeName.value
          : viewModel.scheduleTypeNames[viewModel.selectedScheduleType.value] ??
              '전체';

      return Row(
        children: [
          Icon(
            Icons.schedule,
            color: shuttleColor,
            size: 22,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '$scheduleTypeName',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: shuttleColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (stationName.isNotEmpty)
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Get.to(() => NaverMapStationDetailView(stationId: selectedId));
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      stationName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Platform.isIOS
                        ? CupertinoIcons.info_circle_fill
                        : Icons.info_outline,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _buildScheduleTable(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final headerBgColor = brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade200;

    return Obx(() {
      if (viewModel.isLoadingSchedules.value) {
        return Center(
          child: CircularProgressIndicator.adaptive(),
        );
      }

      if (viewModel.filteredSchedules.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 16),
              Text(
                '선택한 정류장의 ${viewModel.scheduleTypeName.value.isNotEmpty ? viewModel.scheduleTypeName.value : viewModel.scheduleTypeNames[viewModel.selectedScheduleType.value]} 시간표가 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              if (viewModel.selectedDate.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '날짜: ${_formatDate(viewModel.selectedDate.value)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  // 다른 날짜 선택 다이얼로그 열기
                  if (Platform.isIOS) {
                    _showIOSDatePicker(context);
                  } else {
                    _showAndroidDatePicker(context);
                  }
                },
                child: Text('다른 날짜 선택하기'),
              ),
            ],
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          // border: Border.all(color: Colors.grey.shade300),
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
            // 테이블 헤더
            Container(
              decoration: BoxDecoration(
                color: headerBgColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text('번호',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text('노선',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('도착 시간',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // 테이블 내용
            Expanded(
              child: Platform.isIOS
                  ? _buildIosScheduleList()
                  : _buildAndroidScheduleList(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildIosScheduleList() {
    return ListView.separated(
      itemCount: viewModel.filteredSchedules.length,
      separatorBuilder: (context, index) => Divider(height: 1),
      itemBuilder: (context, index) {
        final schedule = viewModel.filteredSchedules[index];
        final routeName = viewModel.getRouteName(schedule.routeId);

        return InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            // 스케줄 항목 클릭 시 노선 상세 화면으로 이동
            Get.to(() => ShuttleRouteDetailView(
                  scheduleId: schedule.scheduleId,
                  routeName: routeName,
                  round: 0, // 회차 정보가 없으므로 0으로 설정
                  startTime: _formatTime(schedule.arrivalTime),
                ));
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text('${index + 1}'),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    routeName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(schedule.arrivalTime),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: shuttleColor,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAndroidScheduleList() {
    return Scrollbar(
      interactive: true,
      thumbVisibility: true,
      child: ListView.separated(
        itemCount: viewModel.filteredSchedules.length,
        separatorBuilder: (context, index) => Divider(height: 1),
        itemBuilder: (context, index) {
          final schedule = viewModel.filteredSchedules[index];
          final routeName = viewModel.getRouteName(schedule.routeId);

          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              // 스케줄 항목 클릭 시 노선 상세 화면으로 이동
              Get.to(() => ShuttleRouteDetailView(
                    scheduleId: schedule.scheduleId,
                    routeName: routeName,
                    round: 0, // 회차 정보가 없으므로 0으로 설정
                    startTime: _formatTime(schedule.arrivalTime),
                  ));
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text('${index + 1}'),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      routeName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(schedule.arrivalTime),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: shuttleColor,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // "HH:MM:SS" 형식의 시간을 "HH:MM" 형식으로 변환
  String _formatTime(String timeString) {
    if (timeString.length >= 5) {
      return timeString.substring(0, 5);
    }
    return timeString;
  }

  // 날짜 형식 변환 (YYYY-MM-DD -> YYYY년 MM월 DD일)
  String _formatDate(String dateStr) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return '${DateFormat('yyyy년 MM월 dd일').format(date)} (${_getDayOfWeekString(date)})';
    } catch (e) {
      return dateStr;
    }
  }
}
