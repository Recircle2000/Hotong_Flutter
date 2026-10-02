import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/notice/view/notice_detail_view.dart';
import 'package:hsro/features/notice/view/notice_list_view.dart';
import 'package:hsro/features/notice/viewmodel/notice_viewmodel.dart';
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '공지사항',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () {
                  noticeViewModel.fetchAllNotices();
                  Get.to(() => const NoticeListView());
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  alignment: Alignment.center,
                  child: Text(
                    '전체보기',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
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
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Obx(() {
                      if (noticeViewModel.isLoading.value) {
                        // 공지 로딩 중
                        return const Text(
                          '서버에 연결 중...',
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        );
                      }

                      final notice = noticeViewModel.notice.value;
                      // 공지 제목은 길면 말줄임표로 자름
                      return Text(
                        notice?.title ?? '새로운 공지사항이 없습니다',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15),
                      );
                    }),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Color(0xFF8A909C),
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
