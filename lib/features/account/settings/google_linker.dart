import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';

/// Starts Supabase's browser OAuth link flow for Google. The only direct Supabase auth call in Settings:
/// linking is an auth operation the server cannot perform for the user. supabase_flutter itself consumes the
/// `ng.com.sentinelxesports.app://link-callback` deep link and exchanges the code; the screen refetches the
/// account when the app resumes.
abstract class GoogleLinker {
  Future<void> link();
}

class SupabaseGoogleLinker implements GoogleLinker {
  SupabaseGoogleLinker(this._launch);
  final Future<bool> Function() _launch;

  static const redirectTo = 'ng.com.sentinelxesports.app://link-callback';

  @override
  Future<void> link() async {
    if (!await _launch()) throw StateError('No browser could open the Google link.');
  }
}

final googleLinkerProvider = Provider<GoogleLinker>((ref) {
  final auth = ref.watch(supabaseClientProvider).auth;
  return SupabaseGoogleLinker(() => auth.linkIdentity(OAuthProvider.google, redirectTo: SupabaseGoogleLinker.redirectTo));
});
