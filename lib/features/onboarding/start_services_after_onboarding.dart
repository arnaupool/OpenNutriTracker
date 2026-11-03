import 'dart:async';

import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/reminders/domain/reminders_service.dart';

/// Starts what `_bootstrap` skips for a profile without user data: account
/// sync and reminders. Without it, a profile that signed in to a new account
/// and then went through onboarding would not sync until the next launch.
/// Both starts are idempotent.
void startServicesAfterOnboarding() {
  if (locator.isRegistered<SyncService>()) unawaited(locator<SyncService>().start());
  if (locator.isRegistered<RemindersService>()) unawaited(locator<RemindersService>().start());
}
