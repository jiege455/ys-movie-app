/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 投屏模块异常定义
/// 说明：统一投屏功能相关的异常类型，便于错误处理和用户提示

/// 投屏基础异常
class CastException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  const CastException(this.code, this.message, {this.details});

  @override
  String toString() => 'CastException[$code]: $message';
}

/// 设备搜索异常
class DeviceSearchException extends CastException {
  const DeviceSearchException(String message, {dynamic details})
      : super('DEVICE_SEARCH_ERROR', message, details: details);
}

/// 设备连接异常
class DeviceConnectionException extends CastException {
  const DeviceConnectionException(String message, {dynamic details})
      : super('DEVICE_CONNECTION_ERROR', message, details: details);
}

/// 投屏播放异常
class CastPlaybackException extends CastException {
  const CastPlaybackException(String message, {dynamic details})
      : super('CAST_PLAYBACK_ERROR', message, details: details);
}

/// 网络异常
class CastNetworkException extends CastException {
  const CastNetworkException(String message, {dynamic details})
      : super('NETWORK_ERROR', message, details: details);
}

/// 格式不支持异常
class FormatNotSupportedException extends CastException {
  const FormatNotSupportedException(String message, {dynamic details})
      : super('FORMAT_NOT_SUPPORTED', message, details: details);
}

/// 设备断开异常
class DeviceDisconnectedException extends CastException {
  const DeviceDisconnectedException(String message, {dynamic details})
      : super('DEVICE_DISCONNECTED', message, details: details);
}
