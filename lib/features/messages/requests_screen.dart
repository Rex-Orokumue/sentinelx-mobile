import 'package:flutter/material.dart';

import '../../core/l10n/gen/app_localizations.dart';
import 'inbox_providers.dart';
import 'inbox_screen.dart';

/// `/messages/requests`: conversations from players the viewer has not accepted yet. Accept, decline and
/// block happen inside the thread (preview-only), not from this list.
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dmRequestsTitle)),
      body: ThreadListBody(provider: requestsInboxProvider, requestsBox: true),
    );
  }
}
