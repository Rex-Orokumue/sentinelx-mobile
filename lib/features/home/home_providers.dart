import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) => ApiHomeRepository(ref.watch(apiClientProvider)));

final homeProvider = FutureProvider.autoDispose((ref) => ref.watch(homeRepositoryProvider).fetchHome());
