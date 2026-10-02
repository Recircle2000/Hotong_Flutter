import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/city_bus/viewmodel/busmap_viewmodel.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

// 시내버스 상세 화면 공통 포인트 색상
const Color cityBusAccent = Color(0xFF2F62D0);

// 정류장 강조 상태를 여러 위젯에서 공유하기 위한 관리자
class StationHighlightManager {
  static final RxInt highlightedStation = RxInt(-1);

  static void highlightStation(int index) {
    highlightedStation.value = index;
  }

  static void clearHighlightedStation() {
    highlightedStation.value = -1;
  }
}

class StationItem extends StatelessWidget {
  // 목록 스크롤 위치 계산에 쓰는 정류장 한 줄의 고정 높이
  static const double itemExtent = 80;

  // 타임라인 세로선의 가로 중심과 정류장명 시작 위치
  static const double _timelineX = 28;
  static const double _contentLeft = 56;

  final int index;
  final String stationName;
  final bool isBusHere;
  final bool isLastStation;

  const StationItem({
    Key? key,
    required this.index,
    required this.stationName,
    required this.isBusHere,
    required this.isLastStation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 현재 정류장이 강조 대상인지 확인
      final isHighlighted =
          StationHighlightManager.highlightedStation.value == index;

      // 강조 중인 정류장은 배경 애니메이션 적용
      if (isHighlighted) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return Container(
              color: Color.lerp(
                Colors.transparent,
                Colors.yellow.withValues(alpha: 0.3),
                value,
              ),
              child: child,
            );
          },
          child: _buildStationContent(context, isHighlighted),
        );
      }

      // 일반 상태 정류장 렌더링
      return _buildStationContent(context, isHighlighted);
    });
  }

  // 정류장 내용 위젯
  Widget _buildStationContent(BuildContext context, bool isHighlighted) {
    return Obx(() {
      final controller = Get.find<BusMapViewModel>();
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      // 이 정류장을 지나 다음 정류장으로 가는 버스 목록
      final busesInSegment = controller.detailedBusPositions
          .where((busPos) => busPos.nearestStationIndex == index)
          .toList();
      // 이전 정류장에서 이 정류장으로 오는 버스 목록 (경계 부근 표시용)
      final busesFromPrevious = controller.detailedBusPositions
          .where((busPos) => busPos.nearestStationIndex == index - 1)
          .toList();

      // 가장 뒤에 있는 버스부터 종점까지를 운행 구간으로 표시
      final positions = controller.currentPositions;
      final int? firstBusIndex = positions.isEmpty
          ? null
          : positions.reduce((a, b) => a < b ? a : b);

      final lineColor = isDark ? Colors.grey[700]! : const Color(0xFFCBD0D8);

      return Container(
        height: itemExtent,
        // 버스가 있는 정류장은 옅은 배경으로 구분 (강조 중에는 강조 배경 우선)
        color: isBusHere && !isHighlighted
            ? cityBusAccent.withValues(alpha: isDark ? 0.18 : 0.08)
            : null,
        child: CustomPaint(
          painter: StationPainter(
            index: index,
            isLastStation: isLastStation,
            isHighlighted: isHighlighted,
            isBusHere: isBusHere,
            busesInSegment: busesInSegment,
            busesFromPrevious: busesFromPrevious,
            firstBusIndex: firstBusIndex,
            timelineX: _timelineX,
            lineColor: lineColor,
            nodeFillColor: theme.cardColor,
          ),
          child: Stack(
            // 줄 경계에 걸친 버스 아이콘이 잘리지 않도록 클립 해제
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: _contentLeft, right: 16),
                child: Row(
                  children: [
                    // 정류장 이름과 번호
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stationName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: isHighlighted
                                  ? Colors.orange
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Obx(() {
                            final controller = Get.find<BusMapViewModel>();
                            final stationNumber =
                                controller.stationNumbers.length > index
                                    ? controller.stationNumbers[index]
                                    : "";
                            return Text(
                              "$stationNumber",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.2,
                                color: isHighlighted
                                    ? Colors.orange[700]
                                    : (isDark
                                        ? Colors.grey[400]
                                        : const Color(0xFF6B7280)),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // 강조 중일 때만 위치 아이콘 표시
                    if (isHighlighted) ...[
                      const SizedBox(width: 8),
                      _buildPulsingIcon(),
                    ],

                    // 이 구간을 운행 중인 버스의 차량 번호
                    for (final busPos in busesInSegment)
                      if (_extractBusNumber(busPos.vehicleNo).isNotEmpty)
                        _buildVehicleBadge(
                          context,
                          _extractBusNumber(busPos.vehicleNo),
                        ),
                  ],
                ),
              ),

              // 버스 위치 원 안의 아이콘 (타임라인 위, 진행률에 맞춰 이동)
              for (final busPos in busesInSegment)
                _buildBusIcon(
                  itemExtent / 2 + itemExtent * busPos.progressToNext,
                ),
              for (final busPos in busesFromPrevious)
                _buildBusIcon(
                  itemExtent / 2 - itemExtent * (1 - busPos.progressToNext),
                ),

              // 다음 정류장과 시각적 구분선
              if (!isLastStation)
                Positioned(
                  left: _contentLeft,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 1,
                    color: isHighlighted
                        ? Colors.orange.withValues(alpha: 0.3)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE1E4E9)),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  // 타임라인 위 버스 원 안에 올리는 버스 아이콘
  Widget _buildBusIcon(double centerY) {
    const double size = 16;
    return Positioned(
      left: _timelineX - size / 2,
      top: centerY - size / 2,
      child: const IgnorePointer(
        child: Icon(PhosphorIconsRegular.bus, size: size, color: Colors.white),
      ),
    );
  }

  // 차량 번호 배지
  Widget _buildVehicleBadge(BuildContext context, String number) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cityBusAccent.withValues(alpha: isDark ? 0.6 : 0.3),
        ),
      ),
      child: Text(
        number,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF8FB0FF) : cityBusAccent,
        ),
      ),
    );
  }

  /// 버스 번호에서 4자리 숫자만 추출
  String _extractBusNumber(String vehicleNo) {
    // 정규식으로 4자리 연속 숫자 찾기
    final RegExp numberRegex = RegExp(r'\d{4}');
    final match = numberRegex.firstMatch(vehicleNo);
    return match?.group(0) ?? '';
  }

  // 강조 정류장용 펄스 애니메이션 아이콘
  Widget _buildPulsingIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.2),
      duration: const Duration(milliseconds: 800),
      // 애니메이션 종료 후 다시 갱신해 반복 효과 유지
      onEnd: () {
        Future.microtask(
            () => StationHighlightManager.highlightedStation.refresh());
      },
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: const Icon(
        Icons.location_on,
        color: Colors.orange,
        size: 20,
      ),
    );
  }
}

