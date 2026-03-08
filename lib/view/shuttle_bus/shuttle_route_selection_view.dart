import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import '../../viewmodel/shuttle_viewmodel.dart';
import '../../models/emergency_notice_model.dart';
import '../../models/shuttle_models.dart';
import 'shuttle_schedule_view.dart'; // 시간표 화면 임포트
import 'package:intl/intl.dart';
import 'nearby_stops_view.dart'; // 가까운 정류장 찾기 화면 임포트
import '../components/scale_button.dart';
import '../components/emergency_notice_banner.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../utils/responsive_layout.dart';

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
  // 셔틀버스 색상 - 홈 화면과 동일하게 맞춤
  final Color shuttleColor = const Color(0xFFB83227);
  final ScrollController _scrollController = ScrollController();
  Worker? _errorWorker;

  final GlobalKey _nearbyButtonKey = GlobalKey();

  bool _isExperienceTourRunning = false;

  @override
  void initState() {
    super.initState();
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
    final layout = AppResponsive.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '셔틀버스 노선 선택',
          style: TextStyle(
            fontSize: layout.font(20),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const EmergencyNoticeBanner(
              category: EmergencyNoticeCategory.shuttle,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: AppPageFrame(
                  child: Padding(
                    padding: EdgeInsets.all(layout.space(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSelectionArea(context),
                        SizedBox(height: layout.space(32)),
                        Center(
                          child: ScaleButton(
                            onTap: () {
                              // 노선과 운행일자가 모두 선택되었는지 확인
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
                                // 날짜 포맷 변환
                                DateFormat('yyyy-MM-dd')
                                    .parse(viewModel.selectedDate.value);

                                // 조회 버튼을 누를 때만 API를 호출하도록 변경
                                viewModel
                                    .fetchSchedules(
                                        viewModel.selectedRouteId.value,
                                        viewModel.selectedDate.value)
                                    .then((success) {
                                  if (!success) {
                                    // 404 에러: 해당 날짜에 운행하는 셔틀 노선이 없음
                                    _showNoScheduleAlert(context);
                                  } else {
                                    // API 호출 성공 또는 더미 데이터로 대체된 경우
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
                                // 에러가 발생해도 기본 API 호출은 계속 진행
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
                                horizontal: layout.space(50, maxScale: 1.12),
                                vertical: layout.space(15),
                              ),
                              decoration: BoxDecoration(
                                color: shuttleColor,
                                borderRadius:
                                    BorderRadius.circular(layout.radius(20)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: layout.space(5),
                                    offset: Offset(0, layout.space(3)),
                                  )
                                ],
                              ),
                              child: Text(
                                '시간표 조회',
                                style: TextStyle(
                                  fontSize: layout.font(16),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: layout.space(24)),
                        Divider(
                          color: shuttleColor.withOpacity(0.3),
                          thickness: layout.border(1.5),
                        ),
                        SizedBox(height: layout.space(24)),
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
                                      horizontal:
                                          layout.space(40, maxScale: 1.12),
                                      vertical: layout.space(15),
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade700,
                                      borderRadius: BorderRadius.circular(
                                        layout.radius(20),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: layout.space(5),
                                          offset: Offset(0, layout.space(3)),
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: Colors.white,
                                          size: layout.icon(24),
                                        ),
                                        SizedBox(width: layout.space(8)),
                                        Text(
                                          '정류장별 시간표 간편 조회',
                                          style: TextStyle(
                                            fontSize: layout.font(16),
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: layout.space(8)),
                              Text(
                                '(주변 정류장 검색)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: layout.font(12),
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startExperienceTour() async {
    if (!mounted || _isExperienceTourRunning) return;
    _isExperienceTourRunning = true;

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
    final layout = AppResponsive.of(context);

    return Container(
      constraints: BoxConstraints(
        maxWidth: layout.isCompactWidth ? layout.space(300) : 320,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: layout.font(20),
            ),
          ),
          SizedBox(height: layout.space(8)),
          Text(
            description,
            style: TextStyle(
              color: Colors.white,
              fontSize: layout.font(15),
              height: 1.4,
            ),
          ),
          SizedBox(height: layout.space(14)),
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
                    borderRadius: BorderRadius.circular(layout.radius(12)),
                  ),
                ),
                child: Text(isLast ? '완료' : '다음'),
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
    final layout = AppResponsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCurrentTimeInfo(context),
        SizedBox(height: layout.space(24)),
        Text(
          '노선 선택',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: layout.font(16),
          ),
        ),
        SizedBox(height: layout.space(12)),

        // 로딩 인디케이터를 플랫폼별로 표시
        Obx(
          () => viewModel.isLoadingRoutes.value
              ? Center(child: _buildPlatformLoadingIndicator())
              : viewModel.routes.isEmpty
                  ? Text('사용 가능한 노선이 없습니다')
                  : _buildRouteSelector(context),
        ),
        SizedBox(height: layout.space(20)),
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

  // 현재 시간 정보 및 도움말 카드
  // 현재 시간/날짜를 간결하게 보여주는 헤더
  Widget _buildCurrentTimeInfo(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final layout = AppResponsive.of(context);
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
          padding: EdgeInsets.all(layout.space(16)),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(layout.radius(20)),
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
                      fontSize: layout.font(17),
                      color: titleColor.withOpacity(0.85),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeString,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: layout.font(17),
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: layout.space(10)),
              Text(
                '노선과 운행 날짜를 선택해 시간표를 조회하세요.',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: layout.font(13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteSelector(BuildContext context) {
    if (Platform.isIOS) {
      return _buildIOSRouteSelector(context);
    } else {
      return _buildAndroidRouteSelector();
    }
  }

  Widget _buildIOSRouteSelector(BuildContext context) {
    final layout = AppResponsive.of(context);
    return ScaleButton(
      onTap: () => _showIOSRoutePicker(context),
      child: Container(
        height: layout.space(50),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(layout.radius(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: layout.space(10),
              offset: Offset.zero,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Obx(() {
                if (viewModel.selectedRouteId.value == -1) {
                  return Text(
                    '노선을 선택하세요',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: layout.font(14),
                    ),
                  );
                } else {
                  final selectedRoute = viewModel.routes.firstWhere(
                    (route) => route.id == viewModel.selectedRouteId.value,
                    orElse: () => ShuttleRoute(
                        id: -1, routeName: '알 수 없음', direction: ''),
                  );
                  return Text(
                    '${selectedRoute.routeName}',
                    style: TextStyle(fontSize: layout.font(14)),
                  );
                }
              }),
              Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).hintColor,
                size: layout.icon(24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIOSRoutePicker(BuildContext context) {
    int selectedIndex = 0;

    // 현재 선택된 노선의 인덱스 찾기
    if (viewModel.selectedRouteId.value != -1) {
      final index = viewModel.routes
          .indexWhere((route) => route.id == viewModel.selectedRouteId.value);
      if (index != -1) {
        selectedIndex = index;
      }
    }

    // 노선이 없는 경우 처리
    if (viewModel.routes.isEmpty) {
      Get.snackbar('알림', '사용 가능한 노선이 없습니다',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: AppResponsive.of(context).space(250, maxScale: 1.08),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              height: AppResponsive.of(context).space(50),
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
                      if (viewModel.routes.isNotEmpty) {
                        viewModel
                            .selectRoute(viewModel.routes[selectedIndex].id);
                      }
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController:
                    FixedExtentScrollController(initialItem: selectedIndex),
                onSelectedItemChanged: (int index) {
                  selectedIndex = index;
                },
                children: viewModel.routes.map((route) {
                  return Center(
                    child: Text(
                      '${route.routeName}',
                      style: TextStyle(
                        fontSize: AppResponsive.of(context).font(16),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidRouteSelector() {
    final context = Get.context!;
    final layout = AppResponsive.of(context);
    return Container(
      height: layout.space(50),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(layout.radius(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: layout.space(10),
            offset: Offset.zero,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
      child: Obx(() {
        return DropdownButton<int>(
          value: viewModel.selectedRouteId.value != -1
              ? viewModel.selectedRouteId.value
              : null,
          hint: Text(
            '노선을 선택하세요',
            style: TextStyle(fontSize: layout.font(14)),
          ),
          isExpanded: true,
          underline: SizedBox(), // 밑줄 제거
          icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).hintColor),
          onChanged: (int? value) {
            if (value != null) {
              viewModel.selectRoute(value);
            }
          },
          items: viewModel.routes.map<DropdownMenuItem<int>>((route) {
            return DropdownMenuItem<int>(
              value: route.id,
              child: Text(
                '${route.routeName}',
                style: TextStyle(fontSize: layout.font(14)),
              ),
            );
          }).toList(),
        );
      }),
    );
  }

  Widget _buildScheduleTypeSelector(BuildContext context) {
    if (Platform.isIOS) {
      return _buildIOSDateSelector(context);
    } else {
      return _buildAndroidDateSelector(context);
    }
  }

  Widget _buildIOSDateSelector(BuildContext context) {
    final layout = AppResponsive.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '탑승일',
          style: TextStyle(
            fontSize: layout.font(16),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: layout.space(12)),
        _buildDateSelectorWithArrows(
          context,
          onTapDatePicker: () => _showIOSDatePicker(context),
        ),
        SizedBox(height: layout.space(8)),
        _buildScheduleTypeInfoText(context),
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
        height: AppResponsive.of(context).space(250, maxScale: 1.08),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              height: AppResponsive.of(context).space(50),
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
    final layout = AppResponsive.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '탑승일',
          style: TextStyle(
            fontSize: layout.font(16),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: layout.space(12)),
        _buildDateSelectorWithArrows(
          context,
          onTapDatePicker: () => _showAndroidDatePicker(context),
        ),
        SizedBox(height: layout.space(8)),
        _buildScheduleTypeInfoText(context),
      ],
    );
  }

  Widget _buildScheduleTypeInfoText(BuildContext context) {
    final layout = AppResponsive.of(context);
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
              fontSize: layout.font(14),
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.redAccent
                  : shuttleColor,
            ),
          ),
          SizedBox(width: layout.space(8)),
          SizedBox(
            width: layout.space(14),
            height: layout.space(14),
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
      final layout = AppResponsive.of(context);
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
          SizedBox(width: layout.space(8)),
          Expanded(
            child: ScaleButton(
              onTap: onTapDatePicker,
              child: Container(
                height: layout.space(50),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(layout.radius(25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: layout.space(10),
                      offset: Offset.zero,
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getSelectedDateLabel(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: layout.font(14),
                          color: hasSelectedDate
                              ? null
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).hintColor,
                      size: layout.icon(18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: layout.space(8)),
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
    final layout = AppResponsive.of(context);
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: ScaleButton(
          onTap: onTap,
          child: Container(
            width: layout.space(40),
            height: layout.space(40),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: layout.space(10),
                  offset: Offset.zero,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: layout.icon(24),
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
