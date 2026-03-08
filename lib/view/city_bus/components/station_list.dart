import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../viewmodel/busmap_viewmodel.dart';
import 'station_item.dart';

/// 정류장 목록 표시하는 컴포넌트
class StationList extends StatelessWidget {
  final Map<String, String> routeDisplayNames;
  final ScrollController scrollController;
  
  const StationList({
    Key? key, 
    required this.routeDisplayNames,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BusMapViewModel>();
    
    return Obx(() {
      final currentPositions = controller.currentPositions;
      final totalStations = controller.stationMarkers.length;

      if (totalStations == 0) {
        // 정류장 데이터 로딩 중일 때 표시할 UI
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator.adaptive(),
              const SizedBox(height: 16),
              Text(
                '${routeDisplayNames[controller.selectedRoute.value] ?? controller.selectedRoute.value}\n정류장 정보를 불러오는 중입니다...',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      if (controller.stationNames.isEmpty) {
        return const Center(child: Text('정류장 정보가 없습니다.'));
      }

      return ListView.builder(
        primary: false,
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: controller.stationNames.length,
        itemBuilder: (context, index) {
          final isBusHere = currentPositions.contains(index);
          final stationName = controller.stationNames.length > index
              ? controller.stationNames[index]
              : "정류장 ${index + 1}";

          // 마지막 정류장인지 확인
          final isLastStation = index == controller.stationNames.length - 1;

          return StationItem(
            index: index,
            stationName: stationName,
            isBusHere: isBusHere,
            isLastStation: isLastStation,
          );
        },
      );
    });
  }
} 