import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hsro/features/notice/models/emergency_notice_model.dart';
import 'package:hsro/shared/widgets/auto_scroll_text.dart';

class EmergencyNoticeDetailView extends StatelessWidget {
  const EmergencyNoticeDetailView({
    super.key,
    required this.notice,
  });

  final EmergencyNotice notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryLabel = _emergencyNoticeCategoryLabel(notice.category);

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final headerMaxExtent = _calculateEmergencyHeaderMaxExtent(
            context: context,
            availableWidth: constraints.maxWidth,
            title: notice.title,
          );

          return CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _EmergencyNoticeHeaderDelegate(
                  notice: notice,
                  postedLabel: '게시 : ${_formatDateTime(notice.createdAt)}',
                  validLabel: '유효 : ${_formatDateTime(notice.endAt)}',
                  categoryLabel: categoryLabel,
                  expandedExtent: headerMaxExtent,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: MarkdownBody(
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
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
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
                ),
              ),
            ],
          );
        },
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

double _calculateEmergencyHeaderMaxExtent({
  required BuildContext context,
  required double availableWidth,
  required String title,
}) {
  final theme = Theme.of(context);
  final titleStyle = theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        height: 1.35,
      ) ??
      const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.35,
      );
  final contentWidth =
      availableWidth > 40 ? availableWidth - 40 : availableWidth;
  final titlePainter = TextPainter(
    text: TextSpan(text: title, style: titleStyle),
    maxLines: 3,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: contentWidth);

  const verticalPadding = 33.0;
  const titleToMetaGap = 12.0;
  const postedRowHeight = 28.0;
  const rowGap = 6.0;
  const validRowHeight = 20.0;
  const dividerHeight = 1.0;
  const layoutBuffer = 2.0;
  final expandedExtent = verticalPadding +
      titlePainter.height +
      titleToMetaGap +
      postedRowHeight +
      rowGap +
      validRowHeight +
      dividerHeight +
      layoutBuffer;

  final minExpandedExtent = _EmergencyNoticeHeaderDelegate.minHeaderExtent + 52;
  final resolvedExtent = expandedExtent.ceilToDouble();

  return resolvedExtent < minExpandedExtent
      ? minExpandedExtent
      : resolvedExtent;
}

class _EmergencyNoticeHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _EmergencyNoticeHeaderDelegate({
    required this.notice,
    required this.postedLabel,
    required this.validLabel,
    required this.categoryLabel,
    required this.expandedExtent,
  });

  static const double minHeaderExtent = 64;

  final EmergencyNotice notice;
  final String postedLabel;
  final String validLabel;
  final String categoryLabel;
  final double expandedExtent;

  @override
  double get minExtent => minHeaderExtent;

  @override
  double get maxExtent => expandedExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final denominator = maxExtent - minExtent;
    final collapseProgress = denominator <= 0
        ? 1.0
        : (shrinkOffset / denominator).clamp(0.0, 1.0).toDouble();
    final expandedOpacity =
        (1 - collapseProgress * 1.35).clamp(0.0, 1.0).toDouble();
    final compactOpacity =
        ((collapseProgress - 0.4) / 0.6).clamp(0.0, 1.0).toDouble();

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -shrinkOffset * 0.18,
            left: 0,
            right: 0,
            height: maxExtent,
            child: Opacity(
              opacity: expandedOpacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.35,
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
                            postedLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _EmergencyNoticeCategoryBadge(label: categoryLabel),
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
                            validLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: compactOpacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 11),
                child: Row(
                  children: [
                    Expanded(
                      child: AutoScrollText(
                        text: notice.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ) ??
                            const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                        height: 24,
                        scrollDuration: const Duration(seconds: 5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _EmergencyNoticeCategoryBadge(
                      label: categoryLabel,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _EmergencyNoticeHeaderDelegate oldDelegate) {
    return notice != oldDelegate.notice ||
        postedLabel != oldDelegate.postedLabel ||
        validLabel != oldDelegate.validLabel ||
        categoryLabel != oldDelegate.categoryLabel ||
        expandedExtent != oldDelegate.expandedExtent;
  }
}

class _EmergencyNoticeCategoryBadge extends StatelessWidget {
  const _EmergencyNoticeCategoryBadge({
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 96 : 128),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorScheme.onError,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String _emergencyNoticeCategoryLabel(String category) {
  switch (category) {
    case 'shuttle':
      return '셔틀';
    case 'asan_citybus':
      return '아산 버스';
    case 'cheonan_citybus':
      return '천안 버스';
    case 'subway':
      return '지하철';
  }

  return '긴급';
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
