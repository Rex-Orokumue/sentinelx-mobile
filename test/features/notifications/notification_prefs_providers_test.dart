import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/notifications_models.dart';
import 'package:sentinelx_mobile/features/notifications/notification_prefs_providers.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_providers.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';

import '../../fakes/fake_notifications_repository.dart';

class _Viewer extends Notifier<String?> {
  _Viewer(this.initial);
  final String? initial;
  @override
  String? build() => initial;
  void set(String? v) => state = v;
}

final _viewerProvider = NotifierProvider<_Viewer, String?>(() => _Viewer('u1'));

NotificationPrefs _prefs({bool reaction = true}) => NotificationPrefs(
      push: {for (final k in kPushPrefKeys) k: true, 'post_reaction': reaction},
      whatsapp: {for (final k in kWhatsappPrefKeys) k: false},
      achievementSharing: {for (final k in kSharingPrefKeys) k: true},
    );

class _Rig {
  _Rig(this.repo, {String? viewer = 'u1'}) {
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      notificationsRepositoryProvider.overrideWithValue(repo),
      _viewerProvider.overrideWith(() => _Viewer(viewer)),
      notificationsViewerIdProvider.overrideWith((ref) async => ref.watch(_viewerProvider)),
    ]);
    container.listen(notificationPrefsProvider, (_, _) {});
  }

  final FakeNotificationsRepository repo;
  late final ProviderContainer container;
  NotificationPrefsNotifier get notifier => container.read(notificationPrefsProvider.notifier);
  NotificationPrefs? get value => container.read(notificationPrefsProvider).value;
  Future<NotificationPrefs?> get loaded => container.read(notificationPrefsProvider.future);
}

