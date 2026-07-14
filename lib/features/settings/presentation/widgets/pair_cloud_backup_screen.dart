import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opennutritracker/core/utils/cloud_backup_token_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// FA-15: scan the QR code (or paste the text) that
/// [showCloudBackupTokenDialog] shows on another device, to link this one
/// to the same cloud-backup slot. A one-time pairing action per device —
/// once stored, the token lives in secure storage and every later sync
/// just reuses it, no re-scanning needed.
class PairCloudBackupScreen extends StatefulWidget {
  final CloudBackupTokenService? tokenService;

  const PairCloudBackupScreen({super.key, this.tokenService});

  @override
  State<PairCloudBackupScreen> createState() => _PairCloudBackupScreenState();
}

class _PairCloudBackupScreenState extends State<PairCloudBackupScreen>
    with WidgetsBindingObserver {
  late final CloudBackupTokenService _tokenService =
      widget.tokenService ?? locator<CloudBackupTokenService>();
  late final MobileScannerController _cameraController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cameraController.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraController.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        unawaited(_cameraController.stop());
      case AppLifecycleState.resumed:
        unawaited(_cameraController.start());
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.cloudBackupPairScreenTitle),
        actions: [
          Semantics(
            identifier: 'pair-cloud-backup-paste-button',
            child: IconButton(
              icon: const Icon(Icons.keyboard_outlined),
              tooltip: s.pasteCodeLabel,
              onPressed: _showPasteCodeDialog,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(s.cloudBackupPairInstructionsLabel),
          ),
          Expanded(
            child: MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    // Flip synchronously, before any await, so a second onDetect fired
    // while the same QR is still in frame can't pass the gate — same
    // reasoning as ImportMealScannerScreen._onDetect.
    _isProcessing = true;
    unawaited(_processToken(raw));
  }

  Future<void> _showPasteCodeDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(ctx).pasteCodeLabel),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: S.of(ctx).cloudBackupPairPasteHint,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.of(ctx).dialogCancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(S.of(ctx).dialogOKLabel),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) {
      await _processToken(code);
    }
  }

  Future<void> _processToken(String raw) async {
    setState(() => _isProcessing = true);
    try {
      await _tokenService.store(raw.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).cloudBackupPairSuccessLabel)),
      );
    } on ArgumentError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).cloudBackupPairInvalidTokenError)),
      );
      setState(() => _isProcessing = false);
    }
  }
}
