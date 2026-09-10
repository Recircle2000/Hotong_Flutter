import 'dart:ui';
import 'package:share_plus/share_plus.dart';

class LinkShareContent {
  final String title;
  final Uri uri;

  const LinkShareContent({required this.title, required this.uri});
}

class LinkShareService {
  const LinkShareService();

  Future<void> share(LinkShareContent content, Rect origin) async {
    // Dismissed and unavailable are normal outcomes, not errors.
    await SharePlus.instance.share(ShareParams(
      uri: content.uri,
      title: content.title,
      subject: content.title,
      sharePositionOrigin: origin,
    ));
  }
}
