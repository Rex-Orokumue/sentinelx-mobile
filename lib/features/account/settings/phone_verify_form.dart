import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/providers.dart';
import 'account_error_copy.dart';
import 'account_repository.dart';

/// The WhatsApp verification flow, shared by Settings -> Phone and the `/onboarding/phone` gate: number,
/// then a 6-digit code with a resend countdown, then [onVerified]. The server owns every limit (cooldown,
/// daily cap, attempts); the countdown here is a courtesy that a 429's `retryAfterSeconds` always overrides.
class PhoneVerifyForm extends ConsumerStatefulWidget {
  const PhoneVerifyForm({super.key, required this.onVerified});

  final VoidCallback onVerified;

  @override
  ConsumerState<PhoneVerifyForm> createState() => _PhoneVerifyFormState();
}

class _PhoneVerifyFormState extends ConsumerState<PhoneVerifyForm> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  Timer? _tick;
  bool _codeSent = false;
  bool _busy = false;
  bool _unavailable = false;
  int _secondsLeft = 0;
  String? _error;

  @override
  void dispose() {
    _tick?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _tick?.cancel();
    setState(() => _secondsLeft = seconds);
    if (seconds <= 0) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 3600));
      if (_secondsLeft == 0) t.cancel();
    });
  }

  String _copy(Object e) => phoneErrorCopy(AppLocalizations.of(context), e is ApiException ? e.code : 'unknown');

  Future<void> _send() async {
    final number = _phone.text.trim();
    if (number.isEmpty || _busy || _secondsLeft > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ticket = await ref.read(accountRepositoryProvider).requestPhoneCode(number);
      if (!mounted) return;
      // Clamped to 0..60: a skewed device clock must neither lock the button for hours nor open it early
      // (the server's cooldown is the real gate and answers 429 with retryAfterSeconds if we are early).
      final remaining = ticket.resendAt.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 60);
      setState(() {
        _busy = false;
        _codeSent = true;
      });
      _startCountdown(remaining);
    } catch (e) {
      if (!mounted) return;
      final code = e is ApiException ? e.code : '';
      setState(() {
        _busy = false;
        if (code == 'phone_unavailable') {
          _unavailable = true;
        } else {
          _error = _copy(e);
        }
      });
      if (e is ApiException && e.code == 'phone_cooldown') {
        _startCountdown(int.tryParse(e.fields['retryAfterSeconds'] ?? '') ?? 60);
      }
    }
  }

  Future<void> _resendFromCodeStep() async {
    // Same call as the first send, with the number the user already typed (the field is read-only now).
    setState(() => _codeSent = false);
    await _send();
    if (mounted && _error != null) setState(() => _codeSent = true);
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (_busy) return;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() => _error = AppLocalizations.of(context).mobileSettingsPhoneErrorCodeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).confirmPhoneCode(code);
      if (!mounted) return;
      ref.invalidate(myAccountProvider);
      ref.invalidate(meProvider); // the onboarding gate reads phoneVerifiedAt from /me
      widget.onVerified();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _copy(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_unavailable) {
      return Text(l10n.mobileSettingsPhoneUnavailable, key: const Key('phone-unavailable'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('phone-number'),
          controller: _phone,
          enabled: !_codeSent,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: InputDecoration(labelText: l10n.mobileSettingsPhoneNumberLabel),
        ),
        const SizedBox(height: 12),
        if (!_codeSent)
          FilledButton(
            key: const Key('phone-send'),
            onPressed: (_busy || _secondsLeft > 0) ? null : _send,
            child: Text(_secondsLeft > 0 ? l10n.mobileSettingsPhoneResendIn('$_secondsLeft') : l10n.mobileSettingsPhoneSendCode),
          )
        else ...[
          TextField(
            key: const Key('phone-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(labelText: l10n.mobileSettingsPhoneCodeLabel, counterText: ''),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 8),
          FilledButton(key: const Key('phone-confirm'), onPressed: _busy ? null : _confirm, child: Text(l10n.mobileSettingsPhoneConfirm)),
          TextButton(
            key: const Key('phone-resend'),
            onPressed: (_busy || _secondsLeft > 0) ? null : _resendFromCodeStep,
            child: Text(_secondsLeft > 0 ? l10n.mobileSettingsPhoneResendIn('$_secondsLeft') : l10n.mobileSettingsPhoneResend),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, key: const Key('phone-error'), style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }
}
