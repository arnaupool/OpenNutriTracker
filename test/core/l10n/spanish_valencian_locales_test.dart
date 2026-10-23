import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Spanish (`es`) and Valencian (`ca`) must load through the same delegates
/// MaterialApp uses in main.dart, including Flutter's own Material strings.
void main() {
  const expected = {
    'es': ('Desayuno', 'Versión 1.2.3'),
    'ca': ('Esmorzar', 'Versió 1.2.3'),
  };

  for (final MapEntry(key: code, value: (breakfast, version))
      in expected.entries) {
    testWidgets('MaterialApp renders in $code', (tester) async {
      expect(
        S.delegate.supportedLocales.map((l) => l.languageCode),
        contains(code),
      );
      expect(
        GlobalMaterialLocalizations.delegate.isSupported(Locale(code)),
        isTrue,
      );

      late MaterialLocalizations material;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: Builder(
            builder: (context) {
              material = MaterialLocalizations.of(context);
              return Scaffold(
                body: Column(
                  children: [
                    Text(S.of(context).breakfastLabel),
                    Text(S.of(context).appVersionName('1.2.3')),
                    Text(material.cancelButtonLabel),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(breakfast), findsOneWidget);
      expect(find.text(version), findsOneWidget);
      expect(
        Localizations.localeOf(tester.element(find.text(breakfast))),
        Locale(code),
      );
      expect(material.cancelButtonLabel, isNot('Cancel'));
    });
  }
}
