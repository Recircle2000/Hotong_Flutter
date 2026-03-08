import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../viewmodel/shuttle_viewmodel.dart';
import '../components/auto_scroll_text.dart';
import 'dart:io' show Platform;
import 'naver_map_station_detail_view.dart'; // 네이버 지도 정류장 상세 정보 화면 임포트

class ShuttleRouteDetailView extends StatefulWidget {
  final int scheduleId;
  final String routeName;
  final int round;
  final String startTime;

  const ShuttleRouteDetailView({
    Key? key,
    required this.scheduleId,
    required this.routeName,
    required this.round,
    required this.startTime,
  }) : super(key: key);

  @override
  _ShuttleRouteDetailViewState createState() => _ShuttleRouteDetailViewState();
}

class _ShuttleRouteDetailViewState extends State<ShuttleRouteDetailView> {
  final ShuttleViewModel viewModel = Get.find<ShuttleViewModel>();

  @override
  void initState() {
    super.initState();
    // 화면이 열릴 때 정류장 정보 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.fetchScheduleStops(widget.scheduleId).then((success) {
        if (!success) {
          // 404 에러: 해당 스케줄의 정류장 정보가 없음
          _showNoStopsAlert(context);
        }
      });
    });
  }

  // 404 에러 - 정류장 정보가 없음을 알리는 팝업
  void _showNoStopsAlert(BuildContext context) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('알림'),
          content: Text('해당 스케줄의 정류장 정보가 없습니다.'),
          actions: [
            CupertinoDialogAction(
              child: Text('확인'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // 이전 화면으로 돌아가기
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('알림'),
          content: Text('해당 스케줄의 정류장 정보가 없습니다.'),
          actions: [
            TextButton(
              child: Text('확인'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // 이전 화면으로 돌아가기
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('노선 상세 정보'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 노선 정보 헤더
            _buildHeaderInfo(),

            SizedBox(height: 20),

            // 정류장 목록
            Expanded(
              child: _buildStopsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    const shuttleColor = Color(0xFFB83227);
    final brightness = Theme.of(context).brightness;
    final backgroundColor = brightness == Brightness.dark
        ? shuttleColor.withOpacity(0.2)
        : shuttleColor.withOpacity(0.1);
    final primaryTextColor =
        brightness == Brightness.dark ? Colors.redAccent : shuttleColor;
    final secondaryTextColor = primaryTextColor.withOpacity(0.78);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Obx(() {
        // 정류장 정보에서 출발 시간 가져오기 (stop_order가 1인 정류장)
        String departureTime = '';
        if (viewModel.scheduleStops.isNotEmpty) {
          try {
            // stop_order가 1인 정류장 찾기
            final firstStop = viewModel.scheduleStops.firstWhere(
              (stop) => stop.stopOrder == 1,
              orElse: () => viewModel.scheduleStops.first,
            );

            // HH:MM:SS 형식을 HH:MM으로 변환
            if (firstStop.arrivalTime.length >= 5) {
              departureTime = firstStop.arrivalTime.substring(0, 5);
            } else {
              departureTime = firstStop.arrivalTime;
            }
          } catch (e) {
            departureTime = widget.startTime;
          }
        } else {
          departureTime = widget.startTime;
        }

        final departureLabel = '$departureTime 출발';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.directions_bus_rounded,
                  color: shuttleColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AutoScrollText(
                    text: widget.routeName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.1,
                      color: primaryTextColor,
                    ),
                    height: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                departureLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: secondaryTextColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStopsList() {
    return Obx(
      () => viewModel.isLoadingStops.value
          ? Center(child: CircularProgressIndicator.adaptive())
          : viewModel.scheduleStops.isEmpty
              ? Center(child: Text('정류장 정보를 불러올 수 없습니다'))
              : Container(
                  decoration: BoxDecoration(
                    // border: Border.all(
                    //   color: Colors.grey.withOpacity(0.3),
                    //   width: 1,
                    // ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '정류장 정보',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '총 ${viewModel.scheduleStops.length}개 정류장',
                              style: TextStyle(
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
                      // 헤더 행
                      Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                              child: Text('순서',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.left), // 순서 번호 가운데 정렬
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '정류장',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center, // 정류장 이름 가운데 정렬
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('도착(경유) 시간',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.right), // 도착 시간 가운데 정렬
                            ),
                          ],
                        ),
                      ),

                      // 데이터 행
                      Expanded(
                        child: Platform.isIOS
                            ? ListView.builder(
                                itemCount: viewModel.scheduleStops.length,
                                itemBuilder: _buildStopItem,
                              )
                            : Scrollbar(
                                // Android 기본 스크롤바
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
                ),
    );
  }

  // 정류장 아이템 빌더
  Widget _buildStopItem(BuildContext context, int index) {
    final stop = viewModel.scheduleStops[index];
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 10,
            child: Text(
              '${stop.stopOrder}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(width: 50),
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
                style: TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left, // 텍스트 가운데 정렬
              ),
            ),
          ),
          SizedBox(width: 8),
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
                Container(
                  alignment: Alignment.topLeft, // 경유 시간 왼쪽 정렬
                  child: Text(
                    stop.arrivalTime.length > 5
                        ? stop.arrivalTime.substring(0, 5)
                        : stop.arrivalTime,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Platform.isIOS
                      ? CupertinoIcons.info_circle_fill
                      : Icons.info_outline,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 정류장 상세 정보가 없음을 알리는 팝업
  void _showNoStationDetailAlert(BuildContext context) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('정보 없음'),
          content: Text('이 정류장의 상세 정보가 없습니다.'),
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
          title: Text('정보 없음'),
          content: Text('이 정류장의 상세 정보가 없습니다.'),
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
