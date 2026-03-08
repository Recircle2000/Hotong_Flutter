import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../viewmodel/busmap_viewmodel.dart';

// BusMapViewModel 확장 - 강조 표시용 변수
// 전역 상태로 사용하기 위해 파일 레벨에 선언
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
      // 강조 표시 여부 확인
      final isHighlighted = StationHighlightManager.highlightedStation.value == index;
      
      // 강조 표시된 정류장이면 애니메이션 효과 추가
      if (isHighlighted) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return Container(
              decoration: BoxDecoration(
                color: Color.lerp(Colors.transparent, Colors.yellow.withOpacity(0.3), value),
                borderRadius: BorderRadius.circular(8),
              ),
              child: child,
            );
          },
          child: _buildStationContent(context, isHighlighted),
        );
      }
      
      // 일반 정류장
      return _buildStationContent(context, isHighlighted);
    });
  }
  
  // 정류장 내용 위젯
  Widget _buildStationContent(BuildContext context, bool isHighlighted) {
    return Obx(() {
      final controller = Get.find<BusMapViewModel>();
      
      // 현재 정류장에서 다음 정류장 사이에 있는 버스들 찾기 (정류장에 있는 버스 포함)
      final busesInSegment = controller.detailedBusPositions.where((busPos) => 
        busPos.nearestStationIndex == index
      ).toList();
      
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 26.0, horizontal: 16.0),
            child: Row(
              children: [
                // 왼쪽: 정류장 번호와 연결선 (버스 위치 포함)
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

                // 버스 아이콘 제거 (StationPainter에서 원 강조로 대체)
                SizedBox(
                  width: 40,
                  child: isHighlighted 
                      ? _buildPulsingIcon()
                      : null,
                ),

                // 정류장 이름과 번호 (강조 제거)
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
                            color: isHighlighted ? Colors.orange[700] : Colors.grey,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 구분선
          if (!isLastStation)
            Padding(
              padding: const EdgeInsets.only(left: 76.0),
              child: Divider(
                height: 0, 
                thickness: 1, 
                color: isHighlighted ? Colors.orange.withOpacity(0.3) : Colors.grey,
              ),
            ),
        ],
      );
    });
  }
  
  // 펄스 애니메이션 아이콘
  Widget _buildPulsingIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.2),
      duration: const Duration(milliseconds: 800),
      // 애니메이션 반복
      onEnd: () {
        // 반복 애니메이션을 위해 다시 빌드하게 함
        Future.microtask(() => StationHighlightManager.highlightedStation.refresh());
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
    // 원 그리기 (버스가 있으면 파란색으로 강조)
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

    // 세로선 그리기 (마지막 정류장이 아닌 경우)
    if (!isLastStation) {
      final Paint linePaint = Paint()
        ..color = isBusHere
            ? Colors.blue[300]!
            : isHighlighted 
              ? Colors.orange[300]! 
              : Colors.grey[300]!
        ..strokeWidth = isBusHere || isHighlighted ? 2.0 : 2.0;

      final startPoint = Offset(size.width / 2, size.height);
      final endPoint = Offset(size.width / 2, size.height + 78.0); // 세로선을 더 길게 (화살표까지 닿도록)

      canvas.drawLine(startPoint, endPoint, linePaint);
      
      // 버스 위치 표시 (세로선 위에)
      for (int i = 0; i < busesInSegment.length; i++) {
        final busPos = busesInSegment[i];
        final progress = busPos.progressToNext;
        
        // 버스 위치 계산 (세로선을 따라)
        final busY = size.height + (78.0 * progress); // 길어진 세로선에 맞춰 조정
        final busCenter = Offset(size.width / 2, busY);
        
        // 버스 아이콘 배경 (흰색 원)
        final Paint busBgPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        
        final Paint busBorderPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        
        // 버스 아이콘 그리기 (더 큰 원)
        canvas.drawCircle(busCenter, 10, busBgPaint);
        canvas.drawCircle(busCenter, 10, busBorderPaint);
        
        // 더 직관적인 버스 아이콘 그리기
        final Paint busIconPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;
        
        // 버스 본체 (직사각형)
        final busBodyRect = Rect.fromCenter(
          center: busCenter,
          width: 12,
          height: 7,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(busBodyRect, const Radius.circular(1.5)),
          busIconPaint,
        );
        
        // 버스 창문들 (작은 흰색 사각형들)
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
        
        // 버스 바퀴들 (파란색 원)
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
        
        // 버스 번호 표시 (아이콘 밑에, "충남72자" 제거하고 4자리 숫자만)
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
          
          // 버스 번호를 버스 아이콘 오른쪽에 표시
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