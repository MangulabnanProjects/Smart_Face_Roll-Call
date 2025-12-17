import 'package:flutter/foundation.dart';

/// A simple singleton service to notify parts of the app when an image is saved.
class ImageService {
  static final ImageService _instance = ImageService._internal();

  factory ImageService() {
    return _instance;
  }

  ImageService._internal();

  // ValueNotifier to trigger updates. The value itself doesn't matter much,
  // we just increment it to signal a change.
  final ValueNotifier<int> onImageSaved = ValueNotifier<int>(0);

  void notifyImageSaved() {
    onImageSaved.value++;
    debugPrint('📸 ImageService: Notified listeners of new image');
  }
}
