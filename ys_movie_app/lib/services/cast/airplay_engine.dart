/// 开发者：杰哥网络科技 (qq: 2711793818)
/// AirPlay协议投屏引擎实现
/// 说明：iOS平台使用原生AirPlay实现投屏
/// Android平台使用系统分享作为fallback

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'cast_engine.dart';
import 'models.dart';
import 'exceptions.dart';

class AirPlayEngine extends BaseCastEngine {
  static const MethodChannel _channel = MethodChannel('com.jiege.cast');

  @override
  String get name => 'AirPlay引擎';

  @override
  CastProtocol get protocol => CastProtocol.airplay;

  @override
  Future<bool> get isAvailable async {
    if (Platform.isIOS) {
      try {
        final result = await _channel.invokeMethod<bool>('isAirPlayAvailable');
        return result ?? false;
      } catch (e) {
        return false;
      }
    }
    // Android使用系统分享作为fallback
    return true;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startSearch({Duration timeout = const Duration(seconds: 10)}) async {
    if (isSearching) return;

    setSearching(true);
    _foundDevices.clear();
    setSearchTimeout(timeout);

    try {
      if (Platform.isIOS) {
        // iOS调用原生搜索AirPlay设备
        final result = await _channel.invokeMethod<List<dynamic>>('searchAirPlayDevices');
        if (result != null) {
          for (final item in result) {
            final map = Map<String, dynamic>.from(item);
            final device = CastDevice(
              id: map['id'] ?? '',
              name: map['name'] ?? '未知设备',
              protocol: CastProtocol.airplay,
            );
            if (!_foundDevices.any((d) => d.id == device.id)) {
              _foundDevices.add(device);
            }
          }
        }
      } else {
        // Android显示系统投屏选项
        _foundDevices.add(const CastDevice(
          id: 'android_system_cast',
          name: '系统投屏',
          protocol: CastProtocol.system,
        ));
      }

      updateDevices(List.unmodifiable(_foundDevices));
    } catch (e) {
      debugPrint('AirPlay搜索错误: $e');
    } finally {
      setSearching(false);
      clearSearchTimeout();
    }
  }

  final List<CastDevice> _foundDevices = [];

  @override
  Future<void> stopSearch() async {
    if (!isSearching) return;
    
    setSearching(false);
    clearSearchTimeout();
    
    if (Platform.isIOS) {
      try {
        await _channel.invokeMethod('stopSearchAirPlayDevices');
      } catch (e) {
        debugPrint('停止AirPlay搜索错误: $e');
      }
    }
  }

  @override
  Future<void> connect(CastDevice device) async {
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('connectAirPlayDevice', {
          'deviceId': device.id,
        });
      }

      setConnected(device.copyWith(isConnected: true));
      updateState(const CastPlaybackState(status: CastStatus.connected));
    } catch (e) {
      throw DeviceConnectionException('连接设备失败: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('disconnectAirPlayDevice');
      }
    } catch (e) {
      debugPrint('断开连接错误: $e');
    } finally {
      setConnected(null);
      updateState(const CastPlaybackState(status: CastStatus.idle));
    }
  }

  @override
  Future<void> play(CastMediaInfo media) async {
    if (currentDevice == null) {
      throw const CastPlaybackException('未连接设备');
    }

    try {
      updateState(currentState.copyWith(status: CastStatus.buffering));

      if (Platform.isIOS) {
        await _channel.invokeMethod('airPlayCast', {
          'url': media.url,
          'title': media.title,
          'deviceId': currentDevice!.id,
        });
      } else {
        // Android使用系统分享
        await _channel.invokeMethod('cast', {
          'url': media.url,
          'title': media.title,
          'deviceId': currentDevice!.id,
        });
      }

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
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('pause');
      }
      updateState(currentState.copyWith(status: CastStatus.paused));
    } catch (e) {
      throw CastPlaybackException('暂停失败: $e');
    }
  }

  @override
  Future<void> resume() async {
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('play');
      }
      updateState(currentState.copyWith(status: CastStatus.playing));
    } catch (e) {
      throw CastPlaybackException('恢复播放失败: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('stop');
      }
      updateState(currentState.copyWith(status: CastStatus.connected));
    } catch (e) {
      debugPrint('停止播放失败: $e');
    }
  }

  @override
  Future<void> seek(int position) async {
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('seek', {
          'position': position,
        });
      }
      updateState(currentState.copyWith(position: position));
    } catch (e) {
      throw CastPlaybackException('跳转失败: $e');
    }
  }

  @override
  Future<void> setVolume(int volume) async {
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('setVolume', {
          'volume': volume,
        });
      }
      updateState(currentState.copyWith(volume: volume));
    } catch (e) {
      throw CastPlaybackException('设置音量失败: $e');
    }
  }

  @override
  Future<void> setMute(bool muted) async {
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('setMute', {
          'muted': muted,
        });
      }
      updateState(currentState.copyWith(isMuted: muted));
    } catch (e) {
      throw CastPlaybackException('设置静音失败: $e');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('setSpeed', {
          'speed': speed,
        });
      }
      updateState(currentState.copyWith(speed: speed));
    } catch (e) {
      throw CastPlaybackException('设置播放速度失败: $e');
    }
  }

  @override
  Future<int> getPosition() async {
    try {
      if (Platform.isIOS) {
        final result = await _channel.invokeMethod<int>('getPosition');
        return result ?? currentState.position;
      }
    } catch (e) {
      debugPrint('获取位置失败: $e');
    }
    return currentState.position;
  }

  @override
  Future<void> onHeartbeat() async {
    if (currentDevice == null || !isConnected) return;

    try {
      final position = await getPosition();
      if (position != currentState.position) {
        updateState(currentState.copyWith(position: position));
      }
    } catch (e) {
      debugPrint('AirPlay心跳检测失败: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await stopSearch();
    await super.dispose();
  }
}
