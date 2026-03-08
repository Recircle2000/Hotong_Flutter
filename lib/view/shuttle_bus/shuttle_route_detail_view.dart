import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../utils/responsive_layout.dart';
import '../../viewmodel/shuttle_viewmodel.dart';
import '../components/auto_scroll_text.dart';
import 'naver_map_station_detail_view.dart';

class ShuttleRouteDetailView extends StatefulWidget {
  final int scheduleId;
  final String routeName;
  final int round;
  final String startTime;

  const ShuttleRouteDetailView({
    super.key,
    required this.scheduleId,
    required this.routeName,
    required this.round,
    required this.startTime,
  });

  @override
  State<ShuttleRouteDetailView> createState() => _ShuttleRouteDetailViewState();
}

class _ShuttleRouteDetailViewState extends State<ShuttleRouteDetailView> {
  static const shuttleColor = Color(0xFFB83227);

  final ShuttleViewModel viewModel = Get.find<ShuttleViewModel>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.fetchScheduleStops(widget.scheduleId).then((success) {
        if (!success && mounted) {
          _showNoStopsAlert(context);
        }
      });
    });
  }

  void _showNoStopsAlert(BuildContext context) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('알림'),
          content: const Text('해당 스케줄의 정류장 정보가 없습니다.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림'),
        content: const Text('해당 스케줄의 정류장 정보가 없습니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppResponsive.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '노선 상세 정보',
          style:
              TextStyle(fontSize: layout.font(20), fontWeight: FontWeight.w700),
        ),
      ),
      body: AppPageFrame(
        child: Padding(
          padding: EdgeInsets.all(layout.space(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderInfo(context),
              SizedBox(height: layout.space(20)),
              Expanded(child: _buildStopsList(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context) {
    final layout = AppResponsive.of(context);
    final brightness = Theme.of(context).brightness;
    final backgroundColor = brightness == Brightness.dark
        ? shuttleColor.withOpacity(0.2)
        : shuttleColor.withOpacity(0.1);
    final primaryTextColor =
        brightness == Brightness.dark ? Colors.redAccent : shuttleColor;
    final secondaryTextColor = primaryTextColor.withOpacity(0.78);

    return Container(
      padding: EdgeInsets.all(layout.space(16)),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(layout.radius(25)),
      ),
      child: Obx(() {
        var departureTime = widget.startTime;
        if (viewModel.scheduleStops.isNotEmpty) {
          try {
            final firstStop = viewModel.scheduleStops.firstWhere(
              (stop) => stop.stopOrder == 1,
              orElse: () => viewModel.scheduleStops.first,
            );
            departureTime = firstStop.arrivalTime.length >= 5
                ? firstStop.arrivalTime.substring(0, 5)
                : firstStop.arrivalTime;
          } catch (_) {}
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_bus_rounded,
                  color: shuttleColor,
                  size: layout.icon(22),
                ),
                SizedBox(width: layout.space(8)),
                Expanded(
                  child: AutoScrollText(
                    text: widget.routeName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: layout.font(22, maxScale: 1.12),
                      height: 1.1,
                      color: primaryTextColor,
                    ),
                    height: layout.space(28, maxScale: 1.10),
                  ),
                ),
              ],
            ),
            SizedBox(height: layout.space(8)),
            Padding(
              padding: EdgeInsets.only(left: layout.space(30)),
              child: Text(
                '$departureTime 출발',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: layout.font(13),
                  color: secondaryTextColor,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStopsList(BuildContext context) {
    final layout = AppResponsive.of(context);

    return Obx(() {
      if (viewModel.isLoadingStops.value) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }

      if (viewModel.scheduleStops.isEmpty) {
        return Center(
          child: Text(
            '정류장 정보를 불러올 수 없습니다',
            style: TextStyle(fontSize: layout.font(14)),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(layout.radius(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: layout.space(10, maxScale: 1.08),
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(layout.space(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '정류장 정보',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: layout.font(16),
                    ),
                  ),
                  Text(
                    '총 ${viewModel.scheduleStops.length}개 정류장',
                    style: TextStyle(
                      fontSize: layout.font(13),
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.withOpacity(0.3),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                vertical: layout.space(12),
                horizontal: layout.space(16),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).cardColor.withOpacity(0.5)
                    : Theme.of(context)
                        .scaffoldBackgroundColor
                        .withOpacity(0.8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      '순서',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: layout.font(13),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '정류장',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: layout.font(13),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '도착(경유) 시간',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: layout.font(13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Platform.isIOS
                  ? ListView.builder(
                      itemCount: viewModel.scheduleStops.length,
                      itemBuilder: _buildStopItem,
                    )
                  : Scrollbar(
                      interactive: true,
                      thumbVisibility: true,
                      child: ListView.builder(
                        itemCount: viewModel.scheduleStops.length,
                        itemBuilder: _buildStopItem,
                      ),
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStopItem(BuildContext context, int index) {
    final layout = AppResponsive.of(context);
    final stop = viewModel.scheduleStops[index];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: layout.space(12),
        horizontal: layout.space(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: layout.space(10, maxScale: 1.08),
            child: Text(
              '${stop.stopOrder}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: layout.font(16),
              ),
            ),
          ),
          SizedBox(width: layout.space(50, maxScale: 1.10)),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (stop.stationId != null) {
                  Get.to(() =>
                      NaverMapStationDetailView(stationId: stop.stationId!));
                } else {
                  _showNoStationDetailAlert(context);
                }
              },
              child: Text(
                stop.stationName,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: layout.font(14),
                ),
              ),
            ),
          ),
          SizedBox(width: layout.space(8)),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              if (stop.stationId != null) {
                Get.to(() =>
                    NaverMapStationDetailView(stationId: stop.stationId!));
              } else {
                _showNoStationDetailAlert(context);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stop.arrivalTime.length > 5
                      ? stop.arrivalTime.substring(0, 5)
                      : stop.arrivalTime,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: layout.font(14),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(width: layout.space(4, maxScale: 1.05)),
                Icon(
                  Platform.isIOS
                      ? CupertinoIcons.info_circle_fill
                      : Icons.info_outline,
                  size: layout.icon(14),
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNoStationDetailAlert(BuildContext context) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('정보 없음'),
          content: const Text('이 정류장의 상세 정보가 없습니다.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정보 없음'),
        content: const Text('이 정류장의 상세 정보가 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
