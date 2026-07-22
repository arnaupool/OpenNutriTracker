import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_or_delete_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  Future<CopyOrDeleteAction?> openDialog(
    WidgetTester tester, {
    bool showMoveOption = false,
  }) async {
    CopyOrDeleteAction? returned;
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final future = showDialog<CopyOrDeleteAction>(
      context: capturedContext,
      builder: (_) => CopyOrDeleteDialog(showMoveOption: showMoveOption),
    );
    await tester.pumpAndSettle();

    if (showMoveOption) {
      await tester.tap(find.text(S.current.moveActionLabel.toUpperCase()));
    }
    await tester.pumpAndSettle();
    returned = await future;
    return returned;
  }

  testWidgets(
    'the Move button is hidden by default (activity flow never offers it)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.delegate.supportedLocales,
          home: const Scaffold(body: CopyOrDeleteDialog()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(S.current.moveActionLabel.toUpperCase()),
        findsNothing,
      );
    },
  );

  testWidgets('showMoveOption shows a Move button that pops .move', (
    tester,
  ) async {
    final result = await openDialog(tester, showMoveOption: true);
    expect(result, CopyOrDeleteAction.move);
  });

  testWidgets('Copy pops .copy', (tester) async {
    CopyOrDeleteAction? returned;
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final future = showDialog<CopyOrDeleteAction>(
      context: capturedContext,
      builder: (_) => const CopyOrDeleteDialog(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.current.dialogCopyLabel.toUpperCase()));
    await tester.pumpAndSettle();
    returned = await future;

    expect(returned, CopyOrDeleteAction.copy);
  });

  testWidgets('Delete pops .delete', (tester) async {
    CopyOrDeleteAction? returned;
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final future = showDialog<CopyOrDeleteAction>(
      context: capturedContext,
      builder: (_) => const CopyOrDeleteDialog(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.current.dialogDeleteLabel.toUpperCase()));
    await tester.pumpAndSettle();
    returned = await future;

    expect(returned, CopyOrDeleteAction.delete);
  });
}
