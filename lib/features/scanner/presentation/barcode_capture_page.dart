import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opennutritracker/features/scanner/presentation/camera_error_fallback.dart';
import 'package:opennutritracker/features/scanner/util/camera_scanner_support.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// True for a code the favorites accept: 8 to 14 digits.
bool isPlausibleBarcode(String code) => RegExp(r'^\d{8,14}$').hasMatch(code);

/// Scans (or takes typed) a barcode and pops it as a `String`. Used to add
/// codes to a favorite. The rear camera opens first (on web too, through
/// getUserMedia); typing the code is the secondary option below it, and the
/// only one when the camera is missing or denied.
class BarcodeCapturePage extends StatefulWidget {
  const BarcodeCapturePage({super.key});

  @override
  State<BarcodeCapturePage> createState() => _BarcodeCapturePageState();
}

class _BarcodeCapturePageState extends State<BarcodeCapturePage> {
  final _typed = TextEditingController();
  MobileScannerController? _camera;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (cameraScannerSupported()) {
      _camera = MobileScannerController(facing: CameraFacing.back, formats: productBarcodeFormats);
    }
  }

  @override
  void dispose() {
    _typed.dispose();
    final camera = _camera;
    if (camera != null) unawaited(camera.dispose());
    super.dispose();
  }

  void _finish(String code) {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && isPlausibleBarcode(raw)) {
        _finish(raw);
        return;
      }
    }
  }

  void _submitTyped() {
    final code = _typed.text.trim();
    if (!isPlausibleBarcode(code)) {
      setState(() => _error = S.of(context).customMealBarcodeInvalid);
      return;
    }
    _finish(code);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(title: Text(s.favoriteBarcodeCaptureTitle)),
      body: Column(
        children: [
          if (camera != null)
            Expanded(
              child: MobileScanner(
                controller: camera,
                onDetect: _onDetect,
                errorBuilder: (context, error) =>
                    CameraErrorFallback(error: error, onRetry: () => unawaited(camera.start())),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    identifier: 'barcode-capture-field',
                    child: TextField(
                      controller: _typed,
                      autofocus: camera == null,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
                      decoration: InputDecoration(hintText: s.favoriteBarcodeAddHint, errorText: _error),
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _submitTyped(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  identifier: 'barcode-capture-submit',
                  child: FilledButton(onPressed: _submitTyped, child: Text(s.favoriteBarcodeAdd)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
