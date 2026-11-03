import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/onboarding/start_services_after_onboarding.dart';
import 'package:opennutritracker/features/reminders/domain/reminders_service.dart';

class _Sync implements SyncService {
  int starts = 0;

  @override
  Future<void> start() async => starts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _Reminders implements RemindersService {
  int starts = 0;

  @override
  Future<void> start() async => starts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  tearDown(() => GetIt.instance.reset());

  test('starts sync and reminders for a profile that had no data at launch', () {
    final sync = _Sync();
    final reminders = _Reminders();
    locator.registerSingleton<SyncService>(sync);
    locator.registerSingleton<RemindersService>(reminders);
    startServicesAfterOnboarding();
    expect(sync.starts, 1);
    expect(reminders.starts, 1);
  });

  test('does nothing when the services are not registered', () {
    expect(startServicesAfterOnboarding, returnsNormally);
  });
}
