import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

class PlatformUtils {
  // Swift AppDelegate에 등록한 채널 이름과 정확히 같아야 Flutter -> iOS 호출이 연결된다.
  static const MethodChannel _iosDisclaimerDialogChannel =
      MethodChannel('hsro/ios_disclaimer_dialog');

  // 간결한 면책 문구
  static const String shortDisclaimer = '호서대학교 비공식 앱';

  // 전체 면책 문구
  static const String fullDisclaimer = '이 앱은 호서대학교 비공식 앱입니다.\n'
      '시내버스 정보는 공공데이터 포털 API를 활용합니다.\n'
      '셔틀버스 정보는 호서대학교 홈페이지 시간표를 기반으로 제공됩니다.\n'
      '1호선 정보는 서울시 API를 활용합니다.\n'
      '실시간 알림 수신을 위해 공식 HOSEO BUS앱과 같이 이용하시는걸 추천합니다.\n';

  // 안드로이드 면책 다이얼로그
  static Future<void> showAndroidDisclaimerDialog(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[850] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            '이 앱은 비공식 입니다.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              fullDisclaimer,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                height: 1.5,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                '확인',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 4.0,
        );
      },
    );
  }

  // iOS 면책 다이얼로그
  static Future<void> showIOSDisclaimerDialog(BuildContext context) async {
    try {
      // iOS에서는 Flutter 다이얼로그 대신 UIKit의 UIAlertController를 띄우도록 요청한다.
      await _iosDisclaimerDialogChannel.invokeMethod<void>(
        'show',
        <String, String>{
          'title': '이 앱은 비공식 입니다.',
          'message': fullDisclaimer,
          'buttonTitle': '확인',
        },
      );
      return;
    } on PlatformException {
      // 네이티브 다이얼로그 표시 중 오류가 나면 기존 Flutter 다이얼로그로 대체한다.
      if (!context.mounted) {
        return;
      }
      return _showFlutterIOSDisclaimerDialog(context);
    } on MissingPluginException {
      // iOS가 아니거나 채널 등록 전인 테스트 환경에서도 화면이 깨지지 않게 한다.
      if (!context.mounted) {
        return;
      }
      return _showFlutterIOSDisclaimerDialog(context);
    }
  }

  // iOS 네이티브 채널을 사용할 수 없을 때의 Flutter fallback
  static Future<void> _showFlutterIOSDisclaimerDialog(BuildContext context) {
    return showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(
            '이 앱은 비공식 입니다.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              fullDisclaimer,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 플랫폼에 따른 면책 다이얼로그 표시
  static Future<void> showPlatformDisclaimerDialog(BuildContext context) async {
    if (Platform.isIOS) {
      return showIOSDisclaimerDialog(context);
    } else {
      return showAndroidDisclaimerDialog(context);
    }
  }
}
