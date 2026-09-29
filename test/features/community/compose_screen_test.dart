import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/features/community/community_image_uploader.dart';
import 'package:sentinelx_mobile/features/community/compose_screen.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:sentinelx_mobile/features/match/evidence.dart' show PickedImage;

import '../../fakes/fake_community_repository.dart';
import '../../fakes/fake_community_uploader.dart';
import '../../support/pump_compete.dart';

PickedImage _img(String name) => PickedImage(name: name, bytes: Uint8List.fromList([1, 2, 3]));

class _Rig {
  _Rig({FakeCommunityRepository? repo, CommunityImageUploader? uploader, FakePicker? picker})
      : repo = repo ?? FakeCommunityRepository(),
        uploader = uploader ?? FakeCommunityUploader(),
        picker = picker ?? FakePicker();
  final FakeCommunityRepository repo;
  final CommunityImageUploader uploader;
  final FakePicker picker;

  List<Override> get overrides => [
        ...competeBaseOverrides(),
        communityRepositoryProvider.overrideWithValue(repo),
        communityImageUploaderProvider.overrideWithValue(uploader),
        communityMultiImagePickerProvider.overrideWithValue(picker),
      ];
}

Future<_Rig> _pump(WidgetTester tester, {_Rig? rig}) async {
  final r = rig ?? _Rig();
  await pumpCompete(
    tester,
    Builder(
      builder: (context) => TextButton(
        key: const Key('open'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ComposeScreen())),
        child: const Text('open'),
      ),
    ),
    overrides: r.overrides,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return r;
}

void main() {
  testWidgets('empty content and no images disables the submit button', (tester) async {
    await _pump(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('compose-submit'))).onPressed, isNull);
  });

  testWidgets('text-only post calls createPost with no images and pops on success', (tester) async {
    final rig = await _pump(tester);
    await tester.enterText(find.byKey(const Key('compose-content')), 'Hello world');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('compose-submit'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('compose-submit')));
    await tester.pumpAndSettle();

    expect(rig.repo.calls, hasLength(1));
    expect(rig.repo.calls.single, startsWith('createPost:Hello world::'));
    expect(find.byType(ComposeScreen), findsNothing);
  });

  testWidgets('adding images shows the count and thumbnails; removing one drops it from the pending list before submit', (tester) async {
    final picker = FakePicker([_img('a.png'), _img('b.png')]);
    final uploader = FakeCommunityUploader();
    final rig = await _pump(tester, rig: _Rig(picker: picker, uploader: uploader));

    await tester.tap(find.byKey(const Key('compose-add-image')));
    await tester.pumpAndSettle();
    expect(find.text('2/5'), findsOneWidget);
    expect(find.byKey(const Key('compose-remove-image-0')), findsOneWidget);
    expect(find.byKey(const Key('compose-remove-image-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('compose-remove-image-1')));
    await tester.pumpAndSettle();
    expect(find.text('1/5'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('compose-content')), 'hi');
    await tester.tap(find.byKey(const Key('compose-submit')));
    await tester.pumpAndSettle();

    expect(uploader.calls, hasLength(1));
    expect(uploader.calls.single.name, 'a.png');
    expect(rig.repo.calls.single, startsWith('createPost:hi:https://fake.test/a.png:'));
  });

  testWidgets('picking more than 5 images caps the pending list at 5', (tester) async {
    final images = List.generate(7, (i) => _img('img$i.png'));
    await _pump(tester, rig: _Rig(picker: FakePicker(images)));

    await tester.tap(find.byKey(const Key('compose-add-image')));
    await tester.pumpAndSettle();

    expect(find.text('5/5'), findsOneWidget);
    expect(find.byKey(const Key('compose-remove-image-4')), findsOneWidget);
    expect(find.byKey(const Key('compose-remove-image-5')), findsNothing);
  });

  testWidgets('submit with images uploads each once then creates the post with the returned URLs in picked order', (tester) async {
    final picker = FakePicker([_img('a.png'), _img('b.png')]);
    final uploader = FakeCommunityUploader();
    final rig = await _pump(tester, rig: _Rig(picker: picker, uploader: uploader));

    await tester.tap(find.byKey(const Key('compose-add-image')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('compose-content')), 'caption');
    await tester.tap(find.byKey(const Key('compose-submit')));
    await tester.pumpAndSettle();

    expect(uploader.calls, hasLength(2));
    expect(uploader.calls.map((i) => i.name).toList(), ['a.png', 'b.png']);
    expect(rig.repo.calls.single, startsWith('createPost:caption:https://fake.test/a.png,https://fake.test/b.png:'));
    expect(find.byType(ComposeScreen), findsNothing);
  });

  testWidgets('an uploader failure shows upload_failed copy, does not pop, and keeps the picked images', (tester) async {
    final picker = FakePicker([_img('a.png')]);
    final failing = FailingCommunityUploader();
    final rig = await _pump(tester, rig: _Rig(picker: picker, uploader: failing));

    await tester.tap(find.byKey(const Key('compose-add-image')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('compose-content')), 'caption');
    await tester.tap(find.byKey(const Key('compose-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Image upload failed. Please try again.'), findsOneWidget);
    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
    expect(rig.repo.calls, isEmpty);
    expect(failing.calls, hasLength(1));
  });

  testWidgets('a validation_failed from createPost shows the validation copy', (tester) async {
    final repo = FakeCommunityRepository();
    repo.writeErrors['createPost'] = const ApiException(status: 400, code: 'validation_failed', message: 'RAW');
    await _pump(tester, rig: _Rig(repo: repo));

    await tester.enterText(find.byKey(const Key('compose-content')), 'hi');
    await tester.pump();
    await tester.tap(find.byKey(const Key('compose-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Write something or add a photo first.'), findsOneWidget);
    expect(find.text('RAW'), findsNothing);
    expect(find.byType(ComposeScreen), findsOneWidget);
  });

  testWidgets('back navigation is blocked while the post is in flight', (tester) async {
    final repo = FakeCommunityRepository()..createPostGate = Completer<void>();
    await _pump(tester, rig: _Rig(repo: repo));

    await tester.enterText(find.byKey(const Key('compose-content')), 'hi');
    await tester.pump();
    await tester.tap(find.byKey(const Key('compose-submit')));
    await tester.pump();

    // `NavigatorState.maybePop()`'s return value means "the attempt was handled" (true for both a
    // successful pop and a blocked one) — so the only reliable signal that PopScope blocked it is
    // that the route is still there afterwards.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    await navigator.maybePop();
    await tester.pump();
    expect(find.byType(ComposeScreen), findsOneWidget);

    repo.createPostGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ComposeScreen), findsNothing);
  });
}
