import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/notice_model.dart';
import '../utils/responsive_layout.dart';
import '../viewmodel/notice_viewmodel.dart';

class NoticeDetailView extends StatelessWidget {
  final Notice notice;

  const NoticeDetailView({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final layout = AppResponsive.of(context);
    final noticeViewModel = Get.find<NoticeViewModel>();

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
      ),
      body: SingleChildScrollView(
        child: AppPageFrame(
          child: Padding(
            padding: EdgeInsets.all(layout.space(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: layout.space(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: layout.font(
                            theme.textTheme.headlineSmall?.fontSize ?? 24,
                            maxScale: 1.12,
                          ),
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: layout.space(12)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: layout.icon(16),
                            color: colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(width: layout.space(6, maxScale: 1.08)),
                          Expanded(
                            child: Text(
                              notice.createdAt
                                  .toLocal()
                                  .toString()
                                  .split('.')[0],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: layout.font(
                                  theme.textTheme.bodyMedium?.fontSize ?? 14,
                                ),
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: layout.space(10),
                              vertical: layout.space(6, maxScale: 1.08),
                            ),
                            decoration: BoxDecoration(
                              color: noticeViewModel.getNoticeTypeColor(
                                notice.noticeType,
                              ),
                              borderRadius:
                                  BorderRadius.circular(layout.radius(16)),
                            ),
                            child: Text(
                              noticeViewModel.getNoticeTypeDisplayName(
                                notice.noticeType,
                              ),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: layout.font(12),
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
                SizedBox(height: layout.space(24)),
                MarkdownBody(
                  data: notice.content,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: layout.font(
                        (theme.textTheme.bodyLarge?.fontSize ?? 16) - 1,
                      ),
                      height: 1.7,
                      letterSpacing: 0.6,
                    ),
                  ),
                  onTapLink: (text, href, title) async {
                    if (href != null && await canLaunchUrl(Uri.parse(href))) {
                      await launchUrl(
                        Uri.parse(href),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  sizedImageBuilder: (config) {
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
    final layout = AppResponsive.of(context);

    return InstaImageViewer(
      imageUrl: imageUrl,
      backgroundColor: Colors.black,
      backgroundIsTransparent: false,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: layout.space(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(layout.radius(16)),
          child: Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return _NoticeImageLoadingPlaceholder(
                loadingProgress: loadingProgress,
                minHeight: height ?? layout.space(180, maxScale: 1.10),
                backgroundColor: colorScheme.surfaceContainerHighest,
                textColor: colorScheme.onSurfaceVariant,
                width: width,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _NoticeImageErrorPlaceholder(
                minHeight: height ?? layout.space(180, maxScale: 1.10),
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
    final expectedTotalBytes = loadingProgress.expectedTotalBytes;
    if (expectedTotalBytes == null || expectedTotalBytes == 0) {
      return null;
    }

    return loadingProgress.cumulativeBytesLoaded / expectedTotalBytes;
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppResponsive.of(context);

    return Container(
      width: width ?? double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.symmetric(
        horizontal: layout.space(20),
        vertical: layout.space(28, maxScale: 1.10),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(layout.radius(16)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _AdaptiveImageLoadingIndicator(progress: _progressValue),
          SizedBox(height: layout.space(12)),
          Text(
            '이미지 불러오는 중',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: layout.font(
                    Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14,
                  ),
                  color: textColor,
                ),
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
    final layout = AppResponsive.of(context);

    return Container(
      width: width ?? double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.symmetric(
        horizontal: layout.space(20),
        vertical: layout.space(28, maxScale: 1.10),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(layout.radius(16)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: layout.icon(34, maxScale: 1.12),
            color: iconColor,
          ),
          SizedBox(height: layout.space(12)),
          Text(
            '이미지를 불러올 수 없습니다.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: layout.font(
                    Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14,
                  ),
                  color: textColor,
                ),
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
    final layout = AppResponsive.of(context);

    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return CupertinoActivityIndicator(radius: layout.space(12));
    }

    return SizedBox(
      width: layout.icon(26, maxScale: 1.12),
      height: layout.icon(26, maxScale: 1.12),
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: layout.border(2.6),
      ),
    );
  }
}
