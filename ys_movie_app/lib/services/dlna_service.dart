import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cast/cast_manager.dart';
import 'cast/models.dart';

/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 投屏服务实现（兼容层）
/// 说明：保留原有接口，内部使用新的 CastManager 实现
/// 建议新项目直接使用 CastManager
class DlnaService {
  static const MethodChannel _channel = MethodChannel('com.jiege.cast');
  final ValueNotifier<List<DeviceInfo>> devices = ValueNotifier<List<DeviceInfo>>([]);
  DeviceInfo? _currentDevice;
  bool _isSearching = false;
  StreamSubscription? _deviceSubscription;
  final CastManager _castManager = CastManager();

  /// 开始搜索局域网内的投屏设备
  Future<void> startSearch() async {
    if (_isSearching) return;
    _isSearching = true;
    devices.value = [];

    try {
      // 确保CastManager已初始化（单例，重复调用安全）
      await _castManager.initialize();
      await _castManager.searchDevices(timeout: const Duration(seconds: 8));

      // 监听设备列表变化
      void onDevicesChanged() {
        final castDevices = _castManager.devices.value;
        devices.value = castDevices.map((d) => DeviceInfo(
          friendlyName: d.name,
          uuid: d.id,
          urlBase: d.protocol.value,
        )).toList();
      }

      _castManager.devices.addListener(onDevicesChanged);
      _deviceSubscription = StreamSubscriptionStub(onCancel: () {
        _castManager.devices.removeListener(onDevicesChanged);
      });
    } catch (e) {
      debugPrint('搜索设备失败: $e');
      _simulateDevices();
    }

    _isSearching = false;
  }

  /// 模拟设备（用于演示或原生方法不可用时）
  void _simulateDevices() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isSearching) return;
      devices.value = [
        DeviceInfo(friendlyName: '客厅电视', uuid: 'tv1', urlBase: 'dlna'),
        DeviceInfo(friendlyName: '卧室电视', uuid: 'tv2', urlBase: 'dlna'),
        DeviceInfo(friendlyName: '小米盒子', uuid: 'box1', urlBase: 'dlna'),
      ];
      _isSearching = false;
    });
  }

  /// 停止搜索设备
  void stopSearch() {
    _isSearching = false;
    _deviceSubscription?.cancel();
    _deviceSubscription = null;
    _castManager.stopSearch();
  }

  /// 连接指定设备
  Future<void> connect(DeviceInfo device) async {
    try {
      _currentDevice = device;

      // 查找对应的 CastDevice
      final castDevices = _castManager.devices.value;
      final targetDevice = castDevices.firstWhere(
        (d) => d.id == device.uuid,
        orElse: () => CastDevice(
          id: device.uuid,
          name: device.friendlyName,
          protocol: CastProtocol.fromString(device.urlBase),
        ),
      );

      await _castManager.connect(targetDevice);
      debugPrint('已连接到设备: ${device.friendlyName}');
    } catch (e) {
      debugPrint('连接设备失败: $e');
      throw Exception('连接设备失败: $e');
    }
  }

  /// 投屏视频到已连接设备
  Future<void> cast(String url, String title) async {
    if (_currentDevice == null) {
      throw Exception('未连接设备，请先连接投屏设备');
    }
    if (url.isEmpty) {
      throw Exception('视频地址为空');
    }

    try {
      final media = CastMediaInfo(url: url, title: title);
      await _castManager.play(media);
      debugPrint('投屏成功: $title');
    } catch (e) {
      debugPrint('投屏失败: $e');
      // 如果新引擎失败，回退到原生方法
      try {
        final result = await _channel.invokeMethod('cast', {
          'url': url,
          'title': title,
          'deviceId': _currentDevice!.uuid,
        });
        debugPrint('原生投屏结果: $result');
      } catch (fallbackError) {
        throw Exception('投屏失败: $e');
      }
    }
  }

  /// 暂停投屏播放
  Future<void> pause() async {
    if (_currentDevice == null) return;
    try {
      await _castManager.pause();
    } catch (e) {
      debugPrint('暂停失败: $e');
      await _channel.invokeMethod('pause');
    }
  }

  /// 恢复投屏播放
  Future<void> resume() async {
    if (_currentDevice == null) return;
    try {
      await _castManager.resume();
    } catch (e) {
      debugPrint('恢复播放失败: $e');
      await _channel.invokeMethod('play');
    }
  }

  /// 停止投屏
  Future<void> stop() async {
    if (_currentDevice == null) return;
    try {
      await _castManager.stop();
      _currentDevice = null;
    } catch (e) {
      debugPrint('停止投屏失败: $e');
      await _channel.invokeMethod('stop');
    }
  }

  /// 断开当前设备连接
  void disconnect() {
    _castManager.disconnect();
    _currentDevice = null;
  }

  /// 释放资源
  void dispose() {
    stopSearch();
    disconnect();
    // 注意：不要dispose devices ValueNotifier，因为它可能被外部监听
  }
}

/// 设备信息类
class DeviceInfo {
  final String friendlyName;
  final String uuid;
  final String urlBase;

  DeviceInfo({
    required this.friendlyName,
    required this.uuid,
    required this.urlBase,
  });
}

/// StreamSubscription 占位实现
/// 用于 ValueNotifier 的 listener 管理
class StreamSubscriptionStub implements StreamSubscription<void> {
  final VoidCallback? onCancel;

  StreamSubscriptionStub({this.onCancel});

  @override
  Future<void> cancel() async {
    onCancel?.call();
  }

  @override
  void onData(void Function(void data)? handleData) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  bool get isPaused => false;

  @override
  Future<E> asFuture<E>([E? futureValue]) => Future.value(futureValue);
}
