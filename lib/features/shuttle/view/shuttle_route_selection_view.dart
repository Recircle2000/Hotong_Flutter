import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hsro/core/utils/platform_utils.dart';
import 'package:hsro/features/notice/models/emergency_notice_model.dart';
import 'package:hsro/features/notice/widgets/emergency_notice_banner.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/view/nearby_stops_view.dart';
import 'package:hsro/features/shuttle/view/shuttle_journey_result_view.dart';
import 'package:hsro/features/shuttle/view/shuttle_schedule_view.dart';
import 'package:hsro/features/shuttle/view/shuttle_station_map_view.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';
import 'package:hsro/features/shuttle/widgets/favorite_journey_edit_sheet.dart';
import 'package:hsro/features/shuttle/widgets/shuttle_station_picker.dart';
import 'package:hsro/shared/widgets/ios_platform_fields.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

class ShuttleRouteSelectionView extends StatefulWidget {
  final bool startExperienceTour;
  final bool routeSelectionOnly;

  const ShuttleRouteSelectionView({
    super.key,
    this.startExperienceTour = false,
    this.routeSelectionOnly = false,
  });

  @override
  State<ShuttleRouteSelectionView> createState() =>
      _ShuttleRouteSelectionViewState();
}

class _ShuttleRouteSelectionViewState extends State<ShuttleRouteSelectionView> {
  static final Uri _shuttleScheduleSourceUrl = Uri.parse(
    'https://www.hoseo.ac.kr/Home/Contents.mbz?action=MAPP_2603202792',
  );

  final ShuttleViewModel viewModel = Get.put(ShuttleViewModel());
  // 셔틀 대표 색상
  final Color shuttleColor = const Color(0xFFB83227);
  final ScrollController _scrollController = ScrollController();
  Worker? _errorWorker;

  final GlobalKey _originFieldKey = GlobalKey();
  final GlobalKey _destinationFieldKey = GlobalKey();
  final GlobalKey _journeySearchButtonKey = GlobalKey();

  bool _isExperienceTourRunning = false;

