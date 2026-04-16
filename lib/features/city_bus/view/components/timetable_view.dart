import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/city_bus/view/helpers/timetable_helper.dart';
import 'package:hsro/features/city_bus/viewmodel/busmap_viewmodel.dart';

/// 버스 시간표 화면 컴포넌트
class TimetableView extends StatelessWidget {
  const TimetableView({Key? key}) : super(key: key);

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
          return Center(child: Text('시간표를 불러올 수 없습니다: ${snapshot.error}'));
        }

        // 선택된 노선의 시간표만 추출
        final times = (snapshot.data?[controller.selectedRoute.value]?['시간표']
                as List<dynamic>?) ??
            [];

        // 시간표를 카드형 그리드로 표시
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: times.length,
          itemBuilder: (context, index) => Card(
            child: Center(
              child: Text(
                times[index].toString(),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      },
    );
  }
}
