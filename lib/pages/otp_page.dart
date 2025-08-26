import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otp/otp.dart';
import '../helpers/otp_helper.dart';
import 'dart:math' as math;
import 'qr_scanner_page.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _secretController = TextEditingController();
  List<Map<String, dynamic>> _otpList = [];
  late Timer _timer;
  int _secondsRemaining = 30;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 使用Future.microtask来确保在构建完成后加载数据
    Future.microtask(() {
      if (mounted) {
        _loadOtpTokens();
      }
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

  // 加载保存的OTP令牌
  Future<void> _loadOtpTokens() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('开始加载OTP令牌...');
      final tokens = await OtpHelper.getAllTokens();
      print('成功获取令牌数量: ${tokens.length}');

      if (!mounted) return; // 检查widget是否仍然挂载

      setState(() {
        _otpList = tokens.map((token) {
          // 添加额外的错误处理，确保即使生成代码失败也不会闪退
          String code;
          try {
            code = _generateOtpCode(token.secret);
            if (code == 'ERROR') {
              code = '------'; // 显示占位符而不是错误
              print('令牌ID: ${token.id} 的代码生成失败');
            }
          } catch (e) {
            code = '------'; // 显示占位符而不是错误
            print('令牌ID: ${token.id} 的代码生成异常: $e');
          }

          return {
            'id': token.id,
            'label': token.label,
            'secret': token.secret,
            'code': code,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('加载OTP令牌错误: $e');

      if (!mounted) return; // 检查widget是否仍然挂载

      setState(() {
        _isLoading = false;
        _otpList = []; // 确保列表为空但不为null
      });

      // 延迟显示错误信息，避免在构建过程中触发
      Future.microtask(() {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('加载OTP令牌失败: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  void _startTimer() {
    // 计算当前时间戳除以30的余数，确定初始剩余秒数
    final int now = DateTime.now().millisecondsSinceEpoch;
    _secondsRemaining = 30 - (now % 30);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining <= 1) {
          _secondsRemaining = 30;
          // 当计时器归零时，更新所有OTP码
          _updateAllOtpCodes();
        } else {
          _secondsRemaining--;
        }
      });
    });
  }

  void _updateAllOtpCodes() {
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    print('更新所有OTP代码，当前时间戳: $currentTime, 时间片: ${currentTime ~/ 30}');

    // 先测试一个已知有效的密钥
    _testOtpGeneration();

    for (int i = 0; i < _otpList.length; i++) {
      final String newCode = _generateOtpCode(_otpList[i]['secret']);
      print(
        'Token ${_otpList[i]['label']} 新代码: $newCode, 密钥: ${_otpList[i]['secret']}',
      );

      setState(() {
        _otpList[i]['code'] = newCode;
      });
    }
  }

  // 测试OTP生成函数
  void _testOtpGeneration() {
    try {
      // 使用一个已知有效的测试密钥
      final testSecret = "JBSWY3DPEHPK3PXP";

      // 当前时间戳(秒)
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      print(
        '测试OTP生成 - 当前时间戳: $currentTimestamp, 时间片: ${currentTimestamp ~/ 30}',
      );

      // 生成验证码
      final code = OTP.generateTOTPCodeString(
        testSecret,
        currentTimestamp,
        length: 6,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );

      print('测试密钥($testSecret)生成的验证码: $code');
    } catch (e) {
      print('测试OTP生成失败: $e');
    }
  }

  // 生成随机ID
  String _generateId() {
    final random = math.Random();
    return DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(1000).toString();
  }

  Future<void> _addOtp() async {
    if (_formKey.currentState!.validate()) {
      try {
        // 清理密钥
        final cleanedSecret = _cleanSecret(_secretController.text);
        bool isDuplicate = _otpList.any((otp) => otp['secret'] == cleanedSecret);
        if (isDuplicate) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('该密钥已存在'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // 生成OTP代码测试有效性
        final testCode = _generateOtpCode(cleanedSecret);
        if (testCode == 'ERROR') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('无法生成验证码，密钥可能无效'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final id = _generateId();

        // 打印详细信息，帮助调试
        print(
          '创建OtpToken: id=$id, label=${_labelController.text}, secret=$cleanedSecret',
        );

        // 创建新令牌
        final newToken = OtpToken(
          id: id,
          label: _labelController.text,
          secret: cleanedSecret,
        );

        // 保存到安全存储
        await OtpHelper.saveToken(newToken);

        // 更新UI
        setState(() {
          _otpList.add(<String, String>{
            'id': id,
            'label': _labelController.text,
            'secret': cleanedSecret,
            'code': testCode,
          });
          _labelController.clear();
          _secretController.clear();
        });

        Navigator.of(context).pop();
      } catch (e) {
        print('添加OTP错误: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('添加OTP令牌失败: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteOtp(String id) async {
    // 获取令牌名称用于显示在确认对话框中
    final String tokenName = _otpList.firstWhere(
      (otp) => otp['id'] == id,
      orElse: () => <String, String>{'label': '未知令牌'},
    )['label'];

    // 显示确认对话框
    final bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除确认'),
        content: Text('确定要删除"$tokenName"的OTP令牌吗？\n\n此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('删除'),
          ),
        ],
      ),
    ) ?? false;  // 如果对话框被取消，返回false

    // 如果用户确认删除，执行删除操作
    if (confirmed) {
      try {
        // 从安全存储中删除
        await OtpHelper.deleteToken(id);

        // 更新UI
        setState(() {
          _otpList.removeWhere((otp) => otp['id'] == id);
        });
        
        // 显示成功消息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已删除"$tokenName"的OTP令牌'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('删除OTP错误: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除OTP令牌失败: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 清理密钥，去除空格和特殊字符
  String _cleanSecret(String secret) {
    if (secret.isEmpty) {
      return '';
    }

    // 移除所有空格和可能的分隔符
    String cleaned = secret.replaceAll(RegExp(r'\s|-|='), '');

    // 只保留有效的Base32字符：A-Z和2-7
    cleaned = cleaned.replaceAll(RegExp(r'[^A-Za-z2-7]'), '').toUpperCase();

    // 打印清理前后的密钥（不显示全部，防止泄露）
    if (cleaned.length > 4) {
      print(
        '密钥清理: ${secret.substring(0, 2)}*** => ${cleaned.substring(0, 2)}***',
      );
    }

    return cleaned;
  }

  // 生成OTP代码
  String _generateOtpCode(String secret) {
    if (secret.isEmpty) {
      print('密钥为空');
      return 'ERROR';
    }

    try {
      // 确保密钥是有效的Base32格式
      final cleanedSecret = _cleanSecret(secret);

      // 如果清理后的密钥为空，则返回错误
      if (cleanedSecret.isEmpty) {
        print('清理后的密钥为空');
        return 'ERROR';
      }

      // 获取当前时间戳(秒)
      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      print('当前时间戳(秒): $timestamp, 30秒时间片: ${timestamp ~/ 30}');

      // 使用原始密钥和两种处理方法尝试生成
      try {
        // 1. 尝试直接使用清理后的密钥
        // 获取当前时间戳（重要：不能缓存，每次都要重新获取）
        int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
        print('生成OTP时间戳: $currentTimestamp, 时间片: ${currentTimestamp ~/ 30}');

        String code = OTP.generateTOTPCodeString(
          cleanedSecret,
          currentTimestamp, // 使用最新的时间戳
          length: 6,
          interval: 30,
          algorithm: Algorithm.SHA1,
          isGoogle: true,
        );

        print('成功生成OTP代码: $code');
        return code;
      } catch (e) {
        print('base32解码生成OTP错误: $e');
        return 'ERROR';
      }
    } catch (e) {
      print('OTP生成总错误: $e');
      return 'ERROR';
    }
  }

  void _showAddOtpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '添加新的OTP令牌',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: '账户名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入账户名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _secretController,
                decoration: InputDecoration(
                  labelText: '密钥',
                  border: OutlineInputBorder(),
                  helperText: '输入服务提供商给的密钥',
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.qr_code_scanner,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () async {
                      Navigator.of(context).pop(); // 关闭当前对话框
                      await _scanQrCode();
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密钥';
                  }
                  // 基础验证，确保是有效的Base32字符
                  final cleanedValue = _cleanSecret(value);
                  if (cleanedValue.isEmpty) {
                    return '请输入有效的密钥（A-Z, 2-7）';
                  }

                  // 长度验证，Base32密钥通常至少有16个字符
                  if (cleanedValue.length < 8) {
                    return '密钥太短，请检查是否完整';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          ElevatedButton(onPressed: _addOtp, child: Text('添加')),
        ],
      ),
    );
  }

  Future<void> _scanQrCode() async {
    try {
      final result = await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const QrScannerPage()));

      // 打印结果类型，帮助调试
      print('扫描结果类型: ${result.runtimeType}');
      print('扫描结果内容: $result');

      if (result != null && result is Map<dynamic, dynamic>) {
        final String label = result['label']?.toString() ?? '';
        final String secret = result['secret']?.toString() ?? '';

        setState(() {
          _labelController.text = label;
          _secretController.text = secret;
        });

        // 重新打开添加对话框
        _showAddOtpDialog();
      }
    } catch (e) {
      print('扫描二维码错误详情: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('扫描二维码出错: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 构建时间进度环
  Widget _buildTimeCircle() {
    final color = _secondsRemaining <= 5
        ? Colors.red
        : Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: _secondsRemaining / 30,
            strokeWidth: 3,
            color: color,
            backgroundColor: color.withOpacity(0.2),
          ),
          Center(
            child: Text(
              _secondsRemaining.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'OTP双因素认证',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : _otpList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security,
                    size: 72,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无OTP令牌',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击下方按钮添加双因素认证令牌',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _otpList.length,
              itemBuilder: (context, index) {
                final otp = _otpList[index];
                return Dismissible(
                  key: Key(otp['id']),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    // 在这里调用删除方法，会显示确认对话框
                    await _deleteOtp(otp['id']);
                    // 总是返回false，因为实际删除在_deleteOtp方法中处理
                    return false;
                  },
                  child: Card(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  otp['label'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.refresh,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        otp['code'] = _generateOtpCode(
                                          otp['secret'],
                                        );
                                      });

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('验证码已刷新'),
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTimeCircle(),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                otp['code'],
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.copy,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: otp['code']),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('验证码已复制到剪贴板'),
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'scan_qr',
            onPressed: _scanQrCode,
            mini: true,
            child: Icon(Icons.qr_code_scanner),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
          ),
          // const SizedBox(height: 16),
          // FloatingActionButton(
          //   heroTag: 'add_manual',
          //   onPressed: _showAddOtpDialog,
          //   child: Icon(Icons.add),
          //   backgroundColor: Theme.of(context).colorScheme.primary,
          //   foregroundColor: Theme.of(context).colorScheme.onPrimary,
          // ),
        ],
      ),
    );
  }
}
