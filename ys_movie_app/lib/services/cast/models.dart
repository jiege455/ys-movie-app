/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 投屏模块数据模型
/// 说明：定义投屏设备、状态、媒体信息等数据模型

// import 'package:flutter/foundation.dart';

/// 投屏协议类型
enum CastProtocol {
  dlna('DLNA', 'dlna'),
  airplay('AirPlay', 'airplay'),
  chromecast('Chromecast', 'chromecast'),
  miracast('Miracast', 'miracast'),
  system('系统分享', 'system');

  final String displayName;
  final String value;

  const CastProtocol(this.displayName, this.value);

  static CastProtocol fromString(String value) {
    return CastProtocol.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CastProtocol.dlna,
    );
  }
}

/// 投屏设备信息
class CastDevice {
  /// 设备唯一标识
  final String id;

  /// 设备友好名称
  final String name;

  /// 设备IP地址
  final String? ipAddress;

  /// 设备端口
  final int? port;

  /// 投屏协议类型
  final CastProtocol protocol;

  /// 设备描述URL（DLNA用）
  final String? descriptionUrl;

  /// 设备图标URL
  final String? iconUrl;

  /// 制造商
  final String? manufacturer;

  /// 设备型号
  final String? modelName;

  /// 是否已连接
  final bool isConnected;

  const CastDevice({
    required this.id,
    required this.name,
    this.ipAddress,
    this.port,
    this.protocol = CastProtocol.dlna,
    this.descriptionUrl,
    this.iconUrl,
    this.manufacturer,
    this.modelName,
    this.isConnected = false,
  });

  CastDevice copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? port,
    CastProtocol? protocol,
    String? descriptionUrl,
    String? iconUrl,
    String? manufacturer,
    String? modelName,
    bool? isConnected,
  }) {
    return CastDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      descriptionUrl: descriptionUrl ?? this.descriptionUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      manufacturer: manufacturer ?? this.manufacturer,
      modelName: modelName ?? this.modelName,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  String toString() {
    return 'CastDevice{name: $name, protocol: ${protocol.displayName}, ip: $ipAddress}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CastDevice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 投屏状态
enum CastStatus {
  /// 空闲状态
  idle,

  /// 搜索设备中
  searching,

  /// 正在连接
  connecting,

  /// 已连接
  connected,

  /// 正在投屏
  casting,

  /// 播放中
  playing,

  /// 已暂停
  paused,

  /// 缓冲中
  buffering,

  /// 正在断开连接
  disconnecting,

  /// 发生错误
  error,
}

/// 投屏播放状态
class CastPlaybackState {
  /// 当前状态
  final CastStatus status;

  /// 当前播放位置（毫秒）
  final int position;

  /// 总时长（毫秒）
  final int duration;

  /// 音量 0-100
  final int volume;

  /// 是否静音
  final bool isMuted;

  /// 播放速度
  final double speed;

  /// 错误信息
  final String? errorMessage;

  const CastPlaybackState({
    this.status = CastStatus.idle,
    this.position = 0,
    this.duration = 0,
    this.volume = 100,
    this.isMuted = false,
    this.speed = 1.0,
    this.errorMessage,
  });

  CastPlaybackState copyWith({
    CastStatus? status,
    int? position,
    int? duration,
    int? volume,
    bool? isMuted,
    double? speed,
    String? errorMessage,
  }) {
    return CastPlaybackState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      speed: speed ?? this.speed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// 获取格式化的当前位置
  String get formattedPosition {
    final seconds = (position / 1000).floor();
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// 获取格式化的总时长
  String get formattedDuration {
    final seconds = (duration / 1000).floor();
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// 获取播放进度百分比
  double get progressPercent {
    if (duration <= 0) return 0.0;
    return (position / duration).clamp(0.0, 1.0);
  }
}

/// 媒体信息
class CastMediaInfo {
  /// 视频URL
  final String url;

  /// 标题
  final String title;

  /// 副标题/剧集信息
  final String? subtitle;

  /// 封面图
  final String? coverUrl;

  /// 媒体类型
  final String mimeType;

  /// 视频宽度
  final int? width;

  /// 视频高度
  final int? height;

  /// 视频时长（毫秒）
  final int? duration;

  const CastMediaInfo({
    required this.url,
    required this.title,
    this.subtitle,
    this.coverUrl,
    this.mimeType = 'video/mp4',
    this.width,
    this.height,
    this.duration,
  });

  /// 判断是否为HLS流
  bool get isHls {
    return url.endsWith('.m3u8') ||
        url.contains('.m3u8?') ||
        mimeType == 'application/x-mpegURL' ||
        mimeType == 'application/vnd.apple.mpegurl';
  }

  /// 判断是否为DASH流
  bool get isDash {
    return url.endsWith('.mpd') || mimeType == 'application/dash+xml';
  }

  /// 获取分辨率描述
  String? get resolution {
    final h = height;
    if (h == null) return null;
    if (h >= 2160) return '4K';
    if (h >= 1080) return '1080P';
    if (h >= 720) return '720P';
    return '${h}P';
  }
}

/// 投屏会话信息
class CastSession {
  /// 会话ID
  final String sessionId;

  /// 目标设备
  final CastDevice device;

  /// 当前媒体
  final CastMediaInfo? mediaInfo;

  /// 会话创建时间
  final DateTime createdAt;

  /// 最后活跃时间
  final DateTime lastActiveAt;

  const CastSession({
    required this.sessionId,
    required this.device,
    this.mediaInfo,
    required this.createdAt,
    required this.lastActiveAt,
  });
}

/// 网络质量
enum NetworkQuality {
  excellent('极佳', 5),
  good('良好', 4),
  fair('一般', 3),
  poor('较差', 2),
  bad('极差', 1);

  final String label;
  final int level;

  const NetworkQuality(this.label, this.level);
}
