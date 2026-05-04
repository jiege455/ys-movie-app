/// 开发者：杰哥网络科技 (qq: 2711793818)
/// DLNA协议投屏引擎实现
/// 说明：基于 dlna_dart 库实现DLNA设备发现和控制
/// 支持设备搜索、连接、播放、暂停、进度控制等功能

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:dlna_dart/dlna.dart' as dlna;
import 'cast_engine.dart';
import 'models.dart';
import 'exceptions.dart';

class DlnaEngine extends BaseCastEngine {
  dlna.DLNAManager? _dlnaManager;
  dlna.DLNADevice? _currentDlnaDevice;
  dlna.DeviceManager? _deviceManager;
  StreamSubscription? _deviceSubscription;

  final List<CastDevice> _foundDevices = [];
  final Map<String, dlna.DLNADevice> _deviceInstances = {};

  @override
  String get name => 'DLNA引擎';

  @override
  CastProtocol get protocol => CastProtocol.dlna;

  @override
  Future<bool> get isAvailable async {
    try {
      final results = await Connectivity().checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    // DLNA引擎初始化
  }

  @override
  Future<void> startSearch({Duration timeout = const Duration(seconds: 10)}) async {
    if (isSearching) return;

    final available = await isAvailable;
    if (!available) {
      throw const CastNetworkException('网络不可用，无法搜索设备');
    }

    _foundDevices.clear();
    _deviceInstances.clear();
    setSearching(true);
    setSearchTimeout(timeout);

    try {
      _dlnaManager = dlna.DLNAManager();
      _deviceManager = await _dlnaManager!.start();

      // 监听设备发现
      _deviceSubscription = _deviceManager!.devices.stream.listen(
        (deviceMap) {
          _onDevicesFound(deviceMap);
        },
        onError: (error) {
          debugPrint('DLNA搜索错误: $error');
        },
      );

      // 超时后自动停止
      Future.delayed(timeout, () {
        if (isSearching) {
          stopSearch();
        }
      });
    } catch (e) {
      setSearching(false);
      throw DeviceSearchException('启动设备搜索失败: $e');
    }
  }

  /// 处理发现的设备
  void _onDevicesFound(Map<String, dlna.DLNADevice> deviceMap) {
    for (final entry in deviceMap.entries) {
      final device = entry.value;
      final info = device.info;

      Uri? uri;
      try {
        uri = Uri.parse(info.URLBase);
      } catch (_) {}

      final castDevice = CastDevice(
        id: entry.key,
        name: info.friendlyName,
        ipAddress: uri?.host,
        port: uri?.port,
        protocol: CastProtocol.dlna,
        descriptionUrl: info.URLBase,
      );

      _deviceInstances[entry.key] = device;

      if (!_foundDevices.any((d) => d.id == castDevice.id)) {
        _foundDevices.add(castDevice);
        updateDevices(List.unmodifiable(_foundDevices));
      }
    }
  }

  @override
  Future<void> stopSearch() async {
    setSearching(false);
    clearSearchTimeout();
    await _deviceSubscription?.cancel();
    _deviceSubscription = null;
    _deviceInstances.clear();
    _dlnaManager?.stop();
    _dlnaManager = null;
    _deviceManager = null;
  }

  @override
  Future<void> connect(CastDevice device) async {
    if (device.protocol != CastProtocol.dlna) {
      throw DeviceConnectionException('不支持的协议类型: ${device.protocol}');
    }

    try {
      final dlnaDevice = _deviceInstances[device.id];
      if (dlnaDevice == null) {
        throw const DeviceConnectionException('设备实例已过期，请重新搜索');
      }

      _currentDlnaDevice = dlnaDevice;
      setConnected(device.copyWith(isConnected: true));

      updateState(const CastPlaybackState(status: CastStatus.connected));
    } catch (e) {
      throw DeviceConnectionException('连接设备失败: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_currentDlnaDevice != null) {
        await stop();
      }
    } catch (e) {
      debugPrint('断开连接时出错: $e');
    } finally {
      _currentDlnaDevice = null;
      setConnected(null);
      updateState(const CastPlaybackState(status: CastStatus.idle));
    }
  }

  @override
  Future<void> play(CastMediaInfo media) async {
    if (_currentDlnaDevice == null) {
      throw const CastPlaybackException('未连接设备');
    }

    try {
      updateState(currentState.copyWith(status: CastStatus.buffering));

      // 设置媒体URL并播放
      await _currentDlnaDevice!.setUrl(media.url, title: media.title);
      await Future.delayed(const Duration(milliseconds: 500));
      await _currentDlnaDevice!.play();

      updateState(currentState.copyWith(
        status: CastStatus.playing,
        duration: media.duration ?? 0,
      ));
    } catch (e) {
      updateState(currentState.copyWith(
        status: CastStatus.error,
        errorMessage: '播放失败: $e',
      ));
      throw CastPlaybackException('播放失败: $e');
    }
  }

  @override
  Future<void> pause() async {
    if (_currentDlnaDevice == null) return;

    try {
      await _currentDlnaDevice!.pause();
      updateState(currentState.copyWith(status: CastStatus.paused));
    } catch (e) {
      throw CastPlaybackException('暂停失败: $e');
    }
  }

  @override
  Future<void> resume() async {
    if (_currentDlnaDevice == null) return;

    try {
      await _currentDlnaDevice!.play();
      updateState(currentState.copyWith(status: CastStatus.playing));
    } catch (e) {
      throw CastPlaybackException('恢复播放失败: $e');
    }
  }

  @override
  Future<void> stop() async {
    if (_currentDlnaDevice == null) return;

    try {
      await _currentDlnaDevice!.stop();
      updateState(currentState.copyWith(status: CastStatus.connected));
    } catch (e) {
      debugPrint('停止播放失败: $e');
    }
  }

  @override
  Future<void> seek(int position) async {
    if (_currentDlnaDevice == null) return;

    try {
      // DLNA使用HH:MM:SS格式
      final duration = Duration(milliseconds: position);
      final hours = duration.inHours.toString().padLeft(2, '0');
      final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      final target = '$hours:$minutes:$seconds';

      await _currentDlnaDevice!.seek(target);
      updateState(currentState.copyWith(position: position));
    } catch (e) {
      throw CastPlaybackException('跳转失败: $e');
    }
  }

  @override
  Future<void> setVolume(int volume) async {
    if (_currentDlnaDevice == null) return;

    try {
      final vol = volume.clamp(0, 100);
      await _currentDlnaDevice!.volume(vol);
      updateState(currentState.copyWith(volume: volume));
    } catch (e) {
      throw CastPlaybackException('设置音量失败: $e');
    }
  }

  @override
  Future<void> setMute(bool muted) async {
    if (_currentDlnaDevice == null) return;

    try {
      await _currentDlnaDevice!.mute(muted);
      updateState(currentState.copyWith(isMuted: muted));
    } catch (e) {
      throw CastPlaybackException('设置静音失败: $e');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    // DLNA标准不直接支持播放速度控制
    debugPrint('DLNA不支持播放速度控制');
  }

  @override
  Future<int> getPosition() async {
    if (_currentDlnaDevice == null) return 0;

    try {
      final posInfo = await _currentDlnaDevice!.position();
      // DLNA position 返回格式如 "00:05:30"，解析为毫秒
      if (posInfo is String && posInfo.contains(':')) {
        final parts = posInfo.split(':');
        if (parts.length == 3) {
          final hours = int.tryParse(parts[0]) ?? 0;
          final minutes = int.tryParse(parts[1]) ?? 0;
          final seconds = int.tryParse(parts[2]) ?? 0;
          return ((hours * 3600 + minutes * 60 + seconds) * 1000);
        }
      }
      return currentState.position;
    } catch (e) {
      return currentState.position;
    }
  }

  @override
  Future<void> onHeartbeat() async {
    if (_currentDlnaDevice == null || !isConnected) return;

    try {
      await _currentDlnaDevice!.getTransportInfo();
    } catch (e) {
      debugPrint('心跳检测失败，设备可能已断开: $e');
      updateState(currentState.copyWith(
        status: CastStatus.error,
        errorMessage: '设备已断开连接',
      ));
      await disconnect();
    }
  }

  @override
  Future<void> dispose() async {
    await stopSearch();
    await super.dispose();
  }
}
