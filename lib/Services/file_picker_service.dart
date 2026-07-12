import 'dart:io';
import 'package:file_picker/file_picker.dart';

class FilePickerService {
  static Future<FilePickerResult?> pickCustomFile(List<String> extensions) async {
    return await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
  }
}