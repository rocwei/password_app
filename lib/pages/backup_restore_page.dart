import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import '../helpers/backup_restore_service.dart';
import '../helpers/database_helper.dart';
import '../helpers/auth_helper.dart';
import '../helpers/encryption_helper.dart';
import '../helpers/otp_helper.dart';
import '../l10n/l10n.dart';
import 'home_page.dart';

export '../helpers/backup_restore_service.dart'
    show BackupRestorePlan, BackupRestoreResult;

/// ============================================================
/// 备份与恢复页面  文件备份方案
/// ============================================================
/// 功能概述：
///   1. 【创建备份】将所有密码条目 + OTP 令牌用备份密钥加密后，
///      写入 .passbackup 文件，用户可通过系统分享面板转发至
///      微信 / QQ / 邮件 / 网盘等任意渠道。
///   2. 【恢复备份】通过系统文件选择器选取 .passbackup 文件，
///      输入备份时使用的主密码解密后恢复数据。
/// 安全说明：
///   - 备份文件内容已使用 AES-256-CBC + PKCS7 加密；
///   - 加密密钥由用户主密码 + 固定 salt 派生，任何持有文件但
///     不知道主密码的人无法解密。
/// ============================================================

class BackupFileSelection {
  const BackupFileSelection({required this.path, required this.name});

  final String? path;
  final String name;
}

class BackupCreationResult {
  const BackupCreationResult({
    required this.path,
    required this.fileName,
    required this.passwordEntryCount,
    required this.otpCount,
  });

  final String path;
  final String fileName;
  final int passwordEntryCount;
  final int otpCount;
}

class BackupRestorePage extends StatefulWidget {
  /// 可选：从外部 Intent 传入的 .passbackup 文件路径
  /// 当用户从微信/文件管理器打开文件时自动传入
  final String? initialFilePath;
  final Future<BackupFileSelection?> Function(String dialogTitle)?
  pickBackupFile;
  final Future<BackupRestorePlan> Function(
    String filePath,
    String fileName,
    String password,
  )?
  inspectBackup;
  final Future<BackupRestoreResult> Function(BackupRestorePlan plan)?
  applyBackupPlan;
  final Future<BackupCreationResult> Function(String password)?
  createBackupFile;
  final WidgetBuilder? destinationBuilder;

  const BackupRestorePage({
    super.key,
    this.initialFilePath,
    this.pickBackupFile,
    this.inspectBackup,
    this.applyBackupPlan,
    this.createBackupFile,
    this.destinationBuilder,
  }) : assert(
         (inspectBackup == null) == (applyBackupPlan == null),
         'inspectBackup and applyBackupPlan must be provided together.',
       );

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  final BackupRestoreService _restoreService = BackupRestoreService();

  /// 是否正在执行异步操作（备份/恢复）
  bool _isLoading = false;

