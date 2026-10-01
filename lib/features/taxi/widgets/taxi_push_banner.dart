import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';

OverlayEntry? _currentBanner;

/// 앱을 보고 있을 때 도착한 택시팟 알림을 화면 위에 잠깐 띄운다.
void showTaxiPushBanner(
  OverlayState overlay, {
  required String title,
  required String body,
  required VoidCallback onTap,
}) {
  _currentBanner?.remove();
  late final OverlayEntry entry;
  void close() {
    if (_currentBanner != entry) return;
    _currentBanner = null;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _TaxiPushBanner(
      title: title,
      body: body,
      onClose: close,
      onTap: () {
        close();
        onTap();
      },
    ),
  );
  _currentBanner = entry;
  overlay.insert(entry);
}

class _TaxiPushBanner extends StatefulWidget {
  const _TaxiPushBanner({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onClose,
  });

  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_TaxiPushBanner> createState() => _TaxiPushBannerState();
}

class _TaxiPushBannerState extends State<_TaxiPushBanner>
    with SingleTickerProviderStateMixin {
  static const _visibleFor = Duration(seconds: 4);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
    _timer = Timer(_visibleFor, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onClose();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -1.4), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOut),
              ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Dismissible(
              key: const ValueKey('taxi-push-banner'),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onClose(),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(18),
                color: theme.colorScheme.surface,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.local_taxi, color: taxiAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
