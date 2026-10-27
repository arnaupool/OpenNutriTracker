// Seeds five weeks of demo data (weigh-ins, meals, daily goals) into a sync
// set, for trying the desktop review and planning screens on a test device.
// Skipped unless SYNC_SEED_URL, SYNC_SEED_KEY (anon / publishable key) and
// SYNC_SEED_CODE (a sync code from Settings > Sync between devices on a TEST
// device) are set. Never point it at your real sync code: it adds entries.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/sync/sync_boxes.dart';
import 'package:opennutritracker/core/sync/sync_engine.dart';
import 'package:opennutritracker/core/sync/sync_pairing.dart';
import 'package:opennutritracker/core/sync/sync_remote.dart';
import 'package:opennutritracker/core/sync/sync_state_store.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/features/meal_plan/data/meal_plan_entry_dbo.dart';
import 'package:opennutritracker/features/reminders/data/reminder_dbo.dart';
import 'package:opennutritracker/hive_registrar.g.dart';

final _url = Platform.environment['SYNC_SEED_URL'];
final _key = Platform.environment['SYNC_SEED_KEY'];
final _code = Platform.environment['SYNC_SEED_CODE'];

MealDBO _meal(String name, double kcal100, double p, double c, double f) => MealDBO(
  code: null,
  name: name,
  brands: null,
  thumbnailImageUrl: null,
  mainImageUrl: null,
  url: null,
  mealQuantity: '100',
  mealUnit: 'g',
  servingQuantity: null,
  servingUnit: null,
  servingSize: null,
  source: MealSourceDBO.custom,
  nutriments: MealNutrimentsDBO(
    energyKcal100: kcal100,
    carbohydrates100: c,
    fat100: f,
    proteins100: p,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  ),
);

void main() {
  final skip = _url == null || _key == null || _code == null ? 'set SYNC_SEED_URL, SYNC_SEED_KEY, SYNC_SEED_CODE' : null;

  setUpAll(() {
    Hive.registerAdapters();
    Hive.registerAdapter(MealPlanEntryDBOAdapter());
    Hive.registerAdapter(ReminderDBOAdapter());
    Hive.registerAdapter(ReminderSettingsDBOAdapter());
  });

  test('seed demo data', () async {
    final pairing = SyncPairing.tryParse(_code!)!;
    Future<Box<T>> open<T>(String name) => Hive.openBox<T>('seed-$name', bytes: Uint8List(0));
    final db = HiveDBProvider()
      ..configBox = await open('config')
      ..userBox = await open('user')
      ..intakeBox = await open('intake')
      ..userActivityBox = await open('activity')
      ..trackedDayBox = await open('tracked')
      ..customMealBox = await open('custom')
      ..recipeBox = await open('recipe')
      ..customActivityTemplateBox = await open('template')
      ..weightLogBox = await open('weight')
      ..waterIntakeBox = await open('water')
      ..fastingBox = await open('fasting')
      ..bodyMeasurementBox = await open('body')
    ..mealPlanBox = await open('plan')
    ..dietPlanBox = await open('diet_plan')
    ..reminderBox = await open('reminders')
    ..reminderSettingsBox = await open('reminder_settings');

    final random = Random(7);
    final today = DateTime.now();
    final meals = [
      (IntakeTypeDBO.breakfast, _meal('Avena con leche', 120, 5, 18, 3), 300.0, 8),
      (IntakeTypeDBO.lunch, _meal('Arroz con pollo', 160, 12, 20, 4), 450.0, 14),
      (IntakeTypeDBO.dinner, _meal('Tortilla de patatas', 190, 7, 14, 12), 300.0, 21),
      (IntakeTypeDBO.snack, _meal('Yogur griego', 97, 9, 4, 5), 170.0, 17),
    ];
    for (var back = 34; back >= 0; back--) {
      final day = DateTime(today.year, today.month, today.day).subtract(Duration(days: back));
      final key = DateFormat('yyyy-MM-dd').format(day);
      // ~0.4 kg/week loss with scale noise; a few skipped weigh-ins.
      if (back % 6 != 3) {
        final kg = 80 - (34 - back) * 0.06 + (random.nextDouble() - 0.5) * 0.8;
        await db.weightLogBox.put(key, WeightLogDBO(date: day, weightKg: double.parse(kg.toStringAsFixed(1))));
      }
      await db.trackedDayBox.put(
        key,
        TrackedDayDBO(day: day, calorieGoal: 2300, caloriesTracked: 0, carbsGoal: 260, fatGoal: 75, proteinGoal: 150),
      );
      for (final (i, m) in meals.indexed) {
        final amount = m.$3 * (0.8 + random.nextDouble() * 0.4);
        await db.intakeBox.add(
          IntakeDBO(
            id: 'demo-$key-$i',
            unit: 'g',
            amount: double.parse(amount.toStringAsFixed(0)),
            type: m.$1,
            meal: m.$2,
            dateTime: day.add(Duration(hours: m.$4)),
          ),
        );
      }
    }

    final engine = SyncEngine(
      boxes: buildSyncedBoxes(db),
      remote: SupabaseSyncRemote(_url!, _key!),
      state: SyncStateStore(await open<dynamic>('state')),
    );
    final result = await engine.sync(pairing);
    // ignore: avoid_print
    print('seeded: pushed ${result.pushed}, pulled ${result.pulled}');
    expect(result.pushed, greaterThan(100));
  }, skip: skip);
}
