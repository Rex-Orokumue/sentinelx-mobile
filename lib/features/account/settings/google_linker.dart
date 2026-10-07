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
  SupabaseGoogleLinker(this._auth);
  final GoTrueClient _auth;

  static const redirectTo = 'ng.com.sentinelxesports.app://link-callback';

  @override
  Future<void> link() async {
    await _auth.linkIdentity(OAuthProvider.google, redirectTo: redirectTo);
  }
}

final googleLinkerProvider = Provider<GoogleLinker>((ref) => SupabaseGoogleLinker(ref.watch(supabaseClientProvider).auth));
