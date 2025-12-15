import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../helpers/database_helper.dart';
import '../helpers/auth_helper.dart';
import '../helpers/encryption_helper.dart';
import '../helpers/otp_helper.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  bool _isLoading = false;

  Future<void> _createBackup() async {
    // 首先要求用户输入主密码以生成备份密钥
    final masterPassword = await showDialog<String>(
      context: context,
      builder: (context) => _MasterPasswordDialog(),
    );

    if (masterPassword == null || masterPassword.trim().isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = AuthHelper().getCurrentUserId();
      if (userId == null) {
        throw Exception('用户未登录');
      }

      // 生成备份密钥（使用固定salt+主密码）
      final backupKey = AuthHelper().getBackupKey(masterPassword);
      if (backupKey == null) {
        throw Exception('无法生成备份密钥');
      }

      // 导出密码条目
      final dbHelper = DatabaseHelper();
      final entries = await dbHelper.exportPasswordEntries(userId);
      
      // 导出OTP令牌
      final otpTokens = await OtpHelper.exportTokens();

      // 步骤1: 用当前账户密钥解密所有密码，得到明文
      // 步骤2: 用备份密钥重新加密每个密码
      final reEncryptedEntries = <Map<String, dynamic>>[];
      for (final entry in entries) {
        try {
          // 解密密码（使用当前设备密钥）
          final plainPassword = EncryptionHelper().decryptString(
            entry['password'],
          );
          
          // 用备份密钥重新加密密码
          final backupEncryptedPassword = EncryptionHelper.encryptPasswordWithBackupKey(
            plainPassword,
            backupKey,
          );
          
          // 创建新的条目数据（使用备份加密的密码）
          final reEncryptedEntry = Map<String, dynamic>.from(entry);
          reEncryptedEntry['password'] = backupEncryptedPassword;
          reEncryptedEntries.add(reEncryptedEntry);
        } catch (e) {
          throw Exception('重新加密密码失败: $e');
        }
      }

      // 创建备份数据
      final backupData = {
        'version': '2.0', // 版本升级以支持新的备份格式
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': userId,
        'entries': reEncryptedEntries, // 使用备份密钥加密的条目
        'otp_tokens': otpTokens,
      };

      // 转换为JSON字符串
      final jsonString = jsonEncode(backupData);

      // 步骤3: 整体用备份密钥加密
      final encryptedBackup = EncryptionHelper().encryptBackupData(
        jsonString,
        backupKey,
      );

      // 显示备份数据
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('备份完成'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('已成功创建 ${entries.length} 个密码条目的备份。'),
                const SizedBox(height: 16),
                const Text(
                  '备份数据：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        encryptedBackup,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '注意：在实际应用中，这些数据应该保存到安全的位置。',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  // 保存到系统备忘录
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  final tempContent = encryptedBackup;
                  
                  try {
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    
                    if (Platform.isWindows) {
                      // Windows平台：使用记事本打开
                      final tempDir = Directory.systemTemp;
                      final file = File('${tempDir.path}\\password_backup_$timestamp.txt');
                      file.writeAsStringSync(tempContent);
                      
                      Process.run('notepad.exe', [file.path]);
                      
                      navigator.pop();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('备份已在记事本中打开')),
                        );
                      }
                    } else if (Platform.isAndroid || Platform.isIOS) {
                      // Android和iOS平台：创建文件并使用分享功能
                      final directory = await getTemporaryDirectory();
                      final file = File('${directory.path}/password_backup_$timestamp.txt');
                      await file.writeAsString(tempContent);
                      
                      navigator.pop();
                      
                      // 分享文件，用户可以选择保存到备忘录或其他应用
                      final result = await Share.shareXFiles(
                        [XFile(file.path)],
                        text: '密码管理器备份数据',
                        subject: '密码备份',
                      );
                      
                      if (mounted) {
                        if (result.status == ShareResultStatus.success) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('备份文件已分享')),
                          );
                        }
                      }
                    } else {
                      // 其他平台（macOS、Linux等）
                      final directory = await getTemporaryDirectory();
                      final file = File('${directory.path}/password_backup_$timestamp.txt');
                      await file.writeAsString(tempContent);
                      
                      navigator.pop();
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('备份已保存到: ${file.path}')),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('保存备份失败: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.note_add),
                label: const Text('保存到备忘录'),
              ),
              TextButton.icon(
                onPressed: () {
                  // 捕获 NavigatorState 和 ScaffoldMessengerState，避免在 await 之后直接使用 BuildContext
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  Clipboard.setData(ClipboardData(text: encryptedBackup))
                      .then((_) {
                        // 先关闭对话框，然后在 mounted 时显示提示
                        navigator.pop();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('备份数据已复制到剪贴板')),
                          );
                        }
                      })
                      .catchError((error) {
                        // 复制失败时显示错误提示（在已挂载时）
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('复制备份失败: $error'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      });
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制备份'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    // 显示输入备份数据的对话框
    final backupData = await showDialog<String>(
      context: context,
      builder: (context) => _RestoreBackupDialog(),
    );

    if (backupData == null || backupData.trim().isEmpty) {
      return;
    }

    // 要求用户输入主密码以生成备份密钥
    if (!mounted) return;
    final masterPassword = await showDialog<String>(
      context: context,
      builder: (context) => _MasterPasswordDialog(isForRestore: true),
    );

    if (masterPassword == null || masterPassword.trim().isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = AuthHelper().getCurrentUserId();
      if (userId == null) {
        throw Exception('用户未登录');
      }

      // 生成备份密钥
      final backupKey = AuthHelper().getBackupKey(masterPassword);
      if (backupKey == null) {
        throw Exception('无法生成备份密钥');
      }

      // 步骤1: 用备份密钥解密整体数据
      final decryptedData = EncryptionHelper().decryptBackupData(
        backupData.trim(),
        backupKey,
      );

      // 解析JSON
      final jsonData = jsonDecode(decryptedData) as Map<String, dynamic>;
      final entries = jsonData['entries'] as List<dynamic>;
      
      // 获取OTP令牌 (如果有)
      List<dynamic>? otpTokens;
      if (jsonData.containsKey('otp_tokens')) {
        otpTokens = jsonData['otp_tokens'] as List<dynamic>;
      }

      // 确认恢复操作
      if (!mounted) return;
      
      // 构建恢复信息文本
      String restoreInfoText = '将恢复 ${entries.length} 个密码条目';
      if (otpTokens != null && otpTokens.isNotEmpty) {
        restoreInfoText += '和 ${otpTokens.length} 个OTP令牌';
      }
      restoreInfoText += '。\n\n注意：这将删除当前所有密码条目';
      if (otpTokens != null && otpTokens.isNotEmpty) {
        restoreInfoText += '和OTP令牌';
      }
      restoreInfoText += '并替换为备份中的数据。\n\n此操作无法撤销，确定要继续吗？';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认恢复'),
          content: Text(restoreInfoText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('确认恢复'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      // 清除当前密码条目
      final dbHelper = DatabaseHelper();
      await dbHelper.clearPasswordEntries(userId);

      // 步骤2: 用备份密钥解密每个密码 → 得到明文
      // 步骤3: 用当前设备密钥重新加密密码
      // 步骤4: 保存到数据库
      int restoredCount = 0;
      for (final entryData in entries) {
        try {
          // 解密密码（使用备份密钥）
          final plainPassword = EncryptionHelper.decryptPasswordWithBackupKey(
            entryData['password'],
            backupKey,
          );
          
          // 用当前设备密钥重新加密
          final deviceEncryptedPassword = EncryptionHelper().encryptString(
            plainPassword,
          );
          
          // 创建条目并保存
          final entry = {
            'user_id': userId,
            'title': entryData['title'],
            'username': entryData['username'],
            'password': deviceEncryptedPassword, // 使用当前设备密钥加密的密码
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
      
      // 恢复OTP令牌(如果有)
      int restoredOtpCount = 0;
      if (jsonData.containsKey('otp_tokens') && jsonData['otp_tokens'] is List) {
        final otpTokens = jsonData['otp_tokens'] as List<dynamic>;
        if (otpTokens.isNotEmpty) {
          // 转换为所需格式
          final List<Map<String, dynamic>> tokensList = 
              otpTokens.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          
          // 导入令牌
          await OtpHelper.importTokens(tokensList);
          restoredOtpCount = otpTokens.length;
        }
      }

      if (mounted) {
        String successMessage = '成功恢复 $restoredCount 个密码条目';
        if (restoredOtpCount > 0) {
          successMessage += '和 $restoredOtpCount 个OTP令牌';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('备份与恢复'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Card(
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '备份功能可以帮助您保护密码数据。当前版本将备份数据显示为加密文本，实际应用中应该保存到安全的位置。',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 备份部分
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.backup, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          '创建备份',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '将您的所有密码数据导出为加密备份。备份数据使用您的主密码加密，确保安全性。',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _createBackup,
                        icon: const Icon(Icons.backup),
                        label: const Text('创建备份'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 恢复部分
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.restore, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          '恢复备份',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '从加密备份中恢复您的密码数据。注意：这将替换当前所有密码条目。',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _restoreBackup,
                        icon: const Icon(Icons.restore),
                        label: const Text('恢复备份'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // const Card(
            //   color: Colors.red,
            //   child: Padding(
            //     padding: EdgeInsets.all(12.0),
            //     child: Row(
            //       children: [
            //         Icon(Icons.warning, color: Colors.white),
            //         SizedBox(width: 8),
            //         Expanded(
            //           child: Text(
            //             '重要提醒：备份数据包含您的所有密码信息（已加密），请妥善保管。恢复操作将删除当前所有数据，请谨慎操作。',
            //             style: TextStyle(color: Colors.white),
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _RestoreBackupDialog extends StatefulWidget {
  @override
  State<_RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends State<_RestoreBackupDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('输入备份数据'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('请粘贴您的加密备份数据：'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '粘贴备份数据...',
            ),
            maxLines: 5,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('恢复'),
        ),
      ],
    );
  }
}

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
    return AlertDialog(
      title: Text(widget.isForRestore ? '输入主密码以恢复备份' : '输入主密码以创建备份'),
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
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: '主密码',
              suffixIcon: IconButton(
                icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '提示：备份使用固定的加密密钥，可在不同设备间互通。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text('确认'),
        ),
      ],
    );
  }
}

