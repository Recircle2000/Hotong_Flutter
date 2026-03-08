// lib/view/settings_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../viewmodel/settings_viewmodel.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'guide/guide_selection_view.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:hsro/utils/bus_times_loader.dart';
import 'components/scale_button.dart';
import '../utils/responsive_layout.dart';

class SettingsView extends StatelessWidget {
  final GlobalKey? guideKey;
  final VoidCallback? onRequestHomeExperienceTour;

  const SettingsView({
    Key? key,
    this.guideKey,
    this.onRequestHomeExperienceTour,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = AppResponsive.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // 드로어 헤더 (AppBar 대체)
          Container(
            padding: EdgeInsets.only(
              top: layout.space(60, maxScale: 1.10),
              bottom: layout.space(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '설정',
              style: TextStyle(
                fontSize: layout.font(20),
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: GetBuilder<SettingsViewModel>(
              init: SettingsViewModel(),
              builder: (controller) => ListView(
                padding: EdgeInsets.symmetric(horizontal: layout.space(20)),
                children: [
                  // 캠퍼스 설정 섹션
                  Padding(
                    padding: EdgeInsets.only(
                      left: layout.space(8),
                      bottom: layout.space(8),
                    ),
                    child: Text(
                      '기준 캠퍼스',
                      style: TextStyle(
                        fontSize: layout.font(18),
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(layout.radius(25)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: layout.space(10, maxScale: 1.08),
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Obx(() => Column(
                          children: [
                            _buildRadioItem(
                              context,
                              title: '아산캠퍼스',
                              value: '아산',
                              groupValue: controller.selectedCampus.value,
                              onChanged: (val) => controller.setCampus(val!),
                              isFirst: true,
                            ),
                            Divider(
                                height: 1, color: Colors.grey.withOpacity(0.1)),
                            _buildRadioItem(
                              context,
                              title: '천안캠퍼스',
                              value: '천안',
                              groupValue: controller.selectedCampus.value,
                              onChanged: (val) => controller.setCampus(val!),
                              isLast: true,
                            ),
                          ],
                        )),
                  ),

                  SizedBox(height: layout.space(24)),

                  // 지하철역 설정 섹션
                  Padding(
                    padding: EdgeInsets.only(
                      left: layout.space(8),
                      bottom: layout.space(8),
                    ),
                    child: Text(
                      '기준 지하철역',
                      style: TextStyle(
                        fontSize: layout.font(18),
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(layout.radius(25)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: layout.space(10, maxScale: 1.08),
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Obx(() => Column(
                          children: [
                            _buildRadioItem(
                              context,
                              title: '천안역',
                              value: '천안',
                              groupValue:
                                  controller.selectedSubwayStation.value,
                              onChanged: (val) =>
                                  controller.setSubwayStation(val!),
                              isFirst: true,
                            ),
                            Divider(
                                height: 1, color: Colors.grey.withOpacity(0.1)),
                            _buildRadioItem(
                              context,
                              title: '아산역',
                              value: '아산',
                              groupValue:
                                  controller.selectedSubwayStation.value,
                              onChanged: (val) =>
                                  controller.setSubwayStation(val!),
                              isLast: true,
                            ),
                          ],
                        )),
                  ),

                  SizedBox(height: layout.space(32)),

                  // 가이드 섹션
                  Padding(
                    padding: EdgeInsets.only(
                      left: layout.space(8),
                      bottom: layout.space(12),
                    ),
                    child: Text(
                      '도움말',
                      style: TextStyle(
                        fontSize: layout.font(18),
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  ScaleButton(
                    onTap: () async {
                      final shouldStartTour =
                          await Get.to(() => const GuideSelectionView());
                      if (shouldStartTour == true) {
                        onRequestHomeExperienceTour?.call();
                      }
                    },
                    child: Container(
                      key: guideKey,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(layout.radius(25)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: layout.space(10, maxScale: 1.08),
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.space(20),
                          vertical: layout.space(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.help_outline,
                              color: Colors.blue,
                              size: layout.icon(24),
                            ),
                            SizedBox(width: layout.space(12)),
                            Expanded(
                              child: Text(
                                '이용 가이드',
                                style: TextStyle(
                                  fontSize: layout.font(16),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios,
                                size: layout.icon(16), color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: layout.space(32)),

                  // 정보 섹션
                  _buildInfoSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioItem(
    BuildContext context, {
    required String title,
    String? subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final layout = AppResponsive.of(context);
    final isSelected = value == groupValue;
    final colorScheme = Theme.of(context).colorScheme;

    return ScaleButton(
      onTap: () => onChanged(value),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: layout.space(20),
          vertical: layout.space(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: layout.font(16),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: layout.space(2, maxScale: 1.05)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: layout.font(12),
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: colorScheme.primary,
                size: layout.icon(24),
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                color: Colors.grey[400],
                size: layout.icon(24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final layout = AppResponsive.of(context);
    return Column(
      children: [
        // 앱 정보
        Container(
          padding: EdgeInsets.symmetric(
            vertical: layout.space(20),
            horizontal: layout.space(24),
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(layout.radius(20)),
          ),
          child: Column(
            children: [
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Column(
                      children: [
                        Text(
                          '현재 버전 ${snapshot.data!.version}',
                          style: TextStyle(
                            fontSize: layout.font(14),
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: layout.space(4, maxScale: 1.08)),
                        FutureBuilder<Map<String, dynamic>>(
                          future: BusTimesLoader.loadBusTimes(),
                          builder: (context, busSnapshot) {
                            if (busSnapshot.hasData) {
                              final version =
                                  busSnapshot.data!["version"] ?? "-";
                              return Text(
                                '시내버스 시간표 버전: $version',
                                style: TextStyle(
                                  fontSize: layout.font(12),
                                  color: Colors.grey[500],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              SizedBox(height: layout.space(20)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 0,
                runSpacing: layout.space(8),
                children: [
                  _buildTextButton(
                    context,
                    '개인정보처리방침 / 지원',
                    () async {
                      final Uri url = Uri.parse(
                          'https://www.notion.so/1eda668f263380ff92aae3ac8b74b157?pvs=4');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: layout.space(4, maxScale: 1.05),
                    ),
                    child: Container(
                      height: layout.space(12, maxScale: 1.08),
                      width: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                  _buildTextButton(
                    context,
                    '오픈소스 라이선스',
                    () async {
                      final packageInfo = await PackageInfo.fromPlatform();
                      if (context.mounted) {
                        showLicensePage(
                          context: context,
                          applicationName: '호통',
                          applicationVersion: packageInfo.version,
                          applicationLegalese:
                              '© 2025 호통\n\n이 앱은 다음 오픈소스 라이브러리들을 사용합니다:',
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextButton(
      BuildContext context, String label, VoidCallback onTap) {
    final layout = AppResponsive.of(context);
    return ScaleButton(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: layout.space(4, maxScale: 1.05),
          vertical: layout.space(2, maxScale: 1.05),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: layout.font(13),
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
