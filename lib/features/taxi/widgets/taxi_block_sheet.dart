import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/widgets/taxi_confirm_dialog.dart';
import 'package:hsro/features/taxi/widgets/taxi_report_sheet.dart';

/// 한 번 더 확인한 뒤 참여자를 차단한다. 차단했으면 true를 돌려준다.
///
/// 차단 뒤에는 이어서 신고할 수 있게 안내한다.
Future<bool> blockTaxiMember(
  BuildContext context, {
  required TaxiRepository repository,
  required String partyId,
  required String targetLabel,
}) async {
  final confirmed = await showTaxiDestructiveConfirm(
    context,
    title: '$targetLabel님을 차단할까요?',
    message:
        '이 사람의 메시지가 접히고, 앞으로 서로의 택시팟이 보이지 않아요. '
        '상대에게는 알리지 않아요.',
    action: '차단',
  );
  if (!confirmed || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await repository.blockMember(partyId: partyId, targetLabel: targetLabel);
  } on TaxiApiException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return false;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('차단하지 못했어요. 잠시 후 다시 시도해주세요.')),
    );
    return false;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('차단했어요. 내정보 > 차단 목록에서 해제할 수 있어요.'),
        action: SnackBarAction(
          label: '신고도 하기',
          onPressed: () {
            if (!context.mounted) return;
            reportTaxiMember(
              context,
              repository: repository,
              partyId: partyId,
              targetLabel: targetLabel,
            );
          },
        ),
      ),
    );
  return true;
}
