import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R09-C frozen public release identity', () {
    test('native product names and application identifiers agree', () {
      final androidManifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final androidStrings = File(
        'android/app/src/main/res/values/strings.xml',
      ).readAsStringSync();
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      final iosPlist = File('ios/Runner/Info.plist').readAsStringSync();
      final xcodeProject = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      expect(androidManifest, contains('android:label="@string/app_name"'));
      expect(
        androidStrings,
        contains('<string name="app_name">IndiFit</string>'),
      );
      expect(iosPlist, contains('<string>IndiFit</string>'));
      expect(iosPlist, isNot(contains('<string>Indifit</string>')));

      expect(
        RegExp(
          r'(namespace|applicationId) = "com\.indifit\.indifit"',
        ).allMatches(gradle),
        hasLength(2),
      );
      expect(
        RegExp(
          r'PRODUCT_BUNDLE_IDENTIFIER = com\.indifit\.indifit;',
        ).allMatches(xcodeProject),
        hasLength(3),
      );
      expect(xcodeProject, isNot(contains('com.justdoit.indifit')));
    });

    test('V1 package metadata is explicit and consistent', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final releaseIdentity = File(
        'docs/release/R09-C_RELEASE_IDENTITY.md',
      ).readAsStringSync();
      final readme = File('README.md').readAsStringSync();

      expect(pubspec, contains('version: 1.0.0+1'));
      expect(
        pubspec,
        contains(
          'description: "Offline-first workout and Indian nutrition tracking for iOS and Android."',
        ),
      );
      expect(releaseIdentity, contains('| Version | `1.0.0` |'));
      expect(releaseIdentity, contains('| Build number | `1` |'));
      expect(readme, contains('`com.indifit.indifit`'));
      expect(readme, isNot(contains('com.indifit.IndiFit')));
    });

    test('release signing remains owner-controlled and fails closed', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      final gitignore = File('.gitignore').readAsStringSync();
      final xcodeProject = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      expect(gradle, contains('rootProject.file("key.properties")'));
      expect(
        gradle,
        contains(
          'Release build requires key.properties keystore configuration',
        ),
      );
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
      expect(gitignore, contains('**/android/key.properties'));
      expect(gitignore, contains('*.jks'));
      expect(xcodeProject, contains('CODE_SIGN_STYLE = Automatic;'));
      expect(
        RegExp(r'DEVELOPMENT_TEAM = [A-Z0-9]{10};').hasMatch(xcodeProject),
        isTrue,
      );
    });
  });

  group('R09-C branded launcher and splash assets', () {
    test(
      'Android declares adaptive, round, monochrome, and branded splash resources',
      () {
        final manifest = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
        final adaptive = File(
          'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
        ).readAsStringSync();
        final themed = File(
          'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml',
        ).readAsStringSync();
        final launch = File(
          'android/app/src/main/res/drawable/launch_background.xml',
        ).readAsStringSync();
        final android12 = File(
          'android/app/src/main/res/values-v31/styles.xml',
        ).readAsStringSync();

        expect(
          manifest,
          contains('android:roundIcon="@mipmap/ic_launcher_round"'),
        );
        expect(adaptive, contains('@color/ic_launcher_background'));
        expect(adaptive, contains('@drawable/ic_launcher_foreground'));
        expect(adaptive, isNot(contains('<monochrome')));
        expect(themed, contains('<monochrome'));
        expect(launch, contains('@color/brand_midnight'));
        expect(launch, contains('@drawable/ic_launcher_foreground'));
        expect(android12, contains('android:windowSplashScreenBackground'));
        expect(android12, contains('android:windowSplashScreenAnimatedIcon'));
      },
    );

    test('brand masters have the required opacity and dimensions', () {
      _expectPng(
        'assets/branding/indifit_app_icon_master.png',
        width: 1024,
        height: 1024,
        colorType: 2,
      );
      _expectPng(
        'assets/branding/indifit_adaptive_foreground.png',
        width: 1024,
        height: 1024,
        colorType: 6,
      );
      expect(
        File('assets/branding/indifit_app_icon_master.png').lengthSync(),
        greaterThan(100000),
        reason: 'The master must not regress to Flutter\'s tiny default icon.',
      );
    });

    test(
      'iOS AppIcon catalog contains every correctly sized opaque raster',
      () {
        const iconSizes = <String, int>{
          'Icon-App-20x20@1x.png': 20,
          'Icon-App-20x20@2x.png': 40,
          'Icon-App-20x20@3x.png': 60,
          'Icon-App-29x29@1x.png': 29,
          'Icon-App-29x29@2x.png': 58,
          'Icon-App-29x29@3x.png': 87,
          'Icon-App-40x40@1x.png': 40,
          'Icon-App-40x40@2x.png': 80,
          'Icon-App-40x40@3x.png': 120,
          'Icon-App-60x60@2x.png': 120,
          'Icon-App-60x60@3x.png': 180,
          'Icon-App-76x76@1x.png': 76,
          'Icon-App-76x76@2x.png': 152,
          'Icon-App-83.5x83.5@2x.png': 167,
          'Icon-App-1024x1024@1x.png': 1024,
        };

        for (final entry in iconSizes.entries) {
          _expectPng(
            'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
            width: entry.value,
            height: entry.value,
            colorType: 2,
          );
        }
      },
    );

    test('native launch images are real transparent brand assets', () {
      const launchSizes = <String, int>{
        'LaunchImage.png': 168,
        'LaunchImage@2x.png': 336,
        'LaunchImage@3x.png': 504,
      };
      for (final entry in launchSizes.entries) {
        _expectPng(
          'ios/Runner/Assets.xcassets/LaunchImage.imageset/${entry.key}',
          width: entry.value,
          height: entry.value,
          colorType: 6,
        );
      }
    });
  });
}

void _expectPng(
  String path, {
  required int width,
  required int height,
  required int colorType,
}) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing.');
  final bytes = file.readAsBytesSync();
  expect(
    bytes.take(8),
    orderedEquals(const [137, 80, 78, 71, 13, 10, 26, 10]),
    reason: '$path is not a PNG.',
  );
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  expect(data.getUint32(16), width, reason: '$path has the wrong width.');
  expect(data.getUint32(20), height, reason: '$path has the wrong height.');
  expect(
    data.getUint8(25),
    colorType,
    reason: '$path has the wrong PNG opacity/color type.',
  );
}
