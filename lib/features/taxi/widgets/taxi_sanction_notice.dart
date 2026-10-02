import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hsro/core/constants/app_links.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:url_launcher/url_launcher.dart';

/// 이용 제한 이의제기는 설정의 피드백/지원 폼으로 받는다.
Future<void> openTaxiAppeal() async {
  final url = Uri.parse(feedbackFormUrl);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

/// 정지 중일 때 생성·참여 대신 보여줄 안내 문구.
String taxiSuspensionMessage(TaxiSanction suspension) {
  final period = suspension.isPermanent
      ? '택시팟 이용이 영구 제한됐어요.'
      : '${suspension.periodLabel} 새 팟을 만들거나 참여할 수 없어요.';
  return '$period\n사유: ${suspension.reason}';
}

/// 아직 확인하지 않은 제재를 한 번 안내한다. 닫으면 확인한 것으로 본다.
Future<void> showTaxiSanctionNotice(
  BuildContext context,
  TaxiSanction sanction, {
  String? userKey,
}) async {
  final title = sanction.isWarning ? '경고를 받았어요' : '택시팟 이용이 제한됐어요';
  final lines = [
    if (sanction.isWarning)
      '신고가 확인되어 경고가 부과됐어요. 반복되면 이용이 제한될 수 있어요.'
    else if (sanction.isPermanent)
      '새 팟을 만들거나 참여할 수 없어요.'
    else
      '${sanction.periodLabel} 새 팟을 만들거나 참여할 수 없어요.',
    '사유: ${sanction.reason}',
    userKey == null
        ? '이의가 있으면 피드백/지원으로 알려주세요.'
        : '이의가 있으면 피드백/지원에 고유번호($userKey)를 적어 알려주세요.',
  ];
  final message = lines.join('\n\n');
  final appeal = Theme.of(context).platform == TargetPlatform.iOS
      ? await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(message),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('이의제기'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context, false),
                child: const Text('확인'),
              ),
            ],
          ),
        )
      : await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              sanction.isWarning
                  ? Icons.warning_amber_rounded
                  : Icons.block_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('이의제기'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('확인'),
              ),
            ],
          ),
        );
  if (appeal == true) await openTaxiAppeal();
}
