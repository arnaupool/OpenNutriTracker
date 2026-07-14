import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/app_banner_version.dart';
import 'package:opennutritracker/core/utils/app_const.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/core/utils/url_const.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/cloud_backup_restore_flow.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/pair_cloud_backup_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingIntroPageBody extends StatefulWidget {
  const OnboardingIntroPageBody({
    super.key,
    required this.setPageContent,
    this.initialAcceptedPolicy = false,
    this.initialAcceptedDataCollection = false,
  });

  final Function(bool active, bool acceptedDataCollection) setPageContent;
  final bool initialAcceptedPolicy;
  final bool initialAcceptedDataCollection;

  @override
  State<OnboardingIntroPageBody> createState() =>
      _OnboardingIntroPageBodyState();
}

class _OnboardingIntroPageBodyState extends State<OnboardingIntroPageBody> {
  late bool _acceptedPolicy = widget.initialAcceptedPolicy;
  late bool _acceptedDataCollection = widget.initialAcceptedDataCollection;
  bool _restoringFromCloud = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AppConst.getVersionNumber(),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.hasData) {
          return Column(
            children: [
              AppBannerVersion(versionNumber: snapshot.requireData),
              const SizedBox(height: 32.0),
              Text(
                S.of(context).appDescription,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32.0),
              Text(
                S.of(context).onboardingIntroDescription,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16.0),
              ListTile(
                onTap: () => _togglePolicy(),
                title: Text.rich(
                  textAlign: TextAlign.center,
                  TextSpan(
                    text: S.of(context).readLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                    children: [
                      TextSpan(
                        text: ' ${S.of(context).privacyPolicyLabel}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            _launchUrl();
                          },
                      ),
                    ],
                  ),
                ),
                leading: Semantics(
                  identifier: 'onboarding-checkbox-privacy',
                  child: Checkbox(
                    value: _acceptedPolicy,
                    onChanged: (value) {
                      if (value != null) {
                        _togglePolicy();
                      }
                    },
                  ),
                ),
              ),
              ListTile(
                onTap: () => _toggleDataCollection(),
                title: Text(
                  S.of(context).dataCollectionLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                leading: Semantics(
                  identifier: 'onboarding-checkbox-data',
                  child: Checkbox(
                    value: _acceptedDataCollection,
                    onChanged: (value) => _toggleDataCollection(),
                  ),
                ),
              ),
              const SizedBox(height: 8.0),
              TextButton.icon(
                onPressed: () => _openSources(context),
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(S.of(context).onboardingIntroSourcesLinkLabel),
              ),
              Semantics(
                identifier: 'onboarding-restore-from-cloud',
                child: TextButton.icon(
                  onPressed: _restoringFromCloud
                      ? null
                      : () => _restoreFromCloud(context),
                  icon: _restoringFromCloud
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                  label: Text(S.of(context).onboardingRestoreFromCloudLabel),
                ),
              ),
            ],
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  void _togglePolicy() {
    setState(() {
      _acceptedPolicy = !_acceptedPolicy;
      widget.setPageContent(_acceptedPolicy, _acceptedDataCollection);
    });
  }

  void _toggleDataCollection() {
    setState(() {
      _acceptedDataCollection = !_acceptedDataCollection;
      widget.setPageContent(_acceptedPolicy, _acceptedDataCollection);
    });
  }

  void _openSources(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SourcesScreen()));
  }

  /// FA-16: lets someone who already has a cloud backup (Fase Cuenta) skip
  /// filling in onboarding data that's just going to be overwritten anyway.
  /// Pair, then chain straight into the same confirm-and-restore flow
  /// Settings uses ([confirmAndRestoreCloudBackup]) — on success this
  /// device now has real user data, so it goes to the main route instead
  /// of continuing the onboarding pages.
  Future<void> _restoreFromCloud(BuildContext context) async {
    setState(() => _restoringFromCloud = true);
    try {
      final paired = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const PairCloudBackupScreen()),
      );
      if (paired != true || !context.mounted) return;

      final restored = await confirmAndRestoreCloudBackup(context);
      if (restored && context.mounted) {
        Navigator.of(context).pushReplacementNamed(NavigationOptions.mainRoute);
      }
    } finally {
      if (mounted) setState(() => _restoringFromCloud = false);
    }
  }

  Future<void> _launchUrl() async {
    if (!await launchUrl(
      Uri.parse(URLConst.privacyPolicyURLEn),
      mode: LaunchMode.externalApplication,
    )) {}
  }
}
