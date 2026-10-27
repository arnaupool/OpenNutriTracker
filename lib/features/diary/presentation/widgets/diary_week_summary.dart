import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_week_strip.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/weekly_nutrient_bars.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Phone-width weekly section of the Diary: a card that is COLLAPSED by
/// default and, once opened, shows total and per-tracked-day average kcal and
/// macros of the week of [selectedDate] (computed from [trackedDaysMap], the
/// same data the day markers use) followed by the weekly bar charts.
class DiaryWeekSummary extends StatelessWidget {
  final DateTime selectedDate;
  final Map<String, TrackedDayEntity> trackedDaysMap;
  final GetTrackedDayUsecase? getTrackedDayUsecase;

  const DiaryWeekSummary({
    super.key,
    required this.selectedDate,
    required this.trackedDaysMap,
    this.getTrackedDayUsecase,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final weekStart = DiaryWeekStrip.weekStartOf(selectedDate);
    final tracked = <TrackedDayEntity>[
      for (var i = 0; i < 7; i++)
        ?trackedDaysMap[DateTime(weekStart.year, weekStart.month, weekStart.day + i).toParsedDay()],
    ];
    final count = tracked.length;
    double sum(double? Function(TrackedDayEntity) pick) => tracked.fold(0.0, (a, t) => a + (pick(t) ?? 0));
    final totals = [
      sum((t) => t.caloriesTracked),
      sum((t) => t.fatTracked),
      sum((t) => t.proteinTracked),
      sum((t) => t.carbsTracked),
    ];

    String line(List<double> v) =>
        '${v[0].round()} ${s.kcalLabel} · ${v[1].round()} g ${s.fatLabel} · '
        '${v[2].round()} g ${s.proteinLabel} · ${v[3].round()} g ${s.carbsLabel}';

    return Semantics(
      identifier: 'diary-week-summary',
      container: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: false,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(s.diaryWeekSummaryTitle),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (count == 0)
              Text(s.diaryWeekSummaryEmpty)
            else ...[
              Text(s.diaryWeekSummaryTotal, style: Theme.of(context).textTheme.labelLarge),
              Text(line(totals)),
              const SizedBox(height: 8),
              Text(s.diaryWeekSummaryAverage, style: Theme.of(context).textTheme.labelLarge),
              Text(line([for (final v in totals) v / count])),
            ],
            const SizedBox(height: 16),
            WeeklyNutrientBars(selectedDate: selectedDate, getTrackedDayUsecase: getTrackedDayUsecase),
          ],
        ),
      ),
    );
  }
}
