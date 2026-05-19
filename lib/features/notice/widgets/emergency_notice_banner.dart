import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:hsro/features/notice/models/emergency_notice_model.dart';
import 'package:hsro/features/notice/view/emergency_notice_detail_view.dart';
import 'package:hsro/features/notice/viewmodel/emergency_notice_viewmodel.dart';
import 'package:hsro/shared/widgets/auto_scroll_text.dart';

class EmergencyNoticeBanner extends StatefulWidget {
  const EmergencyNoticeBanner({
    super.key,
    required this.category,
  });

  final EmergencyNoticeCategory category;

  @override
  State<EmergencyNoticeBanner> createState() => _EmergencyNoticeBannerState();
}

class _EmergencyNoticeBannerState extends State<EmergencyNoticeBanner> {
  late final EmergencyNoticeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = Get.isRegistered<EmergencyNoticeViewModel>()
        ? Get.find<EmergencyNoticeViewModel>()
        : Get.put(EmergencyNoticeViewModel());
    _loadNotice();
  }

  @override
  void didUpdateWidget(covariant EmergencyNoticeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _loadNotice();
    }
  }

  void _loadNotice() {
    _viewModel.fetchLatestNotice(widget.category, force: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bannerColor = isDark
        ? colorScheme.errorContainer.withValues(alpha: 0.45)
        : colorScheme.errorContainer;
    final foregroundColor = colorScheme.onErrorContainer;

    return Obx(() {
      final notice = _viewModel.isLoadingFor(widget.category)
          ? null
          : _viewModel.noticeFor(widget.category);

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        reverseDuration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: notice == null
            ? const SizedBox.shrink(key: ValueKey('empty'))
            : _buildBannerContent(
                context: context,
                notice: notice,
                bannerColor: bannerColor,
                foregroundColor: foregroundColor,
              ),
      );
    });
  }

  Widget _buildBannerContent({
    required BuildContext context,
    required EmergencyNotice notice,
    required Color bannerColor,
    required Color foregroundColor,
  }) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ) ??
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        );

    return Container(
      key: ValueKey(notice.id),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bannerColor,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Get.to(() => EmergencyNoticeDetailView(notice: notice));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.notification_important_rounded,
                  size: 18,
                  color: foregroundColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AutoScrollText(
                    text: notice.title,
                    style: titleStyle,
                    height: 20,
                    pauseDuration: const Duration(milliseconds: 1200),
                    scrollDuration: const Duration(seconds: 4),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: foregroundColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