class StationPainter extends CustomPainter {
  final int index;
  final bool isLastStation;
  final bool isHighlighted;
  final bool isBusHere;
  final List<BusPosition> busesInSegment;
  final List<BusPosition> busesFromPrevious;
  // 가장 뒤에 있는 버스의 정류장 인덱스 (운행 중인 버스가 없으면 null)
  final int? firstBusIndex;
  final double timelineX;
  final Color lineColor;
  final Color nodeFillColor;

  StationPainter({
    required this.index,
    required this.isLastStation,
    required this.isHighlighted,
    required this.isBusHere,
    required this.busesInSegment,
    required this.busesFromPrevious,
    required this.firstBusIndex,
    required this.timelineX,
    required this.lineColor,
    required this.nodeFillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final center = Offset(timelineX, centerY);

    // 버스가 지나갈 구간(가장 뒤 버스 이후)은 포인트 색상으로 표시
    final bool upperActive = firstBusIndex != null && index > firstBusIndex!;
    final bool lowerActive = firstBusIndex != null && index >= firstBusIndex!;

    Paint linePaint(bool active) => Paint()
      ..color = active ? cityBusAccent : lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.butt;

    // 첫 정류장은 위쪽 선 없음, 마지막 정류장은 아래쪽 선 없음
    if (index > 0) {
      canvas.drawLine(Offset(timelineX, 0), center, linePaint(upperActive));
    }
    if (!isLastStation) {
      canvas.drawLine(
        center,
        Offset(timelineX, size.height),
        linePaint(lowerActive),
      );
    }

    // 정류장 원형 노드
    final Color nodeColor = isHighlighted
        ? Colors.orange
        : lowerActive
            ? cityBusAccent
            : lineColor;
    canvas.drawCircle(center, 6, Paint()..color = nodeFillColor);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = nodeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 구간 위에 버스 진행 위치 표시 (진행률 기준으로 세로선 위에 배치)
    final busPaint = Paint()..color = cityBusAccent;
    for (final busPos in busesInSegment) {
      canvas.drawCircle(
        Offset(timelineX, centerY + size.height * busPos.progressToNext),
        15,
        busPaint,
      );
    }
    // 이전 구간의 버스가 이 줄 영역에 걸쳐 있으면 가려지지 않게 다시 그림
    for (final busPos in busesFromPrevious) {
      canvas.drawCircle(
        Offset(
          timelineX,
          centerY - size.height * (1 - busPos.progressToNext),
        ),
        15,
        busPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
