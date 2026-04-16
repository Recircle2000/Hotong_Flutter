import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hsro/features/notice/models/emergency_notice_model.dart';

class EmergencyNoticeDetailView extends StatelessWidget {
  const EmergencyNoticeDetailView({
    super.key,
    required this.notice,
  });

  final EmergencyNotice notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목과 게시/유효 시각 영역
            Text(
              notice.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '게시 : ${_formatDateTime(notice.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.event_busy,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '유효 : ${_formatDateTime(notice.endAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 20),
            MarkdownBody(
              // 긴급 공지 본문은 마크다운으로 렌더링
              data: notice.content,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              onTapLink: (text, href, title) async {
                // 링크가 유효하면 외부 브라우저로 열기
                if (href == null) {
                  return;
                }

                final uri = Uri.tryParse(href);
                if (uri == null) {
                  return;
                }

                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              sizedImageBuilder: (config) {
                // 이미지 확대 보기와 공통 플레이스홀더 적용
                return _EmergencyMarkdownImage(
                  imageUrl: config.uri.toString(),
                  width: config.width,
                  height: config.height,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    // 긴급 공지 시각 표시 형식을 yyyy-MM-dd HH:mm으로 고정
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

class _EmergencyMarkdownImage extends StatelessWidget {
  const _EmergencyMarkdownImage({
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
              return _EmergencyImageLoadingPlaceholder(
                loadingProgress: loadingProgress,
                minHeight: height ?? 180,
                backgroundColor: colorScheme.surfaceContainerHighest,
                textColor: colorScheme.onSurfaceVariant,
                width: width,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // 이미지 실패 시 오류 플레이스홀더 표시
              return _EmergencyImageErrorPlaceholder(
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

class _EmergencyImageLoadingPlaceholder extends StatelessWidget {
  const _EmergencyImageLoadingPlaceholder({
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

class _EmergencyImageErrorPlaceholder extends StatelessWidget {
  const _EmergencyImageErrorPlaceholder({
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
