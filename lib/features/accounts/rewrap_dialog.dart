import 'package:flutter/material.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/accounts/account_ui.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Asks for the current password and wraps the data key again
/// ([AccountSessionService.rewrapAfterReset]). True when it worked.
Future<bool> showRewrapDialog(BuildContext context, String profileId, {AccountSessionService? sessions}) async {
  final s = S.of(context);
  final service = sessions ?? locator<AccountSessionService>();
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      String? error;
      bool busy = false;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(s.accRewrapTitle),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.accRewrapBanner),
                const SizedBox(height: 12),
                AccountPasswordField(
                  identifier: 'account-rewrap-password',
                  controller: controller,
                  label: s.accPasswordLabel,
                  autofocus: true,
                  validator: (v) => AccountValidators.passwordRequired(ctx, v),
                ),
                if (error != null) ...[const SizedBox(height: 12), AccountErrorText(error)],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
            Semantics(
              identifier: 'account-rewrap-submit',
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
                          await service.rewrapAfterReset(profileId, controller.text);
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
                child: Text(s.accRewrapAction),
              ),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s.accRewrapDone)));
  }
  return ok == true;
}

/// Banner for the active profile when its password was reset elsewhere and
/// its data key needs the new password ([AccountStatus.needsRewrap]).
/// Renders nothing otherwise.
class AccountRewrapBanner extends StatefulWidget {
  final AccountSessionService? sessions;
  final SyncService? sync;
  final String? profileId;

  const AccountRewrapBanner({super.key, this.sessions, this.sync, this.profileId});

  @override
  State<AccountRewrapBanner> createState() => _AccountRewrapBannerState();
}

class _AccountRewrapBannerState extends State<AccountRewrapBanner> {
  bool _needed = false;

  String get _profileId => widget.profileId ?? ProfileScope.activeId;
  AccountSessionService get _sessions => widget.sessions ?? locator<AccountSessionService>();

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final status = await _sessions.status(_profileId);
      if (mounted) setState(() => _needed = status == AccountStatus.needsRewrap);
    } on Object {
      // Offline: the status check runs again next time.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_needed) return const SizedBox.shrink();
    final s = S.of(context);
    return Semantics(
      identifier: 'account-rewrap-banner',
      container: true,
      child: MaterialBanner(
        leading: const Icon(Icons.lock_reset_outlined),
        content: Text(s.accRewrapBanner),
        actions: [
          Semantics(
            identifier: 'account-rewrap-open',
            child: TextButton(
              onPressed: () async {
                final done = await showRewrapDialog(context, _profileId, sessions: widget.sessions);
                if (!done || !mounted) return;
                setState(() => _needed = false);
                final sync = widget.sync ?? locator<SyncService>();
                await sync.syncNow();
              },
              child: Text(s.accRewrapAction),
            ),
          ),
        ],
      ),
    );
  }
}
