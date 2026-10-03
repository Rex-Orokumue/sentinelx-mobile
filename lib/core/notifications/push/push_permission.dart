import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'push_gateway.dart';
import 'push_models.dart';

/// Decides when the OS notification dialog is shown.
///
/// Android 13+ gives an app one or two system prompts before it stops showing any, so the ask is spent
/// where it converts: the first confirmed stake in a tournament (spec §3.5). The one gating rule is that a
/// trigger only ever prompts when the OS status is [PushPermission.notDetermined] — which exists only on
/// API 33+ (below that the status is authorized/denied) and, once the player has answered, never again.
class PushPermissionPrompter {
  PushPermissionPrompter(this._ref);

  final Ref _ref;

  // At most one ask per process, and none while a dialog is on screen. The OS records the answer, but a
  // dismissal some OEMs leave as "not determined" must not turn a second stake into a second dialog.
  bool _asked = false;

  /// Contextual ask at a confirmed stake (register, waitlist join, invitation accept). Never throws.
  Future<void> onStake() async {
    if (_asked) return;
    try {
      if (_ref.read(sessionProvider).asData?.value == null) return;
      final gateway = _ref.read(pushGatewayProvider);
      if (!gateway.isAvailable) return;
      if (await gateway.permission() != PushPermission.notDetermined) return;
      if (_asked) return; // a concurrent stake got here first while we awaited the status
      _asked = true;
      await gateway.requestPermission();
    } catch (_) {
      // A permission problem must never surface in the registration flow.
    }
  }

  /// A deliberate tap on a passive row (bell empty state, settings). Authorized is a no-op; a never-asked
  /// state shows the dialog; once the player has denied, try the dialog once (soft denial can be asked
  /// again) and, if that did not enable notifications, take them to system settings.
  Future<PushPermission> enableFromUser() async {
    final gateway = _ref.read(pushGatewayProvider);
    var status = await gateway.permission();
    if (status == PushPermission.authorized) return status;
    final wasNeverAsked = status == PushPermission.notDetermined;
    status = await gateway.requestPermission();
    if (status != PushPermission.authorized && !wasNeverAsked) {
      await gateway.openSystemSettings();
    }
    return status;
  }
}

final pushPermissionPrompterProvider = Provider<PushPermissionPrompter>((ref) => PushPermissionPrompter(ref));

/// Current OS status for passive UI. Callers invalidate it on app resume (the player may have changed it
/// in system settings) and after [PushPermissionPrompter.enableFromUser].
final pushPermissionProvider =
    FutureProvider.autoDispose<PushPermission>((ref) => ref.watch(pushGatewayProvider).permission());
