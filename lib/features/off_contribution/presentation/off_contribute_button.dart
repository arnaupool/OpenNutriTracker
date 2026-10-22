import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/off_contribution/data/off_account_data_source.dart';
import 'package:opennutritracker/features/off_contribution/domain/contribute_to_off_usecase.dart';
import 'package:opennutritracker/features/off_contribution/presentation/off_account_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// "Send to Open Food Facts" for a custom food that has a retail barcode.
/// Asks for the user's OFF account if none is saved, then for an explicit
/// confirmation (the product becomes public under the ODbL) before sending.
class OffContributeButton extends StatefulWidget {
  final MealEntity meal;

  const OffContributeButton({super.key, required this.meal});

  static bool appliesTo(MealEntity meal) =>
      meal.source == MealSourceEntity.custom && ContributeToOffUsecase.canContribute(meal);

  @override
  State<OffContributeButton> createState() => _OffContributeButtonState();
}

class _OffContributeButtonState extends State<OffContributeButton> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _onPressed() async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (await locator<OffAccountDataSource>().read() == null) {
      if (!mounted) return;
      final signedIn = await showOffAccountDialog(context);
      if (!signedIn) {
        messenger.showSnackBar(SnackBar(content: Text(s.offContributeNeedsAccount)));
        return;
      }
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.offContributeConfirmTitle),
        content: Text(s.offContributeConfirmContent),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.dialogCancelLabel)),
          Semantics(
            identifier: 'off-contribute-confirm',
            child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s.offContributeSend)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _sending = true);
    final result = await locator<ContributeToOffUsecase>().contribute(widget.meal);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = result == OffContributionResult.sent || result == OffContributionResult.alreadyOnOff;
    });
    messenger.showSnackBar(SnackBar(content: Text(_message(s, result))));
  }

  static String _message(S s, OffContributionResult result) => switch (result) {
        OffContributionResult.sent => s.offContributeSent,
        OffContributionResult.alreadyOnOff => s.offContributeAlreadyOnOff,
        OffContributionResult.notSignedIn => s.offContributeNeedsAccount,
        OffContributionResult.wrongCredentials => s.offContributeWrongCredentials,
        OffContributionResult.missingData => s.offContributeMissingData,
        OffContributionResult.failed => s.offContributeFailed,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'off-contribute-button',
      child: OutlinedButton.icon(
        onPressed: _sending || _sent ? null : _onPressed,
        icon: _sending
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(_sent ? Icons.check : Icons.cloud_upload_outlined),
        label: Text(S.of(context).offContributeButton),
      ),
    );
  }
}
