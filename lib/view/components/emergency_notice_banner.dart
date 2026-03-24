import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/emergency_notice_model.dart';
import '../../viewmodel/emergency_notice_viewmodel.dart';
import '../emergency_notice_detail_view.dart';

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
    final borderColor = isDark
        ? colorScheme.error.withValues(alpha: 0.55)
        : colorScheme.error.withValues(alpha: 0.28);
    final foregroundColor = colorScheme.onErrorContainer;

    return Obx(() {
      if (_viewModel.isLoadingFor(widget.category)) {
        return const SizedBox.shrink();
      }

      final notice = _viewModel.noticeFor(widget.category);
      if (notice == null) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bannerColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Get.to(() => EmergencyNoticeDetailView(notice: notice));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    Icons.notification_important_rounded,
                    size: 18,
                    color: foregroundColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notice.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: foregroundColor,
                      ),
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
    });
  }
}
