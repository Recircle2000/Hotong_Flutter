import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

/// 되돌리기 어려운 동작(나가기, 취소, 로그아웃)을 한 번 더 확인한다.
///
/// [nativeIOS]가 true면 iOS 26+는 리퀴드 글라스 알림, 그 이전 iOS는
/// Cupertino 알림을 쓰고, 그 외에는 머티리얼 다이얼로그를 쓴다.
Future<bool> showTaxiDestructiveConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String cancelTitle = '닫기',
  bool nativeIOS = false,
}) async {
  if (nativeIOS && NativeLiquidGlassUtils.supportsLiquidGlass) {
    try {
      // UIKit presents this above the native tab bar; no Flutter overlay or
      // global glass suppression is needed.
      return await LiquidGlassAlert.destructive(
        context: context,
        title: title,
        message: message,
        destructiveTitle: action,
        cancelTitle: cancelTitle,
      );
    } on PlatformException {
      if (!context.mounted) return false;
    } on MissingPluginException {
      if (!context.mounted) return false;
    }
  }
  if (!context.mounted) return false;
  if (nativeIOS && Theme.of(context).platform == TargetPlatform.iOS) {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelTitle),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelTitle),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

/// 되돌릴 수 있는 선택(알림 받기 등)을 묻는다. iOS에서는 Cupertino 알림을 쓴다.
Future<bool> showTaxiConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String cancelTitle = '닫기',
}) async {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelTitle),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelTitle),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}
