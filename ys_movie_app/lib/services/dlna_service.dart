import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 投屏服务实现
 * 说明：使用原生平台通道调用系统投屏功能
 * Android: 使用 MediaRouter + Cast 框架
 * iOS: 使用 AirPlay + AVRoutePickerView
 */
class DlnaService {
  static const MethodChannel _channel = MethodChannel('com.jiege.cast');
  final ValueNotifier<List<DeviceInfo>> devices = ValueNotifier<List<DeviceInfo>>([]);
  DeviceInfo? _currentDevice;
  bool _isSearching = false;
  StreamSubscription? _deviceSubscription;

  /**
   * 开始搜索局域网内的投屏设备
   */
  Future<void> startSearch() async {
    if (_isSearching) return;
    _isSearching = true;
    devices.value = [];

    try {
      // 调用原生方法搜索设备
      final List<dynamic> result = await _channel.invokeMethod('searchDevices');
      final List<DeviceInfo> foundDevices = result.map((item) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);
        return DeviceInfo(
          friendlyName: map['name'] ?? '未知设备',
          uuid: map['id'] ?? '',
          urlBase: map['type'] ?? 'dlna',
        );
      }).toList();

      devices.value = foundDevices;
    } catch (e) {
      debugPrint('搜索设备失败: $e');
      // 如果原生方法失败，使用模拟数据演示
      _simulateDevices();
    }

    _isSearching = false;
  }

  /**
   * 模拟设备（用于演示或原生方法不可用时）
   */
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

  /**
   * 停止搜索设备
   */
  void stopSearch() {
    _isSearching = false;
    _deviceSubscription?.cancel();
    _deviceSubscription = null;
  }

  /**
   * 连接指定设备
   */
  Future<void> connect(DeviceInfo device) async {
    try {
      _currentDevice = device;
      debugPrint('已连接到设备: ${device.friendlyName}');
    } catch (e) {
      debugPrint('连接设备失败: $e');
      throw Exception('连接设备失败: $e');
    }
  }

  /**
   * 投屏视频到已连接设备
   */
  Future<void> cast(String url, String title) async {
    if (_currentDevice == null) {
      throw Exception('未连接设备，请先连接投屏设备');
    }
    if (url.isEmpty) {
      throw Exception('视频地址为空');
    }

    try {
      final result = await _channel.invokeMethod('cast', {
        'url': url,
        'title': title,
        'deviceId': _currentDevice!.uuid,
      });
      debugPrint('投屏结果: $result');
    } catch (e) {
      debugPrint('投屏失败: $e');
      // 如果原生投屏失败，尝试使用系统分享
      throw Exception('投屏失败: $e');
    }
  }

  /**
   * 暂停投屏播放
   */
  Future<void> pause() async {
    if (_currentDevice == null) return;
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      debugPrint('暂停失败: $e');
    }
  }

  /**
   * 恢复投屏播放
   */
  Future<void> resume() async {
    if (_currentDevice == null) return;
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      debugPrint('恢复播放失败: $e');
    }
  }

  /**
   * 停止投屏
   */
  Future<void> stop() async {
    if (_currentDevice == null) return;
    try {
      await _channel.invokeMethod('stop');
      _currentDevice = null;
    } catch (e) {
      debugPrint('停止投屏失败: $e');
    }
  }

  /**
   * 断开当前设备连接
   */
  void disconnect() {
    _currentDevice = null;
  }

  /**
   * 释放资源
   */
  void dispose() {
    stopSearch();
    disconnect();
    devices.dispose();
  }
}

/**
 * 设备信息类
 */
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
