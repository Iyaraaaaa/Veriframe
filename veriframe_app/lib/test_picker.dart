// ignore_for_file: avoid_print
// Standalone smoke-test script: run with `flutter run`, not part of the app bundle.
import 'package:file_picker/file_picker.dart';

void main() {
  try {
    final result = FilePicker.pickFiles(type: FileType.video);
    print(result);
  } catch (e) {
    print("Error: $e");
  }
}
