import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/account/account_admin_api.dart';
import 'package:opennutritracker/core/account/account_key_service.dart';
import 'package:opennutritracker/core/account/account_session_exceptions.dart';
import 'package:opennutritracker/core/account/account_session_service.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/features/accounts/account_actions.dart';
import 'package:opennutritracker/features/accounts/admin_panel.dart';
import 'package:opennutritracker/features/accounts/code_entry_screen.dart';
import 'package:opennutritracker/features/accounts/create_account_screen.dart';
import 'package:opennutritracker/features/accounts/sign_in_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _Sessions implements AccountSessionService {
  bool signupsOpenValue = true;
  Object? signInError;
  Object? signUpError;
  Object? verifyError;
  final calls = <String>[];
  AccountLink? linkValue;

  @override
  Future<bool> signupsOpen() async => signupsOpenValue;

  @override
  Future<SignInResult> signIn(String profileId, String email, String password) async {
    calls.add('signIn:$email:$password');
    if (signInError != null) throw signInError!;
    return SignInResult.ready;
  }

  @override
  Future<SignUpResult> signUp(String profileId, String email, String password) async {
    calls.add('signUp:$email');
    if (signUpError != null) throw signUpError!;
    return SignUpResult.codeSent;
  }

  @override
  Future<void> resendSignupCode(String email) async => calls.add('resend:$email');

  @override
  Future<SignInResult> verifySignupCode(String profileId, String email, String code, String password) async {
    calls.add('verify:$code');
    if (verifyError != null) throw verifyError!;
    return SignInResult.ready;
  }

  @override
  Future<void> signOut(String profileId) async => calls.add('signOut:$profileId');

  @override
  Future<AccountLink?> link(String profileId) async => linkValue;

  @override
  Future<String> accessToken(String profileId, {bool forceRefresh = false}) async => 'jwt';

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _Sync implements SyncService {
  bool synced = true;

  @override
  Future<bool> syncBeforeSignOut(String profileId) async => synced;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _Store implements ProfileStore {
  final unlinked = <String>[];
  var wiped = 0;
  final removed = <String>[];

  @override
  Future<void> setAccount(String id, AccountLink? account) async => unlinked.add(id);

  @override
  Future<void> wipeDefault() async => wiped++;

  @override
  Future<void> remove(String id) async => removed.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _Keys implements AccountKeyService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _Admin implements AccountAdminApi {
  bool admin = false;
  bool failSave = false;
  final saved = <bool>[];

  @override
  Future<bool> isAdmin(String accessToken) async => admin;

  @override
  Future<bool> signupsOpen(String accessToken) async => true;

  @override
  Future<void> setSignupsOpen(String accessToken, bool open) async {
    if (failSave) throw const AccountRemoteActionException(403, 'denied');
    saved.add(open);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: const [
    S.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: S.delegate.supportedLocales,
  locale: const Locale('en'),
  home: home,
);

void main() {
  late _Sessions sessions;

  setUp(() => sessions = _Sessions());

  group('sign in', () {
    testWidgets('validates the form before calling the service', (tester) async {
      await tester.pumpWidget(_app(SignInScreen(profileId: 'default', sessions: sessions)));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(sessions.calls, isEmpty);
    });

    testWidgets('explains that the password also protects the data', (tester) async {
      await tester.pumpWidget(_app(SignInScreen(profileId: 'default', sessions: sessions)));
      expect(
        find.text('This password also protects your data and cannot be recovered by email alone.'),
        findsOneWidget,
      );
    });

    testWidgets('signs in with the typed values', (tester) async {
      await tester.pumpWidget(_app(SignInScreen(profileId: 'default', sessions: sessions)));
      await tester.enterText(find.byType(TextFormField).first, ' me@example.org ');
      await tester.enterText(find.byType(TextFormField).last, 'a long password');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(sessions.calls, ['signIn:me@example.org:a long password']);
    });

    testWidgets('shows the error for wrong credentials', (tester) async {
      sessions.signInError = const InvalidCredentialsException();
      await tester.pumpWidget(_app(SignInScreen(profileId: 'default', sessions: sessions)));
      await tester.enterText(find.byType(TextFormField).first, 'me@example.org');
      await tester.enterText(find.byType(TextFormField).last, 'wrong');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Wrong email or password.'), findsOneWidget);
    });
  });

  group('create account', () {
    testWidgets('shows "Registro cerrado" instead of the form when sign-ups are closed', (tester) async {
      sessions.signupsOpenValue = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          locale: const Locale('es'),
          home: CreateAccountScreen(profileId: 'default', sessions: sessions),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Registro cerrado'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('a SignupsClosedException on submit switches to the closed message', (tester) async {
      sessions.signUpError = const SignupsClosedException();
      await tester.pumpWidget(_app(CreateAccountScreen(profileId: 'default', sessions: sessions)));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'new@example.org');
      await tester.enterText(fields.at(1), 'a long password');
      await tester.enterText(fields.at(2), 'a long password');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Sign-ups closed'), findsOneWidget);
    });

    testWidgets('requires 10 characters and a matching confirmation', (tester) async {
      await tester.pumpWidget(_app(CreateAccountScreen(profileId: 'default', sessions: sessions)));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'new@example.org');
      await tester.enterText(fields.at(1), 'short');
      await tester.enterText(fields.at(2), 'other');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text('Use at least 10 characters.'), findsOneWidget);
      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(sessions.calls, isEmpty);
    });
  });

  group('code entry', () {
    Widget screen() =>
        _app(CodeEntryScreen.signup(profileId: 'default', email: 'me@example.org', password: 'pw', sessions: sessions));

    testWidgets('needs exactly six digits', (tester) async {
      await tester.pumpWidget(screen());
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text('Enter the 6 digits.'), findsOneWidget);
      expect(sessions.calls, isEmpty);
    });

    testWidgets('verifies the code and can resend it', (tester) async {
      await tester.pumpWidget(screen());
      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();
      expect(sessions.calls, ['resend:me@example.org']);
      expect(find.text('Code sent again.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(sessions.calls.last, 'verify:123456');
    });

    testWidgets('shows the error for a wrong code', (tester) async {
      sessions.verifyError = const InvalidCodeException();
      await tester.pumpWidget(screen());
      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('The code is wrong or has expired.'), findsOneWidget);
    });
  });

  group('sign out', () {
    late _Sync sync;
    late _Store store;
    var detached = 0;
    const profile = AppProfile(
      AppProfile.defaultId,
      '',
      account: AccountLink(userId: 'u1', email: 'me@example.org'),
    );

    var signingOut = profile;

    Future<void> pumpButton(WidgetTester tester) async {
      final actions = AccountActions(
        sessions: sessions,
        keys: _Keys(),
        sync: sync,
        admin: _Admin(),
        store: store,
        detachReminders: () async => detached++,
        switchProfile: (context, id, {afterSwitch}) async => await afterSwitch?.call(),
      );
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) =>
                TextButton(onPressed: () => actions.signOut(context, signingOut), child: const Text('go')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }

    setUp(() {
      sync = _Sync();
      store = _Store();
      detached = 0;
      signingOut = profile;
    });

    testWidgets('signs out straight away when everything is uploaded', (tester) async {
      await pumpButton(tester);
      expect(find.text('Changes not uploaded'), findsNothing);
      expect(sessions.calls, ['signOut:default']);
      expect(detached, 1);
      expect(store.wiped, 1);
      expect(store.removed, isEmpty);
    });

    testWidgets('wipes the default profile only after the pending-changes confirmation', (tester) async {
      sync.synced = false;
      await pumpButton(tester);
      expect(store.wiped, 0);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(store.wiped, 0);
    });

    testWidgets('wipes the default profile after losing changes explicitly', (tester) async {
      sync.synced = false;
      await pumpButton(tester);
      await tester.tap(find.text('Sign out and lose changes'));
      await tester.pumpAndSettle();
      expect(store.wiped, 1);
    });

    testWidgets('warns when changes are pending and does nothing if cancelled', (tester) async {
      sync.synced = false;
      await pumpButton(tester);
      expect(find.text('Changes not uploaded'), findsOneWidget);
      expect(sessions.calls, isEmpty);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(sessions.calls, isEmpty);
      expect(detached, 0);
    });

    testWidgets('signs out after the explicit confirmation', (tester) async {
      sync.synced = false;
      await pumpButton(tester);
      await tester.tap(find.text('Sign out and lose changes'));
      await tester.pumpAndSettle();
      expect(sessions.calls, ['signOut:default']);
      expect(detached, 1);
    });
  });

  group('admin panel', () {
    late _Admin admin;

    setUp(() {
      admin = _Admin();
      sessions.linkValue = const AccountLink(userId: 'u1', email: 'me@example.org');
    });

    testWidgets('is hidden for a regular account', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AdminPanel(sessions: sessions, api: admin, profileId: 'default'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('Open sign-ups'), findsNothing);
    });

    testWidgets('is hidden for a local profile', (tester) async {
      admin.admin = true;
      sessions.linkValue = null;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AdminPanel(sessions: sessions, api: admin, profileId: 'default'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('shows the switch to an admin and saves the change', (tester) async {
      admin.admin = true;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AdminPanel(sessions: sessions, api: admin, profileId: 'default'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open sign-ups'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(admin.saved, [false]);
    });

    testWidgets('shows the error and undoes the switch when saving fails', (tester) async {
      admin.admin = true;
      admin.failSave = true;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AdminPanel(sessions: sessions, api: admin, profileId: 'default'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('Could not save the change.'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    });
  });
}
