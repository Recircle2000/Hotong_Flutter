import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:hsro/features/city_bus/view/bus_map_view.dart';
import 'package:hsro/features/city_bus/viewmodel/busmap_viewmodel.dart';
import 'package:hsro/features/home/viewmodel/upcoming_departure_viewmodel.dart';
import 'package:hsro/features/shuttle/view/shuttle_route_detail_view.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';
import 'package:hsro/features/home/widgets/upcoming_departure_card.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

class UpcomingDeparturesWidget extends StatefulWidget {
  UpcomingDeparturesWidget({
    Key? key,
    this.campusOverride,
    this.controllerTag,
    this.enableAutoRefresh = true,
  })  : assert(campusOverride == null || controllerTag != null),
        super(key: key);

  final String? campusOverride;
  final String? controllerTag;
  final bool enableAutoRefresh;

  @override
  _UpcomingDeparturesWidgetState createState() =>
      _UpcomingDeparturesWidgetState();
}

class _UpcomingDeparturesWidgetState extends State<UpcomingDeparturesWidget>
    with RouteAware {
  late final UpcomingDepartureViewModel viewModel;
  // 자동 새로고침까지 남은 시간
  int _remainingSeconds = 30;
  Timer? _refreshCountdownTimer;

  final RouteObserver<PageRoute> _routeObserver =
      Get.find<RouteObserver<PageRoute>>();

  @override
  void initState() {
    super.initState();

    // 태그가 있으면 분리된 컨트롤러, 없으면 공용 컨트롤러 사용
    if (widget.controllerTag != null) {
      viewModel = Get.isRegistered<UpcomingDepartureViewModel>(
        tag: widget.controllerTag,
      )
          ? Get.find<UpcomingDepartureViewModel>(tag: widget.controllerTag)
          : Get.put(
              UpcomingDepartureViewModel(
                campusOverride: widget.campusOverride,
                enableAutoRefresh: widget.enableAutoRefresh,
              ),
              tag: widget.controllerTag,
            );
    } else {
      viewModel = Get.isRegistered<UpcomingDepartureViewModel>()
          ? Get.find<UpcomingDepartureViewModel>()
          : Get.put(
              UpcomingDepartureViewModel(
                enableAutoRefresh: widget.enableAutoRefresh,
              ),
            );
    }

    // ViewModel 새로고침 시 카운트다운도 함께 리셋
    viewModel.setRefreshCallback(() {
      _startRefreshCountdown();
    });

    // 첫 카운트다운 시작
    _startRefreshCountdown();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 페이지 전환 감지를 위해 라우트 옵저버 등록
    _routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPush() {
    // 홈 카드가 다시 보이면 활성 상태로 전환
    viewModel.setHomePageState(true);
    _resetTimerDisplay();
    super.didPush();
  }

  @override
  void didPopNext() {
    // 다른 화면에서 돌아오면 카운트다운 리셋
    viewModel.setHomePageState(true);
    _resetTimerDisplay();
    super.didPopNext();
  }

  @override
  void didPushNext() {
    // 다른 화면으로 가면 자동 새로고침 중단
    viewModel.setHomePageState(false);
    super.didPushNext();
  }

  @override
  void didPop() {
    // 홈 카드가 화면에서 사라질 때 비활성화
    viewModel.setHomePageState(false);
    super.didPop();
  }

  @override
  void dispose() {
    _refreshCountdownTimer?.cancel();
    viewModel.setHomePageState(false);
    viewModel.setWidgetEnabled(false);
    viewModel.clearRefreshCallback();
    // 라우트 옵저버 해제 및 태그 기반 컨트롤러 정리
    _routeObserver.unsubscribe(this);
    if (widget.controllerTag != null &&
        Get.isRegistered<UpcomingDepartureViewModel>(
            tag: widget.controllerTag)) {
      Get.delete<UpcomingDepartureViewModel>(tag: widget.controllerTag);
    }
    super.dispose();
  }

  void _startRefreshCountdown() {
    // 기존 카운트다운 취소
    _refreshCountdownTimer?.cancel();

    if (!widget.enableAutoRefresh) {
      _remainingSeconds = 0;
      return;
    }

    // 캠퍼스별 자동 새로고침 주기 반영
    final countdownSeconds = viewModel.currentCampus == '천안' ? 5 : 30;

    _remainingSeconds = countdownSeconds;

    // 1초마다 표시만 감소
    _refreshCountdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          // 0이 되면 다음 주기로 다시 표시
          final newCountdownSeconds = viewModel.currentCampus == '천안' ? 5 : 30;
          _remainingSeconds = newCountdownSeconds;
        }
      });
    });
  }

  // 수동 새로고침
  void _manualRefresh() {
    viewModel.loadData();
    if (widget.enableAutoRefresh) {
      _startRefreshCountdown();
    }
  }

  // 카운트다운 표시 리셋
  void _resetTimerDisplay() {
    if (!mounted) {
      return;
    }

    setState(() {
      final countdownSeconds = widget.enableAutoRefresh
          ? (viewModel.currentCampus == '천안' ? 5 : 30)
          : 0;
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
          // 헤더와 새로고침 상태 표시
          Row(
            children: [
              Text(
                '곧 출발',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: UpcomingDepartureColors.title(context),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Obx(() => Text(
                      // 천안 시내버스 기준은 시내버스 섹션 제목 옆에 표시
                      viewModel.currentCampus == '천안' ? '' : '아캠 출발 기준',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: UpcomingDepartureColors.secondary(context),
                      ),
                    )),
              ),
              ScaleButton(
                onTap: _manualRefresh,
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Obx(() => viewModel.isRefreshing.value
                            ? SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    UpcomingDepartureColors.secondary(context),
                                  ),
                                ),
                              )
                            : Text(
                                widget.enableAutoRefresh
                                    ? '$_remainingSeconds초'
                                    : '-',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: UpcomingDepartureColors.secondary(
                                      context),
                                ),
                              )),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.refresh,
                          size: 18,
                          color: UpcomingDepartureColors.secondary(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          //const SizedBox(height: 8),

          // 로딩/에러/데이터 상태에 따라 본문 전환
          Obx(() {
            if (viewModel.isLoading.value) {
              return Container(
                height: upcomingDepartureBodyHeight, // 로딩 상태에서의 고정된 높이
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
                height: upcomingDepartureBodyHeight, // 에러 상태에서의 고정된 높이
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

            // 셔틀/시내버스 2열 레이아웃으로 표시
            return Container(
              height: upcomingDepartureBodyHeight, // 데이터 표시 상태에서의 고정된 높이
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 셔틀버스 영역
                  Expanded(
                    child: Container(
                      //height: 210,
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // 추가
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const UpcomingDepartureSectionTitle('셔틀버스'),
                          viewModel.upcomingShuttles.isEmpty
                              ? _buildEmptyMessage(context, '셔틀')
                              : Column(
                                  children: viewModel.upcomingShuttles
                                      .take(3) // 최대 2개만 표시
                                      .map(
                                          (shuttle) => _buildCompactShuttleItem(
                                                context,
                                                shuttle,
                                              ))
                                      .toList(),
                                ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: 10),

                  // 시내버스 영역
                  Expanded(
                    child: Container(
                      // height: 210,
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // 추가
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UpcomingDepartureSectionTitle(
                            '시내버스',
                            // 천안은 기점(각원사 회차지) 출발 시각과 실시간 위치가 섞여 있음을 안내
                            caption: viewModel.currentCampus == '천안'
                                ? '기점 출발 · 실시간'
                                : null,
                          ),
                          // 천안은 실시간 버스와 시간표 버스를 함께 노출
                          if (viewModel.currentCampus == '천안')
                            Obx(() {
                              final combinedBuses = [
                                ...viewModel.ceRealtimeBuses,
                                ...viewModel.upcomingCityBuses,
                              ];
                              if (combinedBuses.isEmpty) {
                                return _buildEmptyMessage(context, '버스');
                              }
                              return Column(
                                children: combinedBuses
                                    .take(3)
                                    .map((bus) =>
                                        _buildCompactBusItem(context, bus))
                                    .toList(),
                              );
                            }),
                          // 아산은 시간표 기반 버스만 표시
                          if (viewModel.currentCampus != '천안')
                            Obx(() => viewModel.upcomingCityBuses.isEmpty
                                ? _buildEmptyMessage(context, '버스')
                                : Column(
                                    children: viewModel.upcomingCityBuses
                                        .take(3)
                                        .map((cityBus) => _buildCompactBusItem(
                                              context,
                                              cityBus,
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
    // 운행 종료 여부에 따라 빈 상태 문구 결정
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
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
      decoration: BoxDecoration(
        color: UpcomingDepartureColors.card(context),
        borderRadius: BorderRadius.circular(16),
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

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  // 셔틀 출발 카드
  Widget _buildCompactShuttleItem(
    BuildContext context,
    BusDeparture departure,
  ) {
    final startTime = _formatTime(departure.departureTime);

    return UpcomingDepartureCard(
      primaryText: formatMinutesLeft(departure.minutesLeft),
      primaryColor: _getTimeColor(departure.minutesLeft),
      trailingText: startTime,
      description: departure.destination,
      isLastBus: departure.isLastBus,
      onTap: () {
        // scheduleId가 있으면 셔틀 상세 화면으로 이동
        if (departure.scheduleId != null) {
          if (!Get.isRegistered<ShuttleViewModel>()) {
            Get.put(ShuttleViewModel());
          }

          Get.to(() => ShuttleRouteDetailView(
                scheduleId: departure.scheduleId!,
                routeName: departure.destination,
                round: 0,
                startTime: startTime,
              ));
        } else {
          // 상세 정보가 없으면 안내 스낵바 표시
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
    );
  }

  // 시내버스용 아이템 (노선명 + 목적지 표시)
  Widget _buildCompactBusItem(
    BuildContext context,
    BusDeparture departure,
  ) {
    // 실시간 버스인지 확인
    final isRealtime = departure.destination == '호서대천캠' &&
        (departure.routeKey == '24_DOWN' || departure.routeKey == '81_DOWN');

    String primaryText;
    Color? primaryColor;
    String? trailingText;

    if (isRealtime) {
      // 실시간 버스: 남은 정거장과 현재 위치 표시
      final left = departure.minutesLeft;
      if (left == 1) {
        primaryText = '전';
        primaryColor = Colors.red;
      } else if (left == 2) {
        primaryText = '전전';
        primaryColor = Colors.orange;
      } else if (left >= 3) {
        // 3정거장 이상은 기본 글자색
        primaryText = '$left전';
        primaryColor = null;
      } else {
        primaryText = '';
        primaryColor = Colors.blue;
      }
      trailingText = null;
    } else {
      // 기존 시내버스: 남은 분과 출발 시각 표시
      primaryText = formatMinutesLeft(departure.minutesLeft);
      primaryColor = _getTimeColor(departure.minutesLeft);
      trailingText = _formatTime(departure.departureTime);
    }

    return UpcomingDepartureCard(
      primaryText: primaryText,
      primaryColor: primaryColor,
      trailingText: trailingText,
      routeLabel: departure.routeName,
      // 시간표 기반 버스만 '방면' 표기, 천안 실시간 버스는 현재 위치 표시
      description: isRealtime
          ? '위치: ${departure.departureTime}'
          : '${departure.destination} 방면',
      scrollDescription: true,
      isRealtime: isRealtime,
      isLastBus: departure.isLastBus,
      onTap: () {
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
    );
  }

  // 15분 초과는 null(기본 글자색)
  Color? _getTimeColor(int minutes) {
    if (minutes <= 5) {
      return Colors.red;
    } else if (minutes <= 15) {
      return Colors.orange;
    } else {
      return null;
    }
  }
}
