import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/accounts/account_actions.dart';
import 'package:opennutritracker/features/accounts/account_ui.dart';
import 'package:opennutritracker/features/accounts/sign_in_screen.dart';
import 'package:opennutritracker/features/accounts/create_account_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/main.dart';

String profileDisplayName(BuildContext context, AppProfile profile) =>
    profile.account?.email ?? (profile.name.isEmpty ? S.of(context).profilesDefaultName : profile.name);

/// Settings / Profile row showing the active account or profile; opens
/// [AccountsScreen].
class ProfilesTile extends StatefulWidget {
  const ProfilesTile({super.key});

  @override
  State<ProfilesTile> createState() => _ProfilesTileState();
}

class _ProfilesTileState extends State<ProfilesTile> {
  AppProfile? _active;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await ProfileStore().all();
    if (!mounted) return;
    setState(() => _active = profiles.firstWhere((p) => p.id == ProfileScope.activeId, orElse: () => profiles.first));
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Semantics(
      identifier: 'settings-profiles',
      child: ListTile(
        leading: const Icon(Icons.people_outline),
        title: Text(S.of(context).accountsTitle),
        subtitle: active == null ? null : Text(S.of(context).profilesActiveValue(profileDisplayName(context, active))),
        onTap: () async {
          await pushAccountScreen<void>(context, const AccountsScreen());
          await _load();
        },
      ),
    );
  }
}

/// The account picker (C8): signed-in accounts and local profiles, instant
/// switching, add account, and per-account actions. Replaces the old profile
/// picker.
class AccountsScreen extends StatefulWidget {
  final AccountSessionService? sessions;
  final SyncService? sync;
  final AccountActions? actions;
  final ProfileStore? store;

