// ignore_for_file: avoid_print
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (
      String name,
      List<int> image, [
      Map<String, Object?>? args,
    ]) async {
      print('📸 Processing screenshot "$name"...');
      final destination =
          '/Users/dankmagician/.gemini/antigravity/brain/24f93410-3321-488c-9937-c3af223786db/screenshots/$name.png';
      final file = File(destination);
      await file.parent.create(recursive: true);

      // Attempt native simctl capture
      final res = await Process.run('xcrun', [
        'simctl',
        'io',
        '5AB1CBD7-3581-4418-A603-FD42EC9D8B43',
        'screenshot',
        destination,
      ]);

      if (res.exitCode == 0 && file.existsSync() && file.lengthSync() > 100000) {
        print('✅ Native simctl screenshot captured (${file.lengthSync()} bytes) at $destination');
      } else if (image.isNotEmpty) {
        await file.writeAsBytes(image);
        print('✅ Saved Flutter image bytes (${image.length} bytes) to $destination');
      } else {
        print('⚠️ Screenshot capture produced: exitCode ${res.exitCode}, file size ${file.existsSync() ? file.lengthSync() : 0}');
      }
      return true;
    },
  );
}
