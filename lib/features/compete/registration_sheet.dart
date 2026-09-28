import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/compete_models.dart';
import '../../core/api/registration_fields_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import 'compete_models.dart';
import 'compete_providers.dart';
import 'error_copy.dart';
import 'registration_flow.dart';

enum SheetMode { register, waitlist }

/// Client-side checks that mirror the server's `registrationDetailsSchema`. They only avoid an
/// obvious round trip; the server re-validates everything.
class RegistrationValidators {
  const RegistrationValidators._();

  static final _whatsapp = RegExp(r'^\+?[0-9]{10,15}$');

  static bool displayName(String v) =>
      v.trim().isNotEmpty && v.trim().length <= 60;
  static bool whatsapp(String v) => _whatsapp.hasMatch(v.trim());
}

Future<void> showRegistrationSheet(
  BuildContext context, {
  required CompeteTournament tournament,
  required RegistrationState state,
  required SheetMode mode,
  VoidCallback? onNeedsUsername,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Dragging would bypass PopScope and orphan an in-flight payment; the close button is
    // disabled while busy instead.
    enableDrag: false,
    builder: (_) => RegistrationSheet(
      tournament: tournament,
      state: state,
      mode: mode,
      onNeedsUsername: onNeedsUsername,
    ),
  );
}

class RegistrationSheet extends ConsumerStatefulWidget {
  const RegistrationSheet({
    super.key,
    required this.tournament,
    required this.state,
    required this.mode,
    this.onNeedsUsername,
  });

  final CompeteTournament tournament;
  final RegistrationState state;
  final SheetMode mode;
  final VoidCallback? onNeedsUsername;

  @override
  ConsumerState<RegistrationSheet> createState() => _RegistrationSheetState();
}

