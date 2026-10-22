import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/off_contribution/data/off_account_data_source.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

const _offSignUpUrl = 'https://world.openfoodfacts.org/cgi/user.pl';

/// Signs in with (or out of) the user's own Open Food Facts account.
/// Returns true when an account is saved.
Future<bool> showOffAccountDialog(BuildContext context) async {
  final account = locator<OffAccountDataSource>();
  final current = await account.read();
  if (!context.mounted) return false;
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _OffAccountDialog(account: account, current: current),
  );
  return saved ?? current != null;
}

class _OffAccountDialog extends StatefulWidget {
  final OffAccountDataSource account;
  final OffCredentials? current;

  const _OffAccountDialog({required this.account, required this.current});

  @override
  State<_OffAccountDialog> createState() => _OffAccountDialogState();
}

class _OffAccountDialogState extends State<_OffAccountDialog> {
  late final _userController = TextEditingController(text: widget.current?.userId);
  final _passwordController = TextEditingController();
  bool _obscure = true;

  bool get _canSave =>
      _userController.text.trim().isNotEmpty &&
      (_passwordController.text.isNotEmpty || widget.current != null);

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await widget.account.save(OffCredentials(
      userId: _userController.text.trim(),
      // An empty field keeps the saved password when only the name changes.
      password: _passwordController.text.isNotEmpty ? _passwordController.text : widget.current!.password,
    ));
    navigator.pop(true);
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await widget.account.clear();
    navigator.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.offAccountLabel),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.offAccountExplanation, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Semantics(
              identifier: 'off-account-username',
              child: TextField(
                controller: _userController,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: s.offAccountUsernameLabel),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              identifier: 'off-account-password',
              child: TextField(
                controller: _passwordController,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: s.offAccountPasswordLabel,
                  hintText: widget.current != null ? '••••••••' : null,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(_offSignUpUrl), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(s.offAccountCreateLink),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(onPressed: _signOut, child: Text(s.offAccountSignOut)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(widget.current != null),
          child: Text(s.dialogCancelLabel),
        ),
        Semantics(
          identifier: 'off-account-save',
          child: FilledButton(onPressed: _canSave ? _save : null, child: Text(s.buttonSaveLabel)),
        ),
      ],
    );
  }
}

/// Settings entry for the Open Food Facts account.
class OffAccountTile extends StatefulWidget {
  const OffAccountTile({super.key});

  @override
  State<OffAccountTile> createState() => _OffAccountTileState();
}

class _OffAccountTileState extends State<OffAccountTile> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final credentials = await locator<OffAccountDataSource>().read();
    if (mounted) setState(() => _userId = credentials?.userId);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Semantics(
      identifier: 'settings-off-account',
      child: ListTile(
        leading: const Icon(Icons.cloud_upload_outlined),
        title: Text(s.offAccountLabel),
        subtitle: Text(_userId == null ? s.offAccountSignedOutSubtitle : '${s.offAccountSignedInAs} $_userId'),
        onTap: () async {
          await showOffAccountDialog(context);
          await _refresh();
        },
      ),
    );
  }
}
