import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

void main() {
  tearDown(() => ProfileScope.activate(AppProfile.defaultId));

  test('the default profile keeps the original names, so existing data stays put', () {
    ProfileScope.activate(AppProfile.defaultId);
    expect(ProfileScope.box(HiveDBProvider.intakeBoxName), 'IntakeBox');
    expect(ProfileScope.secret('SyncKey'), 'SyncKey');
  });

  test('other profiles get their own boxes and secrets', () {
    ProfileScope.activate('abc123');
    expect(ProfileScope.box(HiveDBProvider.intakeBoxName), 'p_abc123_IntakeBox');
    expect(ProfileScope.secret('SyncKey'), 'SyncKey.abc123');
  });

  test('every box the app opens is listed for deletion with its profile', () {
    expect(
      HiveDBProvider.profileBoxNames.toSet(),
      containsAll([
        HiveDBProvider.configBoxName,
        HiveDBProvider.intakeBoxName,
        HiveDBProvider.userBoxName,
        HiveDBProvider.mealPlanBoxName,
        HiveDBProvider.dietPlanBoxName,
        HiveDBProvider.syncStateBoxName,
        HiveDBProvider.userImageBytesBoxName,
      ]),
    );
    expect(HiveDBProvider.profileBoxNames.length, 18);
  });
}