  const AccountsScreen({super.key, this.sessions, this.sync, this.actions, this.store});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late final ProfileStore _store = widget.store ?? ProfileStore();
  late final AccountSessionService _sessions = widget.sessions ?? locator<AccountSessionService>();
  late final AccountActions _actions = widget.actions ?? AccountActions(sessions: _sessions, store: _store);
  List<AppProfile> _profiles = [];
  final Map<String, AccountStatus> _status = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await _store.all();
    if (mounted) setState(() => _profiles = profiles);
    for (final p in profiles) {
      if (p.account == null) continue;
      _sessions
          .status(p.id)
          .then((st) {
            if (mounted) setState(() => _status[p.id] = st);
          })
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.accountsTitle)),
      floatingActionButton: Semantics(
        identifier: 'accounts-add',
        child: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add_alt),
          label: Text(s.accountsAdd),
          onPressed: _add,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              s.accountsExplanation,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Semantics(
            identifier: 'accounts-list',
            container: true,
            child: Column(children: [for (final p in _profiles) _tile(context, p)]),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, AppProfile p) {
    final s = S.of(context);
    final active = p.id == ProfileScope.activeId;
    final status = _status[p.id];
    final String subtitle;
    if (p.account == null) {
      subtitle = active ? '${s.accountsActive} · ${s.accountsLocal}' : s.accountsLocal;
    } else if (status == AccountStatus.signedOut) {
      subtitle = s.accountsSignedOut;
    } else if (status == AccountStatus.needsRewrap) {
      subtitle = s.accountsNeedsRewrap;
    } else {
      subtitle = active ? s.accountsActive : '';
    }
    return Semantics(
      identifier: 'accounts-item',
      container: true,
      child: ListTile(
        leading: CircleAvatar(child: Text(profileDisplayName(context, p).characters.first.toUpperCase())),
        title: Text(profileDisplayName(context, p)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _onAction(action, p),
          itemBuilder: (_) => [
            if (p.account == null) ...[
              PopupMenuItem(value: 'rename', child: Text(s.profilesRename)),
              PopupMenuItem(value: 'link', child: Text(s.accountsLink)),
              if (!p.isDefault && !active) PopupMenuItem(value: 'delete', child: Text(s.profilesDelete)),
            ] else ...[
              PopupMenuItem(value: 'password', child: Text(s.accChangePassword)),
              PopupMenuItem(value: 'recovery', child: Text(s.accRecoveryKeyMenu)),
              PopupMenuItem(value: 'signout', child: Text(s.accSignOut)),
              PopupMenuItem(value: 'deleteAccount', child: Text(s.accDeleteAccount)),
            ],
          ],
        ),
        onTap: () => _open(p, status),
      ),
    );
  }

  Future<void> _open(AppProfile p, AccountStatus? status) async {
    if (p.id == ProfileScope.activeId) {
      if (status == AccountStatus.signedOut) await _signInAgain(p);
      return;
    }
    if (status == AccountStatus.signedOut) {
      await _signInAgain(p);
      return;
    }
    await AppRestarter.switchProfile(context, p.id);
  }

  Future<void> _signInAgain(AppProfile p) async {
    final ok = await pushAccountScreen<bool>(
      context,
      SignInScreen(profileId: p.id, email: p.account!.email, sessions: widget.sessions, sync: widget.sync),
    );
    if (ok != true || !mounted) return;
    if (p.id == ProfileScope.activeId) {
      unawaited(_afterLink());
      await _load();
    } else {
      await AppRestarter.switchProfile(context, p.id);
    }
  }

  Future<void> _afterLink() async {
    final sync = widget.sync ?? locator<SyncService>();
    await sync.syncNow();
  }

  Future<void> _onAction(String action, AppProfile p) async {
    switch (action) {
      case 'rename':
        await _rename(p);
      case 'link':
        await linkProfileToAccount(context, p.id, sessions: widget.sessions, sync: widget.sync);
        await _load();
      case 'delete':
        await _delete(p);
      case 'password':
        await _actions.changePassword(context, p);
      case 'recovery':
        await _actions.recoveryKey(context, p);
      case 'signout':
        await _actions.signOut(context, p);
        if (mounted) await _load();
      case 'deleteAccount':
        await _actions.deleteAccount(context, p);
        if (mounted) await _load();
    }
  }

  // Add

  Future<void> _add() async {
    final s = S.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              identifier: 'accounts-add-sign-in',
              child: ListTile(
                leading: const Icon(Icons.login),
                title: Text(s.accSignInTitle),
                onTap: () => Navigator.of(ctx).pop('signin'),
              ),
            ),
            Semantics(
              identifier: 'accounts-add-create',
              child: ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: Text(s.accCreateTitle),
                onTap: () => Navigator.of(ctx).pop('create'),
              ),
            ),
            Semantics(
              identifier: 'accounts-add-local',
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(s.accountsAddLocal),
                onTap: () => Navigator.of(ctx).pop('local'),
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'local') {
      final name = await _askName();
      if (name == null) return;
      final profile = await _store.add(name);
      await _load();
      if (mounted) await AppRestarter.switchProfile(context, profile.id);
      return;
    }
    final profile = await _store.add('');
    if (!mounted) return;
    final Widget screen = choice == 'signin'
        ? SignInScreen(profileId: profile.id, sessions: widget.sessions, sync: widget.sync)
        : CreateAccountScreen(profileId: profile.id, sessions: widget.sessions, sync: widget.sync);
    final ok = await pushAccountScreen<bool>(context, screen);
    if (ok == true && mounted) {
      await AppRestarter.switchProfile(context, profile.id);
    } else {
      await _store.remove(profile.id);
      if (mounted) await _load();
    }
  }

  // Local profiles

  Future<String?> _askName({String initial = ''}) {
    final controller = TextEditingController(text: initial);
    final s = S.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.profilesNameLabel),
        content: Semantics(
          identifier: 'profiles-name-field',
          child: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.dialogCancelLabel)),
          Semantics(
            identifier: 'profiles-name-ok',
            child: FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) Navigator.of(ctx).pop(name);
              },
              child: Text(s.dialogOKLabel),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(AppProfile p) async {
    final name = await _askName(initial: p.name);
    if (name == null) return;
    await _store.rename(p.id, name);
    await _load();
  }

  Future<void> _delete(AppProfile p) async {
    final s = S.of(context);
    final name = profileDisplayName(context, p);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.profilesDeleteTitle(name)),
        content: Text(s.profilesDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
          Semantics(
            identifier: 'profiles-delete-confirm',
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.profilesDelete),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.remove(p.id);
    await _load();
  }
}

/// Offers "Iniciar sesión" / "Crear cuenta" for an existing local profile and
/// keeps its data (the first sync uploads it). Returns true when linked.
Future<bool> linkProfileToAccount(
  BuildContext context,
  String profileId, {
  AccountSessionService? sessions,
  SyncService? sync,
}) async {
  final s = S.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(s.accountsLinkBody)),
          Semantics(
            identifier: 'link-account-sign-in',
            child: ListTile(
              leading: const Icon(Icons.login),
              title: Text(s.accSignInTitle),
              onTap: () => Navigator.of(ctx).pop('signin'),
            ),
          ),
          Semantics(
            identifier: 'link-account-create',
            child: ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: Text(s.accCreateTitle),
              onTap: () => Navigator.of(ctx).pop('create'),
            ),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;
  final Widget screen = choice == 'signin'
      ? SignInScreen(profileId: profileId, sessions: sessions, sync: sync)
      : CreateAccountScreen(profileId: profileId, sessions: sessions, sync: sync);
  final ok = await pushAccountScreen<bool>(context, screen);
  if (ok == true && profileId == ProfileScope.activeId) {
    final service = sync ?? locator<SyncService>();
    // Uploads the profile's data; reminders follow on their own sync.
    unawaited(service.syncNow());
  }
  return ok == true;
}
