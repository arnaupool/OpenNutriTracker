import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/responsive_layout.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/main.dart';

String profileDisplayName(BuildContext context, AppProfile profile) =>
    profile.name.isEmpty ? S.of(context).profilesDefaultName : profile.name;

/// Settings / Profile row showing the active profile; opens [ProfilesScreen].
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
        title: Text(S.of(context).profilesTitle),
        subtitle: active == null ? null : Text(S.of(context).profilesActiveValue(profileDisplayName(context, active))),
        onTap: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const DesktopRouteFrame(child: ProfilesScreen())));
          await _load();
        },
      ),
    );
  }
}

/// Several people on one device (or one desktop web app): each profile has
/// its own diary, goals, settings, photos and sync code. Switching reloads
/// the app on the other profile's data.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  final _store = ProfileStore();
  List<AppProfile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await _store.all();
    if (mounted) setState(() => _profiles = profiles);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.profilesTitle)),
      floatingActionButton: Semantics(
        identifier: 'profiles-add',
        child: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add_alt),
          label: Text(s.profilesAdd),
          onPressed: _add,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              s.profilesExplanation,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          for (final p in _profiles)
            Semantics(
              identifier: 'profiles-item',
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(profileDisplayName(context, p).characters.first.toUpperCase()),
                ),
                title: Text(profileDisplayName(context, p)),
                subtitle: p.id == ProfileScope.activeId ? Text(s.profilesActive) : null,
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => action == 'rename' ? _rename(p) : _delete(p),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(s.profilesRename)),
                    if (!p.isDefault && p.id != ProfileScope.activeId)
                      PopupMenuItem(value: 'delete', child: Text(s.profilesDelete)),
                  ],
                ),
                onTap: p.id == ProfileScope.activeId ? null : () => _switchTo(p),
              ),
            ),
        ],
      ),
    );
  }

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

  Future<void> _add() async {
    final name = await _askName();
    if (name == null) return;
    final profile = await _store.add(name);
    await _load();
    if (mounted) await _switchTo(profile);
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

  Future<void> _switchTo(AppProfile p) async {
    final s = S.of(context);
    final name = profileDisplayName(context, p);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.profilesSwitchTitle(name)),
        content: Text(s.profilesSwitchBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
          Semantics(
            identifier: 'profiles-switch-confirm',
            child: FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.profilesSwitchAction)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppRestarter.switchProfile(context, p.id);
  }
}
