import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:hsro/features/city_bus/view/grouped_bus_view.dart';
import 'package:hsro/features/auth/view/taxi_auth_gate_view.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:hsro/features/shuttle/view/shuttle_route_selection_view.dart';
import 'package:hsro/features/subway/view/subway_view.dart';
import 'package:hsro/features/taxi/services/taxi_availability_service.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

class HomeTransportMenuSection extends StatelessWidget {
  const HomeTransportMenuSection({
    super.key,
    required this.sectionKey,
    required this.settingsViewModel,
  });

  final GlobalKey sectionKey;
  final SettingsViewModel settingsViewModel;

  Widget _buildBottomRow() {
    final subway = Expanded(
      child: _TransportMenuCard(
        title: '지하철',
        icon: PhosphorIconsRegular.trainSimple,
        color: const Color(0xFF0052A4),
        onTap: () => Get.to(
          () => SubwayView(
            stationName: settingsViewModel.selectedSubwayStation.value,
          ),
        ),
        height: 60,
        isCompact: true,
      ),
    );
    if (!Get.isRegistered<TaxiAvailabilityService>()) {
      return Row(children: [subway, const SizedBox(width: 10), _taxiCard()]);
    }
    final availability = Get.find<TaxiAvailabilityService>();
    return Obx(
      () => Row(
        children: [
          subway,
          if (availability.showTaxiMenu) ...[
            const SizedBox(width: 10),
            _taxiCard(availability),
          ],
        ],
      ),
    );
  }

  Widget _taxiCard([TaxiAvailabilityService? availability]) => Expanded(
    child: _TransportMenuCard(
      title: '택시',
      icon: PhosphorIconsRegular.taxi,
      color: const Color(0xFFF5A623),
      onTap: () async {
        await Get.to(() => const TaxiAuthGateView());
        // 택시 화면에서 팟을 나가거나 끝냈다면 메뉴 노출 여부를 다시 확인한다.
        unawaited(availability?.refresh());
      },
      height: 60,
      isCompact: true,
    ),
  );

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
                    icon: PhosphorIconsRegular.van,
                    color: const Color(0xFFB83227),
                    onTap: () =>
                        Get.to(() => const ShuttleRouteSelectionView()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TransportMenuCard(
                    title: '시내버스',
                    icon: PhosphorIconsRegular.bus,
                    color: Colors.blue,
                    onTap: () => Get.to(() => const CityBusGroupedView()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 지하철/택시 카드. 택시 서비스가 꺼지면 지하철이 한 줄을 채운다.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildBottomRow(),
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
        height: height ?? 128,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(isCompact ? 18 : 22),
        ),
        padding: isCompact
            ? const EdgeInsets.symmetric(horizontal: 18)
            : const EdgeInsets.all(18),
        child: isCompact
            // 작은 가로형 카드: 왼쪽 아이콘 + 옆에 텍스트
            ? Row(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              )
            // 세로형 카드: 왼쪽 위 아이콘, 아래 왼쪽 정렬 텍스트
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 30, color: color),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
