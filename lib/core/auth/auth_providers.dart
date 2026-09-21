import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'auth_repository.dart';
import 'onboarding_gate.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final api = ref.watch(apiClientProvider);
  return SupabaseAuthRepository(supabase.auth, api, googleWebClientId: ref.watch(appConfigProvider).googleWebClientId);
});

final onboardingGateProvider = Provider<OnboardingGate>((ref) {
  final me = ref.watch(meProvider).asData?.value;
  final config = ref.watch(remoteConfigProvider).asData?.value;
  return resolveOnboardingGate(me, config);
});
