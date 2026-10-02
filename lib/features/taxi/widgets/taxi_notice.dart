import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// 탭 본문을 대신해 보여주는 안내 문구와 다음 행동 버튼.
class TaxiNotice extends StatelessWidget {
  const TaxiNotice({
    super.key,
    required this.message,
    this.showRetry = false,
    this.onRetry,
    this.onShowCurrent,
    this.onAppeal,
  });

  final String message;

  /// true면 다시 시도 버튼을 보여준다. [onRetry]가 null이면 비활성화된다.
  final bool showRetry;
  final VoidCallback? onRetry;

  /// null이 아니면 현재팟 보기 버튼을 보여준다.
  final VoidCallback? onShowCurrent;

  /// null이 아니면 이용 제한 이의제기 버튼을 보여준다.
  final VoidCallback? onAppeal;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(PhosphorIconsFill.taxi, size: 48, color: taxiAccent),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (showRetry)
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
          if (onShowCurrent != null)
            FilledButton(onPressed: onShowCurrent, child: const Text('현재팟 보기')),
          if (onAppeal != null)
            TextButton(onPressed: onAppeal, child: const Text('이의제기')),
        ],
      ),
    ),
  );
}

/// 목록 위에 붙이는 오류 메시지 카드.
class TaxiErrorCard extends StatelessWidget {
  const TaxiErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message),
  );
}
