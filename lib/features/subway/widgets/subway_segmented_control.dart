import 'package:flutter/material.dart';

// 지하철 화면에서 함께 쓰는 무채색 세그먼트 토글
class SubwaySegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;
  final double fontSize;

  const SubwaySegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 44,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final count = labels.length;
    final alignX = count == 1 ? 0.0 : -1 + 2 * selectedIndex / (count - 1);

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 선택된 칸 위로 미끄러지는 면
          AnimatedAlign(
            alignment: Alignment(alignX, 0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / count,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark
                      ? onSurface.withValues(alpha: 0.12)
                      : theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Center(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: i == selectedIndex
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: i == selectedIndex
                              ? onSurface
                              : theme.hintColor,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// 1호선 노선색 (다크 모드에서는 밝은 톤)
Color subwayLineColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF478ED1)
        : const Color(0xFF0052A4);

// 섹션 머리에 한 번만 두는 1호선 표시
class SubwayLineMark extends StatelessWidget {
  const SubwayLineMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: subwayLineColor(context),
        shape: BoxShape.circle,
      ),
      child: const Text(
        '1',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