class _RegistrationSheetState extends ConsumerState<RegistrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _whatsapp = TextEditingController();
  final _fieldControllers = <String, TextEditingController>{};
  List<RegistrationField>? _registrationFields;
  bool _fieldsFailed = false;
  bool _agreed = false;
  bool _rulesError = false;
  int _coins = 0;

  bool get _isRegister => widget.mode == SheetMode.register;

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() {
      _registrationFields = null;
      _fieldsFailed = false;
    });
    try {
      final fields = await ref
          .read(registrationRepositoryProvider)
          .registrationFields(widget.tournament.id);
      if (!mounted) return;
      for (final controller in _fieldControllers.values) {
        controller.dispose();
      }
      _fieldControllers
        ..clear()
        ..addEntries(
          fields.map(
            (field) => MapEntry(field.fieldKey, TextEditingController()),
          ),
        );
      setState(() => _registrationFields = fields);
    } catch (_) {
      if (mounted) setState(() => _fieldsFailed = true);
    }
  }

  Future<void> _prefill() async {
    try {
      final me = await ref.read(meProvider.future);
      final p = me?.profile;
      if (!mounted || p == null) return;
      if (_name.text.isEmpty && p.displayName != null) {
        _name.text = p.displayName!;
      }
      if (_whatsapp.text.isEmpty && p.whatsappNumber != null) {
        _whatsapp.text = p.whatsappNumber!;
      }
    } catch (_) {
      // Prefill is a convenience only.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _whatsapp.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _coinsVisible(bool hasConfig) =>
      _isRegister &&
      widget.state.coinDiscountEligible &&
      !widget.state.hasWaiver &&
      hasConfig;

  void _submit(bool coinsVisible) {
    final formOk = _formKey.currentState!.validate();
    final rulesMissing = widget.state.agreementRequired && !_agreed;
    setState(() => _rulesError = rulesMissing);
    if (!formOk || rulesMissing) return;
    final details = RegistrationDetails(
      displayName: _name.text.trim(),
      whatsapp: _whatsapp.text.trim(),
      registrationDetails: {
        for (final field in _registrationFields!)
          field.fieldKey: _fieldControllers[field.fieldKey]!.text.trim(),
      },
      // The server only checks this when the tournament has rules; `true` is what web sends otherwise.
      agreedToRules: widget.state.agreementRequired ? _agreed : true,
    );
    final flow = ref.read(
      registrationFlowProvider(widget.tournament.id).notifier,
    );
    if (_isRegister) {
      flow.submitRegister(details, coinsUsed: coinsVisible ? _coins : 0);
    } else {
      flow.submitWaitlist(details);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = widget.tournament.id;

    ref.listen<FlowState>(registrationFlowProvider(id), (prev, next) {
      if (prev?.phase == next.phase && prev?.errorCode == next.errorCode) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      switch (next.phase) {
        case FlowPhase.confirmed:
          final paid =
              prev?.phase == FlowPhase.confirming ||
              prev?.phase == FlowPhase.awaitingPayment;
          Navigator.of(context).pop();
          messenger.showSnackBar(
            SnackBar(
              content: Text(paid ? l10n.cmpPaySuccess : l10n.cmpConfirmedFree),
            ),
          );
        case FlowPhase.waitlisted:
          Navigator.of(context).pop();
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.cmpWaitlistJoined)),
          );
        case FlowPhase.failed when next.needsUsername:
          Navigator.of(context).pop();
          widget.onNeedsUsername?.call();
        default:
      }
    });

    final flow = ref.watch(registrationFlowProvider(id));
    final cfg = ref.watch(remoteConfigProvider).asData?.value;
    final busy = flow.busy;
    final coinsVisible = _coinsVisible(cfg != null);
    final rules = widget.tournament.rules;

    return PopScope(
      canPop: !busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.tournament.title,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      key: const Key('reg-close'),
                      icon: const Icon(Icons.close),
                      onPressed: busy
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                if (_isRegister && widget.state.hasWaiver)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(l10n.cmpFeeWaived),
                  ),
                TextFormField(
                  key: const Key('reg-display-name'),
                  controller: _name,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.cmpFieldDisplayName,
                    errorText: flow.fieldErrors.containsKey('displayName')
                        ? l10n.cmpValDisplayName
                        : null,
                  ),
                  validator: (v) => RegistrationValidators.displayName(v ?? '')
                      ? null
                      : l10n.cmpValDisplayName,
                ),
                TextFormField(
                  key: const Key('reg-whatsapp'),
                  controller: _whatsapp,
                  enabled: !busy,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.cmpFieldWhatsapp,
                    errorText: flow.fieldErrors.containsKey('whatsapp')
                        ? l10n.cmpValWhatsapp
                        : null,
                  ),
                  validator: (v) => RegistrationValidators.whatsapp(v ?? '')
                      ? null
                      : l10n.cmpValWhatsapp,
                ),
                if (_registrationFields == null && !_fieldsFailed)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_fieldsFailed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Text(l10n.cmpLoadError),
                        TextButton(
                          onPressed: _loadFields,
                          child: Text(l10n.cmpRetry),
                        ),
                      ],
                    ),
                  )
                else
                  for (final field in _registrationFields!)
                    TextFormField(
                      key: Key('reg-field-${field.fieldKey}'),
                      controller: _fieldControllers[field.fieldKey],
                      enabled: !busy,
                      keyboardType: switch (field.inputType) {
                        RegistrationFieldInputType.number =>
                          TextInputType.number,
                        RegistrationFieldInputType.url => TextInputType.url,
                        RegistrationFieldInputType.text => null,
                      },
                      decoration: InputDecoration(
                        labelText: field.label,
                        hintText: field.placeholder,
                      ),
                      validator: (value) => field.validate(value ?? ''),
                    ),
                if (_registrationFields != null) ...[
                  if (rules != null && rules.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(l10n.cmpRules),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(rules),
                        ),
                      ],
                    ),
                  if (widget.state.agreementRequired) ...[
                    CheckboxListTile(
                      key: const Key('reg-agree'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _agreed,
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              _agreed = v ?? false;
                              _rulesError = false;
                            }),
                      title: Text(l10n.cmpAgreeRules),
                    ),
                    if (_rulesError)
                      Text(
                        l10n.cmpValRules,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                  if (coinsVisible && cfg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.cmpCoinsTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    RadioGroup<int>(
                      groupValue: _coins,
                      onChanged: (v) => setState(() => _coins = v ?? 0),
                      child: Column(
                        children: [
                          RadioListTile<int>(
                            value: 0,
                            enabled: !busy,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.cmpCoinsNone),
                          ),
                          for (final coins in [
                            cfg.coinsHalfEntry,
                            cfg.coinsPerEntry,
                          ])
                            RadioListTile<int>(
                              value: coins,
                              enabled: !busy,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                l10n.cmpCoinsOption(
                                  coins,
                                  (coins * cfg.nairaPerCoin).round().toString(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (flow.paymentUnresolved)
                    // Registering again would overwrite the stored payment reference; only re-check it.
                    FilledButton(
                      key: const Key('reg-recheck'),
                      onPressed: busy
                          ? null
                          : () => ref
                                .read(registrationFlowProvider(id).notifier)
                                .recheckPayment(),
                      child: Text(
                        busy ? l10n.cmpSubmitting : l10n.cmpPayCheckAgain,
                      ),
                    )
                  else
                    FilledButton(
                      key: const Key('reg-submit'),
                      onPressed: busy ? null : () => _submit(coinsVisible),
                      child: Text(
                        busy
                            ? l10n.cmpSubmitting
                            : (_isRegister
                                  ? l10n.cmpSubmitRegister
                                  : l10n.cmpSubmitWaitlist),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _Status(flow: flow),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.flow});
  final FlowState flow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    switch (flow.phase) {
      case FlowPhase.confirming:
        return Column(
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(l10n.cmpPayConfirming),
          ],
        );
      case FlowPhase.notConfirmed:
        return Text(l10n.cmpPayNotConfirmed);
      case FlowPhase.cancelled:
        return Text(l10n.cmpPayCancelled);
      case FlowPhase.failed:
        if (flow.needsUsername) return const SizedBox.shrink();
        return Text(
          errorCopy(l10n, flow.errorCode ?? ''),
          style: TextStyle(color: error),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
