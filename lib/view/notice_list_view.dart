import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import '../viewmodel/notice_viewmodel.dart';
import 'notice_detail_view.dart';

class NoticeListView extends GetView<NoticeViewModel> {
  const NoticeListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '공지사항',
          style: theme.appBarTheme.titleTextStyle,
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.appBarTheme.iconTheme?.color, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: theme.appBarTheme.iconTheme?.color),
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
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        option,
                        style: TextStyle(
                          color: controller.selectedFilter.value == option 
                            ? colorScheme.primary 
                            : colorScheme.onSurface,
                          fontWeight: controller.selectedFilter.value == option 
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
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  controller.error.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
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
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notice.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: controller.getNoticeTypeColor(notice.noticeType),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              controller.getNoticeTypeDisplayName(notice.noticeType),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            notice.createdAt.toLocal().toString().split('.')[0],
                            style: theme.textTheme.bodySmall?.copyWith(
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
        );
      }),
    );
  }
}
