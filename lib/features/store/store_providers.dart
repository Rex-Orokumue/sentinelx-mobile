import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/store_models.dart';
import '../../core/providers.dart';
import 'store_repository.dart';

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => ApiStoreRepository(ref.watch(apiClientProvider)),
);

/// The catalogue, with ownership and balance when signed in (the catalogue itself is public, so this also
/// loads signed out). Watching the viewer id makes it re-run when the player signs in or out, but a token
/// refresh does not refetch.
final storeCatalogueProvider = FutureProvider.autoDispose<StoreCatalogue>((ref) async {
  await ref.watch(viewerIdProvider.future);
  return ref.watch(storeRepositoryProvider).catalogue();
});
