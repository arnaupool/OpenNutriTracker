import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:mobile_scanner/mobile_scanner.dart';

/// Barcode formats a product scan accepts. Retail codes only, so ZXing on web
/// (iOS Safari has no BarcodeDetector) does not waste time on other symbologies.
const List<BarcodeFormat> productBarcodeFormats = [
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
];

/// Product formats plus QR, for screens that also read the app's shared-QR payloads.
const List<BarcodeFormat> productAndQrBarcodeFormats = [...productBarcodeFormats, BarcodeFormat.qrCode];

/// True where `mobile_scanner` has a camera implementation: web (getUserMedia plus the bundled ZXing library),
/// Android, iOS and macOS. Windows and Linux have none, so callers show manual entry only there.
bool cameraScannerSupported() {
  final override = cameraScannerSupportOverride;
  if (override != null) return override;
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// Test hook: forces [cameraScannerSupported] (for example to emulate web). Reset to null after use.
@visibleForTesting
bool? cameraScannerSupportOverride;