  /// 当前操作状态描述，用于 UI 展示
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    // 如果有从外部传入的文件路径，延迟一帧后自动触发恢复流程
    if (widget.initialFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreFromFile(widget.initialFilePath!);
      });
    }
  }

  // ==========================================================
  // ==================== 创建备份（文件） =======================
  // ==========================================================

  Future<void> _createBackup() async {
    final l10n = context.l10n;
    // 1. 弹出主密码输入对话框
    final masterPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _MasterPasswordDialog(),
    );
    if (masterPassword == null || masterPassword.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = l10n.creatingEncryptedBackup;
    });

    if (widget.createBackupFile case final createBackupFile?) {
      try {
        final result = await createBackupFile(masterPassword);
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        _showBackupSuccessDialog(
          backupFile: File(result.path),
          fileName: result.fileName,
          entryCount: result.passwordEntryCount,
          otpCount: result.otpCount,
        );
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = '';
          });
          _showErrorSnackBar(l10n.backupFailed);
        }
      }
      return;
    }

    try {
      // 2. 校验密码库解锁状态
      final userId = AuthHelper().getCurrentUserId();
      if (userId == null) throw StateError('Vault is not unlocked');

      // 3. 使用主密码派生备份密钥
      final backupKey = AuthHelper().getBackupKey(masterPassword);
      if (backupKey == null) throw StateError('Backup key is unavailable');

      // 4. 导出密码条目 & OTP 令牌 & 分类
      final dbHelper = DatabaseHelper();
      final entries = await dbHelper.exportPasswordEntries(userId);
      final otpTokens = await OtpHelper.exportTokens();
      final categories = await dbHelper.exportCategories(userId);

      // 5. 逐条用备份密钥重新加密密码
      final reEncryptedEntries = <Map<String, dynamic>>[];
      for (final entry in entries) {
        // 先用当前设备密钥解密  明文
        final plainPassword = EncryptionHelper().decryptString(
          entry['password'],
        );
        // 再用备份密钥加密  跨设备兼容
        final backupEncryptedPassword =
            EncryptionHelper.encryptPasswordWithBackupKey(
              plainPassword,
              backupKey,
            );
        final reEncryptedEntry = Map<String, dynamic>.from(entry);
        reEncryptedEntry['password'] = backupEncryptedPassword;
        reEncryptedEntries.add(reEncryptedEntry);
      }

      // 6. 组装备份 JSON 结构
      final backupData = {
        'version': '3.1', // 文件备份版本（包含分类）
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': userId,
        'entries': reEncryptedEntries,
        'otp_tokens': otpTokens,
        'categories': categories,
      };
      final jsonString = jsonEncode(backupData);

      // 7. 整体再用备份密钥加密
      final encryptedBackup = EncryptionHelper().encryptBackupData(
        jsonString,
        backupKey,
      );

      // 8. 写入临时 .passbackup 文件
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'password_backup_$timestamp.passbackup';
      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/$fileName');
      await backupFile.writeAsString(encryptedBackup);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      // 9. 显示备份成功对话框
      _showBackupSuccessDialog(
        backupFile: backupFile,
        fileName: fileName,
        entryCount: entries.length,
        otpCount: otpTokens.length,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        _showErrorSnackBar(l10n.backupFailed);
      }
    }
  }

  /// 备份成功后的对话框：显示摘要 + 分享按钮
  void _showBackupSuccessDialog({
    required File backupFile,
    required String fileName,
    required int entryCount,
    required int otpCount,
  }) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: Text(l10n.backupFileCreated),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                Icons.lock,
                l10n.passwordEntries,
                l10n.backupPasswordEntryCount(entryCount),
              ),
              if (otpCount > 0)
                _buildInfoRow(
                  Icons.access_time,
                  l10n.otpTokens,
                  l10n.backupOtpCount(otpCount),
                ),
              _buildInfoRow(Icons.insert_drive_file, l10n.fileName, fileName),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.exportBackupPrompt,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // 分享按钮  调用系统分享面板
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _shareBackupFile(backupFile, fileName);
            },
            icon: const Icon(Icons.share),
            label: Text(l10n.shareOrExportFile),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.later),
          ),
        ],
      ),
    );
  }

  /// 通过系统分享面板分享备份文件
  Future<void> _shareBackupFile(File backupFile, String fileName) async {
    final l10n = context.l10n;
    try {
      // 获取分享按钮的位置，iOS（尤其 iPad）需要 sharePositionOrigin 作为弹出锚点
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);

      final result = await Share.shareXFiles(
        [XFile(backupFile.path, name: fileName)],
        subject: l10n.backupShareSubject,
        text: l10n.backupShareText,
        sharePositionOrigin: sharePositionOrigin,
      );

      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        _showSuccessSnackBar(l10n.backupShared);
      }
    } catch (_) {
      if (mounted) _showErrorSnackBar(l10n.backupShareFailed);
    }
  }

  // ==========================================================
  // ==================== 恢复备份（文件） =======================
  // ==========================================================

  Future<void> _restoreBackup() async {
    final l10n = context.l10n;
    // 1. 使用系统文件选择器选取 .passbackup 文件
    setState(() {
      _statusMessage = l10n.openingFilePicker;
    });

    BackupFileSelection? selection;
    try {
      if (widget.pickBackupFile case final picker?) {
        selection = await picker(l10n.selectBackupFileTitle);
      } else {
        final pickerResult = await FilePicker.platform.pickFiles(
          type: FileType.any,
          // 部分 Android 设备不识别自定义扩展名过滤，因此允许选择任意文件后再校验。
          dialogTitle: l10n.selectBackupFileTitle,
        );
        if (pickerResult != null && pickerResult.files.isNotEmpty) {
          final pickedFile = pickerResult.files.first;
          selection = BackupFileSelection(
            path: pickedFile.path,
            name: pickedFile.name,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _statusMessage = '');
        _showErrorSnackBar(l10n.filePickerFailed);
      }
      return;
    }

    if (selection == null) {
      // 用户取消了选择
      if (mounted) setState(() => _statusMessage = '');
      return;
    }

    final filePath = selection.path;

    // 校验文件路径
    if (filePath == null) {
      if (mounted) {
        setState(() => _statusMessage = '');
        _showErrorSnackBar(l10n.selectedFileUnavailable);
      }
      return;
    }

    // 校验文件后缀
    if (!filePath.toLowerCase().endsWith('.passbackup')) {
      if (mounted) {
        setState(() => _statusMessage = '');
        _showWarnDialog(
          l10n.invalidBackupFileTitle,
          l10n.invalidBackupFileMessage(selection.name),
        );
      }
      return;
    }

    // 使用通用的文件恢复方法
    await _restoreFromFile(filePath, displayFileName: selection.name);
  }

  /// 从指定文件路径恢复备份数据
  /// 同时被「手动选择文件」和「外部 Intent 传入文件」两个入口调用
  Future<void> _restoreFromFile(
    String filePath, {
    String? displayFileName,
  }) async {
    final l10n = context.l10n;
    final fileName = displayFileName ?? path.basename(filePath);
    if (!mounted) return;
    setState(() => _statusMessage = '');

    final masterPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _MasterPasswordDialog(isForRestore: true),
    );
    if (masterPassword == null || masterPassword.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = l10n.readingEncryptedBackup;
    });

    final inspectBackup = widget.inspectBackup ?? _inspectBackupFile;
    final applyBackupPlan = widget.applyBackupPlan ?? _applyBackupPlan;
    try {
      final plan = await inspectBackup(filePath, fileName, masterPassword);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      if (await _confirmRestore(plan) != true || !mounted) return;

      setState(() {
        _isLoading = true;
        _statusMessage = l10n.restoringData;
      });

      final result = await applyBackupPlan(plan);
      if (!mounted) return;
      _showRestoreSuccess(result);
      final destinationBuilder =
          widget.destinationBuilder ?? (_) => const HomePage();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: destinationBuilder),
        (route) => false,
      );
      return;
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar(l10n.restoreFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }

  Future<BackupRestorePlan> _inspectBackupFile(
    String filePath,
    String fileName,
    String masterPassword,
  ) async {
    final userId = AuthHelper().getCurrentUserId();
    if (userId == null) throw StateError('Vault is not unlocked');

    final backupFile = File(filePath);
    if (!await backupFile.exists()) {
      throw const FileSystemException('Backup file is unavailable');
    }

    final encryptedBackup = await backupFile.readAsString();
    if (encryptedBackup.trim().isEmpty) {
      throw const FormatException('Backup file is empty');
    }

    final backupKey = AuthHelper().getBackupKey(masterPassword);
    if (backupKey == null) throw StateError('Backup key is unavailable');

    String decryptedData;
    try {
      decryptedData = EncryptionHelper().decryptBackupData(
        encryptedBackup.trim(),
        backupKey,
      );
    } catch (_) {
      throw const FormatException('Backup decryption failed');
    }

    final jsonData = jsonDecode(decryptedData) as Map<String, dynamic>;
    final entries = _backupMaps(jsonData['entries']);
    final categories = jsonData.containsKey('categories')
        ? _backupMaps(jsonData['categories'])
        : <Map<String, dynamic>>[];
    final otpTokens = jsonData.containsKey('otp_tokens')
        ? _backupMaps(jsonData['otp_tokens'])
        : <Map<String, dynamic>>[];

    return _restoreService.validatePlan(
      BackupRestorePlan(
        fileName: fileName,
        userId: userId,
        backupKey: backupKey,
        entries: entries,
        categories: categories,
        otpTokens: otpTokens,
      ),
    );
  }

  List<Map<String, dynamic>> _backupMaps(Object? value) {
    if (value is! List) {
      throw const FormatException('Invalid backup collection');
    }
    return value.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid backup record');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  Future<BackupRestoreResult> _applyBackupPlan(BackupRestorePlan plan) async {
    return _restoreService.applyPlan(plan);
  }

  Future<bool?> _confirmRestore(BackupRestorePlan plan) {
    final l10n = context.l10n;
    final counts = _joinRestoreCounts([
      l10n.backupPasswordEntryCount(plan.passwordEntryCount),
      if (plan.categoryCount > 0) l10n.backupCategoryCount(plan.categoryCount),
      if (plan.otpCount > 0) l10n.backupOtpCount(plan.otpCount),
    ]);
    final countSummary = l10n.restoreCountSummary(counts);
    final restoreInfoText = plan.otpCount > 0
        ? l10n.restoreSummaryWithOtp(plan.fileName, countSummary)
        : l10n.restoreSummary(plan.fileName, countSummary);

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 48,
        ),
        title: Text(l10n.confirmRestore),
        content: Text(restoreInfoText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.confirmRestore),
          ),
        ],
      ),
    );
  }

  String _restoreSuccessMessage(BackupRestoreResult result) {
    final l10n = context.l10n;
    final summary = _joinRestoreCounts([
      l10n.backupPasswordEntryCount(result.restoredPasswordEntryCount),
      if (result.restoredCategoryCount > 0)
        l10n.backupCategoryCount(result.restoredCategoryCount),
      if (result.restoredOtpCount > 0)
        l10n.backupOtpCount(result.restoredOtpCount),
    ]);
    return l10n.restoreSucceeded(summary);
  }

  void _showRestoreSuccess(BackupRestoreResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(_restoreSuccessMessage(result))),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _joinRestoreCounts(List<String> counts) {
    final l10n = context.l10n;
    return switch (counts) {
      [final only] => only,
      [final first, final second] => l10n.restoreCountJoinTwo(first, second),
      [final first, final second, final third] => l10n.restoreCountJoinThree(
        first,
        second,
        third,
      ),
      _ => throw StateError('Unexpected restore count length'),
    };
  }

  // ==========================================================
  // ===================== UI 辅助方法 =========================
  // ==========================================================

  /// 构建信息行（图标 + 标签 + 值）
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showWarnDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 40,
        ),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.understood),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ======================== 主界面 ===========================
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.backupAndRestore),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 安全提示卡片 ----
            Card(
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield, color: colorScheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.backupSecurityNotice,
                        style: TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---- 创建备份卡片 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.backup,
                            color: Colors.green,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.createBackup,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.createBackupSubtitle,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.createBackupDescription,
                      style: const TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _createBackup,
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(l10n.createBackupFile),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- 恢复备份卡片 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.restore,
                            color: Colors.orange,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.restoreBackup,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.restoreBackupSubtitle,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.restoreBackupDescription,
                      style: const TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _restoreBackup,
                        icon: const Icon(Icons.folder_open),
                        label: Text(l10n.selectBackupFileToRestore),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---- 使用帮助卡片 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.help_outline,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.usageHelp,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHelpItem(
                      '1',
                      l10n.backupHelpTitle,
                      l10n.backupHelpDescription,
                    ),
                    _buildHelpItem(
                      '2',
                      l10n.restoreHelpTitle,
                      l10n.restoreHelpDescription,
                    ),
                    _buildHelpItem(
                      '3',
                      l10n.migrationHelpTitle,
                      l10n.migrationHelpDescription,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.rememberBackupPassword,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---- 加载状态指示器 ----
            if (_isLoading) ...[
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 帮助步骤条目
  Widget _buildHelpItem(String step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================
// =================== 主密码输入对话框 =========================
// ==============================================================

class _MasterPasswordDialog extends StatefulWidget {
  final bool isForRestore;

  const _MasterPasswordDialog({this.isForRestore = false});

  @override
  State<_MasterPasswordDialog> createState() => _MasterPasswordDialogState();
}

class _MasterPasswordDialogState extends State<_MasterPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.isForRestore
            ? l10n.restorePasswordDialogTitle
            : l10n.createBackupPasswordDialogTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isForRestore
                  ? l10n.restorePasswordPrompt
                  : l10n.createBackupPasswordPrompt,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              obscureText: _obscureText,
              autofocus: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: l10n.masterPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isForRestore
                  ? l10n.restorePasswordHint
                  : l10n.createBackupPasswordHint,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.confirm)),
      ],
    );
  }

  void _submit() {
    if (_controller.text.isNotEmpty) {
      Navigator.of(context).pop(_controller.text);
    }
  }
}
