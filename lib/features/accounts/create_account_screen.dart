import 'package:flutter/material.dart';
import 'package:opennutritracker/core/account/account_session_exceptions.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/accounts/account_ui.dart';
import 'package:opennutritracker/features/accounts/code_entry_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Creates an account for [profileId] (C7): email, password with
/// confirmation, then the emailed 6-digit code. Shows "Registro cerrado"
/// instead of the form when sign-ups are closed. Pops `true` when done.
class CreateAccountScreen extends StatefulWidget {
  final String profileId;
  final AccountSessionService? sessions;
  final SyncService? sync;

  const CreateAccountScreen({super.key, required this.profileId, this.sessions, this.sync});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _closed = false;
  String? _error;

  AccountSessionService get _sessions => widget.sessions ?? locator<AccountSessionService>();

  @override
  void initState() {
    super.initState();
    _checkOpen();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _checkOpen() async {
    try {
      final open = await _sessions.signupsOpen();
      if (mounted && !open) setState(() => _closed = true);
    } on Object {
      // The server decides at sign-up anyway.
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final email = _email.text.trim();
    final password = _password.text;
    try {
      final result = await _sessions.signUp(widget.profileId, email, password);
      if (!mounted) return;
      if (result == SignUpResult.signedIn) {
        Navigator.of(context).pop(true);
        return;
      }
      final done = await pushAccountScreen<bool>(
        context,
        CodeEntryScreen.signup(
          profileId: widget.profileId,
          email: email,
          password: password,
          sessions: widget.sessions,
          sync: widget.sync,
        ),
      );
      if (done == true && mounted) Navigator.of(context).pop(true);
    } on SignupsClosedException {
      if (mounted) setState(() => _closed = true);
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
    if (_closed) {
      return AccountFormScaffold(
        title: s.accCreateTitle,
        children: [
          Semantics(
            identifier: 'account-signups-closed',
            container: true,
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(s.accSignupsClosed),
                subtitle: Text(s.accSignupsClosedBody),
              ),
            ),
          ),
        ],
      );
    }
    return AccountFormScaffold(
      title: s.accCreateTitle,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccountEmailField(controller: _email, autofocus: true),
              const SizedBox(height: 16),
              AccountPasswordField(
                identifier: 'account-password',
                controller: _password,
                label: s.accPasswordLabel,
                helperText: s.accPasswordHelp,
                validator: (v) => AccountValidators.newPassword(context, v),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AccountPasswordField(
                identifier: 'account-password-confirm',
                controller: _confirm,
                label: s.accPasswordConfirmLabel,
                validator: (v) => v == _password.text ? null : s.accPasswordMismatch,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
              ),
              const SizedBox(height: 16),
              AccountErrorText(_error),
              AccountSubmitButton(
                identifier: 'account-create-submit',
                label: s.accCreateAction,
                busy: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              Text(
                s.accountsLinkBody,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
