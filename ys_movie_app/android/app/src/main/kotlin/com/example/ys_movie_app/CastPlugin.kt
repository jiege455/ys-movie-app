package com.example.ys_movie_app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 投屏插件 - Android 原生实现
 * 使用系统分享和原生播放器实现投屏功能
 */
class CastPlugin(private val context: Context) : MethodCallHandler {

    companion object {
        fun registerWith(registrar: PluginRegistry.Registrar) {
            val channel = MethodChannel(registrar.messenger(), "com.jiege.cast")
            channel.setMethodCallHandler(CastPlugin(registrar.context()))
        }

        fun registerWith(engine: FlutterEngine, context: Context) {
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.jiege.cast")
            channel.setMethodCallHandler(CastPlugin(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "searchDevices" -> searchDevices(result)
            "cast" -> {
                val url = call.argument<String>("url") ?: ""
                val title = call.argument<String>("title") ?: ""
                val deviceId = call.argument<String>("deviceId") ?: ""
                castToDevice(url, title, deviceId, result)
            }
            "pause" -> {
                result.success(true)
            }
            "play" -> {
                result.success(true)
            }
            "stop" -> {
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * 搜索局域网内的投屏设备
     */
    private fun searchDevices(result: MethodChannel.Result) {
        val devices = mutableListOf<Map<String, String>>()
        
        // 添加常见设备作为提示
        devices.add(mapOf(
            "id" to "dlna_scan",
            "name" to "搜索 DLNA 设备...",
            "type" to "dlna"
        ))
        
        result.success(devices)
    }

    /**
     * 投屏到指定设备
     */
    private fun castToDevice(url: String, title: String, deviceId: String, result: MethodChannel.Result) {
        try {
            // 使用系统分享功能投屏
            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW)
            intent.setDataAndType(android.net.Uri.parse(url), "video/*")
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            
            // 检查是否有应用可以处理这个 intent
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                result.success(true)
            } else {
                result.error("NO_APP", "没有找到可以投屏的应用", null)
            }
        } catch (e: Exception) {
            result.error("CAST_ERROR", "投屏失败: ${e.message}", null)
        }
    }
}
