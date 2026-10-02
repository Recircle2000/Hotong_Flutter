import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

typedef TaxiReportSubmit =
    Future<void> Function(TaxiReportReason reason, String? detail);

/// 신고 시트를 띄워 접수하고, 접수되면 스낵바로 알린다.
Future<void> reportTaxiMember(
  BuildContext context, {
  required TaxiRepository repository,
  required String partyId,
  required String targetLabel,
  int? messageId,
}) async {
  final submitted = await showTaxiReportSheet(
    context,
    targetLabel: targetLabel,
    onSubmit: (reason, detail) => repository.reportMember(
      partyId,
      targetLabel: targetLabel,
      reason: reason,
      detail: detail,
      messageId: messageId,
    ),
  );
  if (!submitted || !context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('신고가 접수됐어요. 운영진이 확인할게요.')));
}

/// 참여자 신고 사유와 내용을 받는다. 접수되면 true를 돌려준다.
///
/// [onSubmit]이 [TaxiApiException]을 던지면 시트를 닫지 않고 메시지를 보여준다.
Future<bool> showTaxiReportSheet(
  BuildContext context, {
  required String targetLabel,
  required TaxiReportSubmit onSubmit,
}) async {
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        _TaxiReportSheet(targetLabel: targetLabel, onSubmit: onSubmit),
  );
  return submitted ?? false;
}

class _TaxiReportSheet extends StatefulWidget {
  const _TaxiReportSheet({required this.targetLabel, required this.onSubmit});

  final String targetLabel;
  final TaxiReportSubmit onSubmit;

  @override
  State<_TaxiReportSheet> createState() => _TaxiReportSheetState();
}

class _TaxiReportSheetState extends State<_TaxiReportSheet> {
  final _detail = TextEditingController();
  TaxiReportReason? _reason;
  bool _submitting = false;
  String? _error;

  bool get _canSubmit =>
      !_submitting &&
      _reason != null &&
      (_reason != TaxiReportReason.other || _detail.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _detail.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final detail = _detail.text.trim();
      await widget.onSubmit(_reason!, detail.isEmpty ? null : detail);
      if (mounted) Navigator.pop(context, true);
    } on TaxiApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '신고를 보내지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final detailRequired = _reason == TaxiReportReason.other;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.targetLabel} 신고',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '신고한 사실은 상대에게 알리지 않아요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            RadioGroup<TaxiReportReason>(
              groupValue: _reason,
              onChanged: (reason) {
                if (!_submitting) setState(() => _reason = reason);
              },
              child: Column(
                children: [
                  for (final reason in TaxiReportReason.values)
                    RadioListTile<TaxiReportReason>(
                      key: ValueKey('report-reason-${reason.code}'),
                      value: reason,
                      activeColor: taxiAccent,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        reason.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: reason.description.isEmpty
                          ? null
                          : Text(reason.description),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('report-detail'),
              controller: _detail,
              enabled: !_submitting,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              decoration: taxiInputDecoration(
                context,
                label: detailRequired ? '내용 (필수)' : '내용 (선택)',
                hint: '무슨 일이 있었는지 적어주세요.',
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: taxiTint(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: taxiAccentText(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '신고 내용과 이 팟의 최근 채팅이 운영진 검토를 위해 저장돼요. '
                      '처리 후 1년이 지나면 삭제돼요.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ScaleButton(
              onTap: _canSubmit ? _submit : null,
              child: AbsorbPointer(
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    key: const ValueKey('report-submit'),
                    onPressed: _canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onError,
                      textStyle: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _submitting
                        ? SizedBox.square(
                            dimension: 21,
                            child: CircularProgressIndicator.adaptive(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.onError,
                              ),
                              strokeWidth: 2.3,
                            ),
                          )
                        : const Text('신고하기'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
