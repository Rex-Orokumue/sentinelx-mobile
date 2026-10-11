import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_kv.dart';

typedef InstallReferrerReader = Future<String?> Function();

const _checkedKey = 'referral.install.checked';
const _codeKey = 'referral.install.code';
final _validCode = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

/// Google Play returns a query string, not a complete URL. Only the referral code is retained.
String? parseInstallReferrer(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final code = Uri.splitQueryString(raw)['ref']?.trim();
    return code != null && _validCode.hasMatch(code) ? code : null;
  } on FormatException {
    return null;
  }
}

class ReferralAttribution {
  ReferralAttribution(this._kv, this._readInstallReferrer);

  final LocalKv _kv;
  final InstallReferrerReader _readInstallReferrer;

  Future<String?> refForSignup(String? explicitRef) async {
    if (explicitRef != null && explicitRef.isNotEmpty) return explicitRef;
    final saved = await _kv.read(_codeKey);
    if (await _kv.read(_checkedKey) == '1') return saved;
    try {
      final code = parseInstallReferrer(await _readInstallReferrer());
      if (code != null) await _kv.write(_codeKey, code);
      await _kv.write(_checkedKey, '1');
      return code ?? saved;
    } catch (_) {
      // A temporary Play-service failure can retry on the next signup visit.
      return saved;
    }
  }

  Future<void> clearAfterSignup() async {
    await _kv.remove(_codeKey);
    await _kv.write(_checkedKey, '1');
  }
}

final installReferrerReaderProvider = Provider<InstallReferrerReader>(
  (ref) => () async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    return const MethodChannel(
      'sentinelx/referrals',
    ).invokeMethod<String>('readInstallReferrer');
  },
);

final referralAttributionProvider = FutureProvider<ReferralAttribution>((
  ref,
) async {
  final kv = await ref.watch(localKvProvider.future);
  return ReferralAttribution(kv, ref.watch(installReferrerReaderProvider));
});
