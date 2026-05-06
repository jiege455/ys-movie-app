/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 统一投屏管理器
/// 说明：管理所有投屏引擎的生命周期，提供统一的投屏接口
/// 支持多协议自动选择、网络自适应、错误恢复等高级功能

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'cast_engine.dart';
import 'dlna_engine.dart';
import 'airplay_engine.dart';
import 'chromecast_engine.dart';
import 'models.dart';
import 'exceptions.dart';

/// 投屏管理器 - 单例模式
class CastManager {
  static final CastManager _instance = CastManager._internal();
  factory CastManager() => _instance;
  CastManager._internal();

  /// 已注册的引擎列表
  final Map<CastProtocol, CastEngine> _engines = {};

  /// 引擎事件订阅（防止内存泄漏）
  final Map<CastProtocol, List<StreamSubscription>> _engineSubscriptions = {};

  /// 当前使用的引擎
  CastEngine? _currentEngine;

  /// 自动重连次数
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  /// 错误恢复定时器
  Timer? _recoveryTimer;

  /// 最后一次投屏的媒体信息，用于重连后恢复播放
  CastMediaInfo? _lastCastMedia;

  /// 网络监听
  StreamSubscription? _networkSubscription;

  /// 全局投屏状态通知
  final ValueNotifier<CastStatus> castStatus = ValueNotifier<CastStatus>(CastStatus.idle);

  /// 全局设备列表通知
  final ValueNotifier<List<CastDevice>> devices = ValueNotifier<List<CastDevice>>([]);

  /// 全局播放状态通知
  final ValueNotifier<CastPlaybackState> playbackState = ValueNotifier<CastPlaybackState>(const CastPlaybackState());

  /// 当前连接的设备
  CastDevice? get currentDevice => _currentEngine?.currentDevice;

  /// 是否正在投屏
  bool get isCasting => _currentEngine?.isConnected ?? false;

  /// 当前使用的协议
  CastProtocol? get currentProtocol => _currentEngine?.protocol;

  bool _isInitialized = false;
  bool _isDisconnecting = false;

  static const MethodChannel _channel = MethodChannel('com.jiege.cast');
  static const EventChannel _eventChannel = EventChannel('com.jiege.cast/events');
  StreamSubscription? _eventSubscription;

