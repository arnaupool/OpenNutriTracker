import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/features/diet_plan/data/diet_plan_dbo.dart';
import 'package:opennutritracker/features/diet_plan/domain/diet_plan_calc.dart';

DietPlanDBO _plan({
  DateTime? start,
  double kg = 10,
  double pace = 0.5,
  List<DietPlanPause> pauses = const [],
  DietPlanStatus status = DietPlanStatus.active,
  DietPlanMode mode = DietPlanMode.auto,
}) {
  final s = start ?? DateTime(2026, 10, 27);
  return DietPlanDBO(
    mode: mode,
    startDate: s,
    endDate: DietPlanCalc.autoEnd(s, kg, pace),
    startWeightKg: 80,
    targetLossKg: kg,
    paceKgPerWeek: pace,
    pauses: pauses,
    status: status,
  );
}

void main() {
  group('auto end date', () {
    test('10 kg at 0.5 kg/week from 2026-10-27 lasts 140 days and ends 2027-03-16', () {
      expect(DietPlanCalc.durationDays(10, 0.5), 140);
      expect(_plan().endDate, DateTime(2027, 3, 16));
    });

    test('rounds partial weeks up and ignores float noise', () {
      expect(DietPlanCalc.durationDays(4.5, 0.75), 42);
      expect(DietPlanCalc.durationDays(1, 0.75), 10); // 9.33 -> 10
      expect(DietPlanCalc.durationDays(0.5, 0.25), 14);
      expect(DietPlanCalc.durationDays(0, 0.5), 0);
    });
  });

  group('pauses', () {
    test('pausing 7 days moves the end 7 days later', () {
      final plan = _plan();
      final paused = DietPlanCalc.pause(plan, DateTime(2026, 11, 10));
      final resumed = DietPlanCalc.resume(paused, DateTime(2026, 11, 17));
      expect(resumed.pauses.length, 1);
      expect(DietPlanCalc.pausedDays(resumed.pauses, DateTime(2026, 11, 20)), 7);
      expect(DietPlanCalc.effectiveEnd(resumed, DateTime(2026, 11, 20)), DateTime(2027, 3, 23));
    });

    test('an open pause keeps the end moving and reports paused', () {
      final paused = DietPlanCalc.pause(_plan(), DateTime(2026, 11, 10));
      expect(DietPlanCalc.isPaused(paused), isTrue);
      expect(DietPlanCalc.statusAt(paused, DateTime(2026, 11, 13)), DietPlanStatus.paused);
      expect(DietPlanCalc.effectiveEnd(paused, DateTime(2026, 11, 13)), DateTime(2027, 3, 19));
      // The days left stay fixed while paused.
      expect(
        DietPlanCalc.daysLeft(paused, DateTime(2026, 11, 13)),
        DietPlanCalc.daysLeft(paused, DateTime(2026, 11, 20)),
      );
    });

    test('pause and resume are no-ops when they do not apply', () {
      final plan = _plan();
      expect(identical(DietPlanCalc.resume(plan, DateTime(2026, 11, 1)), plan), isTrue);
      final paused = DietPlanCalc.pause(plan, DateTime(2026, 11, 1));
      expect(identical(DietPlanCalc.pause(paused, DateTime(2026, 11, 2)), paused), isTrue);
    });
  });

  group('days left and status', () {
    test('countdown decreases by exactly 1 at local midnight', () {
      final plan = _plan();
      final before = DietPlanCalc.daysLeft(plan, DateTime(2026, 11, 1, 23, 59, 59));
      final after = DietPlanCalc.daysLeft(plan, DateTime(2026, 11, 2, 0, 0, 0));
      expect(before - after, 1);
      expect(
        DietPlanCalc.daysLeft(plan, DateTime(2026, 11, 2, 0, 0, 0)),
        DietPlanCalc.daysLeft(plan, DateTime(2026, 11, 2, 23, 59)),
      );
    });

    test('counts calendar days across a DST change', () {
      final plan = _plan(start: DateTime(2027, 3, 20), kg: 1, pace: 0.5); // ends 2027-04-03
      expect(DietPlanCalc.daysLeft(plan, DateTime(2027, 3, 27)), 7);
      expect(DietPlanCalc.daysLeft(plan, DateTime(2027, 3, 29)), 5);
    });

    test('is active through the end day and finished the day after', () {
      final plan = _plan();
      expect(DietPlanCalc.daysLeft(plan, DateTime(2027, 3, 16, 22)), 0);
      expect(DietPlanCalc.statusAt(plan, DateTime(2027, 3, 16, 22)), DietPlanStatus.active);
      expect(DietPlanCalc.statusAt(plan, DateTime(2027, 3, 17)), DietPlanStatus.finished);
      expect(DietPlanCalc.isFinished(plan, DateTime(2027, 3, 17)), isTrue);
    });

    test('a plan marked finished stays finished', () {
      final plan = _plan(status: DietPlanStatus.finished);
      expect(DietPlanCalc.statusAt(plan, DateTime(2026, 11, 1)), DietPlanStatus.finished);
    });
  });

  group('progress', () {
    test('is elapsed active days over total, clamped', () {
      final plan = _plan();
      expect(DietPlanCalc.progress(plan, DateTime(2026, 10, 20)), 0);
      expect(DietPlanCalc.progress(plan, DateTime(2026, 11, 26)), closeTo(30 / 140, 1e-9));
      expect(DietPlanCalc.progress(plan, DateTime(2028, 1, 1)), 1);
    });

    test('paused days do not count as elapsed', () {
      final paused = DietPlanCalc.pause(_plan(), DateTime(2026, 11, 10)); // 14 days in
      expect(DietPlanCalc.progress(paused, DateTime(2026, 11, 10)), closeTo(14 / 140, 1e-9));
      expect(DietPlanCalc.progress(paused, DateTime(2026, 11, 20)), closeTo(14 / 140, 1e-9));
    });
  });

  group('editing', () {
    test('recomputeAuto follows kg and pace; manual plans are untouched', () {
      final plan = _plan().copyWith(targetLossKg: 5);
      expect(DietPlanCalc.recomputeAuto(plan).endDate, DateTime(2027, 1, 5)); // 70 days
      final manual = _plan(mode: DietPlanMode.manual).copyWith(targetLossKg: 5);
      expect(DietPlanCalc.recomputeAuto(manual).endDate, manual.endDate);
    });

    test('withEffectiveEnd sets the visible end whatever the pauses', () {
      final resumed = DietPlanCalc.resume(DietPlanCalc.pause(_plan(), DateTime(2026, 11, 10)), DateTime(2026, 11, 17));
      final moved = DietPlanCalc.withEffectiveEnd(resumed, DateTime(2027, 6, 1), DateTime(2026, 11, 20));
      expect(DietPlanCalc.effectiveEnd(moved, DateTime(2026, 11, 20)), DateTime(2027, 6, 1));
    });
  });

  group('weight', () {
    final today = DateTime(2026, 12, 1);
    WeightPoint p(int daysAgo, double kg) => (date: DietPlanCalc.addDays(today, -daysAgo), weightKg: kg);

    test('windowAverage covers the last 7 days inclusive', () {
      final points = [p(0, 80), p(6, 82), p(7, 100)];
      expect(DietPlanCalc.windowAverage(points, today), 81);
      expect(DietPlanCalc.windowAverage([p(7, 90)], today), isNull);
    });

    test('goalReached uses the loss target from the start weight', () {
      final plan = _plan(); // 80 kg start, lose 10
      expect(DietPlanCalc.goalReached(plan, 70.0), isTrue);
      expect(DietPlanCalc.goalReached(plan, 70.4), isFalse);
      expect(DietPlanCalc.goalReached(plan, null), isFalse);
      expect(DietPlanCalc.lostKg(plan, 75.5), 4.5);
    });

    test('stalled when the average is not lower than 21 days ago', () {
      final plan = _plan(start: DietPlanCalc.addDays(today, -60));
      expect(DietPlanCalc.isStalled(plan, today, [p(0, 80), p(21, 80)]), isTrue);
      expect(DietPlanCalc.isStalled(plan, today, [p(0, 81), p(21, 80)]), isTrue);
      expect(DietPlanCalc.isStalled(plan, today, [p(0, 79.5), p(21, 80)]), isFalse);
      expect(DietPlanCalc.isStalled(plan, today, [p(0, 80)]), isFalse);
    });

    test('a plan younger than 21 days is never stalled', () {
      final plan = _plan(start: DietPlanCalc.addDays(today, -10));
      expect(DietPlanCalc.isStalled(plan, today, [p(0, 80), p(21, 80)]), isFalse);
    });
  });

  group('storage', () {
    test('json round trip keeps every field, including an open pause', () {
      final plan = DietPlanCalc.pause(_plan(), DateTime(2026, 11, 10)).copyWith(showCountdown: false);
      final back = DietPlanDBO.fromJson(plan.toJson());
      expect(back.toJson(), plan.toJson());
      expect(back.pauses.single.to, isNull);
      expect(back.showCountdown, isFalse);
      expect(back.status, DietPlanStatus.paused);
    });

    test('hive adapter round trip', () async {
      final dir = await Directory.systemTemp.createTemp('diet_plan_hive');
      addTearDown(() => dir.delete(recursive: true));
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(DietPlanDBO.hiveTypeId)) Hive.registerAdapter(DietPlanDBOAdapter());
      final plan = DietPlanCalc.resume(DietPlanCalc.pause(_plan(), DateTime(2026, 11, 10)), DateTime(2026, 11, 17));
      final box = await Hive.openBox<DietPlanDBO>('DietPlanBoxTest');
      await box.put(DietPlanDBO.boxKey, plan);
      await box.close();
      final reopened = await Hive.openBox<DietPlanDBO>('DietPlanBoxTest');
      expect(reopened.get(DietPlanDBO.boxKey)!.toJson(), plan.toJson());
      await reopened.close();
    });
  });
}
