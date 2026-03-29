import 'package:image_picker/image_picker.dart';

class SelectedMediaFile {
  const SelectedMediaFile({required this.path, required this.fileName});

  final String path;
  final String fileName;
}

abstract class MediaPickerService {
  Future<SelectedMediaFile?> pickCompressedImage();
}

class DeviceMediaPickerService implements MediaPickerService {
  DeviceMediaPickerService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<SelectedMediaFile?> pickCompressedImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) {
      return null;
    }

    return SelectedMediaFile(path: file.path, fileName: file.name);
  }
}
