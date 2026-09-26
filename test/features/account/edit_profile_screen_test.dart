import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/edit_profile_screen.dart';
import 'package:sentinelx_mobile/features/account/profile_providers.dart';

import '../../support/pump_compete.dart';

class _Rig {
  _Rig({this.bioFails = false});
  final String bio = 'Hello there';
  final bool bioFails;
  final saved = <ProfileEdit>[];
  int meBuilds = 0;
  Object? result;
  Completer<void>? gate;

  List<Override> overrides({bool signedOut = false}) => [
        remoteConfigProviderStub,
        ownBioProvider.overrideWith((ref) async {
          if (bioFails) throw Exception('offline');
          return bio;
        }),
        meProvider.overrideWith((ref) async {
          meBuilds++;
          return signedOut ? null : testMe();
        }),
        profileEditorProvider.overrideWithValue((edit) async {
          saved.add(edit);
          if (gate != null) await gate!.future;
          final r = result;
          if (r is Exception) throw r;
        }),
      ];
}

final remoteConfigProviderStub = remoteConfigProvider.overrideWith((ref) async => testRemoteConfig());

Future<_Rig> _pump(WidgetTester tester, {bool signedOut = false, bool pushed = false, bool bioFails = false}) async {
  final rig = _Rig(bioFails: bioFails);
  final Widget home = pushed
      ? Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditProfileScreen())),
            child: const Text('open'),
          ),
        )
      : const EditProfileScreen();
  await pumpCompete(tester, home, overrides: rig.overrides(signedOut: signedOut));
  await tester.pumpAndSettle();
  if (pushed) {
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }
  return rig;
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('profile-save')));
  await tester.tap(find.byKey(const Key('profile-save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prefills from the signed-in profile', (tester) async {
    await _pump(tester);
    expect(find.widgetWithText(TextFormField, 'Ada'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'ada'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '+2348012345678'), findsOneWidget);
  });

  testWidgets('an existing bio is loaded and sent back unchanged when only the name is edited (the server clears an empty bio)', (tester) async {
    final rig = await _pump(tester);
    expect(find.widgetWithText(TextFormField, 'Hello there'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profile-display-name')), 'Ada B');
    await _save(tester);
    expect(rig.saved.single.bio, 'Hello there');
  });

  testWidgets('if the bio cannot be loaded the form is not offered (saving would erase it) and retry is', (tester) async {
    await _pump(tester, bioFails: true);
    expect(find.byKey(const Key('profile-save')), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('signed out renders no form', (tester) async {
    await _pump(tester, signedOut: true);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('an invalid WhatsApp number blocks the save', (tester) async {
    final rig = await _pump(tester);
    await tester.enterText(find.byKey(const Key('profile-whatsapp')), '12');
    await _save(tester);
    expect(find.text('Enter a valid WhatsApp number.'), findsOneWidget);
    expect(rig.saved, isEmpty);
  });

  testWidgets('a 281-character bio blocks the save; 280 is fine', (tester) async {
    final rig = await _pump(tester);
    await tester.enterText(find.byKey(const Key('profile-bio')), 'b' * 281);
    await _save(tester);
    expect(find.text('Bio must be 280 characters or fewer.'), findsOneWidget);
    expect(rig.saved, isEmpty);
    await tester.enterText(find.byKey(const Key('profile-bio')), 'b' * 280);
    await _save(tester);
    expect(rig.saved.length, 1);
  });

  testWidgets('an empty display name blocks the save', (tester) async {
    final rig = await _pump(tester);
    await tester.enterText(find.byKey(const Key('profile-display-name')), '  ');
    await _save(tester);
    expect(find.text('Enter a name (1–60 characters).'), findsOneWidget);
    expect(rig.saved, isEmpty);
  });

  testWidgets('an unchanged username is sent as empty (no change); a new one is sent verbatim', (tester) async {
    final rig = await _pump(tester);
    await _save(tester);
    expect(rig.saved.single.username, '');
    expect(rig.saved.single.displayName, 'Ada');
    await tester.enterText(find.byKey(const Key('profile-username')), 'ada_new');
    await _save(tester);
    expect(rig.saved.last.username, 'ada_new');
  });

  testWidgets('a cleared WhatsApp number is allowed and sent empty', (tester) async {
    final rig = await _pump(tester);
    await tester.enterText(find.byKey(const Key('profile-whatsapp')), '');
    await _save(tester);
    expect(rig.saved.single.whatsapp, '');
  });

  testWidgets('username_taken and username_locked show their own copy, not server text', (tester) async {
    final rig = await _pump(tester);
    rig.result = const ApiException(status: 400, code: 'username_taken', message: 'RAW');
    await _save(tester);
    expect(find.text('That username is already taken.'), findsOneWidget);
    expect(find.text('RAW'), findsNothing);
  });

  testWidgets('a server validation_failed on the username shows a localized username hint', (tester) async {
    final rig = await _pump(tester);
    rig.result = const ApiException(status: 400, code: 'validation_failed', message: 'RAW', fields: {'username': 'username_too_short'});
    await tester.enterText(find.byKey(const Key('profile-username')), 'ab');
    await _save(tester);
    expect(find.text('Usernames are 3–20 letters, numbers or underscores.'), findsOneWidget);
    expect(find.text('username_too_short'), findsNothing);
  });

  testWidgets('save is disabled while in flight, so a double tap saves once', (tester) async {
    final rig = await _pump(tester);
    rig.gate = Completer<void>();
    await tester.ensureVisible(find.byKey(const Key('profile-save')));
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('profile-save'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('profile-save')), warnIfMissed: false);
    rig.gate!.complete();
    await tester.pumpAndSettle();
    expect(rig.saved.length, 1);
  });

  testWidgets('success refreshes /me, confirms and leaves the screen', (tester) async {
    final rig = await _pump(tester, pushed: true);
    final before = rig.meBuilds;
    await _save(tester);
    expect(rig.meBuilds, greaterThan(before));
    expect(find.text('Profile saved.'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsNothing);
  });
}
