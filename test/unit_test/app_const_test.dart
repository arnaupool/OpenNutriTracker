import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/app_const.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConst.getUserAgentString', () {
    test(
      'caches after the first call — a later PackageInfo change is not '
      'reflected, since none of its inputs can change while the process '
      'is running and PackageInfo.fromPlatform() is a platform-channel '
      'round-trip not worth repeating on every OFF request',
      () async {
        PackageInfo.setMockInitialValues(
          appName: 'OpenNutriTracker',
          packageName: 'com.example.opennutritracker',
          version: '1.0.0',
          buildNumber: '1',
          buildSignature: '',
        );

        final first = await AppConst.getUserAgentString();
        expect(first, contains('Version 1.0.0'));

        // Simulate PackageInfo somehow reporting a different version on a
        // later platform-channel round-trip — the cached value should win.
        PackageInfo.setMockInitialValues(
          appName: 'OpenNutriTracker',
          packageName: 'com.example.opennutritracker',
          version: '9.9.9',
          buildNumber: '99',
          buildSignature: '',
        );

        final second = await AppConst.getUserAgentString();
        expect(second, first);
        expect(second, contains('Version 1.0.0'));
      },
    );
  });
}
