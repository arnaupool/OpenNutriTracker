import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';
import 'package:opennutritracker/features/reminders/data/reminder_platform.dart';
import 'package:opennutritracker/features/reminders/data/reminders_api.dart';
import 'package:opennutritracker/features/reminders/domain/reminder_rules.dart';
import 'package:opennutritracker/features/reminders/domain/reminders_service.dart';
import 'package:opennutritracker/features/reminders/presentation/reminder_edit_sheet.dart';
import 'package:opennutritracker/features/reminders/presentation/reminder_format.dart';
import 'package:opennutritracker/features/reminders/presentation/reminder_time_field.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings -> Reminders: the list (switch, edit sheet), quiet hours, the
/// state of each channel and a note on what the server stores.
class RemindersScreen extends StatefulWidget {
  final RemindersService? service;

  /// Opens a URL outside the app; replaceable in tests.
  final Future<bool> Function(Uri url)? launcher;

  /// How often to ask the server whether the Telegram link is done.
  final Duration telegramPollInterval;

  const RemindersScreen({
    super.key,
    this.service,
    this.launcher,
    this.telegramPollInterval = const Duration(seconds: 3),
  });

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late final RemindersService _service = widget.service ?? locator<RemindersService>();
  bool _ready = false;
  bool _linkingTelegram = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _linkingTelegram = false;
    super.dispose();
  }

  Future<void> _prepare() async {
    await _service.ensureDefaults();
    if (!mounted) return;
    setState(() => _ready = true);
    // Learns which channels the server already has for this device.
    unawaited(_service.refreshStatus());
  }

  ReminderPlatform get _platform => _service.platform;

  bool get _pushAvailable => _platform.pushSupport == PushSupport.supported;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // -------------------------------------------------------------- reminders

  /// Runs inside a tap: turns web push on when the reminder needs it.
  void _maybeEnablePush(ReminderDBO candidate) {
    if (_service.needsPushSetup(candidate)) unawaited(_enablePush());
  }

  Future<void> _enablePush() async {
    final result = await _service.enablePush();
    if (!mounted) return;
    final s = S.of(context);
    switch (result) {
      case PushSetupResult.active:
      case PushSetupResult.unsupported:
        break;
      case PushSetupResult.denied:
        _snack(s.remindersPushDenied);
      case PushSetupResult.failed:
        _snack(s.remindersPushFailed);
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggle(ReminderDBO r, bool enabled) async {
    _maybeEnablePush(r.copyWith(enabled: enabled));
    await _service.setEnabled(r.id, enabled);
  }

  Future<void> _edit(ReminderDBO reminder) async {
    final result = await showModalBottomSheet<ReminderSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          ReminderEditSheet(reminder: reminder, pushAvailable: _pushAvailable, onBeforeSave: _maybeEnablePush),
    );
    if (result == null || !mounted) return;
    final edited = result.reminder;
    switch (result.action) {
      case ReminderSheetAction.save:
        await _service.update(edited);
      case ReminderSheetAction.test:
        await _service.update(edited);
        await _sendTest(edited);
      case ReminderSheetAction.duplicate:
        await _service.update(edited);
        await _duplicate(edited);
      case ReminderSheetAction.delete:
        await _confirmDelete(edited);
    }
  }

  Future<void> _sendTest(ReminderDBO r) async {
    final s = S.of(context);
    try {
      final channel = await _service.sendTest(r.id);
      if (mounted) _snack(s.remindersTestSent(ReminderFormat.channelByName(context, channel)));
    } catch (_) {
      _snack(s.remindersTestFailed);
    }
  }

  Future<void> _duplicate(ReminderDBO r) async {
    final s = S.of(context);
    final copy = await _service.duplicate(r.id, s.remindersCopyOf(ReminderFormat.name(context, r)));
    if (copy == null) _snack(s.remindersLimitReached);
  }

  Future<void> _confirmDelete(ReminderDBO r) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(s.remindersDeleteQuestion(ReminderFormat.name(context, r))),
        actions: [
          Semantics(
            identifier: 'reminder-delete-cancel',
            child: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.dialogCancelLabel)),
          ),
          Semantics(
            identifier: 'reminder-delete-confirm',
            child: TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s.dialogDeleteLabel)),
          ),
        ],
      ),
    );
    if (ok == true) await _service.delete(r.id);
  }

  Future<void> _add() async {
    final s = S.of(context);
    if (!ReminderRules.canAdd(_service.reminders.length)) {
      _snack(s.remindersLimitReached);
      return;
    }
    final name = await _askText(
      title: s.remindersNew,
      label: s.remindersFieldName,
      maxLength: ReminderRules.maxLabelLength,
      confirm: s.dialogOKLabel,
    );
    if (name == null || !mounted) return;
    final created = await _service.addCustom(name);
    if (created != null && mounted) await _edit(created);
  }

  /// A one-field dialog; null when cancelled.
  Future<String?> _askText({
    required String title,
    required String label,
    int? maxLength,
    String? initial,
    TextInputType? keyboard,
    required String confirm,
    bool Function(String)? validator,
  }) {
    final controller = TextEditingController(text: initial);
    final s = S.of(context);
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final ok = validator?.call(controller.text) ?? ReminderRules.isValidLabel(controller.text);
          return AlertDialog(
            title: Text(title),
            content: Semantics(
              identifier: 'reminders-dialog-field',
              child: TextField(
                controller: controller,
                autofocus: true,
                maxLength: maxLength,
                keyboardType: keyboard,
                decoration: InputDecoration(labelText: label),
                onChanged: (_) => setState(() {}),
              ),
            ),
            actions: [
              Semantics(
                identifier: 'reminders-dialog-cancel',
                child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.dialogCancelLabel)),
              ),
              Semantics(
                identifier: 'reminders-dialog-confirm',
                child: TextButton(
                  onPressed: ok ? () => Navigator.of(context).pop(controller.text.trim()) : null,
                  child: Text(confirm),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ quiet hours

  Future<void> _setQuiet(bool on) async {
    final s = _service.settings;
    await _service.saveSettings(
      on
          ? s.copyWith(quietStart: ReminderSettingsDBO.defaultQuietStart, quietEnd: ReminderSettingsDBO.defaultQuietEnd)
          : s.copyWith(clearQuiet: true),
    );
  }

  // --------------------------------------------------------------- channels

  Future<void> _linkTelegram() async {
    final s = S.of(context);
    setState(() => _linkingTelegram = true);
    final url = await _service.requestTelegramLink();
    if (!mounted) return;
    if (url == null) {
      setState(() => _linkingTelegram = false);
      _snack(s.remindersSyncFailed);
      return;
    }
    final uri = Uri.parse(url);
    var opened = false;
    try {
      opened = await (widget.launcher ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
    } catch (_) {
      opened = false;
    }
    // Browsers may refuse to open a window after the network round trip: offer a fresh tap.
    if (!opened && mounted) await _offerTelegramLink(uri);
    if (!mounted) return;
    final linked = await _service.waitForTelegram(
      interval: widget.telegramPollInterval,
      cancelled: () => !mounted || !_linkingTelegram,
    );
    if (!mounted) return;
    setState(() => _linkingTelegram = false);
    _snack(linked ? s.remindersTelegramDone : s.remindersTelegramTimeout);
  }

  Future<void> _offerTelegramLink(Uri uri) async {
    final s = S.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(s.remindersTelegramOpenBody),
        actions: [
          Semantics(
            identifier: 'reminders-telegram-open',
            child: TextButton(
              onPressed: () async {
                await (widget.launcher ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(s.remindersTelegramOpen),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyEmail() async {
    final s = S.of(context);
    final email = await _askText(
      title: s.remindersChannelEmail,
      label: s.remindersEmailAddress,
      initial: _service.settings.email,
      keyboard: TextInputType.emailAddress,
      confirm: s.remindersEmailSendCode,
      validator: (v) => RegExp(r'^[^@\s]{1,64}@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()),
    );
    if (email == null || !mounted) return;
    try {
      await _service.requestEmailCode(email);
    } on RemindersApiException catch (e) {
      _snack(_emailError(e.code));
      return;
    } catch (_) {
      _snack(s.remindersError);
      return;
    }
    if (!mounted) return;
    _snack(s.remindersEmailCodeSent(email));
    final code = await _askText(
      title: s.remindersEmailCode,
      label: s.remindersEmailCode,
      maxLength: 6,
      keyboard: TextInputType.number,
      confirm: s.remindersEmailConfirm,
      validator: (v) => RegExp(r'^\d{6}$').hasMatch(v.trim()),
    );
    if (code == null || !mounted) return;
    try {
      await _service.confirmEmail(code);
      _snack(s.remindersEmailDone);
    } on RemindersApiException catch (e) {
      _snack(_emailError(e.code));
    } catch (_) {
      _snack(s.remindersError);
    }
  }

  String _emailError(String code) {
    final s = S.of(context);
    switch (code) {
      case 'bad_email':
        return s.remindersEmailErrorBad;
      case 'too_soon':
        return s.remindersEmailErrorTooSoon;
      case 'wrong_code':
        return s.remindersEmailErrorWrongCode;
      case 'expired':
        return s.remindersEmailErrorExpired;
      case 'too_many_attempts':
        return s.remindersEmailErrorTooMany;
      default:
        return s.remindersError;
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.remindersTitle),
        actions: [
          Semantics(
            identifier: 'reminders-add',
            child: IconButton(tooltip: s.remindersAdd, icon: const Icon(Icons.add), onPressed: _ready ? _add : null),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: Listenable.merge([_service.data.listenable, _service.status, _service.pushActive]),
              builder: (context, _) => _body(context),
            ),
    );
  }

  Widget _body(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final reminders = _service.reminders;
    final settings = _service.settings;
    return ListView(
      children: [
        if (_service.status.value == ReminderSyncStatus.error)
          ListTile(
            leading: Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
            title: Text(s.remindersSyncFailed),
          ),
        Semantics(
          identifier: 'reminders-list',
          container: true,
          child: Column(children: [for (final r in reminders) _tile(context, r)]),
        ),
        const Divider(),
        _sectionTitle(context, s.remindersQuietTitle),
        Semantics(
          identifier: 'reminders-quiet-switch',
          child: SwitchListTile(
            title: Text(s.remindersQuietTitle),
            value: settings.hasQuietHours,
            onChanged: _setQuiet,
          ),
        ),
        if (settings.hasQuietHours)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ReminderTimeField(
                  identifier: 'reminders-quiet-start',
                  label: s.remindersQuietFrom,
                  value: settings.quietStart!,
                  onChanged: (v) => _service.saveSettings(settings.copyWith(quietStart: v)),
                ),
                ReminderTimeField(
                  identifier: 'reminders-quiet-end',
                  label: s.remindersQuietTo,
                  value: settings.quietEnd!,
                  onChanged: (v) => _service.saveSettings(settings.copyWith(quietEnd: v)),
                ),
              ],
            ),
          ),
        const Divider(),
        _sectionTitle(context, s.remindersChannelsTitle),
        _telegramTile(context, settings),
        _emailTile(context, settings),
        if (kIsWeb || _platform.pushSupport != PushSupport.notSupported) _pushTile(context),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(s.remindersLateNote, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );

  Widget _tile(BuildContext context, ReminderDBO r) {
    final icon = switch (r.type) {
      ReminderType.weighIn => Icons.monitor_weight_outlined,
      ReminderType.meal => Icons.restaurant_outlined,
      ReminderType.custom => Icons.notifications_outlined,
    };
    return Semantics(
      identifier: 'reminders-item-${r.id}',
      container: true,
      child: ListTile(
        leading: Icon(icon),
        title: Text(ReminderFormat.name(context, r)),
        subtitle: Text(
          '${r.time} · ${ReminderFormat.days(context, r.days)} · ${ReminderFormat.channel(context, r.channel)}',
        ),
        trailing: Semantics(
          identifier: 'reminders-toggle-${r.id}',
          child: Switch(value: r.enabled, onChanged: (v) => _toggle(r, v)),
        ),
        onTap: () => _edit(r),
      ),
    );
  }

  Widget _telegramTile(BuildContext context, ReminderSettingsDBO settings) {
    final s = S.of(context);
    return ListTile(
      leading: const Icon(Icons.send_outlined),
      title: Text(s.remindersChannelTelegram),
      subtitle: settings.telegramLinked
          ? Text(s.remindersTelegramLinked)
          : (_linkingTelegram ? Text(s.remindersTelegramWaiting) : null),
      trailing: settings.telegramLinked
          ? const Icon(Icons.check_circle_outline)
          : (_linkingTelegram
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Semantics(
                    identifier: 'reminders-telegram-link',
                    child: FilledButton.tonal(onPressed: _linkTelegram, child: Text(s.remindersTelegramLink)),
                  )),
    );
  }

  Widget _emailTile(BuildContext context, ReminderSettingsDBO settings) {
    final s = S.of(context);
    return Semantics(
      identifier: 'reminders-email',
      container: true,
      child: ListTile(
        leading: const Icon(Icons.email_outlined),
        title: Text(s.remindersChannelEmail),
        subtitle: Text(
          settings.emailVerified ? s.remindersEmailVerifiedAs(settings.email ?? '') : s.remindersEmailUnverified,
        ),
        trailing: settings.emailVerified ? const Icon(Icons.check_circle_outline) : const Icon(Icons.chevron_right),
        onTap: _verifyEmail,
      ),
    );
  }

  Widget _pushTile(BuildContext context) {
    final s = S.of(context);
    final support = _platform.pushSupport;
    final permission = _platform.pushPermission;
    String subtitle;
    Widget? trailing;
    switch (support) {
      case PushSupport.iosNotInstalled:
        subtitle = s.remindersPushIosNotInstalled;
      case PushSupport.notSupported:
        subtitle = s.remindersPushNotSupported;
      case PushSupport.supported:
        if (_service.pushActive.value && permission == PushPermission.granted) {
          subtitle = s.remindersPushActive;
          trailing = const Icon(Icons.check_circle_outline);
        } else if (permission == PushPermission.denied) {
          subtitle = s.remindersPushDenied;
        } else {
          subtitle = s.remindersPushNoPermission;
          trailing = Semantics(
            identifier: 'reminders-push-enable',
            child: FilledButton.tonal(onPressed: _enablePush, child: Text(s.remindersPushEnable)),
          );
        }
    }
    return ListTile(
      leading: const Icon(Icons.notifications_active_outlined),
      title: Text(s.remindersChannelPush),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}
