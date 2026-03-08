import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../viewmodel/busmap_viewmodel.dart';
import '../helpers/timetable_helper.dart';

/// 노선 정보 화면 컴포넌트
class RouteInfoView extends StatelessWidget {
  final Map<String, String> routeDisplayNames;
  final Map<String, String> routeSimpleNames;
  
  const RouteInfoView({
    Key? key,
    required this.routeDisplayNames,
    required this.routeSimpleNames,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BusMapViewModel>();
    
    return FutureBuilder<Map<String, dynamic>>(
      future: TimetableHelper.loadTimetable(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (snapshot.hasError) {
          return Center(child: Text('정보를 불러올 수 없습니다: ${snapshot.error}'));
        }

        final routeData = snapshot.data?[controller.selectedRoute.value];
        if (routeData == null) return const Center(child: Text('노선 정보가 없습니다'));

        final List<dynamic> times = routeData['시간표'] ?? [];
        final String firstBus = times.isNotEmpty ? times.first.toString() : '-';
        final String lastBus = times.isNotEmpty ? times.last.toString() : '-';
        final String interval = TimetableHelper.calculateInterval(times);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _infoCard(
                context,
                '노선',
                routeSimpleNames[controller.selectedRoute.value] ??
                    controller.selectedRoute.value),
            _infoCard(context, '기점', routeData['출발지'] ?? '-'),
            _infoCard(context, '종점', routeData['종점'] ?? '-'),
            _infoCard(context, '배차 간격', interval),
            _infoCard(context, '운행시간', "$firstBus ~ $lastBus"),
          ],
        );
      },
    );
  }
  
  /// 정보 카드 위젯
  Widget _infoCard(BuildContext context, String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              content,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 