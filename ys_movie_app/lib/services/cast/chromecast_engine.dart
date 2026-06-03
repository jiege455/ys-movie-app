/// 开发者：杰哥网络科技 (qq: 2711793818)
/// Chromecast协议投屏引擎实现
/// 说明：基于Android MediaRouter和系统分享实现Chromecast支持
/// iOS平台通过AirPlay fallback支持
/// 完整Google Cast SDK集成可作为后续升级方向

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'cast_engine.dart';
import 'models.dart';
import 'exceptions.dart';

/// Chromecast引擎
/// 当前实现使用系统级投屏能力，完整SDK集成需添加google_cast依赖
class ChromecastEngine extends BaseCastEngine {
  static const MethodChannel _channel = MethodChannel('com.jiege.cast');

  @override
  String get name => 'Chromecast引擎';

  @override
  CastProtocol get protocol => CastProtocol.chromecast;

  @override
  Future<bool> get isAvailable async {
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('isChromecastAvailable');
        return result ?? false;
      } catch (e) {
        // 方法未实现时返回true，允许尝试系统分享
        return true;
      }
    }
    // iOS通过AirPlay处理
    return false;
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
      if (Platform.isAndroid) {
        // 尝试调用原生Chromecast设备搜索
        final result = await _channel.invokeMethod<List<dynamic>>('searchChromecastDevices');
        if (result != null) {
          for (final item in result) {
            final map = Map<String, dynamic>.from(item);
            final device = CastDevice(
              id: map['id'] ?? '',
              name: map['name'] ?? 'Chromecast设备',
              protocol: CastProtocol.chromecast,
            );
            if (!_foundDevices.any((d) => d.id == device.id)) {
              _foundDevices.add(device);
            }
          }
        }
      }

      // 如果没有找到设备，添加一个系统投屏选项
      if (_foundDevices.isEmpty) {
        _foundDevices.add(const CastDevice(
          id: 'chromecast_system',
          name: '系统投屏 (Chromecast)',
          protocol: CastProtocol.system,
        ));
      }

      updateDevices(List.unmodifiable(_foundDevices));
    } catch (e) {
      debugPrint('Chromecast搜索错误: $e');
      // 添加系统投屏作为fallback
      _foundDevices.add(const CastDevice(
        id: 'chromecast_fallback',
        name: '系统投屏',
        protocol: CastProtocol.system,
      ));
      updateDevices(List.unmodifiable(_foundDevices));
    } finally {
      setSearching(false);
      clearSearchTimeout();
    }
  }

  final List<CastDevice> _foundDevices = [];

  @override
  Future<void> stopSearch() async {
    if (!isSearching) return;
    
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('stopSearchChromecastDevices');
      }
    } catch (e) {
      debugPrint('停止Chromecast搜索错误: $e');
    } finally {
      setSearching(false);
      clearSearchTimeout();
      _foundDevices.clear();
    }
  }

  @override
  Future<void> connect(CastDevice device) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('connectChromecastDevice', {
          'deviceId': device.id,
        });
      }

      setConnected(device.copyWith(isConnected: true));
      updateState(const CastPlaybackState(status: CastStatus.connected));
    } on MissingPluginException {
      setConnected(device.copyWith(isConnected: true));
      updateState(const CastPlaybackState(status: CastStatus.connected));
    } catch (e) {
      throw DeviceConnectionException('连接Chromecast设备失败: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('disconnectChromecastDevice');
      }
    } catch (e) {
      debugPrint('断开Chromecast连接错误: $e');
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

      if (Platform.isAndroid) {
        await _channel.invokeMethod('chromecastCast', {
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
      // 如果原生方法失败，使用系统分享
      try {
        await _channel.invokeMethod('cast', {
          'url': media.url,
          'title': media.title,
          'deviceId': currentDevice!.id,
        });
        updateState(currentState.copyWith(
          status: CastStatus.playing,
          duration: media.duration ?? 0,
        ));
      } catch (fallbackError) {
        updateState(currentState.copyWith(
          status: CastStatus.error,
          errorMessage: '播放失败: $e',
        ));
        throw CastPlaybackException('播放失败: $e');
      }
    }
  }

  @override
  Future<void> pause() async {
    try {
      if (Platform.isAndroid) {
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
      if (Platform.isAndroid) {
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
      if (Platform.isAndroid) {
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
      if (Platform.isAndroid) {
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
      if (Platform.isAndroid) {
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
      if (Platform.isAndroid) {
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
    // Chromecast支持有限的速度控制
    debugPrint('Chromecast播放速度控制: $speed');
    updateState(currentState.copyWith(speed: speed));
  }

  @override
  Future<int> getPosition() async {
    try {
      if (Platform.isAndroid) {
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
      debugPrint('Chromecast心跳检测失败: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await stopSearch();
    await super.dispose();
  }
}
