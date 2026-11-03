import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:permission_handler/permission_handler.dart';

/// Replaces [MobileScanner]'s default black screen on any camera error.
///
/// - [MobileScannerErrorCode.permissionDenied]: once denied on iOS/macOS/web the app cannot re-request it, so
///   "try again" alone can strand the user. Native builds get a shortcut to the OS settings; on web (no such API)
///   the text says to allow the camera in the browser's site settings.
/// - [MobileScannerErrorCode.unsupported]: no camera (a desktop without a webcam) or no getUserMedia. The screen
///   says so and the caller's manual-entry option stays available next to it.
/// - Anything else gets the generic message and a retry.
class CameraErrorFallback extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onRetry;

  const CameraErrorFallback({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final noCamera = error.errorCode == MobileScannerErrorCode.unsupported;
    final title = denied
        ? s.scannerCameraPermissionDeniedTitle
        : noCamera
        ? s.scannerNoCameraTitle
        : error.errorCode.message;
    final explanation = denied
        ? (kIsWeb ? s.scannerCameraPermissionDeniedWebExplanation : s.scannerCameraPermissionDeniedExplanation)
        : noCamera
        ? s.scannerNoCameraExplanation
        : null;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied || noCamera ? Icons.no_photography_outlined : Icons.error_outline,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              if (explanation != null) ...[
                const SizedBox(height: 8),
                Text(
                  explanation,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              if (denied && !kIsWeb)
                Semantics(
                  identifier: 'scanner-open-settings',
                  child: FilledButton.icon(
                    onPressed: () => unawaited(openAppSettings()),
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(s.scannerOpenSettingsButton),
                  ),
                ),
              const SizedBox(height: 8),
              Semantics(
                identifier: 'scanner-camera-retry',
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_outlined, color: Colors.white),
                  label: Text(s.retryLabel, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
