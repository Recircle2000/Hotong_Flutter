import 'package:flutter/material.dart';
import 'package:hsro/core/services/link_share_service.dart';

class LinkShareButton extends StatefulWidget {
  final LinkShareContent Function() content;
  final bool enabled;
  final LinkShareService service;

  const LinkShareButton({
    super.key,
    required this.content,
    this.enabled = true,
    this.service = const LinkShareService(),
  });

  @override
  State<LinkShareButton> createState() => _LinkShareButtonState();
}

class _LinkShareButtonState extends State<LinkShareButton> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing || !widget.enabled) return;
    final box = context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      await widget.service.share(widget.content(), origin);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크를 공유하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: '링크 공유',
        onPressed: widget.enabled && !_sharing ? _share : null,
        icon: const Icon(Icons.ios_share),
      );
}
