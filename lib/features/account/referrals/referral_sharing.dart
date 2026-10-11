import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ShareReferral = Future<void> Function(String text);

final referralCopyProvider = Provider<ShareReferral>(
  (ref) => (text) async {
    await Clipboard.setData(ClipboardData(text: text));
  },
);

/// Android uses the native text share sheet. Kept behind a provider so widget tests never launch another app.
final referralShareProvider = Provider<ShareReferral>(
  (ref) => (text) async {
    await const MethodChannel(
      'sentinelx/share',
    ).invokeMethod<void>('shareText', {'text': text});
  },
);

final referralWhatsAppProvider = Provider<ShareReferral>(
  (ref) => (text) async {
    final url = Uri.https('wa.me', '/', {'text': text});
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw StateError('WhatsApp share unavailable');
    }
  },
);
