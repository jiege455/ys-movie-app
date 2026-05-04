import Flutter
import UIKit
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 开发者：杰哥网络科技 (qq: 2711793818)
    // 注册投屏插件
    CastPlugin.register(with: self.registrar(forPlugin: "CastPlugin")!)

    // 配置音频会话以支持画中画（PiP）和后台播放
    configureAudioSession()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playback,
        mode: .moviePlayback,
        options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
      )
      try session.setActive(true)
    } catch {
      print("音频会话配置失败: \(error)")
    }
  }
}
