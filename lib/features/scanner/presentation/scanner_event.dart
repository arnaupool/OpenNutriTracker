part of 'scanner_bloc.dart';

@immutable
abstract class ScannerEvent extends Equatable {
  const ScannerEvent();

  @override
  List<Object?> get props => [];
}

class ScannerLoadProductEvent extends ScannerEvent {
  final String barcode;

  const ScannerLoadProductEvent({required this.barcode});

  @override
  List<Object?> get props => [barcode];
}

/// Returns to [ScannerInitial] so the screen re-shows the live camera.
/// Used by the "product not found" fallback's "Scan again" action —
/// re-submitting the same barcode string would just fail identically
/// every time, since a 404 from OFF is deterministic, not transient.
class ScannerResetEvent extends ScannerEvent {
  const ScannerResetEvent();
}
