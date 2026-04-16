import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/city_bus/view/grouped_bus_view.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:hsro/features/shuttle/view/shuttle_route_selection_view.dart';
import 'package:hsro/features/subway/view/subway_view.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

class HomeTransportMenuSection extends StatelessWidget {
  const HomeTransportMenuSection({
    super.key,
    required this.sectionKey,
    required this.settingsViewModel,
  });

  final GlobalKey sectionKey;
  final SettingsViewModel settingsViewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
      child: Column(
        children: [
          // 셔틀/시내버스 카드
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _TransportMenuCard(
                    title: '셔틀버스',
                    icon: Icons.airport_shuttle,
                    color: const Color(0xFFB83227),
                    onTap: () =>
                        Get.to(() => const ShuttleRouteSelectionView()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TransportMenuCard(
                    title: '시내버스',
                    icon: Icons.directions_bus,
                    color: Colors.blue,
                    onTap: () => Get.to(() => const CityBusGroupedView()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 지하철 카드
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _TransportMenuCard(
              title: '지하철',
              icon: Icons.subway_outlined,
              color: const Color(0xFF0052A4),
              onTap: () => Get.to(
                () => SubwayView(
                  stationName: settingsViewModel.selectedSubwayStation.value,
                ),
              ),
              height: 80,
              isHorizontal: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportMenuCard extends StatelessWidget {
  const _TransportMenuCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.height,
    this.isHorizontal = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double? height;
  final bool isHorizontal;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return ScaleButton(
      onTap: onTap,
      child: Container(
        height: height ?? 180,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: isHorizontal
            // 가로형 카드 레이아웃
            ? Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isHorizontal ? 8 : 16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '실시간 도착 정보 / 시간표',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              )
            // 세로형 카드 레이아웃
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 48,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
