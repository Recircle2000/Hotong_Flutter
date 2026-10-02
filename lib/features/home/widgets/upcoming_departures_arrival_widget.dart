import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/city_bus/view/bus_map_view.dart';
import 'package:hsro/features/city_bus/viewmodel/busmap_viewmodel.dart';
import 'package:hsro/features/home/viewmodel/upcoming_departures_arrival_viewmodel.dart';
import 'package:hsro/features/home/widgets/upcoming_departure_card.dart';
import 'package:hsro/features/home/widgets/upcoming_departures_widget.dart';
import 'package:hsro/features/shuttle/view/shuttle_route_detail_view.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';

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
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Text(
                    '곧 도착',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: UpcomingDepartureColors.title(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _buildHeaderSubtitle(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: UpcomingDepartureColors.secondary(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLiveStatusChip(context),
                ],
              ),
            ),
            // 에러, 로딩, 데이터 상태에 따라 본문 전환
            if (viewModel.error.isNotEmpty)
              Container(
                height: upcomingDepartureBodyHeight,
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
                height: upcomingDepartureBodyHeight,
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
                height: upcomingDepartureBodyHeight,
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
                          const UpcomingDepartureSectionTitle('셔틀버스'),
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
                          const UpcomingDepartureSectionTitle('시내버스'),
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
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
      decoration: BoxDecoration(
        color: UpcomingDepartureColors.card(context),
        borderRadius: BorderRadius.circular(16),
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
    final String arrivalTime = _formatTime(arrival.arrivalTime);

    return UpcomingDepartureCard(
      primaryText: formatMinutesLeft(arrival.minutesLeft),
      primaryColor: _getMinuteBadgeColor(arrival.minutesLeft),
      trailingText: arrivalTime,
      description: arrival.routeName,
      isLastBus: arrival.isLastBus,
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
            startTime: arrivalTime,
          ),
        );
      },
    );
  }

  Widget _buildCompactBusItem(
    BuildContext context,
    LocationBusArrival arrival,
  ) {
    // 시간표 기반과 실시간 기반 표시 규칙 분리
    final bool isScheduled = arrival.kind == LocationBusArrivalKind.scheduled;

    return UpcomingDepartureCard(
      primaryText: isScheduled
          ? formatMinutesLeft(arrival.minutesLeft ?? 0)
          : arrival.badgeText,
      primaryColor: isScheduled
          ? _getMinuteBadgeColor(arrival.minutesLeft ?? 0)
          : _getStopsAwayColor(arrival.stopsAway ?? 0),
      // 시간표 기반은 출발 시각, 실시간 기반은 현재 위치 표시
      trailingText: isScheduled
          ? _formatTime(arrival.departureTime!)
          : arrival.currentNodeName,
      routeLabel: arrival.routeName,
      description: arrival.targetStopName,
      scrollDescription: true,
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
    );
  }

  String _formatTime(DateTime dateTime) {
    // HH:mm 형식으로 변환
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // 15분 초과는 null(기본 글자색)
  Color? _getMinuteBadgeColor(int minutes) {
    // 임박할수록 경고 색상 강조
    if (minutes <= 5) {
      return Colors.red;
    }
    if (minutes <= 15) {
      return Colors.orange;
    }
    return null;
  }

  // 3정류장 이상은 null(기본 글자색)
  Color? _getStopsAwayColor(int stopsAway) {
    // 남은 정류장 수가 적을수록 경고 색상 강조
    if (stopsAway <= 1) {
      return Colors.red;
    }
    if (stopsAway == 2) {
      return Colors.orange;
    }
    return null;
  }
}
