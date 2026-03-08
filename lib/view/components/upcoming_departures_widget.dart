import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../../viewmodel/upcoming_departure_viewmodel.dart';
import '../shuttle_bus/shuttle_route_detail_view.dart';
import '../../viewmodel/shuttle_viewmodel.dart';
import '../city_bus/bus_map_view.dart';
import 'auto_scroll_text.dart';
import 'scale_button.dart';
import '../../viewmodel/busmap_viewmodel.dart';

class UpcomingDeparturesWidget extends StatefulWidget {
  UpcomingDeparturesWidget({Key? key}) : super(key: key);

  @override
  _UpcomingDeparturesWidgetState createState() =>
      _UpcomingDeparturesWidgetState();
}

class _UpcomingDeparturesWidgetState extends State<UpcomingDeparturesWidget>
    with RouteAware {
  final UpcomingDepartureViewModel viewModel =
      Get.put(UpcomingDepartureViewModel());
  int _remainingSeconds = 30; // 자동 새로고침까지 남은 시간(초)
  Timer? _refreshCountdownTimer;

  final RouteObserver<PageRoute> _routeObserver =
      Get.find<RouteObserver<PageRoute>>();

  @override
  void initState() {
    super.initState();

    // 뷰모델의 새로고침 콜백 등록
    viewModel.setRefreshCallback(() {
      // 뷰모델에서 새로고침이 발생할 때 카운트다운 초기화
      _startRefreshCountdown();
    });

    // 초기 타이머 시작
    _startRefreshCountdown();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 라우트 옵저버에 등록
    _routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPush() {
    // 새 페이지가 이 위젯으로 푸시될 때 (진입할 때)
    viewModel.setHomePageState(true);
    _resetTimerDisplay();
    super.didPush();
  }

  @override
  void didPopNext() {
    // 이 페이지가 최상위로 올라왔을 때 (다른 페이지에서 돌아왔을 때)
    viewModel.setHomePageState(true);
    _resetTimerDisplay();
    super.didPopNext();
  }

  @override
  void didPushNext() {
    // 이 페이지 위에 새 페이지가 푸시될 때 (다른 페이지로 이동할 때)
    viewModel.setHomePageState(false);
    super.didPushNext();
  }

  @override
  void didPop() {
    // 이 페이지가 스택에서 제거될 때 (뒤로가기 등)
    viewModel.setHomePageState(false);
    super.didPop();
  }

  @override
  void dispose() {
    _refreshCountdownTimer?.cancel();
    // 라우트 옵저버에서 구독 해제
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _startRefreshCountdown() {
    // 기존 타이머 취소
    _refreshCountdownTimer?.cancel();

    // 천안 캠퍼스는 5초, 나머지는 30초
    final countdownSeconds =
        viewModel.settingsViewModel.selectedCampus.value == '천안' ? 5 : 30;

    // 초기값 설정
    _remainingSeconds = countdownSeconds;

    // 1초마다 카운트다운
    _refreshCountdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          // 카운트다운 종료 시 다시 시작 (캠퍼스 변경 시 간격도 변경 가능하도록)
          final newCountdownSeconds =
              viewModel.settingsViewModel.selectedCampus.value == '천안' ? 5 : 30;
          _remainingSeconds = newCountdownSeconds;
          // 타이머 초기화와 동시에 수행되는 자동 새로고침
          // 뷰모델의 타이머가 자동으로 새로고침을 실행하므로 여기서는 호출하지 않음
        }
      });
    });
  }

  // 수동 새로고침 시 카운트다운도 리셋
  void _manualRefresh() {
    viewModel.loadData();
    _startRefreshCountdown();
  }

  // 타이머 디스플레이를 리셋하는 메소드
  void _resetTimerDisplay() {
    setState(() {
      final countdownSeconds =
          viewModel.settingsViewModel.selectedCampus.value == '천안' ? 5 : 30;
      _remainingSeconds = countdownSeconds;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Icons.timer,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '곧 출발',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Obx(() => Text(
                      '${viewModel.settingsViewModel.selectedCampus.value == '천안' ? '기점 출발 기준 / 실시간 도착 정보 제공' : '아캠 출발 기준'} ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    )),
              ),
              const SizedBox(width: 8),
              Obx(() => viewModel.isRefreshing.value
                  ? SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                      ),
                    )
                  : Text(
                      '${_remainingSeconds}초',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    )),
              const SizedBox(width: 4),
              ScaleButton(
                onTap: _manualRefresh,
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(
                    Icons.refresh,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),

          //const SizedBox(height: 8),

          // 로딩 상태에 따른 표시
          Obx(() {
            if (viewModel.isLoading.value) {
              return Container(
                height: 210, // 로딩 상태에서의 고정된 높이
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            if (viewModel.error.isNotEmpty) {
              return Container(
                height: 200, // 에러 상태에서의 고정된 높이
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    viewModel.error.value,
                    style: TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // // 셔틀과 시내버스 데이터 모두 없는 경우
            // if (viewModel.upcomingShuttles.isEmpty && viewModel.upcomingCityBuses.isEmpty) {
            //   String message;
            //   if (viewModel.isShuttleServiceEnded.value && viewModel.isCityBusServiceEnded.value) {
            //     message = '오늘 모든 셔틀버스/시내버스 운행 종료';
            //   } else if (viewModel.isShuttleServiceEnded.value) {
            //     message = '오늘 운행 종료';
            //   } else if (viewModel.isCityBusServiceEnded.value) {
            //     message = '오늘 운행 종료';
            //   } else {
            //     message = '90분 내에 출발 예정인 버스/셔틀이 없습니다';
            //   }
            //   return Container(
            //     height: 200, // 데이터 없음 상태에서의 고정된 높이
            //     decoration: BoxDecoration(
            //       color: Theme.of(context).cardColor,
            //       borderRadius: BorderRadius.circular(12),
            //       border: Border.all(
            //         color: Colors.grey.withOpacity(0.2),
            //         width: 1,
            //       ),
            //     ),
            //     child: Center(
            //       child: Text(
            //         message,
            //         style: TextStyle(
            //           color: Colors.grey,
            //           fontSize: 12,
            //         ),
            //         textAlign: TextAlign.center,
            //       ),
            //     ),
            //   );
            // }

            // 기본 데이터가 있는 경우는 고정된 컨테이너로 감싸기
            return Container(
              height: 210, // 데이터 표시 상태에서의 고정된 높이
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 셔틀버스 (왼쪽)
                  Expanded(
                    child: Container(
                      //height: 210,
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // 추가
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, '셔틀버스'),
                          viewModel.upcomingShuttles.isEmpty
                              ? _buildEmptyMessage(context, '셔틀')
                              : Column(
                                  children: viewModel.upcomingShuttles
                                      .take(3) // 최대 2개만 표시
                                      .map(
                                          (shuttle) => _buildCompactShuttleItem(
                                                context,
                                                shuttle,
                                                Colors.deepOrange,
                                                Icons.airport_shuttle,
                                              ))
                                      .toList(),
                                ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: 10),

                  // 시내버스 (오른쪽)
                  Expanded(
                    child: Container(
                      // height: 210,
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // 추가
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, '시내버스'),
                          // 천안 캠퍼스: 실시간 버스 + 기존 시내버스 합쳐서 최대 3개
                          if (viewModel
                                  .settingsViewModel.selectedCampus.value ==
                              '천안')
                            Obx(() {
                              final combinedBuses = [
                                ...viewModel.ceRealtimeBuses,
                                ...viewModel.upcomingCityBuses,
                              ];
                              if (combinedBuses.isEmpty) {
                                return _buildEmptyMessage(context, '버스');
                              }
                              return Column(
                                children: combinedBuses.take(3).map((bus) {
                                  // destination이 "호서대(천안)"이고 routeKey가 24_DOWN 또는 81_DOWN이면 실시간 버스
                                  final isRealtime =
                                      bus.destination == '호서대천캠' &&
                                          (bus.routeKey == '24_DOWN' ||
                                              bus.routeKey == '81_DOWN');
                                  return _buildCompactBusItem(
                                    context,
                                    bus,
                                    isRealtime ? Colors.blue : Colors.blue,
                                    isRealtime
                                        ? Icons.location_on
                                        : Icons.directions_bus,
                                  );
                                }).toList(),
                              );
                            }),
                          // 아산 캠퍼스: 기존 시내버스만 최대 3개
                          if (viewModel
                                  .settingsViewModel.selectedCampus.value !=
                              '천안')
                            Obx(() => viewModel.upcomingCityBuses.isEmpty
                                ? _buildEmptyMessage(context, '버스')
                                : Column(
                                    children: viewModel.upcomingCityBuses
                                        .take(3)
                                        .map((cityBus) => _buildCompactBusItem(
                                              context,
                                              cityBus,
                                              Colors.blue,
                                              Icons.directions_bus,
                                            ))
                                        .toList(),
                                  )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyMessage(BuildContext context, String type) {
    String message;
    String? firstTimeText;
    if (type == '셔틀' && viewModel.isShuttleServiceNotOperated.value) {
      message = '오늘 셔틀버스 운행 없음';
    } else if (type == '셔틀' && viewModel.isShuttleServiceEnded.value) {
      message = '오늘 셔틀버스 운행 종료';
    } else if (type == '버스' && viewModel.isCityBusServiceEnded.value) {
      message = '오늘 시내버스 운행 종료';
    } else {
      message = '90분 내 출발 $type 없음';
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15.5, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            if (firstTimeText != null) ...[
              SizedBox(height: 4),
              Text(
                firstTimeText,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
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

  // 셔틀버스용 아이템 (노선명만 표시)
  Widget _buildCompactShuttleItem(
    BuildContext context,
    BusDeparture departure,
    Color color,
    IconData icon,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ScaleButton(
        onTap: () {
          // 셔틀버스 클릭 시 상세 페이지로 이동

          // 해당 셔틀의 scheduleId가 있는 경우에만 이동
          if (departure.scheduleId != null) {
            // ShuttleViewModel이 없는 경우 초기화 (Get.find 오류 방지)
            if (!Get.isRegistered<ShuttleViewModel>()) {
              Get.put(ShuttleViewModel());
            }

            // 셔틀 상세 화면으로 이동
            Get.to(() => ShuttleRouteDetailView(
                  scheduleId: departure.scheduleId!, // 각 셔틀의 scheduleId 사용
                  routeName: departure.destination, // 노선명 전달
                  round: 0, // 기본값으로 0 (0으로 설정시 표시되지 않음)
                  startTime:
                      '${departure.departureTime.hour.toString().padLeft(2, '0')}:${departure.departureTime.minute.toString().padLeft(2, '0')}', // 출발 시간 전달
                ));
          } else {
            // scheduleId가 없는 경우 스낵바 표시
            Get.snackbar(
              '정보 없음',
              '해당 셔틀의 상세 정보를 불러올 수 없습니다.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red.withOpacity(0.1),
              colorText: Colors.red,
              duration: Duration(seconds: 2),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoScrollText(
                        text: departure.destination,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${departure.departureTime.hour.toString().padLeft(2, '0')}:${departure.departureTime.minute.toString().padLeft(2, '0')} 출발',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (departure.isLastBus) // 막차 표시
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
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
                    color:
                        _getTimeColor(departure.minutesLeft).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '${departure.minutesLeft}분',
                    style: TextStyle(
                      color: _getTimeColor(departure.minutesLeft),
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

  // 시내버스용 아이템 (노선명 → 목적지 표시)
  Widget _buildCompactBusItem(
    BuildContext context,
    BusDeparture departure,
    Color color,
    IconData icon,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ScaleButton(
        onTap: () {
          // 시내버스 클릭 시 햅틱 피드백 제공

          // BusMapView로 이동 (클릭한 노선 정보와 목적지 전달)
          Get.to(
            () => BusMapView(
              initialRoute: departure.routeName,
              initialDestination: departure.destination,
            ),
            // 페이지가 닫힐 때 컨트롤러 제거를 위한 바인딩 (웹소켓 연결 해제)
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 자동 롤링 텍스트
                      AutoScrollText(
                        text:
                            '${departure.routeName} → ${departure.destination}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          // 실시간 버스인지 확인
                          final isRealtime = departure.destination == '호서대천캠' &&
                              (departure.routeKey == '24_DOWN' ||
                                  departure.routeKey == '81_DOWN');

                          // 실시간 버스가 아닐 때만 출발 시간 표시
                          if (isRealtime) {
                            // 실시간 버스는 문자열 그대로 출력, Row를 Expanded로 감싸 overflow 방지
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '위치 : ' +
                                        departure.departureTime.toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    softWrap: false,
                                    maxLines: 1,
                                  ),
                                ),
                                if (departure.isLastBus)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 5),
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
                            );
                          }

                          return Row(
                            children: [
                              Text(
                                '${departure.departureTime.hour.toString().padLeft(2, '0')}:${departure.departureTime.minute.toString().padLeft(2, '0')} 출발',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (departure.isLastBus)
                                Padding(
                                  padding: const EdgeInsets.only(left: 5),
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
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) {
                    // 실시간 버스인지 확인 (destination이 "호서대(천안)"이고 routeKey가 24_DOWN 또는 81_DOWN)
                    final isRealtime = departure.destination == '호서대천캠' &&
                        (departure.routeKey == '24_DOWN' ||
                            departure.routeKey == '81_DOWN');

                    String displayText;
                    Color badgeColor;

                    if (isRealtime) {
                      // 실시간 버스: 남은 정거장 표시
                      final left = departure.minutesLeft;
                      if (left == 1) {
                        displayText = '전';
                        badgeColor = Colors.red;
                      } else if (left == 2) {
                        displayText = '전전';
                        badgeColor = Colors.orange;
                      } else if (left >= 3) {
                        displayText = '${left}전';
                        badgeColor = Colors.green;
                      } else {
                        displayText = '';
                        badgeColor = Colors.blue;
                      }
                    } else {
                      // 기존 시내버스: 분 표시
                      displayText = '${departure.minutesLeft}분';
                      badgeColor = _getTimeColor(departure.minutesLeft);
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        displayText,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTimeColor(int minutes) {
    if (minutes <= 5) {
      return Colors.red;
    } else if (minutes <= 15) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
}
