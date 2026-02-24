import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../helpers/database_helper.dart';
import '../helpers/auth_helper.dart';
import '../helpers/encryption_helper.dart';
import '../helpers/otp_helper.dart';
import 'home_page.dart';

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

class BackupRestorePage extends StatefulWidget {
  /// 可选：从外部 Intent 传入的 .passbackup 文件路径
  /// 当用户从微信/文件管理器打开文件时自动传入
  final String? initialFilePath;

  const BackupRestorePage({super.key, this.initialFilePath});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
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
    // 1. 弹出主密码输入对话框
    final masterPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _MasterPasswordDialog(),
    );
    if (masterPassword == null || masterPassword.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '正在加密数据并生成备份文件';
    });

    try {
      // 2. 校验用户登录状态
      final userId = AuthHelper().getCurrentUserId();
      if (userId == null) throw Exception('用户未登录');

      // 3. 使用主密码派生备份密钥
      final backupKey = AuthHelper().getBackupKey(masterPassword);
      if (backupKey == null) throw Exception('无法生成备份密钥');

      // 4. 导出密码条目 & OTP 令牌
      final dbHelper = DatabaseHelper();
      final entries = await dbHelper.exportPasswordEntries(userId);
      final otpTokens = await OtpHelper.exportTokens();

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
        'version': '3.0', // 文件备份版本
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': userId,
        'entries': reEncryptedEntries,
        'otp_tokens': otpTokens,
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        _showErrorSnackBar('备份失败: $e');
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('备份文件已生成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.lock, '密码条目', '$entryCount 条'),
            if (otpCount > 0)
              _buildInfoRow(Icons.access_time, 'OTP 令牌', '$otpCount 个'),
            _buildInfoRow(Icons.insert_drive_file, '文件名', fileName),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请点击下方按钮，将备份文件分享到安全的位置（微信文件传输助手、网盘、邮件等）。',
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 分享按钮  调用系统分享面板
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _shareBackupFile(backupFile, fileName);
            },
            icon: const Icon(Icons.share),
            label: const Text('分享 / 导出文件'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('稍后处理'),
          ),
        ],
      ),
    );
  }

  /// 通过系统分享面板分享备份文件
  Future<void> _shareBackupFile(File backupFile, String fileName) async {
    try {
      final result = await Share.shareXFiles(
        [XFile(backupFile.path, name: fileName)],
        subject: '密盾安存 - 密码备份文件',
        text: '这是「密盾安存」生成的加密备份文件，请妥善保管。恢复时需要输入备份密码。',
      );

      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        _showSuccessSnackBar('备份文件已成功分享');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('分享失败: $e');
    }
  }

  // ==========================================================
  // ==================== 恢复备份（文件） =======================
  // ==========================================================

  Future<void> _restoreBackup() async {
    // 1. 使用系统文件选择器选取 .passbackup 文件
    setState(() {
      _statusMessage = '正在打开文件选择器';
    });

    FilePickerResult? pickerResult;
    try {
      pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.any,
        // 备注: 部分 Android 设备不识别自定义扩展名过滤,
        // 因此使用 FileType.any 让用户手动选择 .passbackup 文件
        dialogTitle: '选择 .passbackup 备份文件',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = '');
        _showErrorSnackBar('无法打开文件选择器: $e');
      }
      return;
    }

    if (pickerResult == null || pickerResult.files.isEmpty) {
      // 用户取消了选择
      if (mounted) setState(() => _statusMessage = '');
      return;
    }

    final pickedFile = pickerResult.files.first;
    final filePath = pickedFile.path;

    // 校验文件路径
    if (filePath == null) {
      if (mounted) {
        setState(() => _statusMessage = '');
        _showErrorSnackBar('无法访问所选文件');
      }
      return;
    }

    // 校验文件后缀
    if (!filePath.toLowerCase().endsWith('.passbackup')) {
      if (mounted) {
        setState(() => _statusMessage = '');
        _showWarnDialog(
          '文件格式不正确',
          '请选择后缀为 .passbackup 的备份文件。\n\n'
              '当前选择的文件: ${pickedFile.name}',
        );
      }
      return;
    }

    // 使用通用的文件恢复方法
    await _restoreFromFile(filePath);
  }

  /// 从指定文件路径恢复备份数据
  /// 同时被「手动选择文件」和「外部 Intent 传入文件」两个入口调用
  Future<void> _restoreFromFile(String filePath) async {
    // 弹出主密码输入对话框
    if (!mounted) return;
    setState(() => _statusMessage = '');

    final masterPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const _MasterPasswordDialog(isForRestore: true),
    );
    if (masterPassword == null || masterPassword.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '正在读取并解密备份文件';
    });

    try {
      // 3. 校验登录状态
      final userId = AuthHelper().getCurrentUserId();
      if (userId == null) throw Exception('用户未登录');

      // 4. 读取备份文件内容
      final backupFile = File(filePath);
      if (!await backupFile.exists()) throw Exception('文件不存在或已被移除');

      final encryptedBackup = await backupFile.readAsString();
      if (encryptedBackup.trim().isEmpty) throw Exception('备份文件内容为空');

      // 5. 派生备份密钥
      final backupKey = AuthHelper().getBackupKey(masterPassword);
      if (backupKey == null) throw Exception('无法生成备份密钥');

      // 6. 解密整体数据
      String decryptedData;
      try {
        decryptedData = EncryptionHelper().decryptBackupData(
          encryptedBackup.trim(),
          backupKey,
        );
      } catch (_) {
        throw Exception('解密失败，请确认密码是否与备份时一致');
      }

      // 7. 解析 JSON
      final jsonData = jsonDecode(decryptedData) as Map<String, dynamic>;
      final entries = jsonData['entries'] as List<dynamic>;

      // 获取 OTP 令牌（兼容旧版本备份）
      List<dynamic>? otpTokens;
      if (jsonData.containsKey('otp_tokens')) {
        otpTokens = jsonData['otp_tokens'] as List<dynamic>;
      }

      if (!mounted) return;

      // 8. 确认恢复操作
      String restoreInfoText = '将恢复 ${entries.length} 个密码条目';
      if (otpTokens != null && otpTokens.isNotEmpty) {
        restoreInfoText += ' 和 ${otpTokens.length} 个 OTP 令牌';
      }
      restoreInfoText += '。\n\n';
      restoreInfoText += ' 注意：此操作将删除当前所有密码数据';
      if (otpTokens != null && otpTokens.isNotEmpty) {
        restoreInfoText += '和 OTP 令牌';
      }
      restoreInfoText += '并替换为备份中的数据。\n\n此操作无法撤销，确定要继续吗？';

      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded,
              color: Colors.red, size: 48),
          title: const Text('确认恢复'),
          content: Text(restoreInfoText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('确认恢复'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() {
        _isLoading = true;
        _statusMessage = '正在恢复数据';
      });

      // 9. 清除当前数据
      final dbHelper = DatabaseHelper();
      await dbHelper.clearPasswordEntries(userId);

      // 10. 逐条恢复密码条目
      int restoredCount = 0;
      for (final entryData in entries) {
        try {
          // 用备份密钥解密  明文
          final plainPassword =
              EncryptionHelper.decryptPasswordWithBackupKey(
            entryData['password'],
            backupKey,
          );
          // 用当前设备密钥重新加密
          final deviceEncryptedPassword =
              EncryptionHelper().encryptString(plainPassword);

          final entry = {
            'user_id': userId,
            'title': entryData['title'],
            'username': entryData['username'],
            'password': deviceEncryptedPassword,
            'website': entryData['website'],
            'note': entryData['note'],
            'created_at': entryData['created_at'],
            'updated_at': DateTime.now().toIso8601String(),
          };

          await dbHelper.database.then(
            (db) => db.insert('password_entries', entry),
          );
          restoredCount++;
        } catch (e) {
          throw Exception('恢复密码条目失败: $e');
        }
      }

      // 11. 恢复 OTP 令牌（如果有）
      int restoredOtpCount = 0;
      if (otpTokens != null && otpTokens.isNotEmpty) {
        final tokensList = otpTokens
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        await OtpHelper.importTokens(tokensList);
        restoredOtpCount = otpTokens.length;
      }

      if (!mounted) return;

      // 12. 显示恢复成功提示并跳转到首页
      String successMessage = '成功恢复 $restoredCount 个密码条目';
      if (restoredOtpCount > 0) {
        successMessage += ' 和 $restoredOtpCount 个 OTP 令牌';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(successMessage)),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
      return; // 避免执行 finally 中的 setState
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        _showErrorSnackBar('恢复失败: $e');
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
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis),
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
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 40),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('备份与恢复'),
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
                    Icon(Icons.shield,
                        color: colorScheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '备份文件已使用 AES-256 加密，可安全存储或分享。\n'
                        '恢复时需要输入备份时使用的主密码。',
                        style: TextStyle(
                            color: colorScheme.onPrimaryContainer),
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
                          child: const Icon(Icons.backup,
                              color: Colors.green, size: 28),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('创建备份',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text('生成加密 .passbackup 文件',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '将所有密码和 OTP 令牌导出为加密备份文件，可通过微信、QQ、邮件、网盘等方式安全转发或保存。',
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _createBackup,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('创建备份文件'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
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
                          child: const Icon(Icons.restore,
                              color: Colors.orange, size: 28),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('恢复备份',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text('从 .passbackup 文件恢复',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '选择之前导出的 .passbackup 备份文件进行恢复。\n'
                      '注意：恢复操作将覆盖当前所有密码数据。',
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _restoreBackup,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('选择备份文件恢复'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
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
                          child: const Icon(Icons.help_outline,
                              color: Colors.blue, size: 28),
                        ),
                        const SizedBox(width: 12),
                        const Text('使用帮助',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHelpItem(
                      '1',
                      '备份',
                      '点击「创建备份文件」 输入主密码  通过分享发送到安全位置',
                    ),
                    _buildHelpItem(
                      '2',
                      '恢复',
                      '点击「选择备份文件恢复」 找到 .passbackup 文件  输入备份密码',
                    ),
                    _buildHelpItem(
                      '3',
                      '跨设备迁移',
                      '旧设备创建备份  分享到微信/邮件  新设备下载文件  恢复',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '请牢记备份密码！忘记密码将无法恢复数据。',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
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
                      Text(_statusMessage,
                          style:
                              const TextStyle(color: Colors.grey)),
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
            child: Text(step,
                style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13, height: 1.4)),
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
  State<_MasterPasswordDialog> createState() =>
      _MasterPasswordDialogState();
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
    return AlertDialog(
      title: Text(
          widget.isForRestore ? '输入备份密码以恢复' : '输入主密码以创建备份'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isForRestore
                ? '请输入创建备份时使用的主密码：'
                : '请输入您的主密码以生成备份密钥：',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscureText,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: '主密码',
              suffixIcon: IconButton(
                icon: Icon(_obscureText
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () =>
                    setState(() => _obscureText = !_obscureText),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isForRestore
                ? '提示：请输入备份时设置的密码，密码错误将无法恢复数据。'
                : '提示：备份使用固定的加密密钥，可在不同设备间互通。',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('确认'),
        ),
      ],
    );
  }

  void _submit() {
    if (_controller.text.trim().isNotEmpty) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }
}
