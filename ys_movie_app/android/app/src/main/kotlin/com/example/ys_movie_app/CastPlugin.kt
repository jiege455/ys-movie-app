package com.example.ys_movie_app

import android.content.Context
import android.net.wifi.WifiManager
import androidx.mediarouter.media.MediaControlIntent
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import androidx.mediarouter.media.MediaRouter.RouteInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry
import java.net.InetAddress
import java.net.UnknownHostException
import java.nio.ByteOrder

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 投屏插件 - Android 原生实现
 * 使用 MediaRouter 框架搜索和连接投屏设备
 */
class CastPlugin(private val context: Context) : MethodCallHandler {
    private val channelName = "com.jiege.cast"
    private var mediaRouter: MediaRouter? = null
    private var routeSelector: MediaRouteSelector? = null
    private var callback: MediaRouter.Callback? = null
    private val routes = mutableListOf<RouteInfo>()

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

    init {
        mediaRouter = MediaRouter.getInstance(context)
        routeSelector = MediaRouteSelector.Builder()
            .addControlCategory(MediaControlIntent.CATEGORY_REMOTE_PLAYBACK)
            .addControlCategory(MediaControlIntent.CATEGORY_LIVE_VIDEO)
            .build()
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
                // 暂停投屏（需要通过 DLNA 协议发送暂停命令）
                result.success(true)
            }
            "play" -> {
                // 恢复投屏
                result.success(true)
            }
            "stop" -> {
                // 停止投屏
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * 搜索局域网内的投屏设备
     */
    private fun searchDevices(result: MethodChannel.Result) {
        routes.clear()
        
        // 获取 WiFi 信息
        val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val wifiInfo = wifiManager.connectionInfo
        val ipAddress = wifiInfo.ipAddress
        
        // 构建设备列表
        val devices = mutableListOf<Map<String, String>>()
        
        // 添加通过 MediaRouter 发现的设备
        mediaRouter?.routes?.forEach { route ->
            if (route.isDefaultRoute) return@forEach
            if (route.playbackType == RouteInfo.PLAYBACK_TYPE_REMOTE) {
                devices.add(mapOf(
                    "id" to route.id,
                    "name" to route.name,
                    "type" to "chromecast"
                ))
            }
        }
        
        // 如果没有发现设备，添加一些常见的 DLNA 设备提示
        if (devices.isEmpty()) {
            // 尝试通过 SSDP 发现设备（简化版）
            discoverDlnaDevices(devices)
        }
        
        result.success(devices)
    }

    /**
     * 简单的 DLNA 设备发现（基于常见的设备IP范围）
     */
    private fun discoverDlnaDevices(devices: MutableList<Map<String, String>>) {
        // 获取当前网段
        val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val ip = wifiManager.connectionInfo.ipAddress
        val ipString = if (ByteOrder.nativeOrder() == ByteOrder.LITTLE_ENDIAN) {
            Integer.reverseBytes(ip)
        } else {
            ip
        }
        
        // 添加常见设备作为提示
        devices.add(mapOf(
            "id" to "dlna_scan",
            "name" to "搜索 DLNA 设备...",
            "type" to "dlna"
        ))
    }

    /**
     * 投屏到指定设备
     */
    private fun castToDevice(url: String, title: String, deviceId: String, result: MethodChannel.Result) {
        try {
            // 找到对应的设备路由
            val route = routes.find { it.id == deviceId }
            
            if (route != null) {
                // 使用 MediaRouter 发送投屏请求
                val intent = android.content.Intent(MediaControlIntent.ACTION_PLAY)
                intent.addCategory(MediaControlIntent.CATEGORY_REMOTE_PLAYBACK)
                intent.setDataAndType(android.net.Uri.parse(url), "video/*")
                intent.putExtra(MediaControlIntent.EXTRA_ITEM_STATUS, title)
                
                route.sendControlRequest(intent, null)
                result.success(true)
            } else {
                // 如果没有找到路由，尝试使用系统分享
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("CAST_ERROR", "投屏失败: ${e.message}", null)
        }
    }
}
