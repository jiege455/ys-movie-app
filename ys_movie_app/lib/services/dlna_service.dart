import 'package:flutter/material.dart';

/**
 * 开发者：狐狸影视 (qq: 2711793818)
 * DLNA 投屏服务占位文件
 */
class DlnaService {
  final ValueNotifier<List<dynamic>> devices = ValueNotifier<List<dynamic>>([]);

  void startSearch() {
    // TODO: 实现设备搜索
  }

  void stopSearch() {
    // TODO: 实现停止搜索
  }

  Future<void> connect(dynamic device) async {
    // TODO: 实现设备连接
  }

  Future<void> cast(String url, String title) async {
    // TODO: 实现投屏
  }
}

class DeviceInfo {
  final String friendlyName;
  DeviceInfo({required this.friendlyName});
}
