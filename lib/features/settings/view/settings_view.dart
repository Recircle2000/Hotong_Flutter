import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hsro/core/constants/app_links.dart';
import 'package:hsro/core/utils/bus_static_data_loader.dart';
import 'package:hsro/core/utils/bus_times_loader.dart';
import 'package:hsro/features/guide/view/guide_selection_view.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

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
      // 홈 화면 드로어로 사용하는 설정 패널
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: GetBuilder<SettingsViewModel>(
          builder: (controller) => Obx(
            () => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                // 상단 타이틀
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '설정',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
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
                        // 기본 캠퍼스 선택
                        _buildCompactChoiceSection(
                          context,
                          title: '기준 캠퍼스',
                          selectedValue: controller.selectedCampus.value,
                          choices: const [
                            _SettingChoice(label: '아산', value: '아산'),
                            _SettingChoice(label: '천안', value: '천안'),
                          ],
                          onChanged: controller.setCampus,
                        ),
                        _buildSectionDivider(context),
                        // 지하철 기본역 선택
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
                        // 위치 기반 곧 도착 위젯 사용 여부
                        _buildToggleTile(
                          context,
                          title: '위치 기반 위젯 활성화',
                          description:
                              '캠퍼스 밖에서는 등교 정보,\n캠퍼스 안에서는 하교 정보 표시\n동남구·서북구 셔틀 미지원',
                          value: controller
                              .isLocationBasedDepartureWidgetEnabled.value,
                          onChanged: (enabled) {
                            HapticFeedback.lightImpact();
                            controller.setLocationBasedDepartureWidgetEnabled(
                              enabled,
                            );
                          },
                        ),
                        _buildSectionDivider(context),
                        // 튜토리얼/가이드 진입
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
                              // 홈 체험하기 요청 콜백 연결
                              onRequestHomeExperienceTour?.call();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 버전 및 외부 링크 정보 영역
                _buildInfoSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildCardDecoration(BuildContext context, Color cardColor) {
    // 설정 카드 공통 배경 스타일
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
    );
  }

  Widget _buildCompactChoiceSection(
    BuildContext context, {
    required String title,
    required String selectedValue,
    required List<_SettingChoice> choices,
    required ValueChanged<String> onChanged,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // 여러 선택지 중 하나를 고르는 섹션
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final choice in choices)
                _buildChoiceSegment(
                  context,
                  label: choice.label,
                  isSelected: selectedValue == choice.value,
                  onTap: () {
                    if (selectedValue == choice.value) {
                      return;
                    }
                    HapticFeedback.selectionClick();
                    onChanged(choice.value);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceSegment(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 선택된 칸은 트랙보다 한 단계 밝게 띄운다(다크 모드에서는 surface가 트랙보다 어둡다).
    final selectedColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.14)
        : colorScheme.surface;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              style: theme.textTheme.bodySmall!.copyWith(
                color: colorScheme.onSurface.withValues(
                  alpha: isSelected ? 0.92 : 0.52,
                ),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider(BuildContext context) {
    // 섹션 사이 구분선
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
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

    // 설명과 토글 스위치를 함께 보여주는 행
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
                  fontWeight: FontWeight.w600,
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
            // 액션 아이콘 영역
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
                      fontWeight: FontWeight.w600,
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
              color: theme.hintColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: _buildCardDecoration(context, theme.cardColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '앱 정보',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // 앱 버전과 버스 데이터 버전 표시
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              return _buildInfoRow(context, '앱', snapshot.data!.version);
            },
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: BusTimesLoader.loadBusTimes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final version = snapshot.data!['version'] ?? '-';
              return _buildInfoRow(context, '시내버스 시간표', '$version');
            },
          ),
          FutureBuilder<String?>(
            future: BusStaticDataLoader.loadActiveVersion(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final version = snapshot.data ?? '-';
              return _buildInfoRow(context, '시내버스 노선', version);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          // 정책/라이선스/피드백 링크
          _buildLinkRow(
            context,
            '개인정보처리방침',
            () async {
              // 개인정보처리방침 문서 열기
              final Uri url = Uri.parse(
                  'https://www.notion.so/1eda668f263380ff92aae3ac8b74b157?pvs=4');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          _buildLinkRow(
            context,
            '오픈소스 라이선스',
            () async {
              // Flutter 기본 라이선스 페이지 표시
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
          _buildLinkRow(
            context,
            '피드백/지원',
            () async {
              // 피드백 접수 폼 열기
              final Uri url = Uri.parse(feedbackFormUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  // 버전 정보 한 줄: 왼쪽 이름, 오른쪽 고정폭 값
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(color: theme.hintColor),
            ),
          ),
          Text(
            value,
            style: style?.copyWith(
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // 설정 하단 링크 한 줄
  Widget _buildLinkRow(BuildContext context, String label, VoidCallback onTap) {
    final theme = Theme.of(context);

    return ScaleButton(
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.hintColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingChoice {
  // 선택형 설정 버튼에 사용하는 라벨/값 쌍
  final String label;
  final String value;

  const _SettingChoice({
    required this.label,
    required this.value,
  });
}
