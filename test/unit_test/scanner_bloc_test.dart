import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/scanner/data/product_not_found_exception.dart';
import 'package:opennutritracker/features/scanner/domain/usecase/search_product_by_barcode_usecase.dart';
import 'package:opennutritracker/features/scanner/presentation/scanner_bloc.dart';

class _FakeSearchUseCase implements SearchProductByBarcodeUseCase {
  final MealEntity? result;
  final Object? error;
  _FakeSearchUseCase({this.result, this.error});

  @override
  Future<MealEntity> searchProductByBarcode(String barcode) async {
    if (error != null) throw error!;
    return result!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetConfigUsecase implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(false, false, false, AppThemeEntity.dark);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

final _meal = MealEntity(
  code: '1234567890123',
  name: 'Greek yoghurt',
  url: null,
  mealQuantity: '100',
  mealUnit: 'g',
  servingQuantity: null,
  servingUnit: 'g',
  servingSize: null,
  source: MealSourceEntity.off,
  nutriments: const MealNutrimentsEntity(
    energyKcal100: 100,
    carbohydrates100: 4,
    fat100: 5,
    proteins100: 10,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  ),
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('ScannerBloc', () {
    test('emits ScannerLoadedState on a successful lookup', () async {
      final bloc = ScannerBloc(
        _FakeSearchUseCase(result: _meal),
        _FakeGetConfigUsecase(),
      );
      addTearDown(bloc.close);

      bloc.add(const ScannerLoadProductEvent(barcode: '1234567890123'));
      await _settle();

      expect(bloc.state, isA<ScannerLoadedState>());
      expect((bloc.state as ScannerLoadedState).product.code, '1234567890123');
    });

    test(
      'emits ScannerFailedState(productNotFound) for a genuine 404 '
      '(regression: `exception == ProductNotFoundException` compared the '
      'thrown instance to the Type object and never matched)',
      () async {
        final bloc = ScannerBloc(
          _FakeSearchUseCase(error: ProductNotFoundException()),
          _FakeGetConfigUsecase(),
        );
        addTearDown(bloc.close);

        bloc.add(const ScannerLoadProductEvent(barcode: '0000000000000'));
        await _settle();

        expect(
          bloc.state,
          const ScannerFailedState(ScannerFailedStateType.productNotFound),
        );
      },
    );

    test('emits ScannerFailedState(error) for any other failure', () async {
      final bloc = ScannerBloc(
        _FakeSearchUseCase(error: Exception('network down')),
        _FakeGetConfigUsecase(),
      );
      addTearDown(bloc.close);

      bloc.add(const ScannerLoadProductEvent(barcode: '0000000000000'));
      await _settle();

      expect(
        bloc.state,
        const ScannerFailedState(ScannerFailedStateType.error),
      );
    });

    test(
      'ScannerResetEvent returns to ScannerInitial from a failed state — '
      'the "Scan again" action re-opens the camera instead of re-submitting '
      'the same (deterministically failing) barcode',
      () async {
        final bloc = ScannerBloc(
          _FakeSearchUseCase(error: ProductNotFoundException()),
          _FakeGetConfigUsecase(),
        );
        addTearDown(bloc.close);

        bloc.add(const ScannerLoadProductEvent(barcode: '0000000000000'));
        await _settle();
        expect(
          bloc.state,
          const ScannerFailedState(ScannerFailedStateType.productNotFound),
        );

        bloc.add(const ScannerResetEvent());
        await _settle();

        expect(bloc.state, isA<ScannerInitial>());
      },
    );
  });
}
