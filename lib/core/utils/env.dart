import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'FDC_API_KEY', obfuscate: true)
  static final String fdcApiKey = _Env.fdcApiKey;
  @EnviedField(varName: 'SENTRY_DNS', obfuscate: true)
  static final String sentryDns = _Env.sentryDns;
  @EnviedField(varName: 'BACKUP_SUPABASE_PROJECT_URL', obfuscate: true)
  static final String backupSupabaseProjectUrl = _Env.backupSupabaseProjectUrl;
  @EnviedField(varName: 'BACKUP_SUPABASE_PROJECT_ANON_KEY', obfuscate: true)
  static final String backupSupabaseProjectAnonKey =
      _Env.backupSupabaseProjectAnonKey;
}
