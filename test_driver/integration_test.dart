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
      const brainDir =
          '/Users/dankmagician/.gemini/antigravity/brain/2c0d3756-ff26-4ed4-9557-a0dde2eccf15';
      const workspaceRoot =
          '/Users/dankmagician/Documents/New project/indifit';

      final targetPlatform =
          Platform.environment['TARGET_PLATFORM']?.toLowerCase() ?? 'android';

      bool captured = false;

      if (targetPlatform == 'android') {
        final androidArtifactFile =
            File('$brainDir/screenshots_android/$name.png');
        final androidWorkspaceFile =
            File('$workspaceRoot/test_artifacts/screenshots_android/$name.png');
        await androidArtifactFile.parent.create(recursive: true);
        await androidWorkspaceFile.parent.create(recursive: true);

        // Native Android adb screencap
        try {
          const adbPath =
              '/Users/dankmagician/Library/Android/sdk/platform-tools/adb';
          final adbRes = await Process.run(
            adbPath,
            ['-s', 'emulator-5554', 'exec-out', 'screencap', '-p'],
            stdoutEncoding: null,
          );
          if (adbRes.exitCode == 0 && adbRes.stdout is List<int>) {
            final bytes = adbRes.stdout as List<int>;
            if (bytes.length > 50000) {
              await androidArtifactFile.writeAsBytes(bytes);
              await androidWorkspaceFile.writeAsBytes(bytes);
              print(
                  '✅ Native Android adb screenshot captured (${bytes.length} bytes) at ${androidArtifactFile.path}');
              captured = true;
            }
          }
        } catch (e) {
          print('⚠️ adb screencap failed: $e');
        }

        if (!captured && image.isNotEmpty) {
          await androidArtifactFile.writeAsBytes(image);
          await androidWorkspaceFile.writeAsBytes(image);
          print(
              '✅ Saved Flutter image bytes (${image.length} bytes) to ${androidArtifactFile.path}');
          captured = true;
        }
      } else {
        final iosArtifactFile = File('$brainDir/screenshots/$name.png');
        final iosWorkspaceFile =
            File('$workspaceRoot/test_artifacts/screenshots/$name.png');
        await iosArtifactFile.parent.create(recursive: true);
        await iosWorkspaceFile.parent.create(recursive: true);

        // Attempt native simctl capture
        try {
          final res = await Process.run('xcrun', [
            'simctl',
            'io',
            '5AB1CBD7-3581-4418-A603-FD42EC9D8B43',
            'screenshot',
            iosArtifactFile.path,
          ]);

          if (res.exitCode == 0 &&
              iosArtifactFile.existsSync() &&
              iosArtifactFile.lengthSync() > 100000) {
            await iosArtifactFile.copy(iosWorkspaceFile.path);
            print(
                '✅ Native simctl screenshot captured (${iosArtifactFile.lengthSync()} bytes) at ${iosArtifactFile.path}');
            captured = true;
          }
        } catch (e) {
          print('⚠️ simctl capture failed: $e');
        }

        if (!captured && image.isNotEmpty) {
          await iosArtifactFile.writeAsBytes(image);
          await iosWorkspaceFile.writeAsBytes(image);
          print(
              '✅ Saved Flutter image bytes (${image.length} bytes) to ${iosArtifactFile.path}');
          captured = true;
        }
      }

      if (!captured) {
        print('⚠️ Failed to capture screenshot for "$name"');
      }
      return true;
    },
  );
}