  /// 初始化管理器
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('CastManager 已经初始化，跳过');
      return;
    }

    // 设置统一的方法通道回调
    _channel.setMethodCallHandler(_handleMethodCall);

    // 监听事件通道（原生端主动发送的事件）
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onEventReceived,
      onError: (error) {
        debugPrint('事件通道错误: $error');
      },
    );

    // 注册DLNA引擎
    final dlnaEngine = DlnaEngine();
    _registerEngine(dlnaEngine);
    await dlnaEngine.initialize();

    // 注册AirPlay引擎
    final airPlayEngine = AirPlayEngine();
    _registerEngine(airPlayEngine);
    await airPlayEngine.initialize();

    // 注册Chromecast引擎
    final chromecastEngine = ChromecastEngine();
    _registerEngine(chromecastEngine);
    await chromecastEngine.initialize();

    // 监听网络变化
    _networkSubscription = Connectivity().onConnectivityChanged.listen(_onNetworkChanged);

    _isInitialized = true;
    debugPrint('CastManager 初始化完成');
  }

  /// 处理事件通道收到的数据
  void _onEventReceived(dynamic event) {
    if (event is! Map) return;

    final eventName = event['event'] as String?;
    final data = event['data'];

    switch (eventName) {
      case 'onPlaybackStateChanged':
        _onPlaybackStateChanged(data);
        break;
      case 'onDeviceDisconnected':
      case 'onChromecastDeviceDisconnected':
        if (!_isDisconnecting) {
          _performDisconnect();
        }
        break;
      case 'onChromecastStateChanged':
        _onChromecastStateChanged(data);
        break;
    }
  }

  /// 统一处理方法通道回调（Dart调用原生）
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    // 方法通道主要用于Dart调用原生方法
    // 原生主动发送的事件通过EventChannel处理
  }

  /// 处理播放状态变化事件
  void _onPlaybackStateChanged(dynamic args) {
    if (args is! Map) return;

    final status = args['status'] as String?;
    final position = args['position'] as int? ?? 0;
    final duration = args['duration'] as int? ?? 0;
    final volume = args['volume'] as int? ?? 100;
    final muted = args['muted'] as bool? ?? false;
    final speed = args['speed'] as double? ?? 1.0;

    CastStatus newStatus;
    switch (status) {
      case 'playing':
        newStatus = CastStatus.playing;
        break;
      case 'paused':
        newStatus = CastStatus.paused;
        break;
      case 'buffering':
        newStatus = CastStatus.buffering;
        break;
      case 'stopped':
        newStatus = CastStatus.connected;
        break;
      case 'error':
        newStatus = CastStatus.error;
        break;
      default:
        newStatus = CastStatus.casting;
    }

    playbackState.value = CastPlaybackState(
      status: newStatus,
      position: position,
      duration: duration,
      volume: volume,
      isMuted: muted,
      speed: speed,
    );
    castStatus.value = newStatus;
  }

  /// 处理Chromecast状态变化事件
  void _onChromecastStateChanged(dynamic args) {
    // Chromecast状态与通用状态格式相同
    _onPlaybackStateChanged(args);
  }

  /// 注册引擎
  void _registerEngine(CastEngine engine) {
    _engines[engine.protocol] = engine;

    // 监听引擎的播放状态变化
    final playbackSubscription = engine.playbackStream.listen((state) {
      playbackState.value = state;
      castStatus.value = state.status;

      // 检查是否需要错误恢复
      if (state.status == CastStatus.error && state.errorMessage != null) {
        _handleError(state.errorMessage!);
      }
    });

    _engineSubscriptions.putIfAbsent(engine.protocol, () => []);
    _engineSubscriptions[engine.protocol]!.add(playbackSubscription);
  }

  /// 搜索设备（自动使用所有可用协议）
  Future<void> searchDevices({Duration timeout = const Duration(seconds: 10)}) async {
    devices.value = [];

    // 并行搜索所有可用协议
    final futures = <Future<void>>[];

    for (final entry in _engines.entries) {
      final engine = entry.value;
      futures.add(_searchWithEngine(engine, timeout));
    }

    await Future.wait(futures, eagerError: false);
  }

  /// 使用指定引擎搜索
  Future<void> _searchWithEngine(CastEngine engine, Duration timeout) async {
    StreamSubscription? subscription;
    try {
      final available = await engine.isAvailable;
      if (!available) return;

      // 监听设备发现
      subscription = engine.deviceStream.listen((foundDevices) {
        final currentList = List<CastDevice>.from(devices.value);
        for (final device in foundDevices) {
          if (!currentList.any((d) => d.id == device.id)) {
            currentList.add(device);
          }
        }
        devices.value = currentList;
      });

      await engine.startSearch(timeout: timeout);
      await Future.delayed(timeout);
    } catch (e) {
      debugPrint('${engine.name} 搜索失败: $e');
    } finally {
      await subscription?.cancel();
    }
  }

  /// 停止搜索
  Future<void> stopSearch() async {
    for (final engine in _engines.values) {
      await engine.stopSearch();
    }
  }

  /// 连接设备（自动选择对应协议的引擎）
  Future<void> connect(CastDevice device) async {
    // 断开当前连接
    await disconnect();

    // 获取对应协议的引擎
    final engine = _engines[device.protocol];
    if (engine == null) {
      throw CastException('UNSUPPORTED_PROTOCOL', '不支持的协议: ${device.protocol.displayName}');
    }

    try {
      castStatus.value = CastStatus.connecting;
      await engine.connect(device);
      _currentEngine = engine;
      _reconnectAttempts = 0;
      debugPrint('已连接到设备: ${device.name}');
    } catch (e) {
      castStatus.value = CastStatus.error;
      rethrow;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;

    if (_currentEngine != null) {
      try {
        await _currentEngine!.disconnect();
      } catch (e) {
        debugPrint('引擎断开连接异常: $e');
      }
      _currentEngine = null;
    }

    _lastCastMedia = null;
    castStatus.value = CastStatus.idle;
    debugPrint('已断开投屏连接');
  }

  /// 投屏播放
  Future<void> play(CastMediaInfo media) async {
    if (_currentEngine == null) {
      throw const CastPlaybackException('未连接设备');
    }

    try {
      _lastCastMedia = media;
      await _currentEngine!.play(media);
      debugPrint('开始投屏: ${media.title}');
    } catch (e) {
      _handleError('播放失败: $e');
      rethrow;
    }
  }

  /// 暂停
  Future<void> pause() async {
    await _currentEngine?.pause();
  }

  /// 恢复播放
  Future<void> resume() async {
    await _currentEngine?.resume();
  }

  /// 停止播放
  Future<void> stop() async {
    await _currentEngine?.stop();
  }

  /// 跳转进度
  Future<void> seek(int position) async {
    await _currentEngine?.seek(position);
  }

  /// 设置音量
  Future<void> setVolume(int volume) async {
    await _currentEngine?.setVolume(volume.clamp(0, 100));
  }

  /// 设置静音
  Future<void> setMute(bool muted) async {
    await _currentEngine?.setMute(muted);
  }

  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    await _currentEngine?.setSpeed(speed);
  }

  /// 获取当前位置
  Future<int> getPosition() async {
    return await _currentEngine?.getPosition() ?? 0;
  }

  /// 取消心跳检测（用于拖动进度条时避免冲突）
  void cancelHeartbeat() {
    if (_currentEngine is BaseCastEngine) {
      (_currentEngine as BaseCastEngine).cancelHeartbeat();
    }
  }

  /// 恢复心跳检测
  void startHeartbeat() {
    if (_currentEngine is BaseCastEngine) {
      (_currentEngine as BaseCastEngine).startHeartbeat();
    }
  }

  /// 网络变化处理
  void _onNetworkChanged(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      // 网络断开，暂停投屏
      if (isCasting) {
        _handleNetworkPause();
      }
    } else if (results.contains(ConnectivityResult.wifi)) {
      // WiFi连接，尝试恢复
      if (isCasting && castStatus.value == CastStatus.paused) {
        _handleNetworkResume();
      }
    }
  }

  Future<void> _handleNetworkPause() async {
    try {
      await pause();
      debugPrint('网络已断开，暂停投屏');
    } catch (e) {
      debugPrint('网络断开时暂停失败: $e');
    }
  }

  Future<void> _handleNetworkResume() async {
    try {
      await resume();
      debugPrint('WiFi已连接，恢复投屏');
    } catch (e) {
      debugPrint('WiFi恢复时恢复播放失败: $e');
    }
  }

  /// 错误处理与恢复
  void _handleError(String errorMessage) {
    debugPrint('投屏错误: $errorMessage');

    // 检查是否是设备断开错误
    if (errorMessage.contains('断开') || errorMessage.contains('disconnected')) {
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _reconnectAttempts++;
        debugPrint('尝试重连 ($_reconnectAttempts/$_maxReconnectAttempts)...');

        // 取消之前的恢复定时器
        _recoveryTimer?.cancel();
        _recoveryTimer = Timer(Duration(seconds: 2 * _reconnectAttempts), () {
          _performReconnect();
        });
      } else {
        debugPrint('重连次数已达上限，放弃重连');
        _performDisconnect();
      }
    }
  }

  /// 执行重连操作
  Future<void> _performReconnect() async {
    try {
      final device = currentDevice;
      final lastMedia = _lastCastMedia;
      final lastPosition = playbackState.value.position;

      if (device != null) {
        await connect(device);

        if (lastMedia != null) {
          await _currentEngine!.play(lastMedia);
          if (lastPosition > 0) {
            await _currentEngine!.seek(lastPosition);
          }
        } else if (playbackState.value.status == CastStatus.paused) {
          await resume();
        }
      }
    } catch (e) {
      debugPrint('重连失败: $e');
    }
  }

  /// 执行断开操作
  Future<void> _performDisconnect() async {
    if (_isDisconnecting) return;
    _isDisconnecting = true;
    try {
      await disconnect();
    } catch (e) {
      debugPrint('断开连接失败: $e');
    } finally {
      _isDisconnecting = false;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _networkSubscription?.cancel();
    _networkSubscription = null;
    _eventSubscription?.cancel();
    _eventSubscription = null;

    // 取消所有引擎的流订阅，防止内存泄漏
    for (final subs in _engineSubscriptions.values) {
      for (final sub in subs) {
        await sub.cancel();
      }
    }
    _engineSubscriptions.clear();

    for (final engine in _engines.values) {
      await engine.dispose();
    }
    _engines.clear();
    _currentEngine = null;

    // 重置初始化状态，允许重新初始化
    _isInitialized = false;

    debugPrint('CastManager 已释放');
  }
}
