import 'package:flutter/material.dart';
import 'package:opennutritracker/core/account/account_admin_api.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Administration section of the settings (C9). Visible only when the
/// server says the active account is an administrator (`rpc/is_admin`);
/// holds the "Registro abierto" switch, which writes
/// `app_settings.signups_open` with the account's own token.
class AdminPanel extends StatefulWidget {
  final AccountSessionService? sessions;
  final AccountAdminApi? api;

  /// The profile to check; the active one by default.
  final String? profileId;

  const AdminPanel({super.key, this.sessions, this.api, this.profileId});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  bool _admin = false;
  bool _open = true;
  bool _saving = false;
  String? _error;

  AccountSessionService get _sessions => widget.sessions ?? locator<AccountSessionService>();
  AccountAdminApi get _api => widget.api ?? locator<AccountAdminApi>();
  String get _profileId => widget.profileId ?? ProfileScope.activeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (await _sessions.link(_profileId) == null) return;
      final token = await _sessions.accessToken(_profileId);
      if (!await _api.isAdmin(token)) return;
      bool open = true;
      String? error;
      try {
        open = await _api.signupsOpen(token);
      } on Object {
        error = '';
      }
      if (!mounted) return;
      setState(() {
        _admin = true;
        _open = open;
        _error = error;
      });
    } on Object {
      // Not signed in, offline or not an admin: nothing to show.
    }
  }

  Future<void> _set(bool value) async {
    final previous = _open;
    setState(() {
      _open = value;
      _saving = true;
      _error = null;
    });
    try {
      await _api.setSignupsOpen(await _sessions.accessToken(_profileId), value);
      if (mounted) setState(() => _saving = false);
    } on Object {
      if (mounted) {
        setState(() {
          _open = previous;
          _saving = false;
          _error = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_admin) return const SizedBox.shrink();
    final s = S.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(s.adminTitle, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ),
        ),
        Semantics(
          identifier: 'admin-signups-open',
          child: SwitchListTile(
            secondary: const Icon(Icons.how_to_reg_outlined),
            title: Text(s.adminSignupsOpen),
            subtitle: Text(s.adminSignupsHelp),
            value: _open,
            onChanged: _saving ? null : _set,
          ),
        ),
        if (_error != null)
          Semantics(
            identifier: 'admin-error',
            liveRegion: true,
            child: ListTile(
              leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
              title: Text(s.adminSaveFailed, style: TextStyle(color: theme.colorScheme.error)),
            ),
          ),
      ],
    );
  }
}
