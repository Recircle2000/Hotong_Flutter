import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hsro/features/notice/models/notice_model.dart';
import 'package:hsro/features/notice/viewmodel/notice_viewmodel.dart';

class NoticeDetailView extends StatelessWidget {
  final Notice notice;

  const NoticeDetailView({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noticeViewModel = Get.find<NoticeViewModel>();

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
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.appBarTheme.iconTheme?.color,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목, 게시 시각, 카테고리 영역
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notice.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          notice.createdAt.toLocal().toString().split('.')[0],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: noticeViewModel
                                .getNoticeTypeColor(notice.noticeType),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            noticeViewModel
                                .getNoticeTypeDisplayName(notice.noticeType),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 24),
              MarkdownBody(
                // 공지 본문은 마크다운으로 렌더링
                data: notice.content,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 16) - 1,
                    height: 1.7,
                    letterSpacing: 0.6,
                  ),
                ),
                onTapLink: (text, href, title) async {
                  // 링크가 있으면 외부 브라우저로 열기
                  if (href != null && await canLaunchUrl(Uri.parse(href))) {
                    await launchUrl(
                      Uri.parse(href),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                sizedImageBuilder: (config) {
                  // 마크다운 이미지에 확대 보기와 플레이스홀더 적용
                  return _NoticeMarkdownImage(
                    imageUrl: config.uri.toString(),
                    width: config.width,
                    height: config.height,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeMarkdownImage extends StatelessWidget {
  const _NoticeMarkdownImage({
    required this.imageUrl,
    this.width,
    this.height,
  });

  final String imageUrl;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InstaImageViewer(
      // 이미지 탭 시 확대/드래그 뷰어 제공
      imageUrl: imageUrl,
      backgroundColor: Colors.black,
      backgroundIsTransparent: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              // 로딩 중에는 공통 플레이스홀더 표시
              return _NoticeImageLoadingPlaceholder(
                loadingProgress: loadingProgress,
                minHeight: height ?? 180,
                backgroundColor: colorScheme.surfaceContainerHighest,
                textColor: colorScheme.onSurfaceVariant,
                width: width,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // 이미지 실패 시 오류 플레이스홀더 표시
              return _NoticeImageErrorPlaceholder(
                minHeight: height ?? 180,
                backgroundColor: colorScheme.surfaceContainerHighest,
                iconColor: colorScheme.error,
                textColor: colorScheme.onSurfaceVariant,
                width: width,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NoticeImageLoadingPlaceholder extends StatelessWidget {
  const _NoticeImageLoadingPlaceholder({
    required this.loadingProgress,
    required this.minHeight,
    required this.backgroundColor,
    required this.textColor,
    this.width,
  });

  final ImageChunkEvent loadingProgress;
  final double minHeight;
  final Color backgroundColor;
  final Color textColor;
  final double? width;

  double? get _progressValue {
    // 총 바이트 수가 있으면 진행률 계산
    final expectedTotalBytes = loadingProgress.expectedTotalBytes;
    if (expectedTotalBytes == null || expectedTotalBytes == 0) {
      return null;
    }

    return loadingProgress.cumulativeBytesLoaded / expectedTotalBytes;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 플랫폼에 맞는 로딩 인디케이터 사용
          _AdaptiveImageLoadingIndicator(progress: _progressValue),
          const SizedBox(height: 12),
          Text(
            '이미지 불러오는 중',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _NoticeImageErrorPlaceholder extends StatelessWidget {
  const _NoticeImageErrorPlaceholder({
    required this.minHeight,
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
    this.width,
  });

  final double minHeight;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 이미지 로드 실패 안내
          Icon(Icons.broken_image_outlined, size: 34, color: iconColor),
          const SizedBox(height: 12),
          Text(
            '이미지를 불러올 수 없습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveImageLoadingIndicator extends StatelessWidget {
  const _AdaptiveImageLoadingIndicator({this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;

    // Apple 플랫폼은 Cupertino 인디케이터 사용
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return const CupertinoActivityIndicator(radius: 12);
    }

    // 그 외 플랫폼은 Material 인디케이터 사용
    return SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 2.6,
      ),
    );
  }
}
