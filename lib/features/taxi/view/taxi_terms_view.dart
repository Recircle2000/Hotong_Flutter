import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// 택시팟 이용약관 전문(노션). 비어 있으면 '전문 보기' 버튼을 숨긴다.
const taxiTermsUrl = '';

/// 약관 전문을 외부 브라우저로 연다.
Future<void> openTaxiTerms() async {
  final url = Uri.parse(taxiTermsUrl);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

/// 동의 화면에 보여주는 핵심 수칙. 전문은 [taxiTermsUrl]에 있다.
const taxiTermsSummary = <({String title, String body})>[
  (title: '본인만 이용하기', body: '학교 이메일로 인증한 계정은 본인만 쓰고, 다른 사람에게 빌려주지 않아요.'),
  (title: '약속 지키기', body: '약속한 시간과 장소를 지켜요. 못 가게 되면 미리 알리고 팟에서 나가요.'),
  (title: '요금은 똑같이 나누기', body: '택시비는 탑승 인원이 똑같이 나눠 내고, 내린 뒤 바로 정산해요.'),
  (
    title: '불쾌한 언행 금지',
    body:
        '욕설, 성희롱, 혐오 표현, 위협, 노쇼, 정산 거부는 허용하지 않아요. '
        '신고가 확인되면 경고 없이 이용이 정지되거나 영구 제한될 수 있어요.',
  ),
  (
    title: '신고와 차단',
    body:
        '문제가 있는 참여자는 신고하거나 차단할 수 있어요. '
        '신고가 들어오면 운영진이 신고 시점의 채팅 사본을 확인해요.',
  ),
  (
    title: '호통의 역할',
    body:
        '호통은 같이 탈 사람을 찾는 것만 도와요. '
        '이동 중 생긴 사고나 요금 문제는 함께 탄 사람끼리 해결해야 해요.',
  ),
];

/// 택시팟을 처음 쓸 때 한 번 받는 이용약관 동의 화면.
///
/// 동의하면 true로 닫힌다. 뒤로 가거나 '나가기'를 누르면 false로 닫힌다.
/// [onAgree]가 없으면 내정보에서 다시 읽어 보는 용도라 동의 버튼을 숨긴다.
class TaxiTermsView extends StatefulWidget {
  const TaxiTermsView({super.key, this.onAgree});

  /// 서버에 동의를 기록한다. 실패하면 [TaxiApiException]을 던진다.
  final Future<void> Function()? onAgree;

  @override
  State<TaxiTermsView> createState() => _TaxiTermsViewState();
}

class _TaxiTermsViewState extends State<TaxiTermsView> {
  bool _checked = false;
  bool _saving = false;
  String? _error;

  Future<void> _agree() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAgree!();
      if (mounted) Navigator.of(context).pop(true);
    } on TaxiApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '동의를 저장하지 못했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('택시팟 이용약관'),
          leading: IconButton(
            tooltip: widget.onAgree == null ? '닫기' : '나가기',
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Text(
              '택시팟을 쓰기 전에\n꼭 확인해주세요',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '모르는 사람과 함께 타는 서비스라 서로 지켜야 할 약속이 있어요.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: taxiCardDecoration(context),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, item) in taxiTermsSummary.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: taxiTint(context),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: taxiAccentText(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.body,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (taxiTermsUrl.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: openTaxiTerms,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('이용약관 전문 보기'),
                ),
              ),
          ],
        ),
        bottomNavigationBar: widget.onAgree == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                      CheckboxListTile(
                        key: const ValueKey('taxi-terms-check'),
                        value: _checked,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _checked = value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: taxiAccent,
                        checkColor: taxiAccentForeground,
                        title: const Text('위 내용과 이용약관에 동의합니다'),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          key: const ValueKey('taxi-terms-agree'),
                          onPressed: _checked && !_saving ? _agree : null,
                          child: _saving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('동의하고 시작'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
