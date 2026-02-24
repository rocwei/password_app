package com.rocwei.password

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "com.rocwei.password/file_intent"
    }

    private var methodChannel: MethodChannel? = null

    /// 冷启动时缓存的文件路径，等 Flutter 侧查询时返回
    private var initialFilePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL
        )

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFilePath" -> {
                    result.success(initialFilePath)
                    // 消费一次后清空，避免重复处理
                    initialFilePath = null
                }
                else -> result.notImplemented()
            }
        }

        // 处理冷启动时携带的 Intent（还没有 Flutter 端监听，先缓存）
        handleIntent(intent, isColdStart = true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 应用已在前台运行时收到新 Intent（热启动 / singleTop）
        handleIntent(intent, isColdStart = false)
    }

    /**
     * 将 Intent 中携带的文件 URI 复制到应用缓存目录，
     * 然后将缓存文件的绝对路径传递给 Flutter 层。
     *
     * 为什么要复制？
     *   微信等应用分享的 URI 通常是 content:// 协议，Flutter/Dart
     *   的 File API 无法直接读取，因此需要通过 ContentResolver
     *   将内容复制到本应用可访问的缓存路径。
     */
    private fun handleIntent(intent: Intent, isColdStart: Boolean) {
        val uri: Uri? = intent.data
            ?: intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri

        if (uri == null) return

        try {
            // 通过 ContentResolver 将 content:// 文件复制到缓存目录
            val inputStream = contentResolver.openInputStream(uri) ?: return

            // 尝试从 URI 获取文件名，否则使用默认名称
            val fileName = getFileNameFromUri(uri) ?: "received_backup.passbackup"

            // 只处理 .passbackup 文件
            if (!fileName.lowercase().endsWith(".passbackup")) {
                inputStream.close()
                return
            }

            val cacheDir = File(cacheDir, "received_backups")
            if (!cacheDir.exists()) cacheDir.mkdirs()
            val cachedFile = File(cacheDir, fileName)

            FileOutputStream(cachedFile).use { outputStream ->
                inputStream.copyTo(outputStream)
            }
            inputStream.close()

            val filePath = cachedFile.absolutePath

            if (isColdStart) {
                // 冷启动时 Flutter 还没准备好，先缓存路径
                initialFilePath = filePath
            } else {
                // 热启动，直接通过 MethodChannel 推送给 Flutter
                methodChannel?.invokeMethod("onNewFileIntent", filePath)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * 尝试从 content:// URI 中提取文件名
     */
    private fun getFileNameFromUri(uri: Uri): String? {
        // 先从 ContentResolver 查 DISPLAY_NAME
        try {
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(
                        android.provider.OpenableColumns.DISPLAY_NAME
                    )
                    if (nameIndex >= 0) {
                        return it.getString(nameIndex)
                    }
                }
            }
        } catch (_: Exception) {}

        // 退而求其次，取 URI path 的最后一段
        return uri.lastPathSegment
    }
}