  @override
  void initState() {
    super.initState();
    // iOS에서는 날짜 필드 초기값을 먼저 맞춤
    if (Platform.isIOS && viewModel.selectedDate.value.isEmpty) {
      viewModel.selectDate(DateFormat('yyyy-MM-dd').format(DateTime.now()));
    }
    // ViewModel 오류 메시지를 스낵바로 연결
    _errorWorker = ever<String?>(viewModel.errorMessage, (message) {
      if (!mounted || message == null || message.isEmpty) return;
      Get.snackbar('오류', message, snackPosition: SnackPosition.BOTTOM);
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
    if (!widget.routeSelectionOnly) {
      return _buildJourneyScaffold(context);
    }
    return Scaffold(
      appBar: AppBar(title: Text('노선별 시간표')),
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
                              DateFormat(
                                'yyyy-MM-dd',
                              ).parse(viewModel.selectedDate.value);

                              // 조회 버튼을 누를 때만 API를 호출하도록 변경
                              viewModel
                                  .fetchSchedules(
                                    viewModel.selectedRouteId.value,
                                    viewModel.selectedDate.value,
                                  )
                                  .then((success) {
                                    if (!context.mounted) {
                                      return;
                                    }

                                    if (!success) {
                                      // 해당 날짜 운행 정보가 없으면 안내 팝업 표시
                                      _showNoScheduleAlert(context);
                                    } else {
                                      // 조회 성공 시 시간표 화면으로 이동
                                      Get.to(
                                        () => ShuttleScheduleView(
                                          routeId:
                                              viewModel.selectedRouteId.value,
                                          date: viewModel.selectedDate.value,
                                          routeName: _getSelectedRouteName(),
                                        ),
                                      );
                                    }
                                  });
                            } catch (e) {
                              debugPrint('날짜 포맷 변환 오류: $e');
                              // 파싱 오류가 나도 조회 자체는 계속 시도
                              viewModel
                                  .fetchSchedules(
                                    viewModel.selectedRouteId.value,
                                    viewModel.selectedDate.value,
                                  )
                                  .then((success) {
                                    if (!context.mounted) {
                                      return;
                                    }

                                    if (!success) {
                                      _showNoScheduleAlert(context);
                                    } else {
                                      Get.to(
                                        () => ShuttleScheduleView(
                                          routeId:
                                              viewModel.selectedRouteId.value,
                                          date: viewModel.selectedDate.value,
                                          routeName: _getSelectedRouteName(),
                                        ),
                                      );
                                    }
                                  });
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 50,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: shuttleColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '시간표 조회',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      _buildScheduleSourceLink(context),
                      const SizedBox(height: 24),
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

  Widget _buildJourneyScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('셔틀버스 찾기')),
      bottomNavigationBar: _buildJourneySearchBar(context),
      body: SafeArea(
        child: Column(
          children: [
            const EmergencyNoticeBanner(
              category: EmergencyNoticeCategory.shuttle,
            ),
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // 내용이 짧으면 시간표 링크를 화면 아래쪽에 붙여 둔다.
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildJourneySelectionArea(context),
                          _buildFavoriteJourneys(context),
                          const SizedBox(height: 24),
                          _buildScheduleTypeSelector(context),
                          const Spacer(),
                          const SizedBox(height: 24),
                          _buildRouteScheduleShortcut(context),
                          _buildScheduleSourceLink(context),
                        ],
                      ),
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

  Widget _buildJourneySearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Container(
          key: _journeySearchButtonKey,
          child: Obx(() {
            final origin = viewModel.selectedOriginStation.value;
            final destination = viewModel.selectedDestinationStation.value;
            final isLoadingDestinations =
                viewModel.isLoadingJourneyDestinations.value;
            final isSearching = viewModel.isLoadingJourneys.value;
            final hasUnavailableDate =
                viewModel.journeyDestinationUnavailableDate.value != null;
            final canSearch =
                origin != null &&
                destination != null &&
                origin.name != destination.name &&
                !isLoadingDestinations &&
                !hasUnavailableDate &&
                !isSearching;
            final foregroundColor = canSearch || isSearching
                ? Colors.white
                : colorScheme.onSurface.withValues(alpha: 0.38);

            return Semantics(
              button: true,
              enabled: canSearch,
              label: isSearching ? '셔틀 찾는 중' : '셔틀버스 찾기',
              excludeSemantics: true,
              child: IgnorePointer(
                ignoring: !canSearch,
                child: ScaleButton(
                  onTap: _openJourneyResults,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: canSearch || isSearching
                          ? shuttleColor
                          : colorScheme.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSearching) ...[
                          _buildPlatformLoadingIndicator(
                            size: 18,
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            isSearching ? '셔틀 찾는 중…' : '셔틀버스 찾기',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: foregroundColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRouteScheduleShortcut(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => Get.to(
          () => const ShuttleRouteSelectionView(routeSelectionOnly: true),
          preventDuplicates: false,
        ),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.72),
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('노선별 전체 시간표 보기'),
            SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  // 다크 모드에서는 셔틀 색이 어두워 잘 안 보여 밝은 빨강을 쓴다.
  Color _accentForeground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.redAccent
      : shuttleColor;

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildScheduleSourceLink(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;

    return Center(
      child: TextButton.icon(
        onPressed: () => _showScheduleSourceInfo(context),
        style: TextButton.styleFrom(
          foregroundColor: hintColor,
          minimumSize: const Size(44, 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 13),
        ),
        icon: const Icon(Icons.info_outline_rounded, size: 15),
        label: const Text('시간표 기준 및 출처'),
      ),
    );
  }

  Future<void> _showScheduleSourceInfo(BuildContext context) async {
    const title = '시간표 기준 안내';
    const message = '셔틀버스 시간표와 공지사항은 매일 19시를 기준으로 확인해 반영합니다.';

    if (Platform.isIOS) {
      final shouldOpenHomepage =
          await PlatformUtils.showIOSNativeActionAlertDialog(
            title: title,
            message: message,
            actionButtonTitle: '홈페이지 이동',
          );

      if (shouldOpenHomepage != null) {
        if (shouldOpenHomepage) {
          await _openShuttleScheduleSource();
        }
        return;
      }

      if (!context.mounted) {
        return;
      }
    }

    return showAdaptiveDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: const Text(title),
        content: const Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openShuttleScheduleSource();
            },
            child: const Text('홈페이지 이동'),
          ),
        ],
      ),
    );
  }

  Future<void> _openShuttleScheduleSource() async {
    final didLaunch = await launchUrl(
      _shuttleScheduleSourceUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!didLaunch) {
      Get.snackbar(
        '알림',
        '호서대학교 셔틀버스 안내 페이지를 열지 못했습니다. 잠시 후 다시 시도해주세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Widget _buildJourneySelectionArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('정류장 선택'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      key: _originFieldKey,
                      child: Obx(
                        () => _buildStationField(
                          context: context,
                          label: '출발',
                          value: viewModel.selectedOriginStation.value?.name,
                          onTap: () => _selectStation(isOrigin: true),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                    Container(
                      key: _destinationFieldKey,
                      child: Obx(
                        () => _buildStationField(
                          context: context,
                          label: '도착',
                          value:
                              viewModel.selectedDestinationStation.value?.name,
                          onTap: () => _selectStation(isOrigin: false),
                          isLoading:
                              viewModel.isLoadingJourneyDestinations.value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: '출발지와 도착지 바꾸기',
                excludeSemantics: true,
                child: ScaleButton(
                  onTap: viewModel.swapJourneyStations,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Obx(() {
          final origin = viewModel.selectedOriginStation.value;
          final destination = viewModel.selectedDestinationStation.value;
          final unavailableDate =
              viewModel.journeyDestinationUnavailableDate.value;
          if (origin == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  child: unavailableDate != null
                      ? Container(
                          key: const ValueKey('journey_unavailable_notice'),
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: shuttleColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.redAccent
                                    : shuttleColor,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '선택한 탑승일에 운행하는 셔틀버스가 없습니다',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )
                      : !viewModel.isCampusStationName(origin.name)
                      ? Padding(
                          key: const ValueKey('journey_campus_only_notice'),
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                          child: Text(
                            '중간 정류장에서는 캠퍼스행 셔틀만 이용할 수 있어요',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : const SizedBox(key: ValueKey('journey_notice_empty')),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: _journeyActionStyle(context),
                      onPressed: () => Get.to(
                        () => NearbyStopsView(
                          initialStationId: origin.id,
                          initialDate: _selectedDateOrNull,
                        ),
                      ),
                      icon: const Icon(Icons.schedule_rounded, size: 17),
                      label: const Text('출발 정류장 시간표'),
                    ),
                    if (destination != null)
                      TextButton.icon(
                        style: _journeyActionStyle(
                          context,
                          foregroundColor: viewModel.isSelectedJourneyFavorite
                              ? Colors.amber.shade800
                              : null,
                        ),
                        onPressed: viewModel.toggleSelectedJourneyFavorite,
                        icon: Icon(
                          viewModel.isSelectedJourneyFavorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 18,
                          color: viewModel.isSelectedJourneyFavorite
                              ? Colors.amber.shade700
                              : null,
                        ),
                        label: Text(
                          viewModel.isSelectedJourneyFavorite
                              ? '경로 저장됨'
                              : '경로 저장',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  ButtonStyle _journeyActionStyle(
    BuildContext context, {
    Color? foregroundColor,
  }) {
    return TextButton.styleFrom(
      foregroundColor:
          foregroundColor ??
          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
      minimumSize: const Size(44, 40),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildStationField({
    required BuildContext context,
    required String label,
    required String? value,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    final hintColor = Theme.of(context).hintColor;
    return Semantics(
      button: true,
      label: '$label 정류장, ${value ?? '선택 안 됨'}, 변경',
      excludeSemantics: true,
      child: ScaleButton(
        onTap: onTap,
        child: Container(
          // 정류장 이름과 화살표 사이 빈 곳을 눌러도 반응하도록 투명 바탕을 깐다.
          color: Colors.transparent,
          height: 56,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: 13, color: hintColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value ?? '정류장을 선택하세요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: value == null ? 16 : 17,
                      fontWeight: value == null
                          ? FontWeight.normal
                          : FontWeight.w600,
                      color: value == null ? hintColor : null,
                    ),
                  ),
                ),
                if (isLoading)
                  _buildPlatformLoadingIndicator(size: 16, strokeWidth: 2)
                else
                  Icon(Icons.chevron_right_rounded, size: 20, color: hintColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteJourneys(BuildContext context) {
    return Obx(() {
      final favorites = viewModel.validFavoriteJourneys;
      if (favorites.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildSectionTitle('즐겨찾는 경로')),
                TextButton(
                  onPressed: () => showFavoriteJourneyEditSheet(
                    context: context,
                    viewModel: viewModel,
                    accentColor: shuttleColor,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).hintColor,
                    minimumSize: const Size(44, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  child: const Text(
                    '편집',
                    semanticsLabel: '즐겨찾는 경로 편집',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 칩 목록은 화면 양 끝까지 스크롤되도록 바깥 여백만큼 넓힌다.
                  final fullWidth = constraints.maxWidth + 32;
                  return OverflowBox(
                    alignment: Alignment.center,
                    minWidth: fullWidth,
                    maxWidth: fullWidth,
                    child: _EdgeFadingHorizontalList(
                      height: 48,
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final favorite = favorites[index];
                        final name = viewModel.favoriteDisplayName(favorite);
                        return Semantics(
                          button: true,
                          label: '즐겨찾는 경로, $name',
                          excludeSemantics: true,
                          child: ScaleButton(
                            onTap: () =>
                                viewModel.applyFavoriteJourney(favorite),
                            child: Container(
                              height: 44,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              constraints: const BoxConstraints(maxWidth: 260),
                              padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 18,
                                    color: Theme.of(context).hintColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _selectStation({required bool isOrigin}) async {
    if (!isOrigin && viewModel.selectedOriginStation.value == null) {
      Get.snackbar(
        '알림',
        '출발 정류장을 먼저 선택해주세요',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!isOrigin && viewModel.isLoadingJourneyDestinations.value) {
      Get.snackbar(
        '알림',
        '이동 가능한 도착지를 확인하고 있습니다',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final allowedIds = isOrigin
        ? null
        : viewModel.journeyDestinations
              .expand(
                (destination) =>
                    viewModel.stationIdsForLogicalName(destination.stationName),
              )
              .toSet();
    final pickerStations = isOrigin
        ? viewModel.logicalJourneyStations
        : viewModel.sortJourneyStationsForPicker(
            viewModel.journeyDestinations.map(
              viewModel.stationForJourneyDestination,
            ),
          );
    final station = await showShuttleStationPicker(
      context: context,
      title: isOrigin ? '출발 정류장 선택' : '도착 정류장 선택',
      stations: pickerStations,
      favoriteStationsProvider: () => viewModel.favoriteStations,
      isStationFavorite: viewModel.isStationFavorite,
      onToggleFavorite: viewModel.toggleStationFavorite,
      detailStationsProvider: (station) =>
          viewModel.stationsForLogicalName(station.name),
      allowedStationIds: allowedIds,
    );
    if (station == null) return;
    if (isOrigin) {
      await viewModel.selectOriginStation(station);
    } else {
      await viewModel.selectDestinationStation(station);
    }
  }

  Future<void> _openJourneyResults() async {
    final origin = viewModel.selectedOriginStation.value;
    final destination = viewModel.selectedDestinationStation.value;
    if (origin == null) {
      Get.snackbar('알림', '출발 정류장을 선택해주세요', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (destination == null) {
      Get.snackbar('알림', '도착 정류장을 선택해주세요', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (origin.name == destination.name) {
      Get.snackbar(
        '알림',
        '출발지와 도착지는 달라야 합니다',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final result = await viewModel.searchJourneys();
    if (!mounted || result == null) return;
    Get.to(() => ShuttleJourneyResultView(initialResult: result));
  }

  Future<void> _startExperienceTour() async {
    if (!mounted || _isExperienceTourRunning) return;
    _isExperienceTourRunning = true;

    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'shuttle_origin_field',
          keyTarget: _originFieldKey,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildExperienceContent(
                controller: controller,
                title: '출발 정류장 선택',
                description: '검색, 현재 위치 또는 지도에서 탑승할 정류장을 선택할 수 있습니다.',
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'shuttle_destination_field',
          keyTarget: _destinationFieldKey,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildExperienceContent(
                controller: controller,
                title: '도착 정류장 선택',
                description: '출발지에서 갈 수 있는 정류장만 확인하고 가는 셔틀을 찾을 수 있습니다.',
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
      onFinish: () => _completeExperienceTour(proceedToNext: true),
      onSkip: () {
        _completeExperienceTour(proceedToNext: false);
        return true;
      },
      onClickOverlay: (target) {},
    ).show(context: context);
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

  String? get _selectedDateOrNull {
    final date = viewModel.selectedDate.value;
    return date.isEmpty ? null : date;
  }

  void _openStationMap() {
    Get.to(() => ShuttleStationMapView(initialDate: _selectedDateOrNull));
  }

  Widget _buildSelectionArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 현재 날짜/시간 안내 카드
        _buildCurrentTimeInfo(context),

        SizedBox(height: 24),

        _buildSectionTitle('노선 선택'),
        const SizedBox(height: 8),

        // 노선 목록 로딩/빈 상태/선택 UI 전환
        Obx(
          () => viewModel.isLoadingRoutes.value
              ? Center(child: _buildPlatformLoadingIndicator())
              : viewModel.routes.isEmpty
              ? const Text('현재 선택한 날짜에 이용 가능한 노선이 없어요.')
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
        final titleColor = brightness == Brightness.dark
            ? Colors.redAccent
            : shuttleColor;

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
                widget.routeSelectionOnly
                    ? '노선과 운행 날짜를 선택하면 시간표를 확인할 수 있어요.'
                    : '출발지와 도착지를 선택하면 이용 가능한 셔틀을 찾아드려요.',
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
    final selector = Platform.isIOS
        ? _buildIOSRouteSelector(context)
        : _buildAndroidRouteSelector();

    return Row(
      children: [
        Expanded(child: selector),
        SizedBox(width: 12),
        _buildMapShortcutButton(),
      ],
    );
  }

  Widget _buildIOSRouteSelector(BuildContext context) {
    // iOS는 네이티브 메뉴형 노선 선택기 사용
    return Obx(() {
      final routes = viewModel.routes.toList(growable: false);
      final selectedRouteId = viewModel.selectedRouteId.value;
      final routeKey = routes
          .map((route) => '${route.id}:${route.routeName}')
          .join('|');

      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
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
          icon: Icon(
            Icons.arrow_drop_down,
            color: Theme.of(Get.context!).hintColor,
          ),
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

  Widget _buildMapShortcutButton() {
    return ScaleButton(
      onTap: _openStationMap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.map_outlined,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.redAccent
              : shuttleColor,
        ),
      ),
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
    return _buildDateSection(
      context,
      center: Obx(() {
        final selectedDate = _getSelectedDateOrToday();
        final weekdayLabel = '(${_getDayOfWeekString(selectedDate)})';

        return LayoutBuilder(
          builder: (context, constraints) {
            final availablePickerWidth = constraints.maxWidth - 44;
            final pickerWidth = availablePickerWidth <= 0
                ? constraints.maxWidth
                : (availablePickerWidth < 210 ? availablePickerWidth : 210.0);

            return Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: pickerWidth,
                    child: IOSCompactDatePickerField(
                      key: ValueKey(viewModel.selectedDate.value),
                      initialDate: selectedDate,
                      minimumDate: _getMinimumSelectableDate(),
                      maximumDate: _getMaximumSelectableDate(),
                      onDateChanged: (date) {
                        viewModel.selectDate(
                          DateFormat('yyyy-MM-dd').format(date),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      weekdayLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }

  Widget _buildAndroidDateSelector(BuildContext context) {
    return _buildDateSection(
      context,
      center: Obx(() {
        final hasSelectedDate = viewModel.selectedDate.value.isNotEmpty;
        final selectedDate = _getSelectedDateOrToday();
        return Semantics(
          button: true,
          label: '탑승일 ${_getSelectedDateLabel()}, 날짜 선택',
          excludeSemantics: true,
          child: ScaleButton(
            onTap: () => _showAndroidDatePicker(context),
            child: SizedBox(
              height: 44,
              child: Center(
                child: hasSelectedDate
                    ? Text.rich(
                        TextSpan(
                          text: DateFormat('yyyy년 M월 d일 ').format(
                            selectedDate,
                          ),
                          children: [
                            TextSpan(
                              text: '(${_getDayOfWeekString(selectedDate)})',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      )
                    : Text(
                        _getSelectedDateLabel(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // 탑승일 카드: 이전/다음 날짜 버튼을 카드 안 양쪽에 둔다.
  Widget _buildDateSection(BuildContext context, {required Widget center}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('탑승일'),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Obx(() {
            final selectedDate = _getSelectedDateOrToday();
            return Row(
              children: [
                _buildDateArrowButton(
                  context: context,
                  icon: Icons.chevron_left_rounded,
                  label: '이전 날짜',
                  enabled: selectedDate.isAfter(_getMinimumSelectableDate()),
                  onTap: () => _moveSelectedDateBy(-1),
                ),
                Expanded(child: center),
                _buildDateArrowButton(
                  context: context,
                  icon: Icons.chevron_right_rounded,
                  label: '다음 날짜',
                  enabled: selectedDate.isBefore(_getMaximumSelectableDate()),
                  onTap: () => _moveSelectedDateBy(1),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: _buildScheduleTypeInfoText(context),
        ),
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

      // "평일(월~목) 시간표 적용"처럼 운행 유형만 강조하고 나머지는 약하게 둔다.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (scheduleTypeName.isNotEmpty) ...[
            Text(
              scheduleTypeName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _accentForeground(context),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '시간표 적용',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
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

  Widget _buildDateArrowButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: label,
      onPressed: enabled ? onTap : null,
      iconSize: 26,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
      disabledColor: Theme.of(context).disabledColor,
      icon: Icon(icon),
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
      final selectedDate = DateFormat(
        'yyyy-MM-dd',
      ).parse(viewModel.selectedDate.value);
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
    DateTime selectedDate = _clampDateToSelectableRange(
      _getSelectedDateOrToday(),
    );
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
  Future<void> _showNoScheduleAlert(BuildContext context) async {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(viewModel.selectedDate.value);
      final formattedDate =
          '${DateFormat('yyyy년 MM월 dd일').format(date)} (${_getDayOfWeekString(date)})';
      final routeName = _getSelectedRouteName();

      final message = '$formattedDate에\n$routeName 노선의 운행 정보가 없습니다.';

      return _showNoScheduleMessage(
        context,
        title: '운행 정보 없음',
        message: message,
      );
    } catch (e) {
      // 날짜 형식 변환 오류 시 기본 메시지 표시
      return _showNoScheduleMessage(
        context,
        title: '알림',
        message: '해당 날짜에 운행하는 셔틀노선이 없습니다.',
      );
    }
  }

  Future<void> _showNoScheduleMessage(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    if (!context.mounted) {
      return;
    }

    if (Platform.isIOS) {
      // iOS에서는 UIKit의 UIAlertController를 먼저 사용한다.
      final didShowNativeDialog = await PlatformUtils.showIOSNativeAlertDialog(
        title: title,
        message: message,
      );

      if (didShowNativeDialog || !context.mounted) {
        return;
      }

      // 채널을 사용할 수 없는 환경에서는 기존 Flutter iOS 팝업으로 대체한다.
      return showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
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
}

class _EdgeFadingHorizontalList extends StatefulWidget {
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const _EdgeFadingHorizontalList({
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<_EdgeFadingHorizontalList> createState() =>
      _EdgeFadingHorizontalListState();
}

class _EdgeFadingHorizontalListState extends State<_EdgeFadingHorizontalList> {
  final ScrollController _controller = ScrollController();
  bool _showLeadingFade = false;
  bool _showTrailingFade = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFades);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void didUpdateWidget(covariant _EdgeFadingHorizontalList oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateFades)
      ..dispose();
    super.dispose();
  }

  void _updateFades() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final showLeading = position.extentBefore > 1;
    final showTrailing = position.extentAfter > 1;
    if (showLeading == _showLeadingFade && showTrailing == _showTrailingFade) {
      return;
    }
    setState(() {
      _showLeadingFade = showLeading;
      _showTrailingFade = showTrailing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: widget.itemBuilder,
          ),
          if (_showLeadingFade)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 18,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        backgroundColor,
                        backgroundColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_showTrailingFade)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 18,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        backgroundColor.withValues(alpha: 0),
                        backgroundColor,
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
