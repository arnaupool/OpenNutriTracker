import 'package:flutter/material.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/accounts/account_ui.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Shown when the password signs in but the data key can not be opened
/// ([SignInResult.needsRecoveryKey], C7): paste the recovery key, or start
/// from scratch. Pops `true` once the profile holds the account.
class RecoveryKeyEntryScreen extends StatefulWidget {
  final String profileId;
  final String email;
  final String password;
  final AccountSessionService? sessions;
  final SyncService? sync;

  const RecoveryKeyEntryScreen({
    super.key,
    required this.profileId,
    required this.email,
    required this.password,
    this.sessions,
    this.sync,
  });

  @override
  State<RecoveryKeyEntryScreen> createState() => _RecoveryKeyEntryScreenState();
}

class _RecoveryKeyEntryScreenState extends State<RecoveryKeyEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _key = TextEditingController();
  bool _busy = false;
  String? _error;

  AccountSessionService get _sessions => widget.sessions ?? locator<AccountSessionService>();
  SyncService get _sync => widget.sync ?? locator<SyncService>();

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _sessions.recoverWithRecoveryKey(widget.profileId, widget.email, widget.password, _key.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) setState(() => _error = accountErrorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startFresh() async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.accStartFreshTitle),
        content: Text(s.accStartFreshBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
          Semantics(
            identifier: 'account-start-fresh-confirm',
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.accStartFreshConfirm),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _sync.startFresh(widget.profileId, widget.password, email: widget.email);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) setState(() => _error = accountErrorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return AccountFormScaffold(
      title: s.accRecoverTitle,
      children: [
        Text(s.accRecoverBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                identifier: 'account-recovery-key',
                child: TextFormField(
                  controller: _key,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  minLines: 2,
                  maxLines: 4,
                  validator: (v) => (v ?? '').trim().isEmpty ? s.accRecoverKeyRequired : null,
                  decoration: InputDecoration(labelText: s.accRecoverKeyLabel, border: const OutlineInputBorder()),
                ),
              ),
              const SizedBox(height: 16),
              AccountErrorText(_error),
              AccountSubmitButton(
                identifier: 'account-recover-submit',
                label: s.accRecoverAction,
                busy: _busy,
                onPressed: _recover,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Semantics(
          identifier: 'account-start-fresh',
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: _busy ? null : _startFresh,
            icon: const Icon(Icons.warning_amber_outlined),
            label: Text(s.accStartFreshAction),
          ),
        ),
      ],
    );
  }
}
