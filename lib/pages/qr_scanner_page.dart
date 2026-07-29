import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/l10n.dart';

typedef QrScannerBuilder =
    Widget Function(
      BuildContext context,
      void Function(BarcodeCapture capture) onDetect,
    );
typedef CameraAction = Future<void> Function();

enum OtpUriParseError {
  malformed,
  notOtpAuth,
  unsupportedType,
  missingSecret,
  invalidSecret,
}

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
    if (otpUri.host.toLowerCase() != 'totp') {
      return const OtpUriParseResult.failure(OtpUriParseError.unsupportedType);
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

OtpUriParseResult parseOtpCapture(BarcodeCapture capture) {
  OtpUriParseResult? firstFailure;
  for (final barcode in capture.barcodes) {
    final rawValue = barcode.rawValue;
    if (rawValue == null) continue;
    final result = parseOtpUri(rawValue);
    if (result.data != null) return result;
    firstFailure ??= result;
  }
  return firstFailure ??
      const OtpUriParseResult.failure(OtpUriParseError.malformed);
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
  const QrScannerPage({
    super.key,
    this.scannerBuilder,
    this.initialCameraErrorCode,
    this.toggleTorch,
    this.switchCamera,
    this.now,
  });

  final QrScannerBuilder? scannerBuilder;
  final MobileScannerErrorCode? initialCameraErrorCode;
  final CameraAction? toggleTorch;
  final CameraAction? switchCamera;
  final DateTime Function()? now;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  MobileScannerErrorCode? _cameraErrorCode;
  DateTime? _lastRejectedAt;

  @override
  void initState() {
    super.initState();
    _cameraErrorCode = widget.initialCameraErrorCode;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final result = parseOtpCapture(capture);
    final data = result.data;
    if (data == null) {
      _showParseErrorOnce(result.error ?? OtpUriParseError.malformed);
      return;
    }

    setState(() => _isProcessing = true);

    if (!mounted) return;
    Navigator.of(context).pop(<String, String>{
      'label': data.label,
      'secret': data.secret,
      'issuer': data.issuer ?? '',
      'path': data.path,
    });
  }

  void _showParseErrorOnce(OtpUriParseError error) {
    final now = (widget.now ?? DateTime.now)();
    final recentlyRejected =
        _lastRejectedAt != null &&
        now.difference(_lastRejectedAt!) < const Duration(seconds: 2);
    if (recentlyRejected) return;

    _lastRejectedAt = now;
    _showParseError(error);
  }

  void _showParseError(OtpUriParseError error) {
    if (!mounted) return;
    final l10n = context.l10n;
    final message = switch (error) {
      OtpUriParseError.missingSecret => l10n.otpQrMissingSecret,
      OtpUriParseError.invalidSecret => l10n.otpQrInvalidSecret,
      OtpUriParseError.malformed ||
      OtpUriParseError.notOtpAuth ||
      OtpUriParseError.unsupportedType => l10n.invalidOtpQrCode,
    };
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
    final scannerBuilder = widget.scannerBuilder;
    if (scannerBuilder != null) return scannerBuilder(context, _onDetect);

    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (context, error, child) {
        _recordCameraError(error.errorCode);
        return QrScannerCameraError(errorCode: error.errorCode);
      },
    );
  }

  void _recordCameraError(MobileScannerErrorCode errorCode) {
    if (_cameraErrorCode == errorCode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _cameraErrorCode == errorCode) return;
      setState(() => _cameraErrorCode = errorCode);
    });
  }

  Future<void> _handleCameraAction(CameraAction action) async {
    if (_cameraErrorCode != null) return;
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraErrorCode = MobileScannerErrorCode.genericError;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.cameraUnavailable),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
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
            onPressed: _cameraErrorCode == null
                ? () => _handleCameraAction(
                    widget.toggleTorch ?? _controller.toggleTorch,
                  )
                : null,
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
            onPressed: _cameraErrorCode == null
                ? () => _handleCameraAction(
                    widget.switchCamera ?? _controller.switchCamera,
                  )
                : null,
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
