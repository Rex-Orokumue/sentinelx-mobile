import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_kv.dart';
import 'account_repository.dart';

const supportedLocaleCodes = {'en', 'fr', 'pcm'};
const _cacheKey = 'app.locale';

/// The app language. Null means "no choice yet": MaterialApp then follows the device and falls back to
/// English. Seeded from the server (`/me.locale`) and cached locally so the first frame after a cold start is
/// already right and signed-out use still remembers the choice.
class LocaleNotifier extends Notifier<Locale?> {
  // Set once the user picks a language this session so a slower, stale /me response cannot undo it. Cleared
  // on sign-out so the next account's saved language applies.
  var _chosen = false;

  @override
  Locale? build() {
    ref.listen(meProvider, (_, next) {
      final me = next.asData?.value;
      if (next.hasValue && me == null) {
        _chosen = false;
        return;
      }
      final code = me?.profile?.locale;
      if (!_chosen && code != null && supportedLocaleCodes.contains(code)) {
        state = Locale(code);
        unawaited(_write(code));
      }
    }, fireImmediately: true);
    unawaited(_restore());
    return null;
  }

  Future<void> _restore() async {
    try {
      final kv = await ref.read(localKvProvider.future);
      final code = await kv.read(_cacheKey);
      if (ref.mounted && state == null && code != null && supportedLocaleCodes.contains(code)) {
        state = Locale(code);
      }
    } catch (_) {
      // Storage unavailable: the app simply starts in the device language.
    }
  }

  Future<void> _write(String? code) async {
    try {
      final kv = await ref.read(localKvProvider.future);
      if (code == null) {
        await kv.remove(_cacheKey);
      } else {
        await kv.write(_cacheKey, code);
      }
    } catch (_) {}
  }

  /// Optimistic. Returns false when the code is not shipped or the server refused; in the second case the
  /// previous language (and cached value) is restored. Signed out, the choice is local only.
  Future<bool> select(String code) async {
    if (!supportedLocaleCodes.contains(code)) return false;
    final previous = state;
    _chosen = true;
    state = Locale(code);
    await _write(code);
    if (await ref.read(viewerIdProvider.future) == null) return true;
    try {
      await ref.read(accountRepositoryProvider).setLocale(code);
      return true;
    } catch (_) {
      if (ref.mounted) {
        state = previous;
        await _write(previous?.languageCode);
      }
      return false;
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);
