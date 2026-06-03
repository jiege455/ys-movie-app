import Flutter
import UIKit
import AVKit
import MediaPlayer

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 投屏插件 - iOS 原生实现
 * 支持 AirPlay 设备发现、连接、播放控制
 * 提供状态回调和错误处理
 */
public class CastPlugin: NSObject, FlutterPlugin {
    private var routePickerView: AVRoutePickerView?
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?
    private var eventSink: FlutterEventSink?
    private var playbackObserver: Any?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.jiege.cast", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "com.jiege.cast/events", binaryMessenger: registrar.messenger())
        
        let instance = CastPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "searchDevices":
            searchDevices(result: result)
        case "searchAirPlayDevices":
            searchAirPlayDevices(result: result)
        case "connectAirPlayDevice":
            if let args = call.arguments as? [String: Any],
               let deviceId = args["deviceId"] as? String {
                connectAirPlayDevice(deviceId: deviceId, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "参数错误", details: nil))
            }
        case "disconnectAirPlayDevice":
            disconnectAirPlayDevice(result: result)
        case "cast", "airPlayCast":
            if let args = call.arguments as? [String: Any],
               let url = args["url"] as? String,
               let title = args["title"] as? String {
                castToDevice(url: url, title: title, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "参数错误", details: nil))
            }
        case "pause":
            pausePlayback(result: result)
        case "play":
            resumePlayback(result: result)
        case "stop":
            stopPlayback(result: result)
        case "seek":
            if let args = call.arguments as? [String: Any],
               let position = args["position"] as? Int {
                seekTo(position: position, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "参数错误", details: nil))
            }
        case "setVolume":
            if let args = call.arguments as? [String: Any],
               let volume = args["volume"] as? Int {
                setVolume(volume: volume, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "参数错误", details: nil))
            }
        case "setMute":
            if let args = call.arguments as? [String: Any],
               let muted = args["muted"] as? Bool {
                setMute(muted: muted, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "参数错误", details: nil))
            }
        case "setSpeed":
            if let args = call.arguments as? [String: Any],
               let speed = args["speed"] as? Double {
                setSpeed(speed: speed, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "参数错误", details: nil))
            }
        case "getPosition":
            getPosition(result: result)
        case "isAirPlayAvailable":
            checkAirPlayAvailability(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - 设备搜索
    
    private func searchDevices(result: @escaping FlutterResult) {
        var devices: [[String: String]] = []
        
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        
        for output in currentRoute.outputs {
            if output.portType == .airPlay {
                devices.append([
                    "id": output.uid,
                    "name": output.portName,
                    "type": "airplay"
                ])
            }
        }
        
        if devices.isEmpty {
            devices.append([
                "id": "airplay_scan",
                "name": "搜索 AirPlay 设备...",
                "type": "airplay"
            ])
        }
        
        result(devices)
    }
    
    private func searchAirPlayDevices(result: @escaping FlutterResult) {
        var devices: [[String: String]] = []
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
            
            // 获取可用的音频输出端口
            let availableInputs = session.availableInputs ?? []
            for input in availableInputs {
                devices.append([
                    "id": input.uid,
                    "name": input.portName,
                    "type": "airplay"
                ])
            }
            
            // 检查当前路由
            let currentRoute = session.currentRoute
            for output in currentRoute.outputs {
                if output.portType == .airPlay || output.portType == .bluetoothA2DP {
                    devices.append([
                        "id": output.uid,
                        "name": output.portName,
                        "type": "airplay"
                    ])
                }
            }
        } catch {
            print("音频会话配置失败: \(error)")
        }
        
        result(devices)
    }
    
    private func checkAirPlayAvailability(result: @escaping FlutterResult) {
        let session = AVAudioSession.sharedInstance()
        let isAvailable = session.currentRoute.outputs.contains { $0.portType == .airPlay }
        result(isAvailable)
    }
    
    // MARK: - 设备连接
    
    private func connectAirPlayDevice(deviceId: String, result: @escaping FlutterResult) {
        // AirPlay 连接由系统处理，这里记录设备ID
        result(true)
    }
    
    private func disconnectAirPlayDevice(result: @escaping FlutterResult) {
        stopPlayback { _ in }
        result(true)
    }
    
    // MARK: - 播放控制
    
    private func castToDevice(url: String, title: String, result: @escaping FlutterResult) {
        guard let videoUrl = URL(string: url) else {
            result(FlutterError(code: "INVALID_URL", message: "无效的视频地址", details: nil))
            return
        }
        
        // 清理之前的播放器
        cleanupPlayer()
        
        // 创建新的播放器
        let asset = AVAsset(url: videoUrl)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        // 监听播放状态
        setupPlaybackObservers()
        
        // 创建播放器视图控制器
        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        
        // 获取当前视图控制器并呈现
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            rootViewController.present(playerViewController!, animated: true) { [weak self] in
                self?.player?.play()
                self?.sendPlaybackEvent(status: "playing", position: 0, duration: 0)
                result(true)
            }
        } else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "无法获取视图控制器", details: nil))
        }
    }
    
    private func pausePlayback(result: @escaping FlutterResult) {
        player?.pause()
        sendPlaybackEvent(status: "paused", position: getCurrentPosition())
        result(true)
    }
    
    private func resumePlayback(result: @escaping FlutterResult) {
        player?.play()
        sendPlaybackEvent(status: "playing", position: getCurrentPosition())
        result(true)
    }
    
    private func stopPlayback(result: @escaping FlutterResult) {
        player?.pause()
        cleanupPlayer()
        sendPlaybackEvent(status: "stopped", position: 0)
        result(true)
    }
    
    private func seekTo(position: Int, result: @escaping FlutterResult) {
        let time = CMTimeMake(value: Int64(position), timescale: 1000)
        player?.seek(to: time) { [weak self] finished in
            if finished {
                self?.sendPlaybackEvent(status: "playing", position: position)
            }
            result(finished)
        }
    }
    
    private func setVolume(volume: Int, result: @escaping FlutterResult) {
        let vol = Float(volume) / 100.0
        player?.volume = vol
        result(true)
    }
    
    private func setMute(muted: Bool, result: @escaping FlutterResult) {
        player?.isMuted = muted
        result(true)
    }
    
    private func setSpeed(speed: Double, result: @escaping FlutterResult) {
        player?.rate = Float(speed)
        result(true)
    }
    
    private func getPosition(result: @escaping FlutterResult) {
        result(getCurrentPosition())
    }
    
    // MARK: - 辅助方法
    
    private func getCurrentPosition() -> Int {
        guard let player = player else { return 0 }
        let seconds = CMTimeGetSeconds(player.currentTime())
        return Int(seconds * 1000)
    }
    
    private func getDuration() -> Int {
        guard let player = player,
              let duration = player.currentItem?.duration else { return 0 }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? Int(seconds * 1000) : 0
    }
    
    private func setupPlaybackObservers() {
        guard let player = player else { return }
        
        // 监听播放状态
        playbackObserver = player.addPeriodicTimeObserver(
            forInterval: CMTimeMake(value: 1, timescale: 1),
            queue: .main
        ) { [weak self] time in
            let position = Int(CMTimeGetSeconds(time) * 1000)
            let duration = self?.getDuration() ?? 0
            let isPlaying = player.rate > 0 && player.error == nil
            let status = isPlaying ? "playing" : "paused"
            self?.sendPlaybackEvent(status: status, position: position, duration: duration)
        }
        
        // 监听播放完成
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }
    
    @objc private func playerDidFinishPlaying() {
        sendPlaybackEvent(status: "stopped", position: getDuration())
    }
    
    private func cleanupPlayer() {
        if let observer = playbackObserver {
            player?.removeTimeObserver(observer)
            playbackObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self)
        
        player?.pause()
        player = nil
        
        if let pvc = playerViewController {
            pvc.dismiss(animated: true)
            playerViewController = nil
        }
    }
    
    private func sendPlaybackEvent(status: String, position: Int, duration: Int = 0) {
        let data: [String: Any] = [
            "status": status,
            "position": position,
            "duration": duration
        ]
        // 发送事件名和数据的组合，与Dart端_handleMethodCall匹配
        eventSink?(["event": "onPlaybackStateChanged", "data": data])
    }
    
    deinit {
        cleanupPlayer()
    }
}

// MARK: - FlutterStreamHandler
extension CastPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
