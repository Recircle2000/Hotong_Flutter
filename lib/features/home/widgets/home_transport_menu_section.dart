import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/city_bus/view/grouped_bus_view.dart';
import 'package:hsro/features/auth/view/taxi_auth_gate_view.dart';
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
          // 지하철/택시 카드
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _TransportMenuCard(
                    title: '지하철',
                    icon: Icons.subway_outlined,
                    color: const Color(0xFF0052A4),
                    onTap: () => Get.to(
                      () => SubwayView(
                        stationName:
                            settingsViewModel.selectedSubwayStation.value,
                      ),
                    ),
                    height: 80,
                    isCompact: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TransportMenuCard(
                    title: '택시',
                    icon: Icons.local_taxi_outlined,
                    color: const Color(0xFFF5A623),
                    onTap: () => Get.to(() => const TaxiAuthGateView()),
                    height: 80,
                    isCompact: true,
                  ),
                ),
              ],
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
    this.isCompact = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double? height;
  final bool isCompact;

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
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: isCompact
            // 작은 가로형 카드 레이아웃
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 28, color: color),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
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
                      color: color.withValues(alpha: 0.1),
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
