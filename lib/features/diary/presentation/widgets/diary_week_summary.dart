import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_panel.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_week_strip.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/weekly_nutrient_bars.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Phone-width weekly section of the Diary: a card that is COLLAPSED by
/// default and, once opened, shows total and per-tracked-day average kcal and
/// macros of the week of [selectedDate] (computed from [trackedDaysMap], the
/// same data the day markers use) followed by the weekly bar charts.
class DiaryWeekSummary extends StatelessWidget {
  static String _capitalize(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

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

    return Semantics(
      identifier: 'diary-week-summary',
      container: true,
      child: DiaryPanel(
        padding: EdgeInsets.zero,
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
              for (final macro in [
                (s.kcalLabel, s.kcalLabel, totals[0]),
                (s.fatLabel, 'g', totals[1]),
                (s.proteinLabel, 'g', totals[2]),
                (s.carbsLabel, 'g', totals[3]),
              ]) ...[
                DiaryPanelRow(
                  child: Row(
                    children: [
                      Expanded(child: Text(_capitalize(macro.$1), style: Theme.of(context).textTheme.labelLarge)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${s.diaryWeekSummaryTotal}: ${macro.$3.round()} ${macro.$2}'),
                          Text(
                            '${s.diaryWeekSummaryAverage}: ${(macro.$3 / count).round()} ${macro.$2}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 16),
            WeeklyNutrientBars(selectedDate: selectedDate, getTrackedDayUsecase: getTrackedDayUsecase, framed: false),
          ],
        ),
      ),
    );
  }
}
