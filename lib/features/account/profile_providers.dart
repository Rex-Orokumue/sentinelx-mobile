import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/compete_models.dart';
import '../../core/providers.dart';

/// Saves the signed-in player's profile. A plain function so tests override one seam.
final profileEditorProvider = Provider<Future<void> Function(ProfileEdit edit)>(
  (ref) => (edit) => ref.read(apiClientProvider).patchMeProfile(edit),
);

/// The caller's own bio (one column, own row). `GET /me` does not return it and `PATCH /me/profile`
/// clears the bio when sent an empty one, so the edit form must know the current value before it
/// can save anything. Drop this direct `profiles` read once `/me` includes `bio` (web change).
final ownBioProvider = FutureProvider.autoDispose<String>((ref) async {
  final me = await ref.watch(meProvider.future);
  if (me == null) return '';
  final row = await ref.watch(supabaseClientProvider).from('profiles').select('bio').eq('id', me.id).maybeSingle();
  return (row?['bio'] as String?) ?? '';
});
