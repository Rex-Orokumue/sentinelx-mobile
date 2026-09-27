import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'idempotency_key.dart';

enum WritePhase { idle, submitting, done, failed }

class WriteState {
  const WriteState({this.phase = WritePhase.idle, this.errorCode, this.fieldErrors = const {}});
  final WritePhase phase;
  final String? errorCode;
  final Map<String, String> fieldErrors;
  bool get busy => phase == WritePhase.submitting;
}

/// One idempotent write (result, rating, wager, lobby result). The family argument is a scope string such as
/// `rating:<matchId>`. Owns the Idempotency-Key policy so no screen re-implements it.
final writeFlowProvider = NotifierProvider.autoDispose.family<WriteFlow, WriteState, String>(WriteFlow.new);

class WriteFlow extends Notifier<WriteState> {
  WriteFlow(this.scope);
  final String scope;

  String? _key;
  Object? _fingerprint;

  @override
  WriteState build() => const WriteState();

  String get currentKey => _key ??= newIdempotencyKey();

  void reset() {
    _key = null;
    _fingerprint = null;
    state = const WriteState();
  }

  /// Returns true on success; false on failure or when ignored because a run is already in flight.
  ///
  /// [fingerprint], when given, identifies the payload this attempt submits (e.g. the stake/pick, the
  /// stars, or the scores+screenshot). The server doesn't fingerprint requests itself, so a kept key
  /// would otherwise let a *changed* retry replay the server's response to the *original* payload —
  /// reporting success for values it never stored. A fingerprint that differs from the one the kept key
  /// was minted for forces a fresh key, even for an error that would otherwise keep it.
  Future<bool> run(Future<void> Function(String idempotencyKey) call, {Object? fingerprint}) async {
    if (state.busy) return false;
    if (fingerprint != null && _key != null && _fingerprint != fingerprint) {
      _key = null;
    }
    _fingerprint = fingerprint;
    state = const WriteState(phase: WritePhase.submitting);
    try {
      await call(currentKey);
    } catch (e) {
      if (!ref.mounted) return false;
      // Same key only when the request may not have been processed; every real response, error or
      // not, is stored server-side under the key and would be replayed on reuse.
      final keep = e is! ApiException || e.code == 'network' || e.code == 'idempotency_in_progress' || e.code == 'bad_response';
      if (!keep) {
        _key = null;
        _fingerprint = null;
      }
      state = e is ApiException
          ? WriteState(phase: WritePhase.failed, errorCode: e.isUnauthorized ? 'unauthorized' : e.code, fieldErrors: e.fields)
          : const WriteState(phase: WritePhase.failed, errorCode: 'network');
      return false;
    }
    if (!ref.mounted) return true;
    _key = null;
    _fingerprint = null;
    state = const WriteState(phase: WritePhase.done);
    return true;
  }
}
