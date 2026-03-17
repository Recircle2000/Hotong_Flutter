import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../viewmodel/busmap_viewmodel.dart';
import '../../viewmodel/shuttle_viewmodel.dart';
import '../../viewmodel/upcoming_departures_arrival_viewmodel.dart';
import '../city_bus/bus_map_view.dart';
import '../shuttle_bus/shuttle_route_detail_view.dart';
import 'auto_scroll_text.dart';
import 'scale_button.dart';
import 'upcoming_departures_widget.dart';

class UpcomingDeparturesArrivalWidget extends StatefulWidget {
  const UpcomingDeparturesArrivalWidget({super.key});

  @override
  State<UpcomingDeparturesArrivalWidget> createState() =>
      _UpcomingDeparturesArrivalWidgetState();
}

class _UpcomingDeparturesArrivalWidgetState
    extends State<UpcomingDeparturesArrivalWidget> {
  late final UpcomingDeparturesArrivalViewModel viewModel;

  int _remainingSeconds = 30;
  Timer? _refreshCountdownTimer;

  @override
  void initState() {
    super.initState();
    viewModel = Get.isRegistered<UpcomingDeparturesArrivalViewModel>()
        ? Get.find<UpcomingDeparturesArrivalViewModel>()
        : Get.put(UpcomingDeparturesArrivalViewModel());

    viewModel.setRefreshCallback(_startRefreshCountdown);
    _startRefreshCountdown();
  }

  @override
  void dispose() {
    _refreshCountdownTimer?.cancel();
    viewModel.clearRefreshCallback();
    super.dispose();
  }

  void _startRefreshCountdown() {
    _refreshCountdownTimer?.cancel();

    if (!viewModel.shouldUseRefreshCountdown) {
      if (mounted) {
        setState(() {
          _remainingSeconds = 0;
        });
      } else {
        _remainingSeconds = 0;
      }
      return;
    }

    if (mounted) {
      setState(() {
        _remainingSeconds = viewModel.refreshIntervalSeconds;
      });
    } else {
      _remainingSeconds = viewModel.refreshIntervalSeconds;
    }

    _refreshCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (!viewModel.shouldUseRefreshCountdown) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
        return;
      }

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _remainingSeconds = viewModel.refreshIntervalSeconds;
        }
      });
    });
  }

  void _manualRefresh() {
    viewModel.refreshLocation();
    _startRefreshCountdown();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String? fallbackCampus = viewModel.fallbackCampus.value;

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
                viewModel.isRefreshing.value
                    ? const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                        ),
                      )
                    : Text(
                        viewModel.shouldUseRefreshCountdown
                            ? '$_remainingSeconds초'
                            : '-',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                const SizedBox(width: 4),
                ScaleButton(
                  onTap: _manualRefresh,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.refresh,
                      size: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
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
        return '위치 또는 주변 정류장 확인 중';
    }
  }

  Widget _buildEmptyMessage(BuildContext context, String message) {
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

  Widget _buildCompactShuttleItem(
    BuildContext context,
    LocationShuttleArrival arrival,
  ) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ScaleButton(
        onTap: () {
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
    final bool isScheduled = arrival.kind == LocationBusArrivalKind.scheduled;
    final Color badgeColor = isScheduled
        ? _getMinuteBadgeColor(arrival.minutesLeft ?? 0)
        : _getStopsAwayColor(arrival.stopsAway ?? 0);
    final String subtitle = isScheduled
        ? '${_formatTime(arrival.departureTime!)} 출발'
        : '현재 ${arrival.currentNodeName}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ScaleButton(
        onTap: () {
          Get.to(
            () => BusMapView(
              initialRoute: arrival.routeKey,
              initialDestination: arrival.targetStopName,
            ),
            binding: BindingsBuilder(() {
              if (!Get.isRegistered<BusMapViewModel>()) {
                Get.put(BusMapViewModel());
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
                        text: '${arrival.routeName} · ${arrival.targetStopName}',
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
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Color _getMinuteBadgeColor(int minutes) {
    if (minutes <= 5) {
      return Colors.red;
    }
    if (minutes <= 15) {
      return Colors.orange;
    }
    return Colors.green;
  }

  Color _getStopsAwayColor(int stopsAway) {
    if (stopsAway <= 1) {
      return Colors.red;
    }
    if (stopsAway == 2) {
      return Colors.orange;
    }
    return Colors.green;
  }
}
