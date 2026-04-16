import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/city_bus/viewmodel/busmap_viewmodel.dart';

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
              decoration: BoxDecoration(
                color: Color.lerp(
                    Colors.transparent, Colors.yellow.withOpacity(0.3), value),
                borderRadius: BorderRadius.circular(8),
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

      // 현재 정류장 구간에 있는 버스 목록 계산
      final busesInSegment = controller.detailedBusPositions
          .where((busPos) => busPos.nearestStationIndex == index)
          .toList();

      return Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 26.0, horizontal: 16.0),
            child: Row(
              children: [
                // 왼쪽 원형 노드와 세로 연결선
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    children: [
                      CustomPaint(
                        painter: StationPainter(
                          index: index,
                          isLastStation: isLastStation,
                          isHighlighted: isHighlighted,
                          isBusHere: isBusHere,
                          busesInSegment: busesInSegment,
                        ),
                        size: const Size(24, 24),
                      ),
                      Center(
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: isHighlighted ? Colors.orange : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // 강조 중일 때만 추가 아이콘 표시
                SizedBox(
                  width: 40,
                  child: isHighlighted ? _buildPulsingIcon() : null,
                ),

                // 정류장 이름과 번호
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stationName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isHighlighted
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isHighlighted
                              ? Colors.orange
                              : Theme.of(context).textTheme.bodyLarge?.color,
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
                            fontSize: 12,
                            color: isHighlighted
                                ? Colors.orange[700]
                                : Colors.grey,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 다음 정류장과 시각적 구분선
          if (!isLastStation)
            Padding(
              padding: const EdgeInsets.only(left: 76.0),
              child: Divider(
                height: 0,
                thickness: 1,
                color: isHighlighted
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.grey,
              ),
            ),
        ],
      );
    });
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

  StationPainter({
    required this.index,
    required this.isLastStation,
    required this.isHighlighted,
    required this.isBusHere,
    required this.busesInSegment,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 정류장 원형 노드 그리기
    final Paint circlePaint = Paint()
      ..color = isBusHere
          ? Colors.blue[100]!
          : isHighlighted
              ? Colors.orange[100]!
              : Colors.grey[300]!
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = isBusHere
          ? Colors.blue
          : isHighlighted
              ? Colors.orange
              : Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = isBusHere || isHighlighted ? 2.0 : 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    canvas.drawCircle(center, radius, circlePaint);
    canvas.drawCircle(center, radius, borderPaint);

    // 마지막 정류장이 아니면 다음 정류장까지 연결선 표시
    if (!isLastStation) {
      final Paint linePaint = Paint()
        ..color = isBusHere
            ? Colors.blue[300]!
            : isHighlighted
                ? Colors.orange[300]!
                : Colors.grey[300]!
        ..strokeWidth = isBusHere || isHighlighted ? 2.0 : 2.0;

      final startPoint = Offset(size.width / 2, size.height);
      final endPoint =
          Offset(size.width / 2, size.height + 78.0); // 세로선을 더 길게 (화살표까지 닿도록)

      canvas.drawLine(startPoint, endPoint, linePaint);

      // 구간 위에 버스 진행 위치 표시
      for (int i = 0; i < busesInSegment.length; i++) {
        final busPos = busesInSegment[i];
        final progress = busPos.progressToNext;

        // 진행률 기준으로 세로선 위 버스 위치 계산
        final busY = size.height + (78.0 * progress); // 길어진 세로선에 맞춰 조정
        final busCenter = Offset(size.width / 2, busY);

        // 버스 아이콘 배경 원
        final Paint busBgPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        final Paint busBorderPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        // 버스 아이콘 외곽 원
        canvas.drawCircle(busCenter, 10, busBgPaint);
        canvas.drawCircle(busCenter, 10, busBorderPaint);

        // 단순화한 버스 아이콘 본체
        final Paint busIconPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;

        // 버스 본체
        final busBodyRect = Rect.fromCenter(
          center: busCenter,
          width: 12,
          height: 7,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(busBodyRect, const Radius.circular(1.5)),
          busIconPaint,
        );

        // 버스 창문
        final Paint windowPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        // 왼쪽 창문
        final leftWindow = Rect.fromCenter(
          center: Offset(busCenter.dx - 3, busCenter.dy),
          width: 2,
          height: 3,
        );
        canvas.drawRect(leftWindow, windowPaint);

        // 오른쪽 창문
        final rightWindow = Rect.fromCenter(
          center: Offset(busCenter.dx + 3, busCenter.dy),
          width: 2,
          height: 3,
        );
        canvas.drawRect(rightWindow, windowPaint);

        // 버스 바퀴
        final Paint wheelPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;

        // 왼쪽 바퀴
        canvas.drawCircle(
          Offset(busCenter.dx - 3.5, busCenter.dy + 4),
          1.5,
          wheelPaint,
        );

        // 오른쪽 바퀴
        canvas.drawCircle(
          Offset(busCenter.dx + 3.5, busCenter.dy + 4),
          1.5,
          wheelPaint,
        );

        // 차량 번호에서 4자리 숫자만 추출해 표시
        String displayNumber = _extractBusNumber(busPos.vehicleNo);
        if (displayNumber.isNotEmpty) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: displayNumber,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();

          // 번호는 아이콘 오른쪽에 배치
          final textOffset = Offset(
            busCenter.dx + 12, // 아이콘 오른쪽으로 이동
            busCenter.dy - textPainter.height / 2, // 세로 중앙 정렬
          );
          textPainter.paint(canvas, textOffset);
        }
      }
    }
  }

  /// 버스 번호에서 4자리 숫자만 추출
  String _extractBusNumber(String vehicleNo) {
    // 정규식으로 4자리 연속 숫자 찾기
    final RegExp numberRegex = RegExp(r'\d{4}');
    final match = numberRegex.firstMatch(vehicleNo);
    return match?.group(0) ?? '';
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
