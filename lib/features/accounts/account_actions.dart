import 'package:flutter/material.dart';
import 'package:opennutritracker/core/account/account_admin_api.dart';
import 'package:opennutritracker/core/account/account_key_service.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/accounts/account_ui.dart';
import 'package:opennutritracker/features/reminders/domain/reminders_service.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/main.dart';

/// Per-account operations of the account picker (C8): change password,
/// recovery key, sign out, delete account. Dependencies default to the
/// locator; tests pass fakes.
class AccountActions {
  final AccountSessionService sessions;
  final AccountKeyService keys;
  final SyncService sync;
  final AccountAdminApi admin;
  final ProfileStore store;

  /// Tells the reminders backend a device left its account (sign-out).
  final Future<void> Function() detachReminders;

  /// Reloads the app on another profile, then runs [afterSwitch] with the
  /// old profile closed. Replaceable in tests.
  final Future<void> Function(BuildContext context, String profileId, {Future<void> Function()? afterSwitch})
  switchProfile;

  AccountActions({
    AccountSessionService? sessions,
    AccountKeyService? keys,
    SyncService? sync,
    AccountAdminApi? admin,
    ProfileStore? store,
    Future<void> Function()? detachReminders,
    Future<void> Function(BuildContext, String, {Future<void> Function()? afterSwitch})? switchProfile,
  }) : sessions = sessions ?? locator<AccountSessionService>(),
       keys = keys ?? locator<AccountKeyService>(),
       sync = sync ?? locator<SyncService>(),
       admin = admin ?? locator<AccountAdminApi>(),
       store = store ?? ProfileStore(),
       detachReminders = detachReminders ?? (() => locator<RemindersService>().detachAccount()),
       switchProfile =
           switchProfile ??
           ((context, id, {afterSwitch}) => AppRestarter.switchProfile(context, id, afterSwitch: afterSwitch));

