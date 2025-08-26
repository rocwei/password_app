import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

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
    
    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.startsWith('otpauth://')) {
        setState(() {
          _isProcessing = true;
        });
        
        // 处理OTP URI并返回到上一页
        _processOtpUri(rawValue);
        break;
      }
    }
  }

  void _processOtpUri(String uri) {
    // 解析OTP URI
    // 格式: otpauth://totp/LABEL?secret=SECRET&issuer=ISSUER
    Uri otpUri = Uri.parse(uri);
    
    if (otpUri.scheme != 'otpauth') {
      _showErrorSnackBar('不是有效的OTP二维码');
      setState(() {
        _isProcessing = false;
      });
      return;
    }
    
    // 获取参数
    String? secret = otpUri.queryParameters['secret'];
    
    if (secret == null || secret.isEmpty) {
      _showErrorSnackBar('未找到密钥信息');
      setState(() {
        _isProcessing = false;
      });
      return;
    }
    
    // 清理密钥，移除非Base32字符
    secret = secret.replaceAll(RegExp(r'[^A-Za-z2-7]'), '').toUpperCase();
    
    if (secret.isEmpty) {
      _showErrorSnackBar('密钥无效');
      setState(() {
        _isProcessing = false;
      });
      return;
    }
    
    // 获取标签
    String path = otpUri.path;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    
    // 优先使用issuer参数
    String? issuer = otpUri.queryParameters['issuer'];
    String label = issuer != null && issuer.isNotEmpty
        ? '$issuer - $path'
        : path;
        
    // 导航回上一页并传递数据
    if (mounted) {
      // 确保返回的是字符串类型
      Map<String, String> result = {
        'label': label,
        'secret': secret,
      };
      print('返回扫描结果: $result');
      Navigator.of(context).pop(result);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '扫描OTP二维码',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.on 
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: Theme.of(context).colorScheme.primary,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller.cameraFacingState,
              builder: (context, state, child) {
                return Icon(
                  state == CameraFacing.front
                      ? Icons.camera_front
                      : Icons.camera_rear,
                  color: Theme.of(context).colorScheme.primary,
                );
              },
            ),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // 扫描框
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // 底部提示
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '将OTP二维码对准框内进行扫描',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}
