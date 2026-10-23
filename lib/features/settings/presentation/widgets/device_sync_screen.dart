import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opennutritracker/core/presentation/widgets/responsive_layout.dart';
import 'package:opennutritracker/core/presentation/widgets/share_qr_dialog.dart';
import 'package:opennutritracker/core/sync/sync_pairing.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Settings row for device sync (FAS-01): shows the current state and opens
/// [DeviceSyncScreen].
class DeviceSyncTile extends StatelessWidget {
  const DeviceSyncTile({super.key});

  @override
  Widget build(BuildContext context) {
    final service = locator<SyncService>();
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: service.status,
      builder: (context, status, _) => Semantics(
        identifier: 'settings-device-sync',
        child: ListTile(
          leading: const Icon(Icons.sync_outlined),
          title: Text(S.of(context).syncTitle),
          subtitle: Text(syncStatusText(context, status)),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DesktopRouteFrame(child: DeviceSyncScreen())),
          ),
        ),
      ),
    );
  }
}

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

class DeviceSyncScreen extends StatefulWidget {
  const DeviceSyncScreen({super.key});

  @override
  State<DeviceSyncScreen> createState() => _DeviceSyncScreenState();
}

class _DeviceSyncScreenState extends State<DeviceSyncScreen> {
  final SyncService _service = locator<SyncService>();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.syncTitle)),
      body: ValueListenableBuilder<SyncStatus>(
        valueListenable: _service.status,
        builder: (context, status, _) {
          final on = status.phase != SyncPhase.off;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(s.syncExplanation, style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 16),
              Semantics(
                identifier: 'device-sync-status',
                child: Row(
                  children: [
                    Icon(
                      switch (status.phase) {
                        SyncPhase.off => Icons.sync_disabled_outlined,
                        SyncPhase.syncing => Icons.sync,
                        SyncPhase.error => Icons.sync_problem_outlined,
                        SyncPhase.idle => Icons.cloud_done_outlined,
                      },
                      color: status.phase == SyncPhase.error ? colors.error : colors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(syncStatusText(context, status), style: textTheme.titleMedium)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!on) ...[
                Semantics(
                  identifier: 'device-sync-enable',
                  child: ListTile(
                    leading: const Icon(Icons.phone_android_outlined),
                    title: Text(s.syncEnableTitle),
                    subtitle: Text(s.syncEnableSubtitle),
                    enabled: !_busy,
                    onTap: _enableAsOwner,
                  ),
                ),
                Semantics(
                  identifier: 'device-sync-link',
                  child: ListTile(
                    leading: const Icon(Icons.link_outlined),
                    title: Text(s.syncLinkTitle),
                    subtitle: Text(s.syncLinkSubtitle),
                    enabled: !_busy,
                    onTap: _link,
                  ),
                ),
              ] else ...[
                Semantics(
                  identifier: 'device-sync-now',
                  child: FilledButton.icon(
                    icon: const Icon(Icons.sync),
                    label: Text(s.syncNowLabel),
                    onPressed: status.phase == SyncPhase.syncing ? null : _syncNow,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  identifier: 'device-sync-show-code',
                  child: ListTile(
                    leading: const Icon(Icons.qr_code_outlined),
                    title: Text(s.syncShowCodeTitle),
                    subtitle: Text(s.syncShowCodeWarning),
                    onTap: _showCode,
                  ),
                ),
                Semantics(
                  identifier: 'device-sync-disable',
                  child: ListTile(
                    leading: Icon(Icons.link_off_outlined, color: colors.error),
                    title: Text(s.syncDisableTitle, style: TextStyle(color: colors.error)),
                    onTap: _disable,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _enableAsOwner() async {
    setState(() => _busy = true);
    try {
      await _service.enableAsOwner();
      if (mounted) await _showCode();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCode() async {
    final pairing = await locator<SyncKeyService>().read();
    if (pairing == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => ShareQrDialog(
        title: S.of(ctx).syncCodeDialogTitle,
        code: pairing.encode(),
        fileBaseName: 'opennutritracker-sync-code',
      ),
    );
  }

  Future<void> _syncNow() async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await _service.syncNow();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == null ? s.syncStatusError : s.syncDoneSnackbar(result.pulled.toString(), result.pushed.toString()),
        ),
      ),
    );
  }

  Future<void> _link() async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final raw = await showDialog<String>(context: context, builder: (_) => const _LinkCodeDialog());
    if (raw == null || !mounted) return;
    final pairing = SyncPairing.tryParse(raw);
    if (pairing == null) {
      messenger.showSnackBar(SnackBar(content: Text(s.syncLinkInvalid)));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.syncLinkConfirmTitle),
        content: Text(s.syncLinkConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
          Semantics(
            identifier: 'device-sync-link-confirm',
            child: FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.syncLinkAction)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.join(pairing);
    messenger.showSnackBar(SnackBar(content: Text(s.syncLinked)));
  }

  Future<void> _disable() async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.syncDisableTitle),
        content: Text(s.syncDisableBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.dialogCancelLabel)),
          Semantics(
            identifier: 'device-sync-disable-confirm',
            child: TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.syncDisableAction)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _service.disable();
  }
}

/// Paste field, plus a camera scanner on phones.
class _LinkCodeDialog extends StatefulWidget {
  const _LinkCodeDialog();

  @override
  State<_LinkCodeDialog> createState() => _LinkCodeDialogState();
}

class _LinkCodeDialogState extends State<_LinkCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.syncLinkTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Semantics(
          identifier: 'device-sync-code-field',
          child: TextField(
            controller: _controller,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(hintText: s.syncPasteHint, border: const OutlineInputBorder()),
          ),
        ),
      ),
      actions: [
        if (!kIsWeb)
          Semantics(
            identifier: 'device-sync-scan',
            child: TextButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(s.syncScanLabel),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scanned = await navigator.push<String>(
                  MaterialPageRoute(builder: (_) => const _SyncCodeScanner()),
                );
                if (scanned != null) navigator.pop(scanned);
              },
            ),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.dialogCancelLabel)),
        Semantics(
          identifier: 'device-sync-code-ok',
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
            child: Text(s.dialogOKLabel),
          ),
        ),
      ],
    );
  }
}

class _SyncCodeScanner extends StatefulWidget {
  const _SyncCodeScanner();

  @override
  State<_SyncCodeScanner> createState() => _SyncCodeScannerState();
}

class _SyncCodeScannerState extends State<_SyncCodeScanner> {
  final _camera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).syncScanLabel)),
      body: MobileScanner(
        controller: _camera,
        onDetect: (capture) {
          if (_done) return;
          final raw = capture.barcodes.firstOrNull?.rawValue;
          if (raw == null || !raw.startsWith(SyncPairing.prefix)) return;
          _done = true;
          Navigator.of(context).pop(raw);
        },
      ),
    );
  }
}
