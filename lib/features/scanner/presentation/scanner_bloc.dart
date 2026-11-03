import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_entity.dart';
import 'package:opennutritracker/features/favorites/domain/favorite_food_repository.dart';
import 'package:opennutritracker/features/scanner/data/product_not_found_exception.dart';
import 'package:opennutritracker/features/scanner/domain/usecase/search_product_by_barcode_usecase.dart';

part 'scanner_event.dart';

part 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final SearchProductByBarcodeUseCase _searchProductUseCase;
  final GetConfigUsecase _getConfigUsecase;
  final FavoriteFoodRepository? _favorites;

  ScannerBloc(this._searchProductUseCase, this._getConfigUsecase, [this._favorites])
      : super(ScannerInitial()) {
    on<ScannerLoadProductEvent>((event, emit) async {
      emit(ScannerLoadingState());

      try {
        // A favorite that carries the code wins over every other source;
        // the screen offers a way to the original product.
        final favorite = _favorites?.findByBarcode(event.barcode);
        if (favorite != null) {
          final config = await _getConfigUsecase.getConfig();
          emit(
            ScannerLoadedState(
              product: favorite.toMealEntity(),
              usesImperialUnits: config.usesImperialUnits,
              favorite: favorite,
            ),
          );
          return;
        }
        final meal = await _searchProductUseCase.searchProductByBarcode(
          event.barcode,
        );
        final config = await _getConfigUsecase.getConfig();
        emit(
          ScannerLoadedState(
            product: meal,
            usesImperialUnits: config.usesImperialUnits,
          ),
        );
      } catch (exception) {
        if (exception is ProductNotFoundException) {
          emit(
            const ScannerFailedState(ScannerFailedStateType.productNotFound),
          );
        } else {
          emit(const ScannerFailedState(ScannerFailedStateType.error));
        }
      }
    });

    on<ScannerResetEvent>((event, emit) => emit(ScannerInitial()));
  }
}
