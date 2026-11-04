import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// 공지·긴급공지 본문 마크다운 스타일.
// 관리자 페이지의 Toast UI 뷰어처럼 제목(#~######)을 모두 굵게, 본문보다 확실히
// 크게 그려 앱에서도 제목이 눈에 띄게 한다.
MarkdownStyleSheet noticeMarkdownStyleSheet(
  ThemeData theme, {
  required TextStyle? paragraph,
}) {
  final base = theme.textTheme.bodyLarge;
  TextStyle? heading(double fontSize) => base?.copyWith(
    fontSize: fontSize,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: theme.colorScheme.onSurface,
  );

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: paragraph,
    h1: heading(24),
    h1Padding: const EdgeInsets.only(top: 16),
    h2: heading(22),
    h2Padding: const EdgeInsets.only(top: 14),
    h3: heading(20),
    h3Padding: const EdgeInsets.only(top: 12),
    h4: heading(18),
    h4Padding: const EdgeInsets.only(top: 8),
    h5: heading(16),
    h5Padding: const EdgeInsets.only(top: 6),
    h6: heading(15),
    h6Padding: const EdgeInsets.only(top: 6),
  );
}