void main() {
  test('loads the 17 / 6 / 5 prefs; signed out is null', () async {
    final repo = FakeNotificationsRepository()..prefsResult = _prefs();
    var r = _Rig(repo);
    addTearDown(r.container.dispose);
    final p = (await r.loaded)!;
    expect(p.push, hasLength(17));
    expect(p.whatsapp, hasLength(6));
    expect(p.achievementSharing, hasLength(5));

    r = _Rig(repo, viewer: null);
    addTearDown(r.container.dispose);
    expect(await r.loaded, isNull);
  });

  test('set is optimistic and sends exactly (section, {key: value})', () async {
    final repo = FakeNotificationsRepository()
      ..prefsResult = _prefs()
      ..holdPatch = Completer<void>();
    final r = _Rig(repo);
    addTearDown(r.container.dispose);
    await r.loaded;
    final call = r.notifier.set(PrefSection.push, 'post_reaction', false);
    await pumpEventQueue();
    expect(r.value!.push['post_reaction'], isFalse, reason: 'flipped before the API answered');
    repo.holdPatch!.complete();
    expect(await call, isTrue);
    expect(repo.patchCalls.single.section, PrefSection.push);
    expect(repo.patchCalls.single.values, {'post_reaction': false});
    expect(r.value!.push['post_reaction'], isFalse);
  });

  test('failure reverts only that key', () async {
    final repo = FakeNotificationsRepository()
      ..prefsResult = _prefs()
      ..failPatchKeys.add('post_reaction');
    final r = _Rig(repo);
    addTearDown(r.container.dispose);
    await r.loaded;
    await r.notifier.set(PrefSection.push, 'post_comment', false); // succeeds
    expect(await r.notifier.set(PrefSection.push, 'post_reaction', false), isFalse);
    expect(r.value!.push['post_reaction'], isTrue, reason: 'reverted');
    expect(r.value!.push['post_comment'], isFalse, reason: 'another key stays as the user left it');
  });

  test('a failure never restores a stale snapshot over a different key toggled meanwhile', () async {
    final repo = FakeNotificationsRepository()
      ..prefsResult = _prefs()
      ..holdPatch = Completer<void>()
      ..failPatchKeys.add('post_reaction');
    final r = _Rig(repo);
    addTearDown(r.container.dispose);
    await r.loaded;
    final failing = r.notifier.set(PrefSection.push, 'post_reaction', false);
    await pumpEventQueue();
    // another key is toggled while the first call is still in flight
    final ok = r.notifier.set(PrefSection.push, 'new_follower', false);
    repo.holdPatch!.complete();
    await Future.wait([failing, ok]);
    expect(r.value!.push['post_reaction'], isTrue);
    expect(r.value!.push['new_follower'], isFalse);
  });

  test('a failure does not revert when the same key was toggled again meanwhile (the later value wins)', () async {
    final repo = FakeNotificationsRepository()
      ..prefsResult = _prefs()
      ..holdPatch = Completer<void>()
      ..failPatchKeys.add('post_reaction');
    final r = _Rig(repo);
    addTearDown(r.container.dispose);
    await r.loaded;
    final first = r.notifier.set(PrefSection.push, 'post_reaction', false);
    await pumpEventQueue();
    repo.failPatchKeys.clear(); // the second call succeeds
    final second = r.notifier.set(PrefSection.push, 'post_reaction', true);
    repo.holdPatch!.complete();
    await Future.wait([first, second]);
    expect(r.value!.push['post_reaction'], isTrue);
  });

  test('a failed toggle never reverts over the latest intent of the user after further quick toggles of the same key', () async {
    final repo = FakeNotificationsRepository()
      ..prefsResult = _prefs()
      ..holdPatch = Completer<void>()
      ..failNextPatches = 1; // only the first call fails
    final r = _Rig(repo);
    addTearDown(r.container.dispose);
    await r.loaded;
    final a = r.notifier.set(PrefSection.push, 'post_reaction', false); // fails
    final b = r.notifier.set(PrefSection.push, 'post_reaction', true);
    final c = r.notifier.set(PrefSection.push, 'post_reaction', false); // the user's last word
    repo.holdPatch!.complete();
    expect(await Future.wait([a, b, c]), [false, true, true]);
    expect(r.value!.push['post_reaction'], isFalse);
  });

  test('rapid toggles of the same key reach the API one at a time, in order', () async {
    final repo = FakeNotificationsRepository()
      ..prefsResult = _prefs()
      ..holdPatch = Completer<void>();
    final r = _Rig(repo);
    addTearDown(r.container.dispose);
    await r.loaded;
    final a = r.notifier.set(PrefSection.push, 'post_reaction', false);
    final b = r.notifier.set(PrefSection.push, 'post_reaction', true);
    await pumpEventQueue();
    expect(repo.patchCalls, hasLength(1), reason: 'the second waits for the first');
    repo.holdPatch!.complete();
    await Future.wait([a, b]);
    expect(repo.patchCalls.map((c) => c.values['post_reaction']), [false, true]);
  });

  test('a disposed notifier does nothing and does not throw', () async {
    final repo = FakeNotificationsRepository()..prefsResult = _prefs();
    final r = _Rig(repo);
    await r.loaded;
    final notifier = r.notifier;
    r.container.dispose();
    expect(await notifier.set(PrefSection.push, 'post_reaction', false), isFalse);
    expect(repo.patchCalls, isEmpty);
  });

  test('account switch refetches for the new viewer and does not show the previous values (Review Focus 4)', () async {
    final repo = FakeNotificationsRepository()..prefsResult = _prefs(reaction: false);
    final r = _Rig(repo);
    addTearDown(r.container.dispose);
    expect((await r.loaded)!.push['post_reaction'], isFalse);
    repo.prefsResult = _prefs(); // user B's prefs
    r.container.read(_viewerProvider.notifier).set('u2');
    await pumpEventQueue();
    expect(r.value!.push['post_reaction'], isTrue);
  });

  test('isTypeSilenced combines a live timed mute with an "always" (push false) flag', () {
    final mutes = NotificationMutes(types: [MutedType('post_comment', DateTime.utc(2099))], posts: const []);
    final prefs = _prefs(reaction: false);
    final now = DateTime.utc(2026, 10, 3);
    expect(isTypeSilenced('post_comment', prefs: prefs, mutes: mutes, now: now), isTrue);
    expect(isTypeSilenced('post_reaction', prefs: prefs, mutes: mutes, now: now), isTrue);
    expect(isTypeSilenced('new_follower', prefs: prefs, mutes: mutes, now: now), isFalse);
    expect(isTypeSilenced('new_follower', prefs: null, mutes: null, now: now), isFalse);
  });
}
