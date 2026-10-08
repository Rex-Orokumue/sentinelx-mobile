import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/account_models.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_locale.dart';
import 'account_error_copy.dart';
import 'account_repository.dart';

String _formatAmount(num amount) => '₦${NumberFormat.decimalPattern('en').format(amount)}';

const _knownBlockers = {
  'wallet_balance',
  'pending_withdrawal',
  'open_escrow_order',
  'active_listing',
  'active_tournament',
  'unfinished_match',
  'unfinished_friendly',
};

/// One readable line per blocker; an unknown code from a newer server still gets a generic line so the user
/// is never told "blocked" with nothing listed.
Widget _blockerLine(AppLocalizations l10n, DeletionBlocker b) {
  final count = '${b.count ?? 0}';
  final text = switch (b.code) {
    'wallet_balance' => l10n.accountDeletionBlockerWalletBalance(_formatAmount(b.amount ?? 0)),
    'pending_withdrawal' => l10n.accountDeletionBlockerWithdrawal(count),
    'open_escrow_order' => l10n.accountDeletionBlockerEscrow(count),
    'active_listing' => l10n.accountDeletionBlockerListing(count),
    'active_tournament' => l10n.accountDeletionBlockerTournament,
    'unfinished_match' => l10n.accountDeletionBlockerMatch(count),
    'unfinished_friendly' => l10n.accountDeletionBlockerFriendly(count),
    _ => l10n.mobileSettingsDeleteFailed,
  };
  return Padding(
    key: _knownBlockers.contains(b.code) ? null : const Key('blocker-unknown'),
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(text),
  );
}

/// Settings -> Delete account (`/account/delete`): schedule (type DELETE, 15-day grace), cancel while
/// pending, or delete now (type the exact username, irreversible).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  final _usernameConfirm = TextEditingController();
  bool _busy = false;
  String? _error;
  List<DeletionBlocker> _blockers = const [];

  @override
  void dispose() {
    _confirm.dispose();
    _usernameConfirm.dispose();
    super.dispose();
  }

  void _fail(Object e) {
    final l10n = AppLocalizations.of(context);
    if (e is ApiException && e.code == 'deletion_blocked') {
      setState(() {
        _busy = false;
        _error = null;
        _blockers = DeletionBlocker.listFrom(e.details);
      });
      return;
    }
    setState(() {
      _busy = false;
      _blockers = const [];
      _error = e is ApiException && e.code == 'network' ? l10n.mobileSettingsNetworkError : l10n.mobileSettingsDeleteFailed;
    });
  }

  Future<void> _schedule() async {
    if (_busy || _confirm.text != 'DELETE') return;
    setState(() {
      _busy = true;
      _error = null;
      _blockers = const [];
    });
    try {
      await ref.read(accountRepositoryProvider).requestDeletion();
      ref.invalidate(myAccountProvider);
      ref.invalidate(meProvider); // the app-wide banner reads deletionRequestedAt from /me
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) _fail(e);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).cancelDeletion();
      ref.invalidate(myAccountProvider);
      ref.invalidate(meProvider);
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) _fail(e);
    }
  }

  Future<void> _deleteNow(String username) async {
    final typed = _usernameConfirm.text.trim();
    if (_busy || typed.toLowerCase() != username.toLowerCase()) return;
    setState(() {
      _busy = true;
      _error = null;
      _blockers = const [];
    });
    try {
      await ref.read(accountRepositoryProvider).deleteNow(typed);
    } catch (e) {
      if (mounted) _fail(e);
      return;
    }
    // The server has deleted the auth user, so signing out may itself be refused. Whatever happens, this
    // account is gone: clear the local session if we can and always land on the login screen.
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(myAccountProvider);
    final username = ref.watch(meProvider).asData?.value?.profile?.username ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountDeletionTitle)),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(genericAccountErrorCopy(l10n, e is ApiException ? e.code : 'unknown')),
            TextButton(onPressed: () => ref.invalidate(myAccountProvider), child: Text(l10n.accountRetry)),
          ]),
        ),
        data: (a) {
          if (a == null) return Center(child: Text(l10n.ntfSignedOut));
          final deletion = a.deletion;
          final locale = dateLocale(l10n.localeName);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (deletion != null) ...[
                Text(l10n.accountDeletionPendingHeading, key: const Key('delete-pending'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(l10n.accountDeletionPendingBody(DateFormat.yMMMd(locale).format(deletion.dueAt.toLocal()), '${deletion.daysRemaining}')),
                const SizedBox(height: 4),
                Text(l10n.accountDeletionCanCancel),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('delete-cancel'),
                  onPressed: _busy ? null : _cancel,
                  child: Text(_busy ? l10n.accountDeletionBannerCancelling : l10n.accountDeletionBannerCancel),
                ),
              ] else ...[
                Text(l10n.accountDeletionHistoryKept),
                const SizedBox(height: 4),
                Text(l10n.accountDeletionUsernameRetired(username)),
                const SizedBox(height: 4),
                Text(l10n.accountDeletionEmailReusable),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('delete-confirm-field'),
                  controller: _confirm,
                  decoration: InputDecoration(labelText: l10n.accountDeletionTypeDelete),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('delete-schedule'),
                  onPressed: (_busy || _confirm.text != 'DELETE') ? null : _schedule,
                  child: Text(_busy ? l10n.accountDeletionConfirmButtonPending : l10n.accountDeletionConfirmButton),
                ),
              ],
              if (_blockers.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.accountDeletionBlockedTitle, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final b in _blockers) _blockerLine(l10n, b),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, key: const Key('delete-error'), style: const TextStyle(color: Colors.redAccent)),
              ],
              const Divider(height: 40),
              Text(l10n.accountDeletionDeleteNowTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(l10n.accountDeletionDeleteNowWarning),
              const SizedBox(height: 12),
              TextField(
                key: const Key('delete-now-field'),
                controller: _usernameConfirm,
                decoration: InputDecoration(labelText: l10n.accountDeletionDeleteNowPrompt(username)),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('delete-now'),
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
                onPressed: _busy ? null : () => _deleteNow(username),
                child: Text(_busy ? l10n.accountDeletionDeleteNowButtonPending : l10n.accountDeletionDeleteNowButton),
              ),
            ],
          );
        },
      ),
    );
  }
}
