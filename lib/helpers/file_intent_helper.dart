import 'dart:async';
import 'package:flutter/services.dart';

/// ============================================================
/// 文件 Intent 处理器（单例）
/// ============================================================
/// 用于接收从微信/QQ/文件管理器等外部应用打开 .passbackup 文件时
/// 传入的文件路径。
///
/// 工作流程:
///   1. Android/iOS 原生层通过 MethodChannel 将文件路径推送到 Flutter
///   2. 本类缓存该路径并通过 Stream 通知监听者
///   3. 登录完成后，UI 层消费待处理的文件路径，跳转至备份恢复页
/// ============================================================
class FileIntentHelper {
  // ---------- 单例 ----------
  static final FileIntentHelper _instance = FileIntentHelper._internal();
  factory FileIntentHelper() => _instance;
  FileIntentHelper._internal();

  /// 与原生层通信的 MethodChannel 名称
  static const _channel = MethodChannel('com.rocwei.password/file_intent');

  /// 待处理的文件路径（登录前可能已收到）
  String? _pendingFilePath;

  /// 文件意图到达时的广播流
  final _fileIntentController = StreamController<String>.broadcast();

  /// 外部监听新文件意图
  Stream<String> get onFileIntent => _fileIntentController.stream;

  /// 获取并清除待处理的文件路径（一次性消费）
  String? consumePendingFilePath() {
    final path = _pendingFilePath;
    _pendingFilePath = null;
    return path;
  }

  /// 是否有待处理的文件
  bool get hasPendingFile => _pendingFilePath != null;

  /// 初始化 — 在 main() 中调用一次
  void init() {
    // 注册原生→Flutter 的回调：处理应用已运行时收到的新 Intent
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewFileIntent') {
        final String? filePath = call.arguments as String?;
        if (filePath != null && filePath.isNotEmpty) {
          _handleIncomingFile(filePath);
        }
      }
    });

    // 主动查询启动时是否携带文件 Intent（冷启动场景）
    _getInitialFilePath();
  }

  /// 查询冷启动时的初始 Intent
  Future<void> _getInitialFilePath() async {
    try {
      final String? filePath =
          await _channel.invokeMethod<String>('getInitialFilePath');
      if (filePath != null && filePath.isNotEmpty) {
        _handleIncomingFile(filePath);
      }
    } on PlatformException catch (_) {
      // 平台不支持（如 Windows 桌面），静默忽略
    } on MissingPluginException catch (_) {
      // 原生端未注册该 Channel，静默忽略
    }
  }

  /// 处理接收到的文件路径
  void _handleIncomingFile(String filePath) {
    // 只接受 .passbackup 文件
    if (!filePath.toLowerCase().endsWith('.passbackup')) return;

    // 验证文件是否存在（对 content:// URI 无法验证，直接放行）
    if (!filePath.startsWith('content://') &&
        !filePath.startsWith('/')) {
      return;
    }

    _pendingFilePath = filePath;
    _fileIntentController.add(filePath);
  }

  /// 释放资源
  void dispose() {
    _fileIntentController.close();
  }
}
