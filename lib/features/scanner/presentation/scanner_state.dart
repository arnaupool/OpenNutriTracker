part of 'scanner_bloc.dart';

@immutable
abstract class ScannerState extends Equatable {
  const ScannerState();
}

class ScannerInitial extends ScannerState {
  @override
  List<Object> get props => [];
}

class ScannerLoadingState extends ScannerState {
  @override
  List<Object?> get props => [];
}

class ScannerLoadedState extends ScannerState {
  final MealEntity product;
  final bool usesImperialUnits;

  /// Set when the code belongs to a favorite (then [product] is its meal).
  final FavoriteFoodEntity? favorite;

  const ScannerLoadedState({
    required this.product,
    this.usesImperialUnits = false,
    this.favorite,
  });

  @override
  List<Object?> get props => [product, favorite];
}

class ScannerFailedState extends ScannerState {
  final ScannerFailedStateType type;

  const ScannerFailedState(this.type);

  @override
  List<Object?> get props => [type];
}

enum ScannerFailedStateType { productNotFound, error }
