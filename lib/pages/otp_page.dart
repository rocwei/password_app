// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:otp/otp.dart';

import '../helpers/otp_helper.dart';
import '../l10n/l10n.dart';
import 'qr_scanner_page.dart';

typedef OtpTokenLoader = Future<List<OtpToken>> Function();
typedef OtpTokenSaver = Future<void> Function(OtpToken token);
typedef OtpTokenDeleter = Future<void> Function(String id);
typedef OtpScanner =
    Future<Map<String, String>?> Function(BuildContext context);

enum OtpCodeError { emptySecret, invalidSecret }

class OtpCodeResult {
  const OtpCodeResult.success(this.code) : error = null;
  const OtpCodeResult.failure(this.error) : code = null;

  final String? code;
  final OtpCodeError? error;
}

class OtpPage extends StatefulWidget {
  const OtpPage({
    super.key,
    this.loadTokens,
    this.saveToken,
    this.deleteToken,
    this.scanQrCode,
  });

  final OtpTokenLoader? loadTokens;
  final OtpTokenSaver? saveToken;
  final OtpTokenDeleter? deleteToken;
  final OtpScanner? scanQrCode;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpItem {
  const _OtpItem({required this.token, required this.code});

  final OtpToken token;
  final String code;

  _OtpItem withCode(String value) => _OtpItem(token: token, code: value);
}

class _OtpPageState extends State<OtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _secretController = TextEditingController();
  List<_OtpItem> _otpList = [];
  late final Timer _timer;
  int _secondsRemaining = 30;
  bool _isLoading = true;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadOtpTokens();
    });
    _startTimer();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _secretController.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadOtpTokens() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasLoadError = false;
      });
    }

    try {
      final tokens = await (widget.loadTokens ?? OtpHelper.getAllTokens)();
      if (!mounted) return;
      setState(() {
        _otpList = tokens.map((token) {
          final result = generateOtpCode(token.secret);
          return _OtpItem(token: token, code: result.code ?? '------');
        }).toList();
        _isLoading = false;
        _hasLoadError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadError = true;
      });
    }
  }

  void _startTimer() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _secondsRemaining = 30 - ((now ~/ 1000) % 30);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining <= 1) {
          _secondsRemaining = 30;
          _otpList = _otpList.map((item) {
            final result = generateOtpCode(item.token.secret);
            return item.withCode(result.code ?? '------');
          }).toList();
        } else {
          _secondsRemaining--;
        }
      });
    });
  }

  String _generateId() {
    final random = math.Random();
    return '${DateTime.now().millisecondsSinceEpoch}${random.nextInt(1000)}';
  }

  String cleanOtpSecret(String secret) {
    if (secret.isEmpty) return '';
    var cleaned = secret.replaceAll(RegExp(r'\s|-|='), '');
    cleaned = cleaned.replaceAll(RegExp(r'[^A-Za-z2-7]'), '').toUpperCase();
    return cleaned;
  }

  OtpCodeResult generateOtpCode(String secret) {
    if (secret.isEmpty) {
      return const OtpCodeResult.failure(OtpCodeError.emptySecret);
    }

    final cleanedSecret = cleanOtpSecret(secret);
    if (cleanedSecret.isEmpty) {
      return const OtpCodeResult.failure(OtpCodeError.invalidSecret);
    }

    try {
      final code = OTP.generateTOTPCodeString(
        cleanedSecret,
        DateTime.now().millisecondsSinceEpoch,
        length: 6,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      return OtpCodeResult.success(code);
    } catch (_) {
      return const OtpCodeResult.failure(OtpCodeError.invalidSecret);
    }
  }

  Future<void> _addOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cleanedSecret = cleanOtpSecret(_secretController.text);
    final duplicate = _otpList.any(
      (item) => item.token.secret == cleanedSecret,
    );
    if (duplicate) {
      _showMessage(context.l10n.duplicateOtpSecret, isWarning: true);
      return;
    }

    final codeResult = generateOtpCode(cleanedSecret);
    if (codeResult.error != null) {
      _showMessage(context.l10n.invalidOtpCode, isError: true);
      return;
    }

    final token = OtpToken(
      id: _generateId(),
      label: _labelController.text,
      secret: cleanedSecret,
    );

    try {
      await (widget.saveToken ?? OtpHelper.saveToken)(token);
      if (!mounted) return;
      setState(() {
        _otpList.add(_OtpItem(token: token, code: codeResult.code!));
        _labelController.clear();
        _secretController.clear();
      });
      Navigator.of(context).pop();
      _showMessage(context.l10n.otpAdded);
    } catch (_) {
      if (!mounted) return;
      _showMessage(context.l10n.otpAddFailed, isError: true);
    }
  }

  Future<void> _deleteOtp(String id) async {
    final token = _otpList
        .map((item) => item.token)
        .where((item) => item.id == id)
        .firstOrNull;
    final tokenName = token?.label ?? context.l10n.unknownOtpAccount;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            final l10n = dialogContext.l10n;
            return AlertDialog(
              title: Text(l10n.otpDeleteTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.otpDeleteConfirmation(tokenName)),
                  const SizedBox(height: 16),
                  Text(l10n.actionCannotBeUndone),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(l10n.delete),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!mounted || !confirmed) return;

    try {
      await (widget.deleteToken ?? OtpHelper.deleteToken)(id);
      if (!mounted) return;
      setState(() => _otpList.removeWhere((item) => item.token.id == id));
      _showMessage(context.l10n.otpDeleted(tokenName));
    } catch (_) {
      if (!mounted) return;
      _showMessage(context.l10n.otpDeleteFailed, isError: true);
    }
  }

  Future<void> _copyOtpCode(String code) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      _showMessage(context.l10n.otpCodeCopied);
    } catch (_) {
      if (!mounted) return;
      _showMessage(context.l10n.otpCopyFailed, isError: true);
    }
  }

  void _showAddOtpDialog() {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.addOtp),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _labelController,
                  decoration: InputDecoration(
                    labelText: l10n.accountName,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.accountNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _secretController,
                  decoration: InputDecoration(
                    labelText: l10n.secretKey,
                    border: const OutlineInputBorder(),
                    helperText: l10n.secretKeyHelper,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: l10n.scanQrCode,
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _scanQrCode();
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.secretKeyRequired;
                    }
                    final cleanedValue = cleanOtpSecret(value);
                    if (cleanedValue.isEmpty) return l10n.secretKeyInvalid;
                    if (cleanedValue.length < 8) return l10n.secretKeyTooShort;
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(onPressed: _addOtp, child: Text(l10n.addOtp)),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _openQrScanner(BuildContext context) {
    return Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
  }

  Future<void> _scanQrCode() async {
    try {
      final result = await (widget.scanQrCode ?? _openQrScanner)(context);
      if (!mounted || result == null) return;

      _labelController.text = result['label'] ?? '';
      _secretController.text = result['secret'] ?? '';
      _showAddOtpDialog();
    } catch (_) {
      if (!mounted) return;
      _showMessage(context.l10n.otpScanFailed, isError: true);
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? colorScheme.error
            : isWarning
            ? Colors.orange
            : colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.oneTimePassword),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadOtpTokens,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.retry,
          ),
        ],
      ),
      body: Column(
        children: [
          Semantics(
            label: l10n.otpRefreshCountdown,
            value: l10n.secondsRemaining(_secondsRemaining),
            child: LinearProgressIndicator(
              value: _secondsRemaining / 30,
              color: _secondsRemaining <= 5
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.2),
              minHeight: 4,
            ),
          ),
          Expanded(child: _buildContent(context)),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'scan_qr',
            onPressed: _scanQrCode,
            tooltip: l10n.scanQrCode,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_otp',
            onPressed: _showAddOtpDialog,
            icon: const Icon(Icons.add),
            label: Text(l10n.addOtp),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading && _otpList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasLoadError && _otpList.isEmpty) {
      return _buildLoadError(context);
    }
    if (_hasLoadError) {
      return Column(
        children: [
          _buildLoadErrorBanner(context),
          Expanded(child: _buildOtpList(context)),
        ],
      );
    }
    if (_otpList.isEmpty) return _buildEmptyState(context);
    return _buildOtpList(context);
  }

  Widget _buildLoadError(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              l10n.otpLoadFailed,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadOtpTokens,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadErrorBanner(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.otpLoadFailed,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: _loadOtpTokens, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noOtpAccounts,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noOtpAccountsDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpList(BuildContext context) {
    final l10n = context.l10n;
    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _otpList.length,
        itemBuilder: (context, index) {
          final item = _otpList[index];
          return Slidable(
            key: ValueKey(item.token.id),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.25,
              children: [
                CustomSlidableAction(
                  onPressed: (_) => _deleteOtp(item.token.id),
                  foregroundColor: Colors.white,
                  child: Container(
                    height: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete, color: Colors.white, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          l10n.delete,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            child: Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.token.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      item.code,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: l10n.copyOtpCode,
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () => _copyOtpCode(item.code),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
