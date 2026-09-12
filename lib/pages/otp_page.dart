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
typedef OtpTokenReportLoader = Future<OtpLoadResult> Function();
typedef OtpTokenSaver = Future<void> Function(OtpToken token);
typedef OtpTokenDeleter = Future<void> Function(String id);
typedef OtpScanner =
    Future<Map<String, String>?> Function(BuildContext context);
typedef OtpClock = DateTime Function();
typedef OtpTickerFactory = OtpTicker Function(VoidCallback callback);
typedef OtpCodeGenerator = OtpCodeResult Function(String secret, int timestamp);

abstract interface class OtpTicker {
  void cancel();
}

class _PeriodicOtpTicker implements OtpTicker {
  _PeriodicOtpTicker(VoidCallback callback)
    : _timer = Timer.periodic(const Duration(seconds: 1), (_) => callback());

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

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
    this.loadTokenReport,
    this.saveToken,
    this.deleteToken,
    this.scanQrCode,
    this.now,
    this.tickerFactory,
    this.codeGenerator,
  });

  final OtpTokenLoader? loadTokens;
  final OtpTokenReportLoader? loadTokenReport;
  final OtpTokenSaver? saveToken;
  final OtpTokenDeleter? deleteToken;
  final OtpScanner? scanQrCode;
  final OtpClock? now;
  final OtpTickerFactory? tickerFactory;
  final OtpCodeGenerator? codeGenerator;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpItem {
  const _OtpItem({required this.token, required this.code});

  final OtpToken token;
  final String code;

  _OtpItem withCode(String value) => _OtpItem(token: token, code: value);
}

