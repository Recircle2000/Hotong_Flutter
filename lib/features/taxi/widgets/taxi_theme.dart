import 'package:flutter/material.dart';

// 택시팟 화면에서 함께 쓰는 색상과 카드·입력창 스타일.

/// 홈의 택시 메뉴와 동일한 포인트 색상.
const taxiAccent = Color(0xFFF5A623);

/// [taxiAccent] 배경 위에 올리는 글자·아이콘 색상.
const taxiAccentForeground = Color(0xFF30210A);

Color taxiTint(BuildContext context, [double? alpha]) => taxiAccent.withValues(
  alpha:
      alpha ?? (Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.12),
);

/// 일반 배경 위에서 읽기 좋은 포인트 글자 색상.
Color taxiAccentText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFFC766)
    : const Color(0xFF855300);

BoxDecoration taxiCardDecoration(BuildContext context) => BoxDecoration(
  color: Theme.of(context).cardColor,
  borderRadius: BorderRadius.circular(24),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ],
);

InputDecoration taxiInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  IconData? icon,
  bool enabled = true,
}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    suffixIcon: enabled
        ? null
        : const Icon(Icons.lock_outline_rounded, size: 18),
    floatingLabelStyle: TextStyle(color: taxiAccentText(context)),
    filled: true,
    fillColor: colors.onSurface.withValues(alpha: enabled ? 0.04 : 0.025),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: taxiAccent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.error, width: 1.5),
    ),
  );
}
