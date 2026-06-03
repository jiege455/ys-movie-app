/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 投屏设备选择对话框
/// 说明：支持多协议设备搜索、连接状态显示、错误提示

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/cast/cast_manager.dart';
import '../services/cast/models.dart';

class CastDialog extends StatefulWidget {
  final String videoUrl;
  final String title;

  const CastDialog({
    Key? key,
    required this.videoUrl,
    required this.title,
  }) : super(key: key);

  @override
  State<CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends State<CastDialog> {
  final CastManager _castManager = CastManager();
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initAndSearch();
  }

  Future<void> _initAndSearch() async {
    try {
      // 确保管理器已初始化
      await _castManager.initialize();
      await _startSearch();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '初始化失败: $e';
        });
      }
    }
  }

  Future<void> _startSearch() async {
    try {
      await _castManager.searchDevices(timeout: const Duration(seconds: 8));
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '搜索设备失败: $e';
        });
      }
    }
  }

  Future<void> _connectAndCast(CastDevice device) async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      await _castManager.connect(device);

      final media = CastMediaInfo(
        url: widget.videoUrl,
        title: widget.title,
      );

      await _castManager.play(media);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在投屏到: ${device.name}')),
        );
      }
    } catch (e) {
      await _castManager.disconnect();
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = '投屏失败: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      _castManager.stopSearch();
    } catch (e) {
      // 忽略停止搜索时的错误
      debugPrint('停止搜索时出错: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Row(
        children: [
          const Icon(Icons.cast_connected, color: AppColors.primaryLight),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '选择投屏设备',
              style: TextStyle(color: AppColors.primaryLight, fontSize: 18),
            ),
          ),
          if (_castManager.castStatus.value == CastStatus.searching)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate300),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: Column(
          children: [
            // 错误提示
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // 设备列表
            Expanded(
              child: ValueListenableBuilder<List<CastDevice>>(
                valueListenable: _castManager.devices,
                builder: (context, devices, _) {
                  if (devices.isEmpty && _castManager.castStatus.value == CastStatus.searching) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.slate300),
                          SizedBox(height: 16),
                          Text(
                            '正在搜索设备...',
                            style: TextStyle(color: AppColors.slate300),
                          ),
                        ],
                      ),
                    );
                  }

                  if (devices.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tv_off, color: AppColors.slate500, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            '未找到投屏设备',
                            style: TextStyle(color: AppColors.slate300),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _startSearch,
                            child: const Text('重新搜索'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return _buildDeviceItem(device);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _buildDeviceItem(CastDevice device) {
    final protocolIcon = _getProtocolIcon(device.protocol);
    final protocolColor = _getProtocolColor(device.protocol);

    return Card(
      color: AppColors.slate50.withOpacity(0.05),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: protocolColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(protocolIcon, color: protocolColor, size: 22),
        ),
        title: Text(
          device.name,
          style: const TextStyle(color: AppColors.primaryLight, fontSize: 15),
        ),
        subtitle: Text(
          '${device.protocol.displayName} ${device.manufacturer != null ? '· ${device.manufacturer}' : ''}',
          style: const TextStyle(color: AppColors.slate500, fontSize: 12),
        ),
        trailing: _isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success),
              )
            : const Icon(Icons.chevron_right, color: AppColors.slate500),
        onTap: _isConnecting ? null : () => _connectAndCast(device),
      ),
    );
  }

  IconData _getProtocolIcon(CastProtocol protocol) {
    switch (protocol) {
      case CastProtocol.dlna:
        return Icons.tv;
      case CastProtocol.airplay:
        return Icons.airplay;
      case CastProtocol.chromecast:
        return Icons.cast;
      case CastProtocol.miracast:
        return Icons.screen_share;
      case CastProtocol.system:
        return Icons.share;
    }
  }

  Color _getProtocolColor(CastProtocol protocol) {
    switch (protocol) {
      case CastProtocol.dlna:
        return AppColors.primary;
      case CastProtocol.airplay:
        return AppColors.primaryDark;
      case CastProtocol.chromecast:
        return AppColors.warning;
      case CastProtocol.miracast:
        return AppColors.primaryAccent;
      case CastProtocol.system:
        return AppColors.slate400;
    }
  }
}
