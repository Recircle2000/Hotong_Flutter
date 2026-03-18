// lib/view/settings_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../viewmodel/settings_viewmodel.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'guide/guide_selection_view.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:hsro/utils/bus_times_loader.dart';
import 'components/scale_button.dart';

class SettingsView extends StatelessWidget {
  final GlobalKey? guideKey;
  final VoidCallback? onRequestHomeExperienceTour;

  const SettingsView({
    super.key,
    this.guideKey,
    this.onRequestHomeExperienceTour,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: GetBuilder<SettingsViewModel>(
          init: SettingsViewModel(),
          builder: (controller) => Obx(
            () => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '설정',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: _buildCardDecoration(context, cardColor),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildCompactChoiceSection(
                          context,
                          title: '기준 캠퍼스',
                          selectedValue: controller.selectedCampus.value,
                          choices: const [
                            _SettingChoice(label: '아산캠퍼스', value: '아산'),
                            _SettingChoice(label: '천안캠퍼스', value: '천안'),
                          ],
                          onChanged: controller.setCampus,
                        ),
                        _buildSectionDivider(context),
                        _buildCompactChoiceSection(
                          context,
                          title: '기준 지하철역',
                          selectedValue: controller.selectedSubwayStation.value,
                          choices: const [
                            _SettingChoice(label: '천안역', value: '천안'),
                            _SettingChoice(label: '아산역', value: '아산'),
                          ],
                          onChanged: controller.setSubwayStation,
                        ),
                        _buildSectionDivider(context),
                        _buildToggleTile(
                          context,
                          title: '위치 기반 위젯 활성화',
                          description: '캠퍼스 밖에서는 등교\n(동남구,서북구 셔틀 미지원)\n캠퍼스 안에서는 하교정보 표시',
                          value: controller
                              .isLocationBasedDepartureWidgetEnabled.value,
                          onChanged:
                              controller.setLocationBasedDepartureWidgetEnabled,
                        ),
                        _buildSectionDivider(context),
                        _buildActionTile(
                          context,
                          key: guideKey,
                          icon: Icons.help_outline_rounded,
                          title: '이용 가이드',
                          subtitle: '튜토리얼과 화면별 사용법 보기',
                          onTap: () async {
                            final shouldStartTour =
                                await Get.to(() => const GuideSelectionView());
                            if (shouldStartTour == true) {
                              onRequestHomeExperienceTour?.call();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildCardDecoration(BuildContext context, Color cardColor) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _buildCompactChoiceSection(
    BuildContext context, {
    required String title,
    required String selectedValue,
    required List<_SettingChoice> choices,
    required ValueChanged<String> onChanged,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var index = 0; index < choices.length; index++) ...[
              Expanded(
                child: _buildChoiceButton(
                  context,
                  label: choices[index].label,
                  isSelected: selectedValue == choices[index].value,
                  onTap: () => onChanged(choices[index].value),
                ),
              ),
              if (index != choices.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceButton(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return ScaleButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : theme.scaffoldBackgroundColor.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.28)
                : theme.dividerColor.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: isSelected ? colorScheme.primary : Colors.grey[400],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
      ),
    );
  }

  Widget _buildToggleTile(
    BuildContext context, {
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(
                  color: textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return ScaleButton(
      onTap: onTap,
      child: Container(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color:
                          textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[500],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '앱 정보',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  return _buildInfoBadge(
                    context,
                    '버전 ${snapshot.data!.version}',
                  );
                },
              ),
              FutureBuilder<Map<String, dynamic>>(
                future: BusTimesLoader.loadBusTimes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  final version = snapshot.data!['version'] ?? '-';
                  return _buildInfoBadge(
                    context,
                    '시내버스 $version',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildTextButton(
                context,
                '개인정보처리방침      ',
                () async {
                  final Uri url = Uri.parse(
                      'https://www.notion.so/1eda668f263380ff92aae3ac8b74b157?pvs=4');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
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
                          '© 2026 호통\n\n이 앱은 다음 오픈소스 라이브러리들을 사용합니다:',
                    );
                  }
                },
              ),
              _buildTextButton(
                context,
                '피드백/지원',
                    () async {
                  final Uri url = Uri.parse(
                      'https://docs.google.com/forms/d/e/1FAIpQLSdPCDCj8mVqkTTHmwPD0b_lINF8woqUBCH_MmNsvs9OS4OfMQ/viewform?usp=publish-editor');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(BuildContext context, String label) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
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

class _SettingChoice {
  final String label;
  final String value;

  const _SettingChoice({
    required this.label,
    required this.value,
  });
}
