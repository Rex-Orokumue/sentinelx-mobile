import 'package:sentinelx_mobile/features/match/evidence.dart';

class FakeUploader implements EvidenceUploader {
  final calls = <PickedImage>[];
  Object? failWith;

  @override
  Future<String> upload({required String userId, required String scopeId, required PickedImage image}) async {
    calls.add(image);
    final f = failWith;
    if (f != null) throw f;
    return '$userId/$scopeId/${calls.length}-${image.name}';
  }
}

class FakePicker implements ImagePickerPort {
  final queue = <PickedImage?>[];

  @override
  Future<PickedImage?> pickScreenshot() async => queue.isEmpty ? null : queue.removeAt(0);
}
