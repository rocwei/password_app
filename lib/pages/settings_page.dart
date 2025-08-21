import 'package:flutter/material.dart';
import '../helpers/auth_helper.dart';
import 'change_master_password_page.dart';
import 'backup_restore_page.dart';
import 'about_page.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthHelper _authHelper = AuthHelper();
  bool _biometricEnabled = false;
  bool _loadingBio = true;

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认登出'),
        content: const Text('确定要登出吗？您将需要重新输入主密码才能访问密码库。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('登出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _authHelper.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBiometricEnabled();
  }

  Future<void> _loadBiometricEnabled() async {
    final enabled = await _authHelper.isBiometricEnabledForCurrentUser();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _loadingBio = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    setState(() => _loadingBio = true);
    bool ok = false;
    if (value) {
      ok = await _authHelper.enableBiometricForCurrentUser();
    } else {
      await _authHelper.disableBiometricForCurrentUser();
      ok = true;
    }
    if (mounted) {
      setState(() {
        _biometricEnabled = ok ? value : _biometricEnabled;
        _loadingBio = false;
      });
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新生物识别设置失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authHelper.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 用户信息
          Card(
            color: Theme.of(context).cardColor,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      Text(
                        '用户信息',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        radius: 24,
                        child: Text(
                          user?.username.isNotEmpty == true 
                              ? user!.username[0].toUpperCase() 
                              : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.username ?? '未知用户',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (user?.createdAt != null)
                              Text(
                                '注册时间: ${_formatDateTime(user!.createdAt!)}',
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                      fontSize: 12,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 安全设置
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '安全设置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                    // color provided by theme
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('生物识别解锁'),
            subtitle: const Text('使用指纹/面部识别快速解锁'),
            trailing: _loadingBio
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Switch(
                    value: _biometricEnabled,
                    onChanged: (v) => _toggleBiometric(v),
                  ),
          ),
              const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('修改主密码'),
            subtitle: const Text('更改您的主密码'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChangeMasterPasswordPage(),
                ),
              );
            },
          ),
              const Divider(height: 1),

          // 数据管理
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '数据管理',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('备份与恢复'),
            subtitle: const Text('备份或恢复您的密码数据'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BackupRestorePage(),
                ),
              );
            },
          ),
              const Divider(height: 1),

          // 关于
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '关于',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于应用'),
            subtitle: const Text('应用信息和版本'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AboutPage(),
                ),
              );
            },
          ),
              const Divider(height: 1),

          const SizedBox(height: 32),

          // 登出按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('登出'),
                    style: ElevatedButton.styleFrom(),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}
