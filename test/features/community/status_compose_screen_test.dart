import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/features/community/community_image_uploader.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:sentinelx_mobile/features/community/status_compose_screen.dart';
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
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StatusComposeScreen())),
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
  testWidgets('no image and no caption disables submit and shows the validation copy', (tester) async {
    await _pump(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('status-compose-submit'))).onPressed, isNull);
    expect(find.text('Add a photo or a caption.'), findsOneWidget);
  });

  testWidgets('caption-only submit calls postStatus with imageUrl null and pops on success', (tester) async {
    final rig = await _pump(tester);
    await tester.enterText(find.byKey(const Key('status-compose-caption')), 'GG!');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('status-compose-submit'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('status-compose-submit')));
    await tester.pumpAndSettle();

    expect(rig.repo.calls, hasLength(1));
    expect(rig.repo.calls.single, startsWith('postStatus:null:GG!:'));
    expect(find.byType(StatusComposeScreen), findsNothing);
  });

  testWidgets('image-only submit uploads then calls postStatus with caption null', (tester) async {
    final picker = FakePicker([_img('story.png')]);
    final uploader = FakeCommunityUploader();
    final rig = await _pump(tester, rig: _Rig(picker: picker, uploader: uploader));

    await tester.tap(find.byKey(const Key('status-compose-add-image')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('status-compose-submit'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('status-compose-submit')));
    await tester.pumpAndSettle();

    expect(uploader.calls, hasLength(1));
    expect(uploader.calls.single.name, 'story.png');
    expect(rig.repo.calls.single, startsWith('postStatus:https://fake.test/story.png:null:'));
    expect(find.byType(StatusComposeScreen), findsNothing);
  });

  testWidgets('an uploader failure shows upload_failed copy, does not pop, and keeps the picked image', (tester) async {
    final picker = FakePicker([_img('story.png')]);
    final failing = FailingCommunityUploader();
    final rig = await _pump(tester, rig: _Rig(picker: picker, uploader: failing));

    await tester.tap(find.byKey(const Key('status-compose-add-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('status-compose-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Image upload failed. Please try again.'), findsOneWidget);
    expect(find.byType(StatusComposeScreen), findsOneWidget);
    expect(find.byKey(const Key('status-compose-remove-image')), findsOneWidget);
    expect(rig.repo.calls, isEmpty);
    expect(failing.calls, hasLength(1));
  });

  testWidgets('success invalidates communityStatusRingsProvider and pops', (tester) async {
    final repo = FakeCommunityRepository();
    final r = _Rig(repo: repo);
    await pumpCompete(
      tester,
      // Watches the rings provider this screen invalidates on success, so the test can observe the
      // invalidation actually causing a refetch (mirrors boost_sheet_test.dart's pattern).
      Consumer(builder: (context, ref, _) {
        ref.watch(communityStatusRingsProvider);
        return Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StatusComposeScreen())),
            child: const Text('open'),
          ),
        );
      }),
      overrides: r.overrides,
    );
    await tester.pumpAndSettle();
    final statusesCallsBefore = repo.calls.where((c) => c == 'statuses').length;

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('status-compose-caption')), 'hi');
    await tester.pump();
    await tester.tap(find.byKey(const Key('status-compose-submit')));
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c == 'statuses').length, greaterThan(statusesCallsBefore));
    expect(find.byType(StatusComposeScreen), findsNothing);
  });

  testWidgets('back navigation is blocked while the story is in flight', (tester) async {
    final repo = FakeCommunityRepository()..postStatusGate = Completer<void>();
    final rig = await _pump(tester, rig: _Rig(repo: repo));
    await tester.enterText(find.byKey(const Key('status-compose-caption')), 'hi');
    await tester.pump();
    await tester.tap(find.byKey(const Key('status-compose-submit')));
    await tester.pump();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    await navigator.maybePop();
    await tester.pump();
    expect(find.byType(StatusComposeScreen), findsOneWidget);

    repo.postStatusGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(StatusComposeScreen), findsNothing);
    expect(rig.repo.calls, hasLength(1));
  });

  testWidgets('a validation_failed from postStatus shows the validation copy', (tester) async {
    final repo = FakeCommunityRepository();
    repo.writeErrors['postStatus'] = const ApiException(status: 400, code: 'validation_failed', message: 'RAW');
    await _pump(tester, rig: _Rig(repo: repo));

    await tester.enterText(find.byKey(const Key('status-compose-caption')), 'hi');
    await tester.pump();
    await tester.tap(find.byKey(const Key('status-compose-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Write something or add a photo first.'), findsOneWidget);
    expect(find.text('RAW'), findsNothing);
    expect(find.byType(StatusComposeScreen), findsOneWidget);
  });
}
