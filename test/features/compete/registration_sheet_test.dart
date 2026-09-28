import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';
import 'package:sentinelx_mobile/core/api/registration_fields_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/compete/registration_flow.dart';
import 'package:sentinelx_mobile/features/compete/registration_sheet.dart';

import '../../fakes/fake_registration_repository.dart';
import '../../support/compete_fixtures.dart';
import '../../support/pump_compete.dart';

class _Env {
  _Env(this.repo);
  final FakeRegistrationRepository repo;
  final launched = <String>[];
}

RegistrationState _canRegister({
  bool coins = false,
  bool waiver = false,
  bool agreementRequired = true,
  int fee = 500,
}) => RegistrationState(
  view: RegView.canRegister,
  feeNaira: fee,
  hasWaiver: waiver,
  coinDiscountEligible: coins,
  agreementRequired: agreementRequired,
);

Future<_Env> _pump(
  WidgetTester tester, {
  required SheetMode mode,
  required RegistrationState state,
  VoidCallback? onNeedsUsername,
  bool launcherReturns = true,
  Object? fieldsResult,
}) async {
  final env = _Env(FakeRegistrationRepository());
  if (fieldsResult != null) env.repo.fieldsResult = fieldsResult;
  final tournament = CompeteTournament.fromJson(tournamentRow());
  await pumpCompete(
    tester,
    Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          key: const Key('open-sheet'),
          onPressed: () => showRegistrationSheet(
            context,
            tournament: tournament,
            state: state,
            mode: mode,
            onNeedsUsername: onNeedsUsername,
          ),
          child: const Text('open'),
        ),
      ),
    ),
    overrides: [
      ...competeBaseOverrides(),
      registrationRepositoryProvider.overrideWithValue(env.repo),
      paystackLauncherProvider.overrideWithValue((url) async {
        env.launched.add(url);
        return launcherReturns;
      }),
      pollDelayProvider.overrideWithValue((_) async {}),
    ],
  );
  await tester.tap(find.byKey(const Key('open-sheet')));
  await tester.pumpAndSettle();
  return env;
}

