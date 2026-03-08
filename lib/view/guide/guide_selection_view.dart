import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/responsive_layout.dart';
import '../components/scale_button.dart';
import 'city_bus_guide_view.dart';
import 'shuttle_guide_view.dart';

class GuideSelectionView extends StatelessWidget {
  const GuideSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final layout = AppResponsive.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '이용 가이드',
          style: TextStyle(
            fontSize: layout.font(20),
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: ScaleButton(
          onTap: () => Get.back(),
          child: Icon(
            Icons.arrow_back_ios,
            color: isDarkMode ? Colors.white : Colors.black87,
            size: layout.icon(22),
          ),
        ),
      ),
      body: AppPageFrame(
        child: ListView(
          padding: EdgeInsets.all(layout.space(20)),
          children: [
            _buildGuideCard(
              context,
              title: '호통 이용 가이드',
              description: '앱 핵심 기능과 화면별 사용 흐름 안내(약 1분 소요)',
              icon: Icons.menu_book_rounded,
              color: Colors.teal,
              onTap: () => Get.back(result: true),
            ),
            SizedBox(height: layout.space(20)),
            _buildGuideCard(
              context,
              title: '셔틀버스 가이드',
              description: '아캠/천캠 셔틀버스 이용 방법 안내',
              icon: Icons.airport_shuttle_rounded,
              color: const Color(0xFFB83227),
              onTap: () => Get.to(() => const ShuttleGuideView()),
            ),
            SizedBox(height: layout.space(20)),
            _buildGuideCard(
              context,
              title: '시내버스 가이드',
              description: '시내버스 이용 방법 및 1호선 환승 안내',
              icon: Icons.directions_bus_rounded,
              color: Colors.blue,
              onTap: () => Get.to(() => const CityBusGuideView()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final layout = AppResponsive.of(context);

    return ScaleButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(layout.radius(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: layout.space(10, maxScale: 1.08),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(layout.space(24)),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(layout.space(12)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(layout.radius(15)),
                ),
                child: Icon(icon, color: color, size: layout.icon(32)),
              ),
              SizedBox(width: layout.space(20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: layout.font(18),
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: layout.space(4, maxScale: 1.05)),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: layout.font(14),
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: layout.icon(16),
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