  void _snack(BuildContext context, String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // Change password

  Future<void> changePassword(BuildContext context, AppProfile profile) async {
    final s = S.of(context);
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(s.accChangePassword),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AccountPasswordField(
                      identifier: 'account-current-password',
                      controller: current,
                      label: s.accCurrentPassword,
                      validator: (v) => AccountValidators.passwordRequired(ctx, v),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    AccountPasswordField(
                      identifier: 'account-new-password',
                      controller: next,
                      label: s.accNewPasswordTitle,
                      helperText: s.accPasswordHelp,
                      validator: (v) => AccountValidators.newPassword(ctx, v),
                    ),
                    const SizedBox(height: 12),
                    AccountPasswordField(
                      identifier: 'account-new-password-confirm',
                      controller: confirm,
                      label: s.accPasswordConfirmLabel,
                      validator: (v) => v == next.text ? null : s.accPasswordMismatch,
                    ),
                    if (error != null) ...[const SizedBox(height: 12), AccountErrorText(error)],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
              Semantics(
                identifier: 'account-change-password-submit',
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await sessions.changePassword(profile.id, current.text, next.text);
                            if (ctx.mounted) Navigator.of(ctx).pop(true);
                          } on Object catch (e) {
                            if (ctx.mounted) {
                              setState(() {
                                busy = false;
                                error = accountErrorText(ctx, e);
                              });
                            }
                          }
                        },
                  child: Text(s.accChangePassword),
                ),
              ),
            ],
          ),
        );
      },
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (ok == true && context.mounted) _snack(context, s.accChangePasswordDone);
  }

  // Recovery key

  Future<void> recoveryKey(BuildContext context, AppProfile profile) async {
    final s = S.of(context);
    String? shown;
    String? error;
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(s.accRecoveryKeyMenu),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shown == null)
                Text(s.accRecoveryKeyBody)
              else ...[
                Text(s.accRecoveryKeyShown),
                const SizedBox(height: 12),
                Semantics(identifier: 'account-recovery-key-value', child: SelectableText(shown!)),
              ],
              if (error != null) ...[const SizedBox(height: 12), AccountErrorText(error)],
            ],
          ),
          actions: [
            if (shown != null)
              Semantics(
                identifier: 'account-recovery-key-copy',
                child: TextButton(onPressed: () => copyToClipboard(ctx, shown!), child: Text(s.accCopy)),
              ),
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.accClose)),
            if (shown == null)
              Semantics(
                identifier: 'account-recovery-key-generate',
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            final key = await sessions.dataKey(profile.id);
                            if (key == null) throw StateError('no data key');
                            final token = await sessions.accessToken(profile.id);
                            final generated = await keys.setRecoveryKey(key, token);
                            if (ctx.mounted) {
                              setState(() {
                                shown = generated;
                                busy = false;
                              });
                            }
                          } on Object catch (e) {
                            if (ctx.mounted) {
                              setState(() {
                                busy = false;
                                error = accountErrorText(ctx, e);
                              });
                            }
                          }
                        },
                  child: Text(s.accRecoveryKeyGenerate),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Sign out

  /// Syncs, warns when something could not be uploaded, signs out and
  /// removes the profile. Only for the active profile (the pending-changes
  /// check reads its boxes).
  Future<void> signOut(BuildContext context, AppProfile profile) async {
    final s = S.of(context);
    if (profile.id != ProfileScope.activeId) {
      _snack(context, s.accountsSwitchFirst);
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.accSignOut),
        content: Text(s.accSignOutBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
          Semantics(
            identifier: 'account-sign-out-confirm',
            child: FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.accSignOut)),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final synced = await _syncWithProgress(context, profile.id);
    if (!context.mounted) return;
    if (!synced) {
      final anyway = await confirmSignOutWithPending(context);
      if (anyway != true || !context.mounted) return;
    }
    await detachReminders();
    await sessions.signOut(profile.id);
    if (!context.mounted) return;
    await _removeOrUnlink(context, profile);
  }

  Future<bool> _syncWithProgress(BuildContext context, String profileId) async {
    final s = S.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 16),
              Expanded(child: Text(s.accSignOutSyncing)),
            ],
          ),
        ),
      ),
    );
    var ok = false;
    try {
      ok = await sync.syncBeforeSignOut(profileId);
    } on Object {
      ok = false;
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return ok;
  }

  /// Explicit confirmation when changes could not be uploaded.
  static Future<bool?> confirmSignOutWithPending(BuildContext context) {
    final s = S.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.accSignOutPendingTitle),
        content: Text(s.accSignOutPendingBody),
        actions: [
          Semantics(
            identifier: 'account-sign-out-cancel',
            child: TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
          ),
          Semantics(
            identifier: 'account-sign-out-anyway',
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.accSignOutAnyway),
            ),
          ),
        ],
      ),
    );
  }

  /// Decision 10: the account and its data leave the device. The default
  /// profile can not be removed, so it is wiped and stays as an empty local
  /// profile (first-run choice); any other profile is removed after
  /// switching away.
  Future<void> _removeOrUnlink(BuildContext context, AppProfile profile) async {
    if (profile.isDefault) {
      await switchProfile(context, AppProfile.defaultId, afterSwitch: store.wipeDefault);
      return;
    }
    await switchProfile(context, AppProfile.defaultId, afterSwitch: () => store.remove(profile.id));
  }

  // Delete account

  Future<void> deleteAccount(BuildContext context, AppProfile profile) async {
    final s = S.of(context);
    final email = profile.account!.email;
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.accDeleteAccount),
        content: Text(s.accDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
          Semantics(
            identifier: 'account-delete-continue',
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.accDeleteAccount),
            ),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final typed = TextEditingController();
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(s.accDeleteAccount),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.accDeleteTypeEmail(email)),
              const SizedBox(height: 12),
              Semantics(
                identifier: 'account-delete-email',
                child: TextField(
                  controller: typed,
                  autofocus: true,
                  autocorrect: false,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: s.accDeleteConfirmField, border: const OutlineInputBorder()),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
            Semantics(
              identifier: 'account-delete-confirm',
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
                onPressed: typed.text.trim().toLowerCase() == email.toLowerCase()
                    ? () => Navigator.of(ctx).pop(true)
                    : null,
                child: Text(s.accDeleteAccount),
              ),
            ),
          ],
        ),
      ),
    );
    typed.dispose();
    if (second != true || !context.mounted) return;
    try {
      await admin.deleteAccount(await sessions.accessToken(profile.id));
    } on Object {
      if (context.mounted) _snack(context, s.accDeleteFailed);
      return;
    }
    await sessions.signOut(profile.id);
    if (!context.mounted) return;
    await _removeOrUnlink(context, profile);
  }
}
