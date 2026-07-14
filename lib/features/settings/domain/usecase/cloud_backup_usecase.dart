import 'package:opennutritracker/core/utils/cloud_backup_token_service.dart';
import 'package:opennutritracker/features/settings/domain/usecase/export_data_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when a cloud-backup action is attempted before this device has a
/// pairing token — see [CloudBackupTokenService] / FA-15's
/// showCloudBackupTokenDialog / PairCloudBackupScreen for how one gets set.
class CloudBackupNotPairedException implements Exception {
  const CloudBackupNotPairedException();
}

/// FA-12: uploads the current local snapshot to the private Supabase
/// Storage bucket set up in docs/cloud-backup-setup.md. Reuses
/// [ExportDataUsecase.buildZipBytes] wholesale — the only thing that
/// changes versus the regular Settings → Export flow is the destination
/// (Storage instead of a file-picker save dialog) and that profile/
/// settings/progress-photos travel too, since the whole point of this
/// bucket is viewing your data on another device, not a shareable backup.
class CloudBackupUsecase {
  final ExportDataUsecase _exportDataUsecase;
  final CloudBackupTokenService _tokenService;
  final SupabaseClient _backupSupabaseClient;

  CloudBackupUsecase(
    this._exportDataUsecase,
    this._tokenService,
    this._backupSupabaseClient,
  );

  Future<void> backup() async {
    final token = await _tokenService.read();
    if (token == null) throw const CloudBackupNotPairedException();

    final zipBytes = await _exportDataUsecase.buildZipBytes(
      includeProfile: true,
      includeProgressPhotos: true,
    );

    // Path matches FA-09's RLS policy exactly: `backups/<token>/latest.zip`
    // — the leading `backups/` is a literal part of the in-bucket object
    // name the policy checks, not a duplicate of the bucket id.
    await _backupSupabaseClient.storage
        .from('backups')
        .uploadBinary(
          'backups/$token/latest.zip',
          zipBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/zip',
          ),
        );
  }
}
