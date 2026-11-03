import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/accounts/account_ui.dart';
import 'package:opennutritracker/features/accounts/new_password_screen.dart';
import 'package:opennutritracker/features/accounts/recovery_key_entry_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum CodeEntryPurpose { signup, passwordReset }

/// Asks for the 6-digit code the server emailed (C7), with "resend".
///
/// - [CodeEntryScreen.signup] confirms the account and signs [profileId] in;
///   pops `true`.
/// - [CodeEntryScreen.passwordReset] collects the code and continues to the
///   new-password screen; pops the [PasswordResetResult].
class CodeEntryScreen extends StatefulWidget {
  final CodeEntryPurpose purpose;
  final String email;
  final String? profileId;
  final String? password;
  final AccountSessionService? sessions;
  final SyncService? sync;

  const CodeEntryScreen.signup({
    super.key,
    required String this.profileId,
    required this.email,
    required String this.password,
    this.sessions,
    this.sync,
  }) : purpose = CodeEntryPurpose.signup;

  const CodeEntryScreen.passwordReset({super.key, required this.email, this.sessions})
    : purpose = CodeEntryPurpose.passwordReset,
      profileId = null,
      password = null,
      sync = null;

  @override
  State<CodeEntryScreen> createState() => _CodeEntryScreenState();
}

class _CodeEntryScreenState extends State<CodeEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _info;

  AccountSessionService get _sessions => widget.sessions ?? locator<AccountSessionService>();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final code = _code.text.trim();
    try {
      if (widget.purpose == CodeEntryPurpose.signup) {
        final result = await _sessions.verifySignupCode(widget.profileId!, widget.email, code, widget.password!);
        if (!mounted) return;
        if (result == SignInResult.ready) {
          Navigator.of(context).pop(true);
          return;
        }
        final done = await pushAccountScreen<bool>(
          context,
          RecoveryKeyEntryScreen(
            profileId: widget.profileId!,
            email: widget.email,
            password: widget.password!,
            sessions: widget.sessions,
            sync: widget.sync,
          ),
        );
        if (done == true && mounted) Navigator.of(context).pop(true);
      } else {
        final result = await pushAccountScreen<PasswordResetResult>(
          context,
          NewPasswordScreen(email: widget.email, code: code, sessions: widget.sessions),
        );
        if (result != null && mounted) Navigator.of(context).pop(result);
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = accountErrorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      if (widget.purpose == CodeEntryPurpose.signup) {
        await _sessions.resendSignupCode(widget.email);
      } else {
        await _sessions.requestPasswordReset(widget.email);
      }
      if (mounted) setState(() => _info = S.of(context).accCodeResent);
    } on Object catch (e) {
      if (mounted) setState(() => _error = accountErrorText(context, e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return AccountFormScaffold(
      title: s.accCodeTitle,
      children: [
        Text(s.accCodeBody(widget.email), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                identifier: 'account-code',
                child: TextFormField(
                  controller: _code,
                  autofocus: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) => AccountValidators.code(context, v),
                  decoration: InputDecoration(labelText: s.accCodeLabel, border: const OutlineInputBorder()),
                ),
              ),
              const SizedBox(height: 8),
              AccountErrorText(_error),
              if (_info != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_info!, style: TextStyle(color: theme.colorScheme.primary)),
                ),
              AccountSubmitButton(
                identifier: 'account-code-submit',
                label: s.accCodeVerify,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          identifier: 'account-code-resend',
          child: TextButton(onPressed: _busy || _resending ? null : _resend, child: Text(s.accCodeResend)),
        ),
      ],
    );
  }
}
