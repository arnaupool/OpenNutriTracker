import 'package:flutter/material.dart';
import 'package:opennutritracker/core/account/account_session_exceptions.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/accounts/account_ui.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Last step of a password reset (C7): the new password, with the emailed
/// [code]. Pops the [PasswordResetResult]. A wrong code goes back to the
/// code screen.
class NewPasswordScreen extends StatefulWidget {
  final String email;
  final String code;
  final AccountSessionService? sessions;

  const NewPasswordScreen({super.key, required this.email, required this.code, this.sessions});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  AccountSessionService get _sessions => widget.sessions ?? locator<AccountSessionService>();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _sessions.completePasswordReset(widget.email, widget.code, _password.text);
      if (mounted) Navigator.of(context).pop(result);
    } on InvalidCodeException {
      // The code is single use: go back to ask for another one.
      if (!mounted) return;
      Navigator.of(context).pop();
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
      title: s.accNewPasswordTitle,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccountPasswordField(
                identifier: 'account-new-password',
                controller: _password,
                label: s.accNewPasswordTitle,
                helperText: s.accPasswordHelp,
                autofocus: true,
                validator: (v) => AccountValidators.newPassword(context, v),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AccountPasswordField(
                identifier: 'account-new-password-confirm',
                controller: _confirm,
                label: s.accPasswordConfirmLabel,
                validator: (v) => v == _password.text ? null : s.accPasswordMismatch,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
              ),
              const SizedBox(height: 16),
              AccountErrorText(_error),
              AccountSubmitButton(
                identifier: 'account-new-password-submit',
                label: s.accNewPasswordAction,
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
