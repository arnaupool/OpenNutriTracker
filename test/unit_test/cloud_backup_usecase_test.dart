import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/cloud_backup_token_service.dart';
import 'package:opennutritracker/features/settings/domain/usecase/cloud_backup_usecase.dart';
import 'package:opennutritracker/features/settings/domain/usecase/cloud_restore_usecase.dart';
import 'package:opennutritracker/features/settings/domain/usecase/export_data_usecase.dart';
import 'package:opennutritracker/features/settings/domain/usecase/import_data_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// The rest of backup()/restore() talks to Supabase Storage, which — like
// FilePicker in ExportDataUsecase/ImportDataUsecase and MobileScanner in
// PairCloudBackupScreen — has no mock set up anywhere in this suite (the
// only other Supabase consumer, SpFdcDataSource, isn't unit tested either).
// What *is* testable without touching the network: the not-paired guard
// runs before any Storage call, so it's covered here with throwaway Fakes
// that would blow up if the code ever tried to reach past that guard.
class _FakeCloudBackupTokenService extends Fake
    implements CloudBackupTokenService {
  final String? token;
  _FakeCloudBackupTokenService(this.token);

  @override
  Future<String?> read() async => token;
}

class _UnreachableExportDataUsecase extends Fake implements ExportDataUsecase {}

class _UnreachableImportDataUsecase extends Fake implements ImportDataUsecase {}

class _UnreachableSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  group('CloudBackupUsecase.backup', () {
    test('throws CloudBackupNotPairedException when no token is stored', () {
      final usecase = CloudBackupUsecase(
        _UnreachableExportDataUsecase(),
        _FakeCloudBackupTokenService(null),
        _UnreachableSupabaseClient(),
      );

      expect(
        () => usecase.backup(),
        throwsA(isA<CloudBackupNotPairedException>()),
      );
    });
  });

  group('CloudRestoreUsecase.restore', () {
    test('throws CloudBackupNotPairedException when no token is stored', () {
      final usecase = CloudRestoreUsecase(
        _UnreachableImportDataUsecase(),
        _FakeCloudBackupTokenService(null),
        _UnreachableSupabaseClient(),
      );

      expect(
        () => usecase.restore(),
        throwsA(isA<CloudBackupNotPairedException>()),
      );
    });
  });
}
