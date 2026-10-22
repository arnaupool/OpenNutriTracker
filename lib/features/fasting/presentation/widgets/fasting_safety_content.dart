import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// The health information behind the fasting timer: who should talk to a
/// doctor first, when to stop, and where the guidance comes from. Shared by
/// the one-time warning and the info button on the fasting screen so both
/// always say the same thing.
class FastingSafetyContent extends StatelessWidget {
  static const _beatUrl = 'https://www.beateatingdisorders.org.uk/';
  static const _nedaUrl = 'https://www.nationaleatingdisorders.org/';
  static const _washuUrl =
      'https://physicians.wustl.edu/a-fast-guide-to-intermittent-fasting/';
  static const _bastyrUrl =
      'https://bastyr.edu/about/news/5-times-you-should-avoid-intermittent-fasting';

  /// Whether to lead with the disordered-eating note and support links.
  final bool includeEatingDisorderNote;

  const FastingSafetyContent({super.key, this.includeEatingDisorderNote = true});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (includeEatingDisorderNote) ...[
          Text(l10n.fastingWarningBody, style: textTheme.bodyMedium),
          const SizedBox(height: 8),
          _link(context, l10n.fastingLinkBeat, _beatUrl),
          const SizedBox(height: 4),
          _link(context, l10n.fastingLinkNeda, _nedaUrl),
          const SizedBox(height: 16),
        ],
        Text(l10n.fastingWarningWhoTitle, style: textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(l10n.fastingWarningWhoList, style: textTheme.bodyMedium),
        const SizedBox(height: 16),
        Text(l10n.fastingStopIfUnwell, style: textTheme.bodyMedium),
        const SizedBox(height: 16),
        Text(l10n.fastingNotMedicalAdvice, style: textTheme.bodySmall),
        const SizedBox(height: 4),
        _link(context, l10n.fastingLinkWashU, _washuUrl),
        const SizedBox(height: 4),
        _link(context, l10n.fastingLinkBastyr, _bastyrUrl),
      ],
    );
  }

  Widget _link(BuildContext context, String label, String url) {
    final textTheme = Theme.of(context).textTheme;
    return Text.rich(
      TextSpan(
        text: label,
        style: textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _open(url),
      ),
    );
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
