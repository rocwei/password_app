import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/l10n.dart';

typedef QrScannerBuilder = Widget Function(BuildContext context);

enum OtpUriParseError { malformed, notOtpAuth, missingSecret, invalidSecret }

class OtpUriData {
  const OtpUriData({
    required this.label,
    required this.secret,
    required this.path,
    required this.issuer,
  });

  final String label;
  final String secret;
  final String path;
  final String? issuer;
}

class OtpUriParseResult {
  const OtpUriParseResult.success(this.data) : error = null;
  const OtpUriParseResult.failure(this.error) : data = null;

  final OtpUriData? data;
  final OtpUriParseError? error;
}

OtpUriParseResult parseOtpUri(String rawValue) {
  try {
    if (RegExp(r'%(?![0-9A-Fa-f]{2})').hasMatch(rawValue)) {
      return const OtpUriParseResult.failure(OtpUriParseError.malformed);
    }
    final otpUri = Uri.tryParse(rawValue);
    if (otpUri == null) {
      return const OtpUriParseResult.failure(OtpUriParseError.malformed);
    }
    if (otpUri.scheme != 'otpauth') {
      return const OtpUriParseResult.failure(OtpUriParseError.notOtpAuth);
    }

    final rawSecret = otpUri.queryParameters['secret'];
    if (rawSecret == null || rawSecret.isEmpty) {
      return const OtpUriParseResult.failure(OtpUriParseError.missingSecret);
    }

    final secret = rawSecret
        .replaceAll(RegExp(r'[^A-Za-z2-7]'), '')
        .toUpperCase();
    if (secret.isEmpty) {
      return const OtpUriParseResult.failure(OtpUriParseError.invalidSecret);
    }

    final encodedPath = otpUri.path.startsWith('/')
        ? otpUri.path.substring(1)
        : otpUri.path;
    final path = Uri.decodeComponent(encodedPath);
    final issuer = otpUri.queryParameters['issuer'];
    final label = issuer != null && issuer.isNotEmpty
        ? '$issuer - $path'
        : path;

    return OtpUriParseResult.success(
      OtpUriData(label: label, secret: secret, path: path, issuer: issuer),
    );
  } on FormatException {
    return const OtpUriParseResult.failure(OtpUriParseError.malformed);
  } catch (_) {
    return const OtpUriParseResult.failure(OtpUriParseError.malformed);
  }
}

class QrScannerCameraError extends StatelessWidget {
  const QrScannerCameraError({super.key, required this.errorCode});

  final MobileScannerErrorCode errorCode;

  @override
  Widget build(BuildContext context) {
    final message = errorCode == MobileScannerErrorCode.permissionDenied
        ? context.l10n.cameraPermissionRequired
        : context.l10n.cameraUnavailable;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key, this.scannerBuilder});

  final QrScannerBuilder? scannerBuilder;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;
      setState(() => _isProcessing = true);
      _processOtpUri(rawValue);
      break;
    }
  }

  void _processOtpUri(String rawValue) {
    final result = parseOtpUri(rawValue);
    final data = result.data;
    if (data == null) {
      _showParseError(result.error ?? OtpUriParseError.malformed);
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(<String, String>{
      'label': data.label,
      'secret': data.secret,
      'issuer': data.issuer ?? '',
      'path': data.path,
    });
  }

  void _showParseError(OtpUriParseError error) {
    if (!mounted) return;
    final l10n = context.l10n;
    final message = switch (error) {
      OtpUriParseError.missingSecret => l10n.otpQrMissingSecret,
      OtpUriParseError.invalidSecret => l10n.otpQrInvalidSecret,
      OtpUriParseError.malformed ||
      OtpUriParseError.notOtpAuth => l10n.invalidOtpQrCode,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
    final scannerBuilder = widget.scannerBuilder;
    if (scannerBuilder != null) return scannerBuilder(context);

    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (context, error, child) {
        return QrScannerCameraError(errorCode: error.errorCode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanQrCode),
        elevation: 0,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                );
              },
            ),
            tooltip: l10n.toggleTorch,
            onPressed: _controller.toggleTorch,
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller.cameraFacingState,
              builder: (context, state, child) {
                return Icon(
                  state == CameraFacing.front
                      ? Icons.camera_front
                      : Icons.camera_rear,
                );
              },
            ),
            tooltip: l10n.switchCamera,
            onPressed: _controller.switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildScanner(context)),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    l10n.qrScanInstruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Positioned.fill(
              child: Semantics(
                label: l10n.processingQrCode,
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.processingQrCode,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
