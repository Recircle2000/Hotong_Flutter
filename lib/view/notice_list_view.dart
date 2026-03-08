import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import '../viewmodel/notice_viewmodel.dart';
import 'notice_detail_view.dart';
import '../utils/responsive_layout.dart';

class NoticeListView extends GetView<NoticeViewModel> {
  const NoticeListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final layout = AppResponsive.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '공지사항',
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            fontSize: layout.font(
              theme.appBarTheme.titleTextStyle?.fontSize ?? 20,
              maxScale: 1.10,
            ),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.appBarTheme.iconTheme?.color,
            size: layout.icon(20),
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list,
              color: theme.appBarTheme.iconTheme?.color,
              size: layout.icon(22),
            ),
            onSelected: (String value) {
              controller.changeFilter(value);
            },
            itemBuilder: (BuildContext context) {
              return controller.filterOptions.map((String option) {
                return PopupMenuItem<String>(
                  value: option,
                  child: Obx(() => Row(
                        children: [
                          Icon(
                            controller.selectedFilter.value == option
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: controller.selectedFilter.value == option
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            size: layout.icon(20),
                          ),
                          SizedBox(width: layout.space(8)),
                          Text(
                            option,
                            style: TextStyle(
                              fontSize: layout.font(14),
                              color: controller.selectedFilter.value == option
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              fontWeight:
                                  controller.selectedFilter.value == option
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                        ],
                      )),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
              strokeWidth: 3,
            ),
          );
        }

        if (controller.error.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: layout.icon(48, maxScale: 1.12),
                  color: colorScheme.error,
                ),
                SizedBox(height: layout.space(16)),
                Text(
                  controller.error.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: layout.font(
                      theme.textTheme.bodyMedium?.fontSize ?? 14,
                    ),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // 진동 피드백 (새로고침 시작)
            HapticFeedback.lightImpact();
            await controller.fetchAllNotices();
            // 진동 피드백 (새로고침 완료)
            HapticFeedback.lightImpact();
          },
          color: colorScheme.primary,
          child: AppPageFrame(
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(vertical: layout.space(12)),
              itemCount: controller.filteredNotices.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.surfaceVariant,
              ),
              itemBuilder: (context, index) {
                final notice = controller.filteredNotices[index];
                return InkWell(
                  onTap: () => Get.to(() => NoticeDetailView(notice: notice)),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: layout.space(20),
                      vertical: layout.space(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notice.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: layout.font(
                                    theme.textTheme.titleMedium?.fontSize ?? 16,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: layout.space(8)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: layout.space(8),
                                vertical: layout.space(4, maxScale: 1.10),
                              ),
                              decoration: BoxDecoration(
                                color: controller
                                    .getNoticeTypeColor(notice.noticeType),
                                borderRadius:
                                    BorderRadius.circular(layout.radius(12)),
                              ),
                              child: Text(
                                controller.getNoticeTypeDisplayName(
                                  notice.noticeType,
                                ),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: layout.font(11),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: layout.space(8)),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: layout.icon(14),
                              color: colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: layout.space(4)),
                            Text(
                              notice.createdAt
                                  .toLocal()
                                  .toString()
                                  .split('.')[0],
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: layout.font(
                                  theme.textTheme.bodySmall?.fontSize ?? 12,
                                ),
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}
