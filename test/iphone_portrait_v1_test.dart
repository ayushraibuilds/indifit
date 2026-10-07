import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/app/app_orientation.dart';

// SC-06: v1 ships iPhone-only and portrait-only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every Runner build configuration targets iPhone only', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final families = RegExp(
      r'TARGETED_DEVICE_FAMILY = "?([^";]+)"?;',
    ).allMatches(project).map((m) => m.group(1)).toList();

    expect(families, hasLength(3));
    expect(families, everyElement('1'));
  });

  test('Info.plist allows portrait only and declares no iPad orientations', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final orientations = RegExp(
      r'<key>UISupportedInterfaceOrientations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);

    expect(orientations, isNotNull);
    expect(
      RegExp(
        r'<string>([^<]+)</string>',
      ).allMatches(orientations!.group(1)!).map((m) => m.group(1)),
      ['UIInterfaceOrientationPortrait'],
    );
    expect(plist, isNot(contains('UISupportedInterfaceOrientations~ipad')));
  });

  test('lockAppOrientation asks the platform for portrait up only', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await lockAppOrientation();

    expect(calls.single.method, 'SystemChrome.setPreferredOrientations');
    expect(calls.single.arguments, ['DeviceOrientation.portraitUp']);
  });

  test('bootstrap locks the orientation before the first frame', () {
    final bootstrap = File('lib/app/bootstrap.dart').readAsStringSync();
    final lock = bootstrap.indexOf('await lockAppOrientation();');

    expect(lock, isNonNegative);
    expect(lock, lessThan(bootstrap.indexOf('runApp(')));
  });
}
