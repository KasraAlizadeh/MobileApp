import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Services/file_picker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FilePickerService Unit Tests', () {
    test('Invokes custom platform file filter channels correctly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('miguelruivo.flutter.plugins.filepicker'),
            (MethodCall methodCall) async {
          return [
            {
              'path': '/mock/dir/ticket.pdf',
              'name': 'ticket.pdf',
              'size': 2048,
              'bytes': null,
            }
          ];
        },
      );

      final result = await FilePickerService.pickCustomFile(['pdf']);

      expect(result, isNotNull);
      expect(result!.files.single.name, 'ticket.pdf');
    });
  });
}