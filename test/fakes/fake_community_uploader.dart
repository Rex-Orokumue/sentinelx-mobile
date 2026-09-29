import 'package:sentinelx_mobile/features/community/community_image_uploader.dart';
import 'package:sentinelx_mobile/features/match/evidence.dart' show PickedImage;

/// In-memory `CommunityImageUploader` for tests. Returns a deterministic public URL per call and
/// records every call (in order) so tests can assert upload counts without a real Storage client.
class FakeCommunityUploader implements CommunityImageUploader {
  final calls = <PickedImage>[];

  @override
  Future<String> upload({required String userId, required PickedImage image}) async {
    calls.add(image);
    return 'https://fake.test/${image.name}';
  }
}

/// A `CommunityImageUploader` that always throws, for exercising the `upload_failed` path.
class FailingCommunityUploader implements CommunityImageUploader {
  final calls = <PickedImage>[];

  @override
  Future<String> upload({required String userId, required PickedImage image}) async {
    calls.add(image);
    throw Exception('storage down');
  }
}

/// In-memory `MultiImagePickerPort` for tests. Returns the seeded [images] list, ignoring
/// [maxCount] (the screen is responsible for clamping to 5, per the brief).
class FakePicker implements MultiImagePickerPort {
  FakePicker([this.images = const []]);
  List<PickedImage> images;

  @override
  Future<List<PickedImage>> pickImages({required int maxCount}) async => images;
}
