import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

class AppConst {
  static const userAgentAppName = "OpenNutriTracker";
  static const platformNameAndroid = "Android";
  static const platformNameIOS = "iOS";
  static const platformNameWeb = "Web";
  static const reportErrorEmail = "opennutritracker-dev@pm.me";
  static const sourceCodeUrl =
      "https://github.com/simonoppowa/OpenNutriTracker";

  // Set at Docker build time (see Dockerfile) via `--dart-define`, a UTC
  // timestamp of when the image was actually built — unlike pubspec.yaml's
  // version (bumped by hand, rarely) this changes on every deploy, so it's
  // what actually answers "is the build in front of me the one I just
  // pushed, or something a CDN/browser cache is still holding onto?" (see
  // the FA-13 cache-purge saga in the commit history). A git-commit-hash
  // stamp was tried first but dropped: Portainer's "Repository" build
  // method doesn't expose .git to the build stage at all. Empty outside a
  // Docker build (local `flutter run`), which AppBannerVersion hides.
  static const buildStamp = String.fromEnvironment('BUILD_STAMP');

  static Future<String> getVersionNumber() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  // dart:io's Platform.isAndroid/isIOS throws on web, so this is built on
  // defaultTargetPlatform (Flutter's own platform signal, works
  // everywhere) with an explicit kIsWeb check first — defaultTargetPlatform
  // alone would still report the host OS a browser is running on, which
  // isn't the distinction this User-Agent string is trying to make.
  static String getPlatformName() {
    if (kIsWeb) return platformNameWeb;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return platformNameAndroid;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return platformNameIOS;
    } else {
      return "";
    }
  }

  // Cached after the first call — none of its inputs (app version,
  // platform) can change while the process is running, but
  // PackageInfo.fromPlatform() is a platform-channel round-trip, and this
  // is built fresh on every OFF request (search-as-you-type included)
  // without caching.
  static String? _cachedUserAgentString;

  static Future<String> getUserAgentString() async {
    final cached = _cachedUserAgentString;
    if (cached != null) return cached;
    final versionNumber = await getVersionNumber();
    final platformVersion = getPlatformName();
    final userAgentString =
        '$userAgentAppName - $platformVersion - Version $versionNumber - $sourceCodeUrl';
    _cachedUserAgentString = userAgentString;
    return userAgentString;
  }
}