class _OtpPageState extends State<OtpPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _secretController = TextEditingController();
  List<_OtpItem> _otpList = [];
  late final OtpTicker _ticker;
  int? _timeWindow;
  int _secondsRemaining = 30;
  bool _isLoading = true;
  bool _hasLoadError = false;
  bool _isSavingOtp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncOtpTime(notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadOtpTokens();
    });
    _ticker = (widget.tickerFactory ?? _createTicker)(_onTick);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _labelController.dispose();
    _secretController.dispose();
    _ticker.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncOtpTime();
    }
  }

  OtpTicker _createTicker(VoidCallback callback) {
    return _PeriodicOtpTicker(callback);
  }

  DateTime _now() => (widget.now ?? DateTime.now)();

  void _onTick() => _syncOtpTime();

  void _syncOtpTime({bool notify = true}) {
    final epochSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    final timeWindow = epochSeconds ~/ 30;
    final secondsRemaining = 30 - (epochSeconds % 30);
    final refreshCodes = _timeWindow != null && _timeWindow != timeWindow;
    _timeWindow = timeWindow;

    List<_OtpItem> updatedItems = _otpList;
    if (refreshCodes) {
      updatedItems = _otpList.map((item) {
        final result = _generateOtpCode(item.token.secret);
        return item.withCode(result.code ?? '------');
      }).toList();
    }

    if (!notify) {
      _secondsRemaining = secondsRemaining;
      _otpList = updatedItems;
      return;
    }
    if (!mounted) return;
    setState(() {
      _secondsRemaining = secondsRemaining;
      _otpList = updatedItems;
    });
  }

  Future<void> _loadOtpTokens() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasLoadError = false;
      });
    }

    try {
      final OtpLoadResult loadResult;
      if (widget.loadTokenReport case final loadTokenReport?) {
        loadResult = await loadTokenReport();
      } else if (widget.loadTokens case final loadTokens?) {
        loadResult = OtpLoadResult(
          tokens: await loadTokens(),
          skippedLegacyTokenCount: 0,
        );
      } else {
        loadResult = await OtpHelper.getAllTokensWithReport();
      }
      if (!mounted) return;
      setState(() {
        _otpList = loadResult.tokens.map((token) {
          final result = _generateOtpCode(token.secret);
          return _OtpItem(token: token, code: result.code ?? '------');
        }).toList();
        _isLoading = false;
        _hasLoadError = false;
      });
      if (loadResult.skippedLegacyTokenCount > 0) {
        _showMessage(
          context.l10n.otpLegacyAccountsSkipped(
            loadResult.skippedLegacyTokenCount,
          ),
          isWarning: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadError = true;
      });
    }
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

  OtpCodeResult _generateOtpCode(String secret) {
    final timestamp = _now().millisecondsSinceEpoch;
    return (widget.codeGenerator ?? _generateOtpCodeAt)(secret, timestamp);
  }

  OtpCodeResult _generateOtpCodeAt(String secret, int timestamp) {
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
        timestamp,
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

  Future<void> _addOtp(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) async {
    if (_isSavingOtp) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cleanedSecret = cleanOtpSecret(_secretController.text);
    final duplicate = _otpList.any(
      (item) => item.token.secret == cleanedSecret,
    );
    if (duplicate) {
      _showMessage(context.l10n.duplicateOtpSecret, isWarning: true);
      return;
    }

    final codeResult = _generateOtpCode(cleanedSecret);
    if (codeResult.error != null) {
      _showMessage(context.l10n.invalidOtpCode, isError: true);
      return;
    }

    final token = OtpToken(
      id: _generateId(),
      label: _labelController.text,
      secret: cleanedSecret,
    );

    setState(() => _isSavingOtp = true);
    if (dialogContext.mounted) {
      setDialogState(() {});
    }

    try {
      await (widget.saveToken ?? OtpHelper.saveToken)(token);
      if (!mounted) return;
      setState(() {
        _otpList.add(_OtpItem(token: token, code: codeResult.code!));
        _labelController.clear();
        _secretController.clear();
        _isSavingOtp = false;
      });
      if (dialogContext.mounted) {
        setDialogState(() {});
        Navigator.of(dialogContext).pop();
      }
      _showMessage(context.l10n.otpAdded);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSavingOtp = false);
      if (dialogContext.mounted) {
        setDialogState(() {});
      }
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final l10n = dialogContext.l10n;
            return PopScope(
              canPop: !_isSavingOtp,
              child: AlertDialog(
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
                              onPressed: _isSavingOtp
                                  ? null
                                  : () {
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
                            if (cleanedValue.isEmpty) {
                              return l10n.secretKeyInvalid;
                            }
                            if (cleanedValue.length < 8) {
                              return l10n.secretKeyTooShort;
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _isSavingOtp
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(l10n.cancel),
                  ),
                  ElevatedButton(
                    onPressed: _isSavingOtp
                        ? null
                        : () => _addOtp(dialogContext, setDialogState),
                    child: _isSavingOtp
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(l10n.addOtp),
                            ],
                          )
                        : Text(l10n.addOtp),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        centerTitle: true,
        toolbarHeight: math.max(
          56,
          MediaQuery.textScalerOf(context).scale(17) * 2 + 16,
        ),
        title: Text(
          l10n.oneTimePassword,
          style: const TextStyle(fontSize: 16),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadOtpTokens,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.retry,
          ),
          IconButton(
            onPressed: _scanQrCode,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: l10n.scanQrCode,
          ),
          IconButton(
            onPressed: _showAddOtpDialog,
            icon: const Icon(Icons.add),
            tooltip: l10n.addOtp,
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
                fontSize: 12,
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
    final theme = Theme.of(context);
    return SlidableAutoCloseBehavior(
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _otpList.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, indent: 64, color: theme.dividerColor),
        itemBuilder: (context, index) {
          final item = _otpList[index];
          // Only present the scanner's existing delimiter on separate lines.
          // The stored label and deletion confirmation remain untouched.
          final separator = item.token.label.indexOf(' - ');
          final hasIssuer =
              separator > 0 && separator + 3 < item.token.label.length;
          final issuer = hasIssuer
              ? item.token.label.substring(0, separator)
              : item.token.label;
          final account = hasIssuer
              ? item.token.label.substring(separator + 3)
              : null;
          final countdownColor = _secondsRemaining <= 5
              ? theme.colorScheme.error
              : theme.colorScheme.primary;
          final countdownSize = math.max(
            32.0,
            MediaQuery.textScalerOf(context).scale(12) * 2 + 8,
          );

          return Slidable(
            key: ValueKey(item.token.id),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.25,
              children: [
                SlidableAction(
                  onPressed: (_) => _deleteOtp(item.token.id),
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  icon: Icons.delete_outline,
                  label: l10n.delete,
                ),
              ],
            ),
            child: Material(
              color: theme.cardColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issuer,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (account != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  account,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 44),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final code = Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.code,
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          );
                          final actions = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy),
                                tooltip: l10n.copyOtpCode,
                                onPressed: () => _copyOtpCode(item.code),
                              ),
                              const SizedBox(width: 8),
                              Semantics(
                                label: l10n.secondsRemaining(_secondsRemaining),
                                child: SizedBox.square(
                                  dimension: countdownSize,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                        child: CircularProgressIndicator(
                                          value: _secondsRemaining / 30,
                                          strokeWidth: 3,
                                          color: countdownColor,
                                          backgroundColor: countdownColor
                                              .withOpacity(0.2),
                                        ),
                                      ),
                                      Text(
                                        '$_secondsRemaining',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: countdownColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                          if (constraints.maxWidth < 240 ||
                              MediaQuery.textScalerOf(context).scale(14) > 20) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                code,
                                const SizedBox(height: 8),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: actions,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: code),
                              const SizedBox(width: 12),
                              actions,
                            ],
                          );
                        },
                      ),
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
