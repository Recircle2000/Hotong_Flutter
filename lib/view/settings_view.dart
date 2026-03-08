// lib/view/settings_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../viewmodel/settings_viewmodel.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'subway/subway_view.dart';
import 'guide/guide_selection_view.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:hsro/utils/bus_times_loader.dart';
import 'components/scale_button.dart';

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
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // 드로어 헤더 (AppBar 대체)
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 10),
            alignment: Alignment.center,
            child: Text(
              '설정',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: GetBuilder<SettingsViewModel>(
              init: SettingsViewModel(),
              builder: (controller) => ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                children: [
                  // 캠퍼스 설정 섹션
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      '기준 캠퍼스',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
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

                  const SizedBox(height: 24),

                  // 지하철역 설정 섹션
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      '기준 지하철역',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
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

                  const SizedBox(height: 32),

                  // 가이드 섹션
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      '도움말',
                      style: TextStyle(
                        fontSize: 18,
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
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Icon(Icons.help_outline, color: Colors.blue),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '이용 가이드',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

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
    final isSelected = value == groupValue;
    final colorScheme = Theme.of(context).colorScheme;

    return ScaleButton(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
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
                size: 24,
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                color: Colors.grey[400],
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Column(
      children: [
        // 앱 정보
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<Map<String, dynamic>>(
                          future: BusTimesLoader.loadBusTimes(),
                          builder: (context, busSnapshot) {
                            if (busSnapshot.hasData) {
                              final version =
                                  busSnapshot.data!["version"] ?? "-";
                              return Text(
                                '시내버스 시간표 버전: $version',
                                style: TextStyle(
                                  fontSize: 12,
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
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 0,
                runSpacing: 8,
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
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      height: 12,
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
    return ScaleButton(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
