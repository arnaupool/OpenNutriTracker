import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/accounts/account_ui.dart';
import 'package:opennutritracker/features/accounts/accounts_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Settings row for sync (C8). For an account it shows the account's email
/// and sync state and opens the account picker. For a local profile it asks
/// to sign in and links the profile to an account without losing its data.
class AccountSyncTile extends StatefulWidget {
  const AccountSyncTile({super.key});

  @override
  State<AccountSyncTile> createState() => _AccountSyncTileState();
}

class _AccountSyncTileState extends State<AccountSyncTile> {
  final _sessions = locator<AccountSessionService>();
  final _sync = locator<SyncService>();
  AccountLink? _link;
  AccountStatus? _status;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _sync.status.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _sync.status.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final id = ProfileScope.activeId;
    final link = await _sessions.link(id);
    AccountStatus? status;
    if (link != null) {
      try {
        status = await _sessions.status(id);
      } on Object {
        status = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _link = link;
      _status = status;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final link = _link;
    if (!_loaded || link == null) {
      return Semantics(
        identifier: 'settings-link-account',
        child: ListTile(
          leading: const Icon(Icons.sync_outlined),
          title: Text(s.syncTitle),
          subtitle: Text(s.accSyncSignInPrompt),
          onTap: !_loaded
              ? null
              : () async {
                  await linkProfileToAccount(context, ProfileScope.activeId);
                  await _load();
                },
        ),
      );
    }
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: _sync.status,
      builder: (context, status, _) {
        final state = switch (_status) {
          AccountStatus.signedOut => s.accSyncSignedOut,
          AccountStatus.needsRewrap => s.accSyncNeedsRewrap,
          _ => syncStatusText(context, status),
        };
        return Semantics(
          identifier: 'settings-account-sync',
          child: ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: Text(s.syncTitle),
            subtitle: Text(s.accSyncSubtitle(link.email, state)),
            onTap: () => pushAccountScreen<void>(context, const AccountsScreen()),
          ),
        );
      },
    );
  }
}

/// One line describing how the last sync went.
String syncStatusText(BuildContext context, SyncStatus status) {
  final s = S.of(context);
  switch (status.phase) {
    case SyncPhase.off:
      return s.syncStatusOff;
    case SyncPhase.syncing:
      return s.syncStatusSyncing;
    case SyncPhase.error:
      return s.syncStatusError;
    case SyncPhase.idle:
      final last = status.lastSync;
      if (last == null) return s.syncStatusWaiting;
      final locale = Localizations.localeOf(context).toLanguageTag();
      return s.syncStatusIdle(DateFormat.MMMd(locale).add_Hm().format(last.toLocal()));
  }
}
