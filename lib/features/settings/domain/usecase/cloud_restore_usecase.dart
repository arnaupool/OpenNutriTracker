import 'package:opennutritracker/core/utils/cloud_backup_token_service.dart';
import 'package:opennutritracker/features/settings/domain/usecase/cloud_backup_usecase.dart';
import 'package:opennutritracker/features/settings/domain/usecase/import_data_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FA-12: downloads the snapshot [CloudBackupUsecase] uploaded and restores
/// it via [ImportDataUsecase.importFromZipBytes] — including profile and
/// settings, unlike the regular Settings → Import flow. This is a plain
/// overwrite, not a merge (same as the rest of importFromZipBytes' upsert-
/// by-key sections): the caller (PairCloudBackupScreen's flow, or a
/// future "restore" button) is expected to warn the user before calling
/// this, since it replaces local data outright.
class CloudRestoreUsecase {
  final ImportDataUsecase _importDataUsecase;
  final CloudBackupTokenService _tokenService;
  final SupabaseClient _backupSupabaseClient;

  CloudRestoreUsecase(
    this._importDataUsecase,
    this._tokenService,
    this._backupSupabaseClient,
  );

  Future<void> restore() async {
    final token = await _tokenService.read();
    if (token == null) throw const CloudBackupNotPairedException();

    // Same literal `backups/<token>/latest.zip` path CloudBackupUsecase
    // uploads to — see its comment for why `backups/` appears twice.
    final zipBytes = await _backupSupabaseClient.storage
        .from('backups')
        .download('backups/$token/latest.zip');

    await _importDataUsecase.importFromZipBytes(zipBytes, restoreProfile: true);
  }
}
