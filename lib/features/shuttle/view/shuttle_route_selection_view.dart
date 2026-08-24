import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:hsro/core/utils/platform_utils.dart';
import 'package:hsro/features/notice/models/emergency_notice_model.dart';
import 'package:hsro/features/notice/widgets/emergency_notice_banner.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/view/nearby_stops_view.dart';
import 'package:hsro/features/shuttle/view/shuttle_journey_result_view.dart';
import 'package:hsro/features/shuttle/view/shuttle_schedule_view.dart';
import 'package:hsro/features/shuttle/view/shuttle_station_map_view.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';
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
    if (!widget.routeSelectionOnly) {
      return _buildJourneyScaffold(context);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('노선별 시간표'),
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
                                if (!context.mounted) {
                                  return;
                                }

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
                              debugPrint('날짜 포맷 변환 오류: $e');
                              // 파싱 오류가 나도 조회 자체는 계속 시도
                              viewModel
                                  .fetchSchedules(
                                      viewModel.selectedRouteId.value,
                                      viewModel.selectedDate.value)
                                  .then((success) {
                                if (!context.mounted) {
                                  return;
                                }

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
                            width: double.infinity,
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
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 24),
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
      appBar: AppBar(title: const Text('셔틀 찾기')),
      bottomNavigationBar: _buildJourneySearchBar(context),
      body: SafeArea(
        child: Column(
          children: [
            const EmergencyNoticeBanner(
              category: EmergencyNoticeCategory.shuttle,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildJourneySelectionArea(context),
                    _buildFavoriteJourneys(context),
                    const SizedBox(height: 24),
                    _buildScheduleTypeSelector(context),
                    const SizedBox(height: 24),
                    _buildRouteScheduleShortcut(context),
                    const SizedBox(height: 8),
                  ],
                ),
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
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
            final canSearch = origin != null &&
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
              label: isSearching ? '셔틀 찾는 중' : '가는 셔틀 찾기',
              excludeSemantics: true,
              child: IgnorePointer(
                ignoring: !canSearch,
                child: ScaleButton(
                  onTap: _openJourneyResults,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: canSearch || isSearching
                          ? shuttleColor
                          : colorScheme.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: canSearch
                          ? [
                              BoxShadow(
                                color: shuttleColor.withValues(alpha: 0.22),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
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
                            isSearching ? '셔틀 찾는 중…' : '가는 셔틀 찾기',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
    return ScaleButton(
      onTap: () => Get.to(
        () => const ShuttleRouteSelectionView(routeSelectionOnly: true),
        preventDuplicates: false,
      ),
      child: Container(
        width: double.infinity,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
        child: Row(
          children: [
            Icon(
              Icons.route_outlined,
              size: 20,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '노선별 시간표 보기',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).hintColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneySelectionArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '정류장 선택',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            Container(
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
                  Container(
                    key: _originFieldKey,
                    child: Obx(
                      () => _buildStationField(
                        context: context,
                        icon: Icons.trip_origin,
                        label: '출발',
                        value: viewModel.selectedOriginStation.value?.name,
                        onTap: () => _selectStation(isOrigin: true),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 58, right: 64),
                    child: Divider(
                      height: 1,
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.45),
                    ),
                  ),
                  Container(
                    key: _destinationFieldKey,
                    child: Obx(
                      () => _buildStationField(
                        context: context,
                        icon: Icons.location_on,
                        label: '도착',
                        value: viewModel.selectedDestinationStation.value?.name,
                        onTap: () => _selectStation(isOrigin: false),
                        isLoading: viewModel.isLoadingJourneyDestinations.value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              child: Semantics(
                button: true,
                label: '출발지와 도착지 바꾸기',
                child: ScaleButton(
                  onTap: viewModel.swapJourneyStations,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: shuttleColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: shuttleColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.swap_vert_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
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
                if (unavailableDate != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(0, 6, 0, 2),
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.redAccent
                              : shuttleColor,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '선택한 탑승일에 운행하는 셔틀버스가 없습니다.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!viewModel.isCampusStationName(origin.name))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Text(
                      '중간 정류장에서는 캠퍼스행 셔틀만 이용할 수 있어요.',
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 4,
                  runSpacing: 0,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => Get.to(
                        () => NearbyStopsView(
                          initialStationId: origin.id,
                          initialDate: _selectedDateOrNull,
                        ),
                      ),
                      icon: const Icon(Icons.schedule, size: 17),
                      label: const Text('출발 정류장 시간표'),
                    ),
                    if (destination != null)
                      Tooltip(
                        message: viewModel.isSelectedJourneyFavorite
                            ? '즐겨찾기 해제'
                            : '즐겨찾기 저장',
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                            foregroundColor: viewModel.isSelectedJourneyFavorite
                                ? Colors.amber.shade800
                                : Theme.of(context).hintColor,
                          ),
                          onPressed: viewModel.toggleSelectedJourneyFavorite,
                          icon: Icon(
                            viewModel.isSelectedJourneyFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: viewModel.isSelectedJourneyFavorite
                                ? Colors.amber.shade700
                                : Theme.of(context).hintColor,
                          ),
                          label: Text(
                            viewModel.isSelectedJourneyFavorite
                                ? '경로 저장됨'
                                : '경로 저장',
                          ),
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

  Widget _buildStationField({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String? value,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return ScaleButton(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 64),
          child: Row(
            children: [
              Icon(icon, color: shuttleColor, size: 19),
              const SizedBox(width: 10),
              SizedBox(
                width: 34,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  value ?? '정류장을 선택하세요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        value == null ? FontWeight.normal : FontWeight.w600,
                    color: value == null ? Theme.of(context).hintColor : null,
                  ),
                ),
              ),
              if (isLoading)
                _buildPlatformLoadingIndicator(size: 16, strokeWidth: 2)
              else
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).hintColor,
                ),
            ],
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
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '즐겨찾는 이동',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 54,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fullWidth = constraints.maxWidth + 32;
                  return OverflowBox(
                    alignment: Alignment.center,
                    minWidth: fullWidth,
                    maxWidth: fullWidth,
                    child: _EdgeFadingHorizontalList(
                      height: 54,
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final favorite = favorites[index];
                        return ScaleButton(
                          onTap: () => viewModel.applyFavoriteJourney(favorite),
                          child: Container(
                            height: 50,
                            constraints: const BoxConstraints(maxWidth: 240),
                            padding: const EdgeInsets.only(left: 16),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 20,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    viewModel.favoriteDisplayName(favorite),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  iconSize: 18,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 40,
                                    height: 40,
                                  ),
                                  onSelected: (action) {
                                    if (action == 'rename') {
                                      _renameFavorite(favorite);
                                    } else {
                                      viewModel.removeFavoriteJourney(favorite);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Text('이름 변경'),
                                    ),
                                    PopupMenuItem(
                                        value: 'delete', child: Text('삭제')),
                                  ],
                                ),
                              ],
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
              (destination) => viewModel.stationIdsForLogicalName(
                destination.stationName,
              ),
            )
            .toSet();
    final pickerStations = isOrigin
        ? viewModel.logicalJourneyStations
        : viewModel.journeyDestinations
            .map(viewModel.stationForJourneyDestination)
            .toList(growable: false);
    final station = await showShuttleStationPicker(
      context: context,
      title: isOrigin ? '출발 정류장 선택' : '도착 정류장 선택',
      stations: pickerStations,
      favoriteStationsProvider: () => viewModel.favoriteStations,
      isStationFavorite: viewModel.isStationFavorite,
      onToggleFavorite: viewModel.toggleStationFavorite,
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
      Get.snackbar('알림', '출발지와 도착지는 달라야 합니다',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final result = await viewModel.searchJourneys();
    if (!mounted || result == null) return;
    Get.to(() => ShuttleJourneyResultView(initialResult: result));
  }

  Future<void> _renameFavorite(FavoriteShuttleJourney favorite) async {
    var editedName = favorite.customName ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('즐겨찾기 이름 변경'),
        content: TextFormField(
          initialValue: editedName,
          autofocus: true,
          maxLength: 30,
          onChanged: (value) => editedName = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
          decoration: const InputDecoration(hintText: '예: 등교'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, editedName),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (name != null) await viewModel.renameFavoriteJourney(favorite, name);
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
    Get.to(
      () => ShuttleStationMapView(
        initialDate: _selectedDateOrNull,
      ),
    );
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
                widget.routeSelectionOnly
                    ? '노선과 운행 날짜를 선택해 시간표를 조회하세요.'
                    : '출발지와 도착지를 선택해 셔틀을 찾아보세요.',
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

  Widget _buildMapShortcutButton() {
    return ScaleButton(
      onTap: _openStationMap,
      child: Container(
        width: 50,
        height: 50,
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
