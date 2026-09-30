import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TaxiSheetAction<T> {
  const TaxiSheetAction({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData icon;
  final bool destructive;
}

/// 메시지·멤버를 눌렀을 때 고를 동작 목록.
/// iOS는 Cupertino 액션 시트, 그 외에는 머티리얼 bottom sheet를 쓴다.
Future<T?> showTaxiActionSheet<T>(
  BuildContext context, {
  String? title,
  required List<TaxiSheetAction<T>> actions,
}) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: action.destructive,
              onPressed: () => Navigator.pop(context, action.value),
              child: Text(action.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            for (final action in actions)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(
                  action.icon,
                  color: action.destructive ? colors.error : null,
                ),
                title: Text(
                  action.label,
                  style: action.destructive
                      ? TextStyle(color: colors.error)
                      : null,
                ),
                onTap: () => Navigator.pop(context, action.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
