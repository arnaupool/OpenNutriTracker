import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opennutritracker/features/scanner/util/barcode_check_digit.dart';
import 'package:path_provider/path_provider.dart';

/// On-device check of the barcode decoding the Scan Product screen relies
/// on: renders real retail barcodes to PNG, runs them through the same
/// mobile_scanner / ML Kit decoder the camera feed uses
/// (MobileScannerController.analyzeImage), and applies the screen's own
/// acceptance rule (isValidBarcodeCheckDigit). The emulator camera can't be
/// pointed at a printed barcode from a script, so this covers everything
/// after the optical capture.
///
/// Run: `flutter test integration_test/barcode_decode_test.dart --flavor develop -d emulator-5554`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const l = ['0001101', '0011001', '0010011', '0111101', '0100011', '0110001', '0101111', '0111011', '0110111', '0001011'];
  const g = ['0100111', '0110011', '0011011', '0100001', '0011101', '0111001', '0000101', '0010001', '0001001', '0010111'];
  const r = ['1110010', '1100110', '1101100', '1000010', '1011100', '1001110', '1010000', '1000100', '1001000', '1110100'];
  const parity = ['LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG', 'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL'];

  String ean13Modules(String code) {
    final d = code.split('').map(int.parse).toList();
    final b = StringBuffer('101');
    for (var i = 0; i < 6; i++) {
      b.write((parity[d[0]][i] == 'L' ? l : g)[d[i + 1]]);
    }
    b.write('01010');
    for (var i = 7; i < 13; i++) {
      b.write(r[d[i]]);
    }
    b.write('101');
    return b.toString();
  }

  String ean8Modules(String code) {
    final d = code.split('').map(int.parse).toList();
    final b = StringBuffer('101');
    for (var i = 0; i < 4; i++) {
      b.write(l[d[i]]);
    }
    b.write('01010');
    for (var i = 4; i < 8; i++) {
      b.write(r[d[i]]);
    }
    b.write('101');
    return b.toString();
  }

  Future<String> renderPng(String modules, String name) async {
    const scale = 6.0, quiet = 15, height = 300.0;
    final width = (modules.length + 2 * quiet) * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height + 80), Paint()..color = Colors.white);
    final black = Paint()..color = Colors.black;
    for (var i = 0; i < modules.length; i++) {
      if (modules[i] == '1') {
        canvas.drawRect(Rect.fromLTWH((quiet + i) * scale, 40, scale, height), black);
      }
    }
    final image = await recorder.endRecording().toImage(width.toInt(), (height + 80).toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file.path;
  }

  // Real retail codes (Open Food Facts): Nutella 400 g, Coca-Cola 330 ml can,
  // and an 8-digit EAN.
  final cases = {
    '3017620422003': ean13Modules,
    '5449000000996': ean13Modules,
    '96385074': ean8Modules,
  };

  for (final entry in cases.entries) {
    testWidgets('ML Kit decodes ${entry.key} and the scanner accepts it', (tester) async {
      final path = await renderPng(entry.value(entry.key), entry.key);
      final controller = MobileScannerController(autoStart: false);
      final capture = await controller.analyzeImage(path);
      await controller.dispose();

      final values = capture?.barcodes.map((b) => b.rawValue).toList() ?? [];
      expect(values, contains(entry.key));
      expect(isValidBarcodeCheckDigit(entry.key), isTrue);
    });
  }

  testWidgets('a code with a wrong check digit is rejected by the scanner rule', (tester) async {
    expect(isValidBarcodeCheckDigit('3017620422004'), isFalse);
  });
}
