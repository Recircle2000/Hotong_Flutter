import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/city_bus/view/bus_map_view.dart';
import 'package:hsro/features/city_bus/viewmodel/busmap_viewmodel.dart';
import 'package:hsro/features/home/viewmodel/upcoming_departures_arrival_viewmodel.dart';
import 'package:hsro/features/home/widgets/upcoming_departures_widget.dart';
import 'package:hsro/features/shuttle/view/shuttle_route_detail_view.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';
import 'package:hsro/shared/widgets/auto_scroll_text.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

class UpcomingDeparturesArrivalWidget extends StatefulWidget {
  const UpcomingDeparturesArrivalWidget({super.key});

  @override
  State<UpcomingDeparturesArrivalWidget> createState() =>
      _UpcomingDeparturesArrivalWidgetState();
}

class _UpcomingDeparturesArrivalWidgetState
    extends State<UpcomingDeparturesArrivalWidget> with RouteAware {
  late final UpcomingDeparturesArrivalViewModel viewModel;
  final RouteObserver<PageRoute> _routeObserver =
      Get.find<RouteObserver<PageRoute>>();

  @override
  void initState() {
    super.initState();
    // 위치 기반 곧 도착 전용 ViewModel 사용
    viewModel = Get.isRegistered<UpcomingDeparturesArrivalViewModel>()
        ? Get.find<UpcomingDeparturesArrivalViewModel>()
        : Get.put(UpcomingDeparturesArrivalViewModel());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 페이지 전환 시 위젯 활성 상태를 맞추기 위해 구독
    _routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void didPush() {
    // 화면 진입 시 위치 기반 위젯 활성화
    unawaited(viewModel.setWidgetEnabled(true));
    super.didPush();
  }

  @override
  void didPopNext() {
    // 다른 화면에서 복귀 시 재활성화
    unawaited(viewModel.setWidgetEnabled(true));
    super.didPopNext();
  }

  @override
  void didPushNext() {
    // 다른 화면으로 이동 시 비활성화
    unawaited(viewModel.setWidgetEnabled(false));
    super.didPushNext();
  }

  @override
  void didPop() {
    // 화면에서 제거될 때 비활성화
    unawaited(viewModel.setWidgetEnabled(false));
    super.didPop();
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    unawaited(viewModel.setWidgetEnabled(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String? fallbackCampus = viewModel.fallbackCampus.value;

      // 캠퍼스 내부 판정이면 기존 곧 출발 위젯으로 fallback
      if (viewModel.shouldShowFallbackUpcomingWidget.value &&
          fallbackCampus != null) {
        return UpcomingDeparturesWidget(
          key: ValueKey('location-based-fallback-$fallbackCampus'),
          campusOverride: fallbackCampus,
          controllerTag: 'location_based_upcoming_departure_$fallbackCampus',
          enableAutoRefresh: true,
        );
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더와 위치 상태 칩
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '곧 도착',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _buildHeaderSubtitle(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildLiveStatusChip(context),
              ],
            ),
            const SizedBox(height: 5),
            // 에러, 로딩, 데이터 상태에 따라 본문 전환
            if (viewModel.error.isNotEmpty)
              Container(
                height: 200,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    viewModel.error.value,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (viewModel.isLoading.value)
              Container(
                height: 210,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              )
            else
              Container(
                height: 210,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 셔틀 도착 정보 영역
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, '셔틀버스'),
                          viewModel.shuttleArrivals.isEmpty
                              ? _buildEmptyMessage(
                                  context,
                                  viewModel.shuttleEmptyMessage.value,
                                )
                              : Column(
                                  children: viewModel.shuttleArrivals
                                      .take(3)
                                      .map(
                                        (arrival) => _buildCompactShuttleItem(
                                          context,
                                          arrival,
                                        ),
                                      )
                                      .toList(),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 시내버스 도착 정보 영역
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, '시내버스'),
                          viewModel.busArrivals.isEmpty
                              ? _buildEmptyMessage(
                                  context,
                                  viewModel.busEmptyMessage.value,
                                )
                              : Column(
                                  children: viewModel.busArrivals
                                      .take(3)
                                      .map(
                                        (arrival) => _buildCompactBusItem(
                                          context,
                                          arrival,
                                        ),
                                      )
                                      .toList(),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  String _buildHeaderSubtitle() {
    // 현재 선택된 브랜치에 맞는 부제 문구 생성
    final String? preferredStopName =
        viewModel.nearbyShuttleStop.value?.station.name ??
            viewModel.nearbyBusStop.value?.displayName;

    switch (viewModel.branchMode.value) {
      case ArrivalBranchMode.asanLocationArrival:
      case ArrivalBranchMode.cheonanLocationArrival:
        return preferredStopName != null
            ? '$preferredStopName 정류장 기준'
            : '현재 위치 기반 주변 정류장 도착 정보';
      case ArrivalBranchMode.fallbackDefaultWidget:
        return '캠퍼스 내부로 인식되어 기본 위젯 사용';
      case ArrivalBranchMode.noNearbyStop:
        return viewModel.statusMessage.value;
    }
  }

  Widget _buildEmptyMessage(BuildContext context, String message) {
    // 주변 정류장 없음 또는 도착 정보 없음 상태 카드
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15.5, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4, left: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildLiveStatusChip(BuildContext context) {
    // 위치 서비스/권한/새로고침 상태를 한 칩으로 표시
    final bool isRefreshing = viewModel.isRefreshing.value;
    final bool isLocationServiceEnabled =
        viewModel.isLocationServiceEnabled.value;
    final bool isLocationPermissionGranted =
        viewModel.isLocationPermissionGranted.value;
    final Color accentColor = !isLocationServiceEnabled
        ? Colors.orange
        : !isLocationPermissionGranted
            ? Colors.redAccent
            : Theme.of(context).colorScheme.primary;
    final String label = !isLocationServiceEnabled
        ? '위치 서비스 꺼짐'
        : !isLocationPermissionGranted
            ? '위치 권한 허용 안됨'
            : isRefreshing
                ? '위치 조회중'
                : '실시간';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLocationServiceEnabled)
            Icon(
              Icons.location_disabled,
              size: 12,
              color: accentColor,
            )
          else if (!isLocationPermissionGranted)
            Icon(
              Icons.location_off,
              size: 12,
              color: accentColor,
            )
          else if (isRefreshing)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            )
          else
            Icon(
              Icons.location_on,
              size: 12,
              color: accentColor,
            ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactShuttleItem(
    BuildContext context,
    LocationShuttleArrival arrival,
  ) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ScaleButton(
        onTap: () {
          // 셔틀 도착 항목 탭 시 상세 시간표로 이동
          if (!Get.isRegistered<ShuttleViewModel>()) {
            Get.put(ShuttleViewModel());
          }

          Get.to(
            () => ShuttleRouteDetailView(
              scheduleId: arrival.scheduleId,
              routeName: arrival.routeName,
              round: 0,
              startTime:
                  '${arrival.arrivalTime.hour.toString().padLeft(2, '0')}:${arrival.arrivalTime.minute.toString().padLeft(2, '0')}',
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.airport_shuttle,
                    color: Colors.deepOrange,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoScrollText(
                        text: arrival.routeName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${arrival.arrivalTime.hour.toString().padLeft(2, '0')}:${arrival.arrivalTime.minute.toString().padLeft(2, '0')} 예정',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (arrival.isLastBus)
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Text(
                                '막차',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getMinuteBadgeColor(arrival.minutesLeft)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '${arrival.minutesLeft}분',
                    style: TextStyle(
                      color: _getMinuteBadgeColor(arrival.minutesLeft),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactBusItem(
    BuildContext context,
    LocationBusArrival arrival,
  ) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // 시간표 기반과 실시간 기반 배지 규칙 분리
    final bool isScheduled = arrival.kind == LocationBusArrivalKind.scheduled;
    final Color badgeColor = isScheduled
        ? _getMinuteBadgeColor(arrival.minutesLeft ?? 0)
        : _getStopsAwayColor(arrival.stopsAway ?? 0);
    final String subtitle = isScheduled
        ? '${_formatTime(arrival.departureTime!)} 출발'
        : '현재: ${arrival.currentNodeName}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ScaleButton(
        onTap: () {
          // 버스 항목 탭 시 해당 노선 지도 화면으로 이동
          Get.to(
            () => BusMapView(
              initialRoute: arrival.routeKey,
              initialDestination: arrival.targetStopName,
            ),
            binding: BindingsBuilder(() {
              if (!Get.isRegistered<BusMapViewModel>()) {
                Get.put(
                  BusMapViewModel(initialRouteOverride: arrival.routeKey),
                );
              }
            }),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Colors.blue,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoScrollText(
                        text:
                            '${arrival.routeName} · ${arrival.targetStopName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    arrival.badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    // HH:mm 형식으로 변환
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Color _getMinuteBadgeColor(int minutes) {
    // 임박할수록 경고 색상 강조
    if (minutes <= 5) {
      return Colors.red;
    }
    if (minutes <= 15) {
      return Colors.orange;
    }
    return Colors.green;
  }

  Color _getStopsAwayColor(int stopsAway) {
    // 남은 정류장 수가 적을수록 경고 색상 강조
    if (stopsAway <= 1) {
      return Colors.red;
    }
    if (stopsAway == 2) {
      return Colors.orange;
    }
    return Colors.green;
  }
}