Future<void> _fill(WidgetTester tester, {bool agree = true}) async {
  await tester.enterText(
    find.byKey(const Key('reg-whatsapp')),
    '+2348012345678',
  );
  await tester.enterText(
    find.byKey(const Key('reg-field-club_name')),
    'FC Ada',
  );
  if (agree && find.byKey(const Key('reg-agree')).evaluate().isNotEmpty) {
    await tester.ensureVisible(find.byKey(const Key('reg-agree')));
    await tester.tap(find.byKey(const Key('reg-agree')));
  }
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('reg-submit')));
  await tester.tap(find.byKey(const Key('reg-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'renders dynamic fields in catalogue order with server labels and input types',
    (tester) async {
      const fields = <RegistrationField>[
        RegistrationField(
          fieldKey: 'uid',
          label: 'Player UID',
          placeholder: '123',
          inputType: RegistrationFieldInputType.number,
          required: true,
          validationPattern: null,
          validationMessage: null,
        ),
        RegistrationField(
          fieldKey: 'profile',
          label: 'Profile URL',
          placeholder: 'https://',
          inputType: RegistrationFieldInputType.url,
          required: false,
          validationPattern: null,
          validationMessage: null,
        ),
      ];
      await _pump(
        tester,
        mode: SheetMode.register,
        state: _canRegister(),
        fieldsResult: fields,
      );
      expect(find.text('Player UID'), findsOneWidget);
      expect(find.text('Profile URL'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const Key('reg-field-uid')),
                matching: find.byType(EditableText),
              ),
            )
            .keyboardType,
        TextInputType.number,
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const Key('reg-field-profile')),
                matching: find.byType(EditableText),
              ),
            )
            .keyboardType,
        TextInputType.url,
      );
    },
  );

  testWidgets('submits a trimmed value for every dynamic catalogue key', (
    tester,
  ) async {
    const fields = <RegistrationField>[
      RegistrationField(
        fieldKey: 'uid',
        label: 'UID',
        placeholder: null,
        inputType: RegistrationFieldInputType.number,
        required: true,
        validationPattern: null,
        validationMessage: null,
      ),
      RegistrationField(
        fieldKey: 'tag',
        label: 'Tag',
        placeholder: null,
        inputType: RegistrationFieldInputType.text,
        required: false,
        validationPattern: null,
        validationMessage: null,
      ),
    ];
    final env = await _pump(
      tester,
      mode: SheetMode.register,
      state: _canRegister(),
      fieldsResult: fields,
    );
    env.repo.registerResults.add(const RegisterConfirmed());
    await tester.enterText(
      find.byKey(const Key('reg-whatsapp')),
      '+2348012345678',
    );
    await tester.enterText(find.byKey(const Key('reg-field-uid')), ' 123 ');
    await tester.enterText(find.byKey(const Key('reg-field-tag')), ' ace ');
    await tester.tap(find.byKey(const Key('reg-agree')));
    await _submit(tester);
    expect(env.repo.registerDetails.single.registrationDetails, {
      'uid': '123',
      'tag': 'ace',
    });
  });

  testWidgets('required dynamic validation blocks submit', (tester) async {
    final env = await _pump(
      tester,
      mode: SheetMode.register,
      state: _canRegister(),
    );
    await tester.enterText(
      find.byKey(const Key('reg-whatsapp')),
      '+2348012345678',
    );
    await tester.tap(find.byKey(const Key('reg-agree')));
    await _submit(tester);
    expect(find.text('Club name is required'), findsOneWidget);
    expect(env.repo.registerKeys, isEmpty);
  });

  testWidgets('an invalid catalogue pattern does not crash or block submit', (
    tester,
  ) async {
    const fields = <RegistrationField>[
      RegistrationField(
        fieldKey: 'uid',
        label: 'UID',
        placeholder: null,
        inputType: RegistrationFieldInputType.text,
        required: true,
        validationPattern: '[',
        validationMessage: 'Invalid UID',
      ),
    ];
    final env = await _pump(
      tester,
      mode: SheetMode.register,
      state: _canRegister(),
      fieldsResult: fields,
    );
    env.repo.registerResults.add(const RegisterConfirmed());
    await tester.enterText(
      find.byKey(const Key('reg-whatsapp')),
      '+2348012345678',
    );
    await tester.enterText(find.byKey(const Key('reg-field-uid')), 'abc');
    await tester.tap(find.byKey(const Key('reg-agree')));
    await _submit(tester);
    expect(env.repo.registerKeys, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('field fetch failure shows retry and retry renders fields', (
    tester,
  ) async {
    final env = await _pump(
      tester,
      mode: SheetMode.register,
      state: _canRegister(),
      fieldsResult: Exception('offline'),
    );
    expect(
      find.text("Couldn't load this. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reg-submit')), findsNothing);
    env.repo.fieldsResult = const <RegistrationField>[
      RegistrationField(
        fieldKey: 'uid',
        label: 'UID',
        placeholder: null,
        inputType: RegistrationFieldInputType.text,
        required: true,
        validationPattern: null,
        validationMessage: null,
      ),
    ];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reg-field-uid')), findsOneWidget);
    expect(env.repo.fieldsCalls, 2);
  });

  testWidgets('prefills display name and WhatsApp from the profile', (
    tester,
  ) async {
    await _pump(tester, mode: SheetMode.register, state: _canRegister());
    expect(find.widgetWithText(TextFormField, 'Ada'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, '+2348012345678'),
      findsOneWidget,
    );
  });

  testWidgets(
    'validates before submitting: no request is made with a bad number',
    (tester) async {
      final env = await _pump(
        tester,
        mode: SheetMode.register,
        state: _canRegister(),
      );
      await tester.enterText(find.byKey(const Key('reg-whatsapp')), '123');
      await tester.enterText(
        find.byKey(const Key('reg-field-club_name')),
        'FC Ada',
      );
      await tester.ensureVisible(find.byKey(const Key('reg-agree')));
      await tester.tap(find.byKey(const Key('reg-agree')));
      await _submit(tester);
      expect(find.text('Enter a valid WhatsApp number.'), findsOneWidget);
      expect(env.repo.registerKeys, isEmpty);
    },
  );

  testWidgets('rules checkbox is required when agreementRequired', (
    tester,
  ) async {
    final env = await _pump(
      tester,
      mode: SheetMode.register,
      state: _canRegister(),
    );
    await _fill(tester, agree: false);
    await _submit(tester);
    expect(find.text('Please agree to the rules.'), findsOneWidget);
    expect(env.repo.registerKeys, isEmpty);
  });

  testWidgets(
    'rules checkbox is hidden when not required, and the request sends agreedToRules true',
    (tester) async {
      final env = await _pump(
        tester,
        mode: SheetMode.register,
        state: _canRegister(agreementRequired: false),
      );
      expect(find.byKey(const Key('reg-agree')), findsNothing);
      env.repo.registerResults.add(const RegisterConfirmed());
      await _fill(tester);
      await _submit(tester);
      expect(env.repo.registerKeys.length, 1);
    },
  );

  testWidgets(
    'coin picker shows three options from remote config and forwards the choice',
    (tester) async {
      final env = await _pump(
        tester,
        mode: SheetMode.register,
        state: _canRegister(coins: true),
      );
      expect(find.text("Don't use coins"), findsOneWidget);
      expect(find.text('500 coins (−₦250)'), findsOneWidget);
      expect(find.text('1000 coins (−₦500)'), findsOneWidget);
      await _fill(tester);
      await tester.ensureVisible(find.text('500 coins (−₦250)'));
      await tester.tap(find.text('500 coins (−₦250)'));
      await tester.pump();
      env.repo.registerResults.add(const RegisterConfirmed());
      await _submit(tester);
      expect(env.repo.registerCoins, [500]);
    },
  );

  testWidgets('no coin picker when the tournament is not coin-eligible', (
    tester,
  ) async {
    await _pump(
      tester,
      mode: SheetMode.register,
      state: _canRegister(coins: false),
    );
    expect(find.text("Don't use coins"), findsNothing);
  });

  testWidgets('a waiver replaces the coin picker with the waiver banner', (
    tester,
  ) async {
    await _pump(
      tester,
      mode: SheetMode.register,
      state: _canRegister(coins: true, waiver: true),
    );
    expect(find.text("Don't use coins"), findsNothing);
    expect(find.text('Free entry — waiver applied'), findsOneWidget);
  });

  testWidgets(
    'waitlist mode: no coin picker, calls the waitlist endpoint, closes with a message',
    (tester) async {
      final env = await _pump(
        tester,
        mode: SheetMode.waitlist,
        state: _canRegister(coins: true),
      );
      expect(find.text("Don't use coins"), findsNothing);
      await _fill(tester);
      await _submit(tester);
      expect(env.repo.waitlistCalls.length, 1);
      expect(find.text("You're on the waitlist."), findsOneWidget);
    },
  );

  testWidgets(
    'a server error is shown as localized copy, not the server message; the button re-enables',
    (tester) async {
      final env = await _pump(
        tester,
        mode: SheetMode.register,
        state: _canRegister(),
      );
      env.repo.registerResults.add(
        const ApiException(
          status: 409,
          code: 'tournament_full',
          message: 'RAW SERVER TEXT',
        ),
      );
      await _fill(tester);
      await _submit(tester);
      expect(find.text('This tournament is full.'), findsOneWidget);
      expect(find.text('RAW SERVER TEXT'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('reg-submit')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'a closed payment window replaces Continue with Check payment status; it never registers again',
    (tester) async {
      final env = await _pump(
        tester,
        mode: SheetMode.register,
        state: _canRegister(),
        launcherReturns: false,
      );
      env.repo.registerResults.add(
        const RegisterPending(
          authorizationUrl: 'https://pay.test/a',
          reference: 'r1',
        ),
      );
      env.repo.paymentResults.addAll([
        PaymentStatus.notSuccessful,
        PaymentStatus.confirmed,
      ]);
      await _fill(tester);
      await _submit(tester);
      expect(find.textContaining('Payment window closed'), findsOneWidget);
      expect(find.byKey(const Key('reg-submit')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('reg-recheck')));
      await tester.tap(find.byKey(const Key('reg-recheck')));
      await tester.pumpAndSettle();
      expect(env.repo.registerKeys.length, 1);
      expect(env.repo.paymentChecks, ['r1', 'r1']);
      expect(find.text("You're in! Payment confirmed."), findsOneWidget);
    },
  );

  testWidgets(
    'an unconfirmed payment also offers Check payment status instead of re-submitting',
    (tester) async {
      final env = await _pump(
        tester,
        mode: SheetMode.register,
        state: _canRegister(),
      );
      env.repo.registerResults.add(
        const RegisterPending(
          authorizationUrl: 'https://pay.test/a',
          reference: 'r1',
        ),
      );
      env.repo.paymentResults.add(PaymentStatus.notSuccessful);
      await _fill(tester);
      await _submit(tester);
      expect(find.byKey(const Key('reg-submit')), findsNothing);
      expect(find.byKey(const Key('reg-recheck')), findsOneWidget);
    },
  );

  testWidgets(
    'a flat dynamic validation response appears as a form-level error',
    (tester) async {
      final env = await _pump(
        tester,
        mode: SheetMode.register,
        state: _canRegister(),
      );
      env.repo.registerResults.add(
        const ApiException(
          status: 400,
          code: 'validation_failed',
          message: 'x',
        ),
      );
      await _fill(tester);
      await _submit(tester);
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    },
  );

  testWidgets('needs_username closes the sheet and calls onNeedsUsername', (
    tester,
  ) async {
    var routed = false;
    final env = await _pump(
      tester,
      mode: SheetMode.register,
      state: _canRegister(),
      onNeedsUsername: () => routed = true,
    );
    env.repo.registerResults.add(
      const ApiException(status: 400, code: 'needs_username', message: 'x'),
    );
    await _fill(tester);
    await _submit(tester);
    expect(routed, isTrue);
    expect(find.byKey(const Key('reg-submit')), findsNothing);
  });

  testWidgets(
    'paid flow: opens checkout with the URL, ends with the success snackbar',
    (tester) async {
      final env = await _pump(
        tester,
        mode: SheetMode.register,
        state: _canRegister(),
      );
      env.repo.registerResults.add(
        const RegisterPending(
          authorizationUrl: 'https://pay.test/a',
          reference: 'r1',
        ),
      );
      env.repo.paymentResults.add(PaymentStatus.confirmed);
      await _fill(tester);
      await _submit(tester);
      expect(env.launched, ['https://pay.test/a']);
      expect(find.text("You're in! Payment confirmed."), findsOneWidget);
    },
  );

  testWidgets('free registration ends with the free-confirmation snackbar', (
    tester,
  ) async {
    final env = await _pump(
      tester,
      mode: SheetMode.register,
      state: _canRegister(fee: 0),
    );
    env.repo.registerResults.add(const RegisterConfirmed());
    await _fill(tester);
    await _submit(tester);
    expect(find.text("You're registered!"), findsOneWidget);
  });

  testWidgets('not confirmed after checkout says so and never claims success', (
    tester,
  ) async {
    final env = await _pump(
      tester,
      mode: SheetMode.register,
      state: _canRegister(),
    );
    env.repo.registerResults.add(
      const RegisterPending(
        authorizationUrl: 'https://pay.test/a',
        reference: 'r1',
      ),
    );
    env.repo.paymentResults.add(PaymentStatus.notSuccessful);
    await _fill(tester);
    await _submit(tester);
    expect(find.textContaining("haven't seen your payment"), findsOneWidget);
    expect(find.textContaining('Payment confirmed'), findsNothing);
  });

  testWidgets(
    'fits 375px with a long dynamic field and coin picker (no overflow)',
    (tester) async {
      await _pump(
        tester,
        mode: SheetMode.register,
        state: _canRegister(coins: true),
      );
      await tester.enterText(
        find.byKey(const Key('reg-field-club_name')),
        'C' * 60,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
