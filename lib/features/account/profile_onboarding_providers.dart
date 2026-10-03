import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/profile_onboarding_models.dart';
import '../../core/providers.dart';

final profileOnboardingSubmitterProvider =
    Provider<
      Future<ProfileOnboardingResult> Function(ProfileOnboardingInput input)
    >(
      (ref) =>
          (input) => ref.read(apiClientProvider).postOnboardingProfile(input),
    );
