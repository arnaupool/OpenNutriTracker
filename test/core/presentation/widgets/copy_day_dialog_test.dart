import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_day_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  final initialDate = DateTime(2026, 5, 21);

  testWidgets(
    'shows the initialDate formatted as dd/MM/yyyy for both start and end '
    '(single day by default, no meal-type dropdown)',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(body: CopyDayDialog(initialDate: initialDate)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('21/05/2026'), findsOneWidget);
      expect(find.byType(DropdownButton<Object>), findsNothing);
    },
  );

  testWidgets('OK with nothing changed returns a single-day range', (
    tester,
  ) async {
    DateTimeRange? returned;
    late BuildContext capturedContext;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: Builder(builder: (context) {
          capturedContext = context;
          return const SizedBox();
        }),
      ),
    ));
    await tester.pumpAndSettle();

    final future = showDialog<DateTimeRange>(
      context: capturedContext,
      builder: (_) => CopyDayDialog(initialDate: initialDate),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.current.dialogOKLabel));
    await tester.pumpAndSettle();
    returned = await future;

    expect(returned, isNotNull);
    expect(returned!.start, initialDate);
    expect(returned.end, initialDate);
  });

  testWidgets('Cancel returns null', (tester) async {
    DateTimeRange? returned;
    late BuildContext capturedContext;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: Builder(builder: (context) {
          capturedContext = context;
          return const SizedBox();
        }),
      ),
    ));
    await tester.pumpAndSettle();

    final future = showDialog<DateTimeRange>(
      context: capturedContext,
      builder: (_) => CopyDayDialog(initialDate: initialDate),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.current.dialogCancelLabel));
    await tester.pumpAndSettle();
    returned = await future;

    expect(returned, isNull);
  });

  testWidgets(
    'picking a start and end day in the range picker returns a distinct '
    'range',
    (tester) async {
      DateTimeRange? returned;
      late BuildContext capturedContext;

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: Builder(builder: (context) {
            capturedContext = context;
            return const SizedBox();
          }),
        ),
      ));
      await tester.pumpAndSettle();

      final future = showDialog<DateTimeRange>(
        context: capturedContext,
        builder: (_) => CopyDayDialog(initialDate: initialDate),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.copyDialogDateLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.text('21').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('27').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.dialogOKLabel));
      await tester.pumpAndSettle();
      returned = await future;

      expect(returned, isNotNull);
      expect(returned!.start, DateTime(2026, 5, 21));
      expect(returned.end, DateTime(2026, 5, 27));
    },
  );
}
