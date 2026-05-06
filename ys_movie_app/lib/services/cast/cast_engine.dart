/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 投屏引擎抽象接口
/// 说明：定义所有投屏协议引擎必须实现的接口，便于统一管理和扩展

import 'dart:async';
import 'models.dart';

/// 投屏引擎抽象接口
abstract class CastEngine {
  /// 引擎名称
  String get name;

  /// 支持的协议类型
  CastProtocol get protocol;

  /// 引擎是否可用
  Future<bool> get isAvailable;

  /// 设备列表流
  Stream<List<CastDevice>> get deviceStream;

  /// 播放状态流
  Stream<CastPlaybackState> get playbackStream;

  /// 当前连接的设备
  CastDevice? get currentDevice;

  /// 当前播放状态
  CastPlaybackState get currentState;

  /// 是否正在搜索
  bool get isSearching;

  /// 是否已连接
  bool get isConnected;

  /// 初始化引擎
  Future<void> initialize();

  /// 开始搜索设备
  /// [timeout] 搜索超时时间，默认10秒
  Future<void> startSearch({Duration timeout = const Duration(seconds: 10)});

  /// 停止搜索设备
  Future<void> stopSearch();

  /// 连接指定设备
  Future<void> connect(CastDevice device);

  /// 断开当前连接
  Future<void> disconnect();

  /// 投屏播放媒体
  Future<void> play(CastMediaInfo media);

  /// 暂停播放
  Future<void> pause();

  /// 恢复播放
  Future<void> resume();

  /// 停止播放
  Future<void> stop();

  /// 跳转到指定位置（毫秒）
  Future<void> seek(int position);

  /// 设置音量 0-100
  Future<void> setVolume(int volume);

  /// 设置静音
  Future<void> setMute(bool muted);

  /// 设置播放速度
  Future<void> setSpeed(double speed);

  /// 获取当前播放位置
  Future<int> getPosition();

  /// 释放引擎资源
  Future<void> dispose();
}

/// 投屏引擎基类，提供通用实现
abstract class BaseCastEngine implements CastEngine {
  final _deviceController = StreamController<List<CastDevice>>.broadcast();
  final _playbackController = StreamController<CastPlaybackState>.broadcast();

  CastDevice? _currentDevice;
  CastPlaybackState _currentState = const CastPlaybackState();
  bool _isSearching = false;
  bool _isConnected = false;
  Timer? _heartbeatTimer;
  Timer? _searchTimeoutTimer;

  @override
  Stream<List<CastDevice>> get deviceStream => _deviceController.stream;

  @override
  Stream<CastPlaybackState> get playbackStream => _playbackController.stream;

  @override
  CastDevice? get currentDevice => _currentDevice;

  @override
  CastPlaybackState get currentState => _currentState;

  @override
  bool get isSearching => _isSearching;

  @override
  bool get isConnected => _isConnected;

  /// 更新设备列表
  void updateDevices(List<CastDevice> devices) {
    if (!_deviceController.isClosed) {
      _deviceController.add(devices);
    }
  }

  /// 更新播放状态
  void updateState(CastPlaybackState state) {
    _currentState = state;
    if (!_playbackController.isClosed) {
      _playbackController.add(state);
    }
  }

  /// 设置连接状态
  void setConnected(CastDevice? device) {
    _currentDevice = device;
    _isConnected = device != null;
    if (device != null) {
      _startHeartbeat();
    } else {
      _stopHeartbeat();
    }
  }

  /// 设置搜索状态
  void setSearching(bool searching) {
    _isSearching = searching;
  }

  /// 启动心跳检测
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await onHeartbeat();
    });
  }

  /// 停止心跳检测
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 取消心跳检测（公开方法，供外部临时暂停）
  void cancelHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 恢复心跳检测（公开方法）
  void startHeartbeat() {
    if (_isConnected) {
      _startHeartbeat();
    }
  }

  /// 心跳回调，子类可重写
  Future<void> onHeartbeat() async {}

  /// 设置搜索超时
  void setSearchTimeout(Duration timeout) {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = Timer(timeout, () {
      if (_isSearching) {
        stopSearch();
      }
    });
  }

  /// 清除搜索超时
  void clearSearchTimeout() {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = null;
  }

  @override
  Future<void> dispose() async {
    _stopHeartbeat();
    clearSearchTimeout();

    // 先标记为非连接状态，防止后续操作发送事件
    _isConnected = false;
    _isSearching = false;
    _currentDevice = null;

    try {
      await disconnect();
    } catch (e) {
      // 断开连接时忽略错误
    }

    // 关闭StreamController
    if (!_deviceController.isClosed) {
      await _deviceController.close();
    }
    if (!_playbackController.isClosed) {
      await _playbackController.close();
    }
  }
}
