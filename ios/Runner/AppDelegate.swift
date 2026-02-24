import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    /// 与 Flutter 端通信的 MethodChannel 名称（需与 Dart 侧一致）
    private let channelName = "com.rocwei.password/file_intent"
    
    /// 冷启动时缓存的文件路径
    private var initialFilePath: String?
    
    /// MethodChannel 实例
    private var methodChannel: FlutterMethodChannel?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // 注册 MethodChannel
        let controller = window?.rootViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "getInitialFilePath" {
                result(self?.initialFilePath)
                self?.initialFilePath = nil  // 消费后清空
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    /// 当其他应用通过 "用其他应用打开" 发送文件到本应用时调用
    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // 只处理 .passbackup 文件
        guard url.pathExtension.lowercased() == "passbackup" else {
            return super.application(app, open: url, options: options)
        }
        
        // 将文件复制到应用缓存目录（确保可访问）
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let receivedDir = cacheDir.appendingPathComponent("received_backups")
        
        try? fileManager.createDirectory(at: receivedDir, withIntermediateDirectories: true)
        
        let destURL = receivedDir.appendingPathComponent(url.lastPathComponent)
        
        // 如果目标已存在则先删除
        try? fileManager.removeItem(at: destURL)
        
        do {
            // 获取安全访问权限（对沙盒外文件）
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            
            try fileManager.copyItem(at: url, to: destURL)
            
            let filePath = destURL.path
            
            if methodChannel != nil {
                // 应用已在运行，直接推送给 Flutter
                methodChannel?.invokeMethod("onNewFileIntent", arguments: filePath)
            } else {
                // 冷启动，先缓存
                initialFilePath = filePath
            }
        } catch {
            print("复制备份文件失败: \(error)")
        }
        
        return true
    }
}
