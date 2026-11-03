import 'package:flutter/material.dart';
import 'package:opennutritracker/core/account/account_session_exceptions.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/accounts/account_ui.dart';
import 'package:opennutritracker/features/accounts/code_entry_screen.dart';
import 'package:opennutritracker/features/accounts/create_account_screen.dart';
import 'package:opennutritracker/features/accounts/forgot_password_screen.dart';
import 'package:opennutritracker/features/accounts/recovery_key_entry_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Signs [profileId] in to an existing account (C7). Pops `true` once the
/// profile holds the account. [email] pre-fills (and locks) the address when
/// the profile already belongs to an account.
class SignInScreen extends StatefulWidget {
  final String profileId;
  final String? email;
  final AccountSessionService? sessions;
  final SyncService? sync;

  const SignInScreen({super.key, required this.profileId, this.email, this.sessions, this.sync});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  AccountSessionService get _sessions => widget.sessions ?? locator<AccountSessionService>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
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
      final result = await _sessions.signIn(widget.profileId, email, password);
      if (!mounted) return;
      if (result == SignInResult.ready) {
        Navigator.of(context).pop(true);
        return;
      }
      final done = await pushAccountScreen<bool>(
        context,
        RecoveryKeyEntryScreen(
          profileId: widget.profileId,
          email: email,
          password: password,
          sessions: widget.sessions,
          sync: widget.sync,
        ),
      );
      if (done == true && mounted) Navigator.of(context).pop(true);
    } on EmailNotConfirmedException {
      if (!mounted) return;
      try {
        await _sessions.resendSignupCode(email);
      } on Object {
        // The code screen offers "resend" again.
      }
      if (!mounted) return;
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
    } on Object catch (e) {
      if (mounted) setState(() => _error = accountErrorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final result = await pushAccountScreen<PasswordResetResult>(
      context,
      ForgotPasswordScreen(initialEmail: _email.text.trim(), sessions: widget.sessions),
    );
    if (result == null || !mounted) return;
    final s = S.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(result == PasswordResetResult.rewrapped ? s.accResetDone : s.accResetNeedsRewrap)),
      );
  }

  Future<void> _create() async {
    final done = await pushAccountScreen<bool>(
      context,
      CreateAccountScreen(profileId: widget.profileId, sessions: widget.sessions, sync: widget.sync),
    );
    if (done == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AccountFormScaffold(
      title: s.accSignInTitle,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccountEmailField(controller: _email, enabled: widget.email == null, autofocus: widget.email == null),
              const SizedBox(height: 16),
              AccountPasswordField(
                identifier: 'account-password',
                controller: _password,
                label: s.accPasswordLabel,
                helperText: s.accPasswordHelp,
                validator: (v) => AccountValidators.passwordRequired(context, v),
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
              ),
              const SizedBox(height: 16),
              AccountErrorText(_error),
              AccountSubmitButton(
                identifier: 'account-sign-in-submit',
                label: s.accSignInAction,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          identifier: 'account-forgot-password',
          child: TextButton(onPressed: _busy ? null : _forgot, child: Text(s.accForgotPassword)),
        ),
        if (widget.email == null)
          Semantics(
            identifier: 'account-go-create',
            child: TextButton(onPressed: _busy ? null : _create, child: Text(s.accNoAccountYet)),
          ),
      ],
    );
  }
}
