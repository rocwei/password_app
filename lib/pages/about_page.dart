import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 应用图标和名称
              Card(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/icon/my_app_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '密码管理器',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '版本 1.0.0',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '安全、简单、可靠的本地密码管理解决方案',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 功能特性
              Card(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '功能特性',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        context,
                        Icons.lock,
                        '安全加密',
                        '使用AES-256加密算法保护您的密码数据',
                      ),
                      _buildFeatureItem(
                        context,
                        Icons.storage,
                        '本地存储',
                        '所有数据存储在本地，不会上传到任何服务器',
                      ),
                      _buildFeatureItem(
                        context,
                        Icons.generating_tokens,
                        '密码生成',
                        '强大的密码生成器，创建安全的随机密码',
                      ),
                      _buildFeatureItem(
                        context,
                        Icons.backup,
                        '备份恢复',
                        '支持加密备份和恢复功能，保护您的数据安全',
                      ),
                      _buildFeatureItem(
                        context,
                        Icons.search,
                        '快速搜索',
                        '快速搜索和管理您的密码条目',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 安全说明
              Card(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '安全说明',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• 您的主密码是解锁所有数据的唯一钥匙，请务必牢记\n'
                        '• 所有敏感数据均使用 AES 加密保护\n'
                        '• 应用不会收集或传输任何个人数据\n'
                        '• 建议定期创建备份以防数据丢失\n'
                        '• 当应用进入后台时会自动锁定以保护安全',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 版权信息 / 联系方式
              Card(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('开发信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color)),
                      const SizedBox(height: 8),
                      Text('基于 Flutter 框架开发', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(const ClipboardData(text: '283187631@qq.com'));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('邮箱地址已复制到剪贴板')));
                        },
                        child: Text('联系邮箱: 283187631@qq.com', style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline)),
                      ),
                      const SizedBox(height: 12),
                      Text('© ${DateTime.now().year} 密码管理器. 保留所有权利.', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
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
    );
  }
}
