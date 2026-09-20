import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final api = ref.watch(apiClientProvider);
  return SupabaseAuthRepository(supabase.auth, api);
});
