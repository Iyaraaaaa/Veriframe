import 'package:file_picker/file_picker.dart';

void main() {
  try {
    final result = FilePicker.pickFiles(type: FileType.video);
    print(result);
  } catch (e) {
    print("Error: $e");
  }
}
