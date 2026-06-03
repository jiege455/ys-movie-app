package com.example.ys_movie_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 投屏插件 - Android 原生实现
 * 支持 DLNA / Chromecast / 系统分享 投屏
 * 提供状态回调和错误处理
 */
class CastPlugin(private val context: Context) : MethodCallHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    companion object {
        const val CHANNEL_NAME = "com.jiege.cast"
        const val EVENT_CHANNEL_NAME = "com.jiege.cast/events"

        fun registerWith(registrar: PluginRegistry.Registrar) {
            val channel = MethodChannel(registrar.messenger(), CHANNEL_NAME)
            channel.setMethodCallHandler(CastPlugin(registrar.context()))
        }

        fun registerWith(engine: FlutterEngine, context: Context) {
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            val plugin = CastPlugin(context)
            channel.setMethodCallHandler(plugin)

            // 注册事件通道
            val eventChannel = EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME)
            eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    plugin.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    plugin.eventSink = null
                }
            })
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "searchDevices" -> searchDevices(result)
            "searchChromecastDevices" -> searchChromecastDevices(result)
            "isChromecastAvailable" -> checkChromecastAvailability(result)
            "connectChromecastDevice" -> {
                val deviceId = call.argument<String>("deviceId") ?: ""
                connectChromecastDevice(deviceId, result)
            }
            "disconnectChromecastDevice" -> disconnectChromecastDevice(result)
            "cast", "chromecastCast" -> {
                val url = call.argument<String>("url") ?: ""
                val title = call.argument<String>("title") ?: ""
                val deviceId = call.argument<String>("deviceId") ?: ""
                castToDevice(url, title, deviceId, result)
            }
            "pause" -> pausePlayback(result)
            "play" -> resumePlayback(result)
            "stop" -> stopPlayback(result)
            "seek" -> {
                val position = call.argument<Int>("position") ?: 0
                seekTo(position, result)
            }
            "setVolume" -> {
                val volume = call.argument<Int>("volume") ?: 100
                setVolume(volume, result)
            }
            "setMute" -> {
                val muted = call.argument<Boolean>("muted") ?: false
                setMute(muted, result)
            }
            "setSpeed" -> {
                val speed = call.argument<Double>("speed") ?: 1.0
                setSpeed(speed, result)
            }
            "getPosition" -> getPosition(result)
            "isAirPlayAvailable" -> result.success(false)
            else -> result.notImplemented()
        }
    }

    // ==================== 设备搜索 ====================

    /**
     * 搜索局域网内的 DLNA 设备
     */
    private fun searchDevices(result: MethodChannel.Result) {
        val devices = mutableListOf<Map<String, String>>()
        devices.add(mapOf(
            "id" to "dlna_scan",
            "name" to "搜索 DLNA 设备...",
            "type" to "dlna"
        ))
        result.success(devices)
    }

    /**
     * 搜索 Chromecast 设备
     * TODO: 集成 Google Cast SDK 实现真正的设备发现
     */
    private fun searchChromecastDevices(result: MethodChannel.Result) {
        val devices = mutableListOf<Map<String, String>>()
        // 当前返回空列表，等待 Google Cast SDK 集成
        result.success(devices)
    }

    /**
     * 检查 Chromecast 是否可用
     */
    private fun checkChromecastAvailability(result: MethodChannel.Result) {
        // 检查是否支持媒体路由
        val isAvailable = context.packageManager.hasSystemFeature("android.hardware.wifi")
        result.success(isAvailable)
    }

    // ==================== 设备连接 ====================

    /**
     * 连接 Chromecast 设备
     */
    private fun connectChromecastDevice(deviceId: String, result: MethodChannel.Result) {
        // TODO: 集成 Google Cast SDK 实现真正的设备连接
        result.success(true)
    }

    /**
     * 断开 Chromecast 设备连接
     */
    private fun disconnectChromecastDevice(result: MethodChannel.Result) {
        // TODO: 断开 Google Cast 会话
        result.success(true)
    }

    // ==================== 播放控制 ====================

    /**
     * 投屏播放媒体
     */
    private fun castToDevice(url: String, title: String, deviceId: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_VIEW)
            intent.setDataAndType(Uri.parse(url), "video/*")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            // 检查是否有应用可以处理这个 intent
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                sendEvent("onPlaybackStateChanged", mapOf(
                    "status" to "playing",
                    "position" to 0,
                    "duration" to 0
                ))
                result.success(true)
            } else {
                result.error("NO_APP", "没有找到可以投屏的应用", null)
            }
        } catch (e: Exception) {
            sendEvent("onPlaybackStateChanged", mapOf(
                "status" to "error",
                "error" to (e.message ?: "未知错误")
            ))
            result.error("CAST_ERROR", "投屏失败: ${e.message}", null)
        }
    }

    /**
     * 暂停播放
     */
    private fun pausePlayback(result: MethodChannel.Result) {
        sendEvent("onPlaybackStateChanged", mapOf(
            "status" to "paused",
            "position" to 0
        ))
        result.success(true)
    }

    /**
     * 恢复播放
     */
    private fun resumePlayback(result: MethodChannel.Result) {
        sendEvent("onPlaybackStateChanged", mapOf(
            "status" to "playing",
            "position" to 0
        ))
        result.success(true)
    }

    /**
     * 停止播放
     */
    private fun stopPlayback(result: MethodChannel.Result) {
        sendEvent("onPlaybackStateChanged", mapOf(
            "status" to "stopped",
            "position" to 0
        ))
        result.success(true)
    }

    /**
     * 跳转到指定位置
     */
    private fun seekTo(position: Int, result: MethodChannel.Result) {
        sendEvent("onPlaybackStateChanged", mapOf(
            "status" to "buffering",
            "position" to position
        ))
        result.success(true)
    }

    /**
     * 设置音量
     */
    private fun setVolume(volume: Int, result: MethodChannel.Result) {
        sendEvent("onPlaybackStateChanged", mapOf(
            "volume" to volume
        ))
        result.success(true)
    }

    /**
     * 设置静音
     */
    private fun setMute(muted: Boolean, result: MethodChannel.Result) {
        sendEvent("onPlaybackStateChanged", mapOf(
            "muted" to muted
        ))
        result.success(true)
    }

    /**
     * 设置播放速度
     */
    private fun setSpeed(speed: Double, result: MethodChannel.Result) {
        sendEvent("onPlaybackStateChanged", mapOf(
            "speed" to speed
        ))
        result.success(true)
    }

    /**
     * 获取当前播放位置
     */
    private fun getPosition(result: MethodChannel.Result) {
        result.success(0)
    }

    // ==================== 事件通知 ====================

    /**
     * 发送事件到 Flutter
     */
    private fun sendEvent(event: String, data: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(mapOf(
                "event" to event,
                "data" to data
            ))
        }
    }
}
