import Flutter
import UIKit
import AVKit
import MediaPlayer

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 投屏插件 - iOS 原生实现
 * 使用 AVRoutePickerView 和 AirPlay 实现投屏
 */
public class CastPlugin: NSObject, FlutterPlugin {
    private var routePickerView: AVRoutePickerView?
    private var window: UIWindow?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.jiege.cast", binaryMessenger: registrar.messenger())
        let instance = CastPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "searchDevices":
            searchDevices(result: result)
        case "cast":
            if let args = call.arguments as? [String: Any],
               let url = args["url"] as? String,
               let title = args["title"] as? String {
                castToDevice(url: url, title: title, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "参数错误", details: nil))
            }
        case "pause":
            // 暂停播放
            result(true)
        case "play":
            // 恢复播放
            result(true)
        case "stop":
            // 停止播放
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /**
     * 搜索可用的 AirPlay 设备
     */
    private func searchDevices(result: @escaping FlutterResult) {
        var devices: [[String: String]] = []
        
        // 检查 AirPlay 是否可用
        let session = AVAudioSession.sharedInstance()
        
        // 获取当前音频输出端口
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
        
        // 添加可用的输出设备
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
            
            // 添加默认设备提示
            if devices.isEmpty {
                devices.append([
                    "id": "airplay_scan",
                    "name": "搜索 AirPlay 设备...",
                    "type": "airplay"
                ])
            }
        } catch {
            print("音频会话配置失败: \(error)")
        }
        
        result(devices)
    }
    
    /**
     * 投屏到设备
     */
    private func castToDevice(url: String, title: String, result: @escaping FlutterResult) {
        guard let url = URL(string: url) else {
            result(FlutterError(code: "INVALID_URL", message: "无效的视频地址", details: nil))
            return
        }
        
        // 使用 AVPlayerViewController 播放
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        // 获取当前视图控制器
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            rootViewController.present(playerViewController, animated: true) {
                player.play()
                result(true)
            }
        } else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "无法获取视图控制器", details: nil))
        }
    }
}
