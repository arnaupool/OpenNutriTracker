import 'package:flutter/material.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/accounts/account_ui.dart';
import 'package:opennutritracker/features/accounts/code_entry_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// "Forgot password" (C7): asks for the email, sends the reset code and
/// continues to the code and new-password screens. Pops the
/// [PasswordResetResult] when the password was changed.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  final AccountSessionService? sessions;

  const ForgotPasswordScreen({super.key, this.initialEmail = '', this.sessions});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  String? _error;

  AccountSessionService get _sessions => widget.sessions ?? locator<AccountSessionService>();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final email = _email.text.trim();
    try {
      await _sessions.requestPasswordReset(email);
      if (!mounted) return;
      final result = await pushAccountScreen<PasswordResetResult>(
        context,
        CodeEntryScreen.passwordReset(email: email, sessions: widget.sessions),
      );
      if (result != null && mounted) Navigator.of(context).pop(result);
    } on Object catch (e) {
      if (mounted) setState(() => _error = accountErrorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AccountFormScaffold(
      title: s.accForgotTitle,
      children: [
        Text(s.accForgotBody, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccountEmailField(controller: _email, autofocus: true),
              const SizedBox(height: 16),
              AccountErrorText(_error),
              AccountSubmitButton(
                identifier: 'account-forgot-submit',
                label: s.accForgotSend,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
