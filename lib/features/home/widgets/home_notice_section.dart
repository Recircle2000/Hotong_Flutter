import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/notice/view/notice_detail_view.dart';
import 'package:hsro/features/notice/view/notice_list_view.dart';
import 'package:hsro/features/notice/viewmodel/notice_viewmodel.dart';
import 'package:hsro/shared/widgets/auto_scroll_text.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

class HomeNoticeSection extends StatelessWidget {
  const HomeNoticeSection({
    super.key,
    required this.noticeViewModel,
  });

  final NoticeViewModel noticeViewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 섹션 제목과 전체보기 링크
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '공지사항',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  noticeViewModel.fetchAllNotices();
                  Get.to(() => const NoticeListView());
                },
                child: Text(
                  '전체보기',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ScaleButton(
            onTap: () {
              // 최신 공지가 있으면 바로 상세, 없으면 목록으로 이동
              final notice = noticeViewModel.notice.value;
              if (notice != null) {
                Get.to(() => NoticeDetailView(notice: notice));
                return;
              }

              noticeViewModel.fetchLatestNotice();
              Get.to(() => const NoticeListView());
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  // 공지 아이콘
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.campaign,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() {
                      if (noticeViewModel.isLoading.value) {
                        // 공지 로딩 중
                        return const Text(
                          '서버에 연결 중...',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        );
                      }

                      final notice = noticeViewModel.notice.value;
                      // 공지 제목은 길면 자동 스크롤
                      return AutoScrollText(
                        text: notice?.title ?? '새로운 공지사항이 없습니다',
                        style: const TextStyle(fontSize: 14),
                        scrollDuration: const Duration(seconds: 5),
                      );
                    }),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
