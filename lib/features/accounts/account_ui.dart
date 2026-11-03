import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/account/account_key_exceptions.dart';
import 'package:opennutritracker/core/account/account_session_exceptions.dart';
import 'package:opennutritracker/core/presentation/widgets/responsive_layout.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Accounts need at least this many characters in the password.
const int accountMinPasswordLength = 10;

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Validators shared by the account forms; they return the message to show.
class AccountValidators {
  static String? email(BuildContext context, String? value) =>
      _emailPattern.hasMatch((value ?? '').trim()) ? null : S.of(context).accEmailInvalid;

  static String? passwordRequired(BuildContext context, String? value) =>
      (value ?? '').isEmpty ? S.of(context).accPasswordRequired : null;

  static String? newPassword(BuildContext context, String? value) =>
      (value ?? '').length < accountMinPasswordLength ? S.of(context).accPasswordTooShort : null;

  static String? code(BuildContext context, String? value) =>
      RegExp(r'^\d{6}$').hasMatch((value ?? '').trim()) ? null : S.of(context).accCodeInvalid;
}

/// The text to show for a failed account operation.
String accountErrorText(BuildContext context, Object error) {
  final s = S.of(context);
  return switch (error) {
    InvalidCredentialsException() => s.accErrorInvalidCredentials,
    AuthRateLimitedException() => s.accErrorRateLimited,
    InvalidCodeException() => s.accErrorInvalidCode,
    AccountNetworkException() => s.accErrorNetwork,
    SessionExpiredException() || NotSignedInException() => s.accErrorSessionExpired,
    AccountAlreadyOnDeviceException() => s.accErrorAlreadyOnDevice,
    ProfileHasOtherAccountException(:final email) => s.accErrorOtherAccount(email),
    WrongRecoveryKeyException() => s.accErrorWrongRecoveryKey,
    InvalidRecoveryKeyFormatException() => s.accErrorRecoveryKeyFormat,
    NoRecoveryKeyException() => s.accErrorNoRecoveryKey,
    WrongPasswordException() => s.accErrorInvalidCredentials,
    _ => s.accErrorGeneric,
  };
}

/// Pushes [screen] framed like the other settings routes.
Future<T?> pushAccountScreen<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => DesktopRouteFrame(child: screen)));

/// Scaffold with a scrolling, width-limited column for the account forms.
class AccountFormScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const AccountFormScaffold({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: children),
      ),
    );
  }
}

/// Password field with a show/hide toggle.
class AccountPasswordField extends StatefulWidget {
  final String identifier;
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final String? helperText;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  const AccountPasswordField({
    super.key,
    required this.identifier,
    required this.controller,
    required this.label,
    this.validator,
    this.helperText,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<AccountPasswordField> createState() => _AccountPasswordFieldState();
}

class _AccountPasswordFieldState extends State<AccountPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: widget.identifier,
      child: TextFormField(
        controller: widget.controller,
        obscureText: _hidden,
        autofocus: widget.autofocus,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helperText,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
          suffixIcon: Semantics(
            identifier: '${widget.identifier}-toggle',
            child: IconButton(
              icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          ),
        ),
      ),
    );
  }
}

/// Email field.
class AccountEmailField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;

  const AccountEmailField({super.key, required this.controller, this.enabled = true, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'account-email',
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        autocorrect: false,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        validator: (v) => AccountValidators.email(context, v),
        decoration: InputDecoration(labelText: S.of(context).accEmailLabel, border: const OutlineInputBorder()),
      ),
    );
  }
}

/// Primary button that shows a spinner while [busy].
class AccountSubmitButton extends StatelessWidget {
  final String identifier;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const AccountSubmitButton({
    super.key,
    required this.identifier,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
      ),
    );
  }
}

/// Error line under a form.
class AccountErrorText extends StatelessWidget {
  final String? message;

  const AccountErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        identifier: 'account-error',
        liveRegion: true,
        child: Text(message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }
}

/// Copies [text] to the clipboard and tells the user.
Future<void> copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(S.of(context).accCopied)));
}
