import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_notice_model.dart';
import '../utils/responsive_layout.dart';

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
    final layout = AppResponsive.of(context);

    return Scaffold(
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
      ),
      body: SingleChildScrollView(
        child: AppPageFrame(
          child: Padding(
            padding: EdgeInsets.all(layout.space(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: layout.font(
                      theme.textTheme.titleLarge?.fontSize ?? 22,
                      maxScale: 1.12,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: layout.space(12)),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: layout.icon(16),
                      color: colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: layout.space(6, maxScale: 1.08)),
                    Expanded(
                      child: Text(
                        '게시 : ${_formatDateTime(notice.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: layout.font(
                            theme.textTheme.bodySmall?.fontSize ?? 12,
                          ),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: layout.space(6, maxScale: 1.08)),
                Row(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: layout.icon(16),
                      color: colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: layout.space(6, maxScale: 1.08)),
                    Expanded(
                      child: Text(
                        '유효 : ${_formatDateTime(notice.endAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: layout.font(
                            theme.textTheme.bodySmall?.fontSize ?? 12,
                          ),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: layout.space(20)),
                Divider(color: colorScheme.outlineVariant),
                SizedBox(height: layout.space(20)),
                MarkdownBody(
                  data: notice.content,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: layout.font(
                        theme.textTheme.bodyLarge?.fontSize ?? 16,
                      ),
                      height: 1.6,
                    ),
                  ),
                  onTapLink: (text, href, title) async {
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
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
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

              return _EmergencyImageLoadingPlaceholder(
                loadingProgress: loadingProgress,
                minHeight: height ?? layout.space(180, maxScale: 1.10),
                backgroundColor: colorScheme.surfaceContainerHighest,
                textColor: colorScheme.onSurfaceVariant,
                width: width,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _EmergencyImageErrorPlaceholder(
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
