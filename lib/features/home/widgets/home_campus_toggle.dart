import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';

class HomeCampusToggle extends StatelessWidget {
  const HomeCampusToggle({super.key, required this.settingsViewModel});

  final SettingsViewModel settingsViewModel;

  void _select(String campus) {
    if (settingsViewModel.selectedCampus.value == campus) {
      return;
    }
    HapticFeedback.lightImpact();
    settingsViewModel.setCampus(campus);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 현재 선택된 캠퍼스에 따라 토글 스타일 갱신
      final isAsan = settingsViewModel.selectedCampus.value == '아산';
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Center(
          // 알약 모양 트랙 위에 선택된 캠퍼스만 흰 버튼으로 표시
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE6E8EC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CampusToggleButton(
                  text: '아캠',
                  isSelected: isAsan,
                  onTap: () => _select('아산'),
                ),
                _CampusToggleButton(
                  text: '천캠',
                  isSelected: !isAsan,
                  onTap: () => _select('천안'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark ? Colors.grey[700]! : Colors.white;
    final selectedTextColor = isDark ? Colors.white : const Color(0xFF16181D);
    final unselectedTextColor = isDark
        ? Colors.grey[400]!
        : const Color(0xFF5B616E);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        // 선택 상태 전환을 부드럽게 표시
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor
              : selectedColor.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            if (isSelected)
              const BoxShadow(
                color: Color(0x2416181D),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }
}
