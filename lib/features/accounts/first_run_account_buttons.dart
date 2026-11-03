import 'package:flutter/material.dart';
import 'package:opennutritracker/core/profiles/profile_store.dart';
import 'package:opennutritracker/features/accounts/account_ui.dart';
import 'package:opennutritracker/features/accounts/create_account_screen.dart';
import 'package:opennutritracker/features/accounts/sign_in_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/main.dart';

/// First-run choices (C7): sign in, create an account, or go on without one
/// (the existing local onboarding). After a successful sign-in or sign-up
/// the app reloads on the profile, which pulls the account's data and skips
/// the setup when the account already has a profile.
class FirstRunAccountButtons extends StatelessWidget {
  final VoidCallback? onUseWithoutAccount;

  const FirstRunAccountButtons({super.key, this.onUseWithoutAccount});

  Future<void> _open(BuildContext context, Widget Function(String profileId) screen) async {
    final profileId = ProfileScope.activeId;
    final ok = await pushAccountScreen<bool>(context, screen(profileId));
    if (ok == true && context.mounted) await AppRestarter.switchProfile(context, profileId);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            Semantics(
              identifier: 'onboarding-sign-in',
              child: OutlinedButton.icon(
                onPressed: () => _open(context, (id) => SignInScreen(profileId: id)),
                icon: const Icon(Icons.login),
                label: Text(s.accSignInTitle),
              ),
            ),
            Semantics(
              identifier: 'onboarding-create-account',
              child: OutlinedButton.icon(
                onPressed: () => _open(context, (id) => CreateAccountScreen(profileId: id)),
                icon: const Icon(Icons.person_add_alt),
                label: Text(s.accCreateTitle),
              ),
            ),
          ],
        ),
        if (onUseWithoutAccount != null)
          Semantics(
            identifier: 'onboarding-use-without-account',
            child: TextButton(onPressed: onUseWithoutAccount, child: Text(s.accUseWithoutAccount)),
          ),
      ],
    );
  }
}
