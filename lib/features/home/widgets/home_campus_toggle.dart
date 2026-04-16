import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';

class HomeCampusToggle extends StatelessWidget {
  const HomeCampusToggle({
    super.key,
    required this.settingsViewModel,
  });

  final SettingsViewModel settingsViewModel;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 현재 선택된 캠퍼스에 따라 토글 스타일 갱신
      final isAsan = settingsViewModel.selectedCampus.value == '아산';
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CampusToggleButton(
                  text: '아캠',
                  isSelected: isAsan,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    settingsViewModel.setCampus('아산');
                  },
                ),
                _CampusToggleButton(
                  text: '천캠',
                  isSelected: !isAsan,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    settingsViewModel.setCampus('천안');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _CampusToggleButton extends StatelessWidget {
  const _CampusToggleButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        // 선택 상태 전환을 부드럽게 표시
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? colorScheme.onPrimary
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}
