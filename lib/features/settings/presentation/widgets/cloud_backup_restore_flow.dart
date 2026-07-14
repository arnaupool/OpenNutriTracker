import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/settings/domain/usecase/cloud_backup_usecase.dart';
import 'package:opennutritracker/features/settings/domain/usecase/cloud_restore_usecase.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

final _log = Logger('CloudBackupRestoreFlow');

/// Shows the destructive-action confirm dialog, and if accepted, runs
/// [CloudRestoreUsecase.restore] and refreshes every bloc a restore could
/// have touched (it may rewrite almost every box). Shared between
/// [SettingsScreen]'s "Restore from cloud" row and FA-16's onboarding
/// entry point ("Already have a cloud backup?") so both get the exact
/// same warning, error handling, and post-restore refresh — the two
/// callers only differ in what they do *after* this returns (Settings
/// stays put; onboarding navigates to the main route).
///
/// Returns whether the restore actually happened — `false` covers both
/// "user cancelled the confirm dialog" and "restore failed".
Future<bool> confirmAndRestoreCloudBackup(BuildContext context) async {
  final s = S.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.settingsCloudBackupRestoreConfirmTitle),
      content: Text(s.settingsCloudBackupRestoreConfirmContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(s.dialogCancelLabel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(s.settingsCloudBackupRestoreConfirmAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await locator<CloudRestoreUsecase>().restore();
    // Theme/locale/energy-unit Providers aren't re-synced here (that's a
    // startup-time concern, not a per-toggle one elsewhere either), so
    // the success message asks for a restart to catch those too.
    locator<SettingsBloc>().add(LoadSettingsEvent());
    locator<ProfileBloc>().add(LoadProfileEvent());
    locator<HomeBloc>().add(const LoadItemsEvent());
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
    messenger.showSnackBar(
      SnackBar(content: Text(s.settingsCloudBackupRestoreSuccessLabel)),
    );
    return true;
  } on CloudBackupNotPairedException {
    messenger.showSnackBar(
      SnackBar(content: Text(s.settingsCloudBackupNotPairedError)),
    );
    return false;
  } catch (e, st) {
    _log.warning('Cloud backup restore failed', e, st);
    messenger.showSnackBar(
      SnackBar(content: Text(s.settingsCloudBackupRestoreErrorLabel)),
    );
    return false;
  }
}
