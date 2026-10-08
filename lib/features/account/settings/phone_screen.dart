import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import 'account_error_copy.dart';
import 'account_repository.dart';
import 'phone_verify_form.dart';

/// Settings -> Phone verification (`/account/phone`).
class PhoneScreen extends ConsumerWidget {
  const PhoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(myAccountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mobileSettingsPhoneTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: account.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(genericAccountErrorCopy(l10n, e is ApiException ? e.code : 'unknown')),
              TextButton(onPressed: () => ref.invalidate(myAccountProvider), child: Text(l10n.accountRetry)),
            ]),
          ),
          data: (a) {
            if (a == null) return Center(child: Text(l10n.ntfSignedOut));
            final phone = a.phone;
            if (phone != null) return Text(l10n.mobileSettingsPhoneVerified(phone.masked), key: const Key('phone-verified'));
            return SingleChildScrollView(child: PhoneVerifyForm(onVerified: () => ref.invalidate(myAccountProvider)));
          },
        ),
      ),
    );
  }
}
