import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_dialog.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  final initialDate = DateTime(2026, 5, 21);

  testWidgets('shows the initialValue as the dropdown selection on open',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: CopyDialog(
          initialValue: AddMealType.dinnerType,
          initialDate: initialDate,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final dropdown =
        tester.widget<DropdownButton<AddMealType>>(find.byType(DropdownButton<AddMealType>));
    expect(dropdown.value, AddMealType.dinnerType);
  });

  testWidgets(
    'shows the initialDate formatted as dd/MM/yyyy for a single-day '
    'selection (start == end)',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: CopyDialog(
            initialValue: AddMealType.dinnerType,
            initialDate: initialDate,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('21/05/2026'), findsOneWidget);
    },
  );

  testWidgets('tapping the date row opens the native date range picker',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: CopyDialog(
          initialValue: AddMealType.dinnerType,
          initialDate: initialDate,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.current.copyDialogDateLabel));
    await tester.pumpAndSettle();

    expect(find.byType(DateRangePickerDialog), findsOneWidget);
  });

  testWidgets('OK returns the initial meal type and date when nothing is '
      'changed, with startDate == endDate (no range)', (tester) async {
    CopyDialogResult? returned;
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

    final future = showDialog<CopyDialogResult>(
      context: capturedContext,
      builder: (_) => CopyDialog(
        initialValue: AddMealType.lunchType,
        initialDate: initialDate,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.current.dialogOKLabel));
    await tester.pumpAndSettle();
    returned = await future;

    expect(returned, isNotNull);
    final (mealType, startDate, endDate) = returned!;
    expect(mealType, AddMealType.lunchType);
    expect(startDate, initialDate);
    expect(endDate, initialDate);
  });

  testWidgets('Cancel returns null even when initialValue is set',
      (tester) async {
    CopyDialogResult? returned;
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

    final future = showDialog<CopyDialogResult>(
      context: capturedContext,
      builder: (_) => CopyDialog(
        initialValue: AddMealType.snackType,
        initialDate: initialDate,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.current.dialogCancelLabel));
    await tester.pumpAndSettle();
    returned = await future;

    expect(returned, isNull);
  });

  testWidgets('user can change the meal type and OK returns the new value',
      (tester) async {
    CopyDialogResult? returned;
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

    final future = showDialog<CopyDialogResult>(
      context: capturedContext,
      builder: (_) => CopyDialog(
        initialValue: AddMealType.breakfastType,
        initialDate: initialDate,
      ),
    );
    await tester.pumpAndSettle();

    // Open the dropdown and pick "dinner".
    await tester.tap(find.byType(DropdownButton<AddMealType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.dinnerLabel).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.current.dialogOKLabel));
    await tester.pumpAndSettle();
    returned = await future;

    expect(returned, isNotNull);
    final (mealType, startDate, endDate) = returned!;
    expect(mealType, AddMealType.dinnerType);
    expect(startDate, initialDate);
    expect(endDate, initialDate);
  });

  testWidgets(
    'picking a start and end day in the range picker in one flow returns '
    'a distinct startDate/endDate pair',
    (tester) async {
      CopyDialogResult? returned;
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

      final future = showDialog<CopyDialogResult>(
        context: capturedContext,
        builder: (_) => CopyDialog(
          initialValue: AddMealType.breakfastType,
          initialDate: initialDate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.copyDialogDateLabel));
      await tester.pumpAndSettle();

      // A single range-picker flow: tap the start day, then the end day,
      // then confirm — no separate toggle or second field involved.
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
      final (_, startDate, endDate) = returned!;
      expect(startDate, DateTime(2026, 5, 21));
      expect(endDate, DateTime(2026, 5, 27));
    },
  );
}
