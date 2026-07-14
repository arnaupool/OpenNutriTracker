import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/share_qr_dialog.dart';
import 'package:opennutritracker/core/utils/cloud_backup_token_service.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Shows this device's cloud-backup pairing token as a QR code (reusing
/// [ShareQrDialog]'s existing copy/share actions), generating one first if
/// this device doesn't have one yet. This is the "activate cloud backup" /
/// "show my pairing code" entry point — pairs with [PairCloudBackupScreen]'s
/// scan/paste flow on the device being linked.
Future<void> showCloudBackupTokenDialog(
  BuildContext context, {
  CloudBackupTokenService? tokenService,
}) async {
  final service = tokenService ?? locator<CloudBackupTokenService>();
  final token = await service.read() ?? await service.generateAndStore();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => ShareQrDialog(
      title: S.of(dialogContext).cloudBackupTokenDialogTitle,
      code: token,
      fileBaseName: 'opennutritracker-backup-token',
    ),
  );
}
