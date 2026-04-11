import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:hsro/features/notice/models/emergency_notice_model.dart';
import 'package:hsro/features/notice/widgets/emergency_notice_banner.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/view/nearby_stops_view.dart';
import 'package:hsro/features/shuttle/view/shuttle_schedule_view.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';
import 'package:hsro/shared/widgets/ios_platform_fields.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

class ShuttleRouteSelectionView extends StatefulWidget {
  final bool startExperienceTour;

  const ShuttleRouteSelectionView({
    super.key,
    this.startExperienceTour = false,
  });

  @override
  State<ShuttleRouteSelectionView> createState() =>
      _ShuttleRouteSelectionViewState();
}

class _ShuttleRouteSelectionViewState extends State<ShuttleRouteSelectionView> {
  final ShuttleViewModel viewModel = Get.put(ShuttleViewModel());
  // 셔틀 대표 색상
  final Color shuttleColor = const Color(0xFFB83227);
  final ScrollController _scrollController = ScrollController();
  Worker? _errorWorker;

  final GlobalKey _nearbyButtonKey = GlobalKey();

  bool _isExperienceTourRunning = false;

  @override
  void initState() {
    super.initState();
    // iOS에서는 날짜 필드 초기값을 먼저 맞춤
    if (Platform.isIOS && viewModel.selectedDate.value.isEmpty) {
      viewModel.selectDate(
        DateFormat('yyyy-MM-dd').format(
          DateTime.now(),
        ),
      );
    }
    // ViewModel 오류 메시지를 스낵바로 연결
    _errorWorker = ever<String?>(viewModel.errorMessage, (message) {
      if (!mounted || message == null || message.isEmpty) return;
      Get.snackbar(
        '오류',
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
      viewModel.clearErrorMessage();
    });

    if (widget.startExperienceTour) {
      // 체험하기 모드면 첫 프레임 후 튜토리얼 시작
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startExperienceTour();
      });
    }
  }

  @override
  void dispose() {
    _errorWorker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('셔틀버스 노선 선택'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 셔틀 긴급 공지 배너
            const EmergencyNoticeBanner(
              category: EmergencyNoticeCategory.shuttle,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSelectionArea(context),

                      SizedBox(height: 32),

                      // 시간표 조회 버튼
                      Center(
                        child: ScaleButton(
                          onTap: () {
                            // 노선과 날짜가 모두 선택됐는지 확인
                            if (viewModel.selectedRouteId.value == -1) {
                              Get.snackbar(
                                '알림',
                                '노선을 선택해주세요',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                              return;
                            }

                            if (viewModel.selectedDate.value.isEmpty) {
                              Get.snackbar(
                                '알림',
                                '운행 날짜를 선택해주세요',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                              return;
                            }

                            try {
                              // 날짜 형식 검증 후 시간표 조회
                              DateFormat('yyyy-MM-dd')
                                  .parse(viewModel.selectedDate.value);

                              // 조회 버튼을 누를 때만 API를 호출하도록 변경
                              viewModel
                                  .fetchSchedules(
                                      viewModel.selectedRouteId.value,
                                      viewModel.selectedDate.value)
                                  .then((success) {
                                if (!success) {
                                  // 해당 날짜 운행 정보가 없으면 안내 팝업 표시
                                  _showNoScheduleAlert(context);
                                } else {
                                  // 조회 성공 시 시간표 화면으로 이동
                                  Get.to(() => ShuttleScheduleView(
                                        routeId:
                                            viewModel.selectedRouteId.value,
                                        date: viewModel.selectedDate.value,
                                        routeName: _getSelectedRouteName(),
                                      ));
                                }
                              });
                            } catch (e) {
                              print('날짜 포맷 변환 오류: $e');
                              // 파싱 오류가 나도 조회 자체는 계속 시도
                              viewModel
                                  .fetchSchedules(
                                      viewModel.selectedRouteId.value,
                                      viewModel.selectedDate.value)
                                  .then((success) {
                                if (!success) {
                                  _showNoScheduleAlert(context);
                                } else {
                                  Get.to(() => ShuttleScheduleView(
                                        routeId:
                                            viewModel.selectedRouteId.value,
                                        date: viewModel.selectedDate.value,
                                        routeName: _getSelectedRouteName(),
                                      ));
                                }
                              });
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
                            decoration: BoxDecoration(
                              color: shuttleColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 5,
                                    offset: Offset(0, 3))
                              ],
                            ),
                            child: Text(
                              '시간표 조회',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // 섹션 구분선
                      Divider(
                        color: shuttleColor.withOpacity(0.3),
                        thickness: 1.5,
                      ),

                      SizedBox(height: 24),

                      // 주변 정류장 기준 간편 조회 버튼
                      Center(
                        child: Column(
                          children: [
                            Container(
                              key: _nearbyButtonKey,
                              child: ScaleButton(
                                onTap: () {
                                  Get.to(() => NearbyStopsView());
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade700,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 5,
                                        offset: Offset(0, 3),
                                      )
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on,
                                          color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        '정류장별 시간표 간편 조회',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '(주변 정류장 검색)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startExperienceTour() async {
    if (!mounted || _isExperienceTourRunning) return;
    _isExperienceTourRunning = true;

    // 하단 버튼까지 보이도록 스크롤
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }

    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'shuttle_nearby_button',
          keyTarget: _nearbyButtonKey,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) => _buildExperienceContent(
                controller: controller,
                title: '정류장별 시간표 간편 조회',
                description: '현재 위치 기준으로 가까운 정류장을 자동 정렬해 빠르게 시간표를 확인할 수 있습니다.',
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
      onFinish: () => _openNearbyStopsExperience(),
      onSkip: () {
        _completeExperienceTour(proceedToNext: false);
        return true;
      },
      onClickOverlay: (target) {},
    ).show(context: context);
  }

  Future<void> _openNearbyStopsExperience() async {
    // 체험하기 흐름을 주변 정류장 화면으로 이어감
    final shouldContinue = await Get.to(
      () => NearbyStopsView(startExperienceTour: widget.startExperienceTour),
    );
    _completeExperienceTour(proceedToNext: shouldContinue == true);
  }

  void _completeExperienceTour({required bool proceedToNext}) {
    _isExperienceTourRunning = false;
    if (widget.startExperienceTour && mounted) {
      Get.back(result: proceedToNext);
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
                onPressed: () {
                  controller.next();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('다음'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 선택된 노선 이름 가져오기
  String _getSelectedRouteName() {
    if (viewModel.selectedRouteId.value != -1) {
      final route = viewModel.routes.firstWhere(
        (route) => route.id == viewModel.selectedRouteId.value,
        orElse: () => ShuttleRoute(id: -1, routeName: '알 수 없음', direction: ''),
      );
      return '${route.routeName}';
    }
    return '';
  }

  Widget _buildSelectionArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 현재 날짜/시간 안내 카드
        _buildCurrentTimeInfo(context),

        SizedBox(height: 24),

        Text('노선 선택',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 12),

        // 노선 목록 로딩/빈 상태/선택 UI 전환
        Obx(
          () => viewModel.isLoadingRoutes.value
              ? Center(child: _buildPlatformLoadingIndicator())
              : viewModel.routes.isEmpty
                  ? Text('사용 가능한 노선이 없습니다')
                  : _buildRouteSelector(context),
        ),

        SizedBox(height: 20),
        _buildScheduleTypeSelector(context),
      ],
    );
  }

  // 플랫폼별 로딩 인디케이터
  Widget _buildPlatformLoadingIndicator({
    double size = 24,
    Color? color,
    double strokeWidth = 2.5,
  }) {
    final indicatorColor = color ?? shuttleColor;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator.adaptive(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
      ),
    );
  }

  // 현재 시간/날짜 안내 카드
  Widget _buildCurrentTimeInfo(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final dayOfWeek = _getDayOfWeekString(now);
        final timeString = DateFormat('HH:mm').format(now);
        final brightness = Theme.of(context).brightness;
        final backgroundColor = brightness == Brightness.dark
            ? shuttleColor.withOpacity(0.2)
            : shuttleColor.withOpacity(0.1);
        final titleColor =
            brightness == Brightness.dark ? Colors.redAccent : shuttleColor;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${DateFormat('MM월 dd일').format(now)} ($dayOfWeek)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: titleColor.withOpacity(0.85),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeString,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '노선과 운행 날짜를 선택해 시간표를 조회하세요.',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteSelector(BuildContext context) {
    // 플랫폼별 노선 선택 UI 분기
    if (Platform.isIOS) {
      return _buildIOSRouteSelector(context);
    } else {
      return _buildAndroidRouteSelector();
    }
  }

  Widget _buildIOSRouteSelector(BuildContext context) {
    // iOS는 네이티브 메뉴형 노선 선택기 사용
    return Obx(() {
      final routes = viewModel.routes.toList(growable: false);
      final selectedRouteId = viewModel.selectedRouteId.value;
      final routeKey =
          routes.map((route) => '${route.id}:${route.routeName}').join('|');

      return Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: IOSRoutePopupButtonField(
          key: ValueKey('$selectedRouteId|$routeKey'),
          routes: routes,
          selectedRouteId: selectedRouteId,
          onRouteChanged: viewModel.selectRoute,
        ),
      );
    });
  }

  Widget _buildAndroidRouteSelector() {
    // Android는 기본 드롭다운 사용
    return Container(
      height: 50,
      decoration: BoxDecoration(
        // border: Border.all(color: Theme.of(Get.context!).dividerColor),
        color: Theme.of(Get.context!).cardColor,
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
      child: Obx(() {
        return DropdownButton<int>(
          value: viewModel.selectedRouteId.value != -1
              ? viewModel.selectedRouteId.value
              : null,
          hint: Text('노선을 선택하세요'),
          isExpanded: true,
          underline: SizedBox(), // 밑줄 제거
          icon: Icon(Icons.arrow_drop_down,
              color: Theme.of(Get.context!).hintColor),
          onChanged: (int? value) {
            if (value != null) {
              viewModel.selectRoute(value);
            }
          },
          items: viewModel.routes.map<DropdownMenuItem<int>>((route) {
            return DropdownMenuItem<int>(
              value: route.id,
              child: Text('${route.routeName}'),
            );
          }).toList(),
        );
      }),
    );
  }

  Widget _buildScheduleTypeSelector(BuildContext context) {
    // 플랫폼별 날짜 선택 UI 분기
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
          '탑승일',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Obx(() {
          final selectedDate = _getSelectedDateOrToday();
          final minimumDate = _getMinimumSelectableDate();
          final maximumDate = _getMaximumSelectableDate();
          final weekdayLabel = '(${_getDayOfWeekString(selectedDate)})';

          return Row(
            children: [
              _buildDateArrowButton(
                context: context,
                icon: Icons.chevron_left,
                enabled: selectedDate.isAfter(minimumDate),
                onTap: () => _moveSelectedDateBy(-1),
              ),
              SizedBox(width: 8),
              Expanded(
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availablePickerWidth = constraints.maxWidth - 44;
                      final pickerWidth = availablePickerWidth <= 0
                          ? constraints.maxWidth
                          : (availablePickerWidth < 210
                              ? availablePickerWidth
                              : 210.0);

                      return Stack(
                        children: [
                          Center(
                            child: SizedBox(
                              width: pickerWidth,
                              child: IOSCompactDatePickerField(
                                key: ValueKey(viewModel.selectedDate.value),
                                initialDate: selectedDate,
                                minimumDate: minimumDate,
                                maximumDate: maximumDate,
                                onDateChanged: (date) {
                                  viewModel.selectDate(
                                    DateFormat('yyyy-MM-dd').format(date),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                weekdayLabel,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.redAccent
                                      : shuttleColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SizedBox(width: 8),
              _buildDateArrowButton(
                context: context,
                icon: Icons.chevron_right,
                enabled: selectedDate.isBefore(maximumDate),
                onTap: () => _moveSelectedDateBy(1),
              ),
            ],
          );
        }),
        SizedBox(height: 8),
        _buildScheduleTypeInfoText(context),
      ],
    );
  }

  Widget _buildAndroidDateSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '탑승일',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        _buildDateSelectorWithArrows(
          context,
          onTapDatePicker: () => _showAndroidDatePicker(context),
        ),
        SizedBox(height: 8),
        _buildScheduleTypeInfoText(context),
      ],
    );
  }

  Widget _buildScheduleTypeInfoText(BuildContext context) {
    return Obx(() {
      if (viewModel.selectedDate.value.isEmpty) {
        return SizedBox.shrink();
      }

      final scheduleTypeName = viewModel.scheduleTypeName.value;
      final isLoading = viewModel.isLoadingScheduleType.value;

      if (scheduleTypeName.isEmpty && !isLoading) {
        return SizedBox.shrink();
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '운행 유형: $scheduleTypeName',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.redAccent
                  : shuttleColor,
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 14,
            height: 14,
            child: Opacity(
              opacity: isLoading ? 1 : 0,
              child: _buildPlatformLoadingIndicator(
                size: 14,
                color: Theme.of(context).hintColor,
                strokeWidth: 2,
              ),
            ),
          ),
        ],
      );
    });
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

    final dateStr = viewModel.selectedDate.value;
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return '${DateFormat('yyyy년 MM월 dd일').format(date)} (${_getDayOfWeekString(date)})';
    } catch (e) {
      return dateStr;
    }
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

  // 요일 이름 가져오기
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

  // 404 에러 - 해당 날짜에 운행하는 셔틀 노선이 없음을 알리는 팝업
  void _showNoScheduleAlert(BuildContext context) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(viewModel.selectedDate.value);
      final formattedDate =
          '${DateFormat('yyyy년 MM월 dd일').format(date)} (${_getDayOfWeekString(date)})';
      final routeName = _getSelectedRouteName();

      final message = '$formattedDate에\n$routeName 노선의 운행 정보가 없습니다.';

      if (Platform.isIOS) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('운행 정보 없음'),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                child: Text('확인'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('운행 정보 없음'),
            content: Text(message),
            actions: [
              TextButton(
                child: Text('확인'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 날짜 형식 변환 오류 시 기본 메시지 표시
      if (Platform.isIOS) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('알림'),
            content: Text('해당 날짜에 운행하는 셔틀노선이 없습니다.'),
            actions: [
              CupertinoDialogAction(
                child: Text('확인'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('알림'),
            content: Text('해당 날짜에 운행하는 셔틀노선이 없습니다.'),
            actions: [
              TextButton(
                child: Text('확인'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }
}
