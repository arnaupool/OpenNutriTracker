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

  testWidgets('shows the initialDate formatted as dd/MM/yyyy', (tester) async {
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
  });

  testWidgets('the end-date row is hidden until the range toggle is on',
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

    expect(find.text(S.current.copyDialogEndDateLabel), findsNothing);

    await tester.tap(find.text(S.current.copyDialogRangeToggleLabel));
    await tester.pumpAndSettle();

    expect(find.text(S.current.copyDialogEndDateLabel), findsOneWidget);
    // Defaults to the same day as the start date.
    expect(find.text('21/05/2026'), findsNWidgets(2));
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
    'toggling the range on and picking an end date returns a distinct '
    'startDate/endDate pair',
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

      await tester.tap(find.text(S.current.copyDialogRangeToggleLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.copyDialogEndDateLabel));
      await tester.pumpAndSettle();
      // Pick day 25 in the open Material date picker.
      await tester.tap(find.text('25').last);
      await tester.pumpAndSettle();
      // The date picker's own OK button is on top of (and shares the same
      // "OK" text as) CopyDialog's — .last is the one just pushed.
      await tester.tap(find.text('OK').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.current.dialogOKLabel));
      await tester.pumpAndSettle();
      returned = await future;

      expect(returned, isNotNull);
      final (_, startDate, endDate) = returned!;
      expect(startDate, initialDate);
      expect(endDate, DateTime(2026, 5, 25));
    },
  );
}
