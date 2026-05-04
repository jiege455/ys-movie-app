/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 投屏播放控制条
/// 说明：投屏状态下显示在播放器上方，提供播放/暂停/进度/音量控制

import 'package:flutter/material.dart';
import '../services/cast/cast_manager.dart';
import '../services/cast/models.dart';

class CastControls extends StatefulWidget {
  final VoidCallback? onStopCast;

  const CastControls({
    Key? key,
    this.onStopCast,
  }) : super(key: key);

  @override
  State<CastControls> createState() => _CastControlsState();
}

class _CastControlsState extends State<CastControls> {
  final CastManager _castManager = CastManager();
  bool _isDragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CastPlaybackState>(
      valueListenable: _castManager.playbackState,
      builder: (context, state, _) {
        return ValueListenableBuilder<CastStatus>(
          valueListenable: _castManager.castStatus,
          builder: (context, status, _) {
            if (status == CastStatus.idle || status == CastStatus.searching) {
              return const SizedBox.shrink();
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 设备信息和状态
                  _buildHeader(status),
                  const SizedBox(height: 12),

                  // 进度条
                  _buildProgressBar(state),
                  const SizedBox(height: 12),

                  // 控制按钮
                  _buildControls(state),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(CastStatus status) {
    final device = _castManager.currentDevice;
    final statusText = _getStatusText(status);
    final statusColor = _getStatusColor(status);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '投屏到: ${device?.name ?? '未知设备'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
          onPressed: () async {
            await _castManager.disconnect();
            if (mounted) {
              widget.onStopCast?.call();
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildProgressBar(CastPlaybackState state) {
    final position = _isDragging ? _dragValue : state.progressPercent;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF4CAF50),
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: position.clamp(0.0, 1.0),
            onChangeStart: (_) {
              setState(() {
                _isDragging = true;
                _dragValue = state.progressPercent;
              });
            },
            onChanged: (value) {
              setState(() => _dragValue = value);
            },
            onChangeEnd: (value) async {
              final targetMs = (value * state.duration).toInt();
              await _castManager.seek(targetMs);
              setState(() => _isDragging = false);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isDragging ? _formatDuration(((_dragValue * state.duration) / 1000).floor()) : state.formattedPosition,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                state.formattedDuration,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(CastPlaybackState state) {
    final isPlaying = state.status == CastStatus.playing;
    final isBuffering = state.status == CastStatus.buffering;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 音量减小
        IconButton(
          icon: const Icon(Icons.volume_down, color: Colors.white70),
          onPressed: () async {
            final newVol = (state.volume - 10).clamp(0, 100);
            await _castManager.setVolume(newVol);
          },
        ),

        // 快退10秒
        IconButton(
          icon: const Icon(Icons.replay_10, color: Colors.white),
          onPressed: () async {
            final newPos = (state.position - 10000).clamp(0, state.duration);
            await _castManager.seek(newPos);
          },
        ),

        // 播放/暂停
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: isBuffering
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: () async {
                    if (isPlaying) {
                      await _castManager.pause();
                    } else {
                      await _castManager.resume();
                    }
                  },
                ),
        ),

        // 快进10秒
        IconButton(
          icon: const Icon(Icons.forward_10, color: Colors.white),
          onPressed: () async {
            final newPos = (state.position + 10000).clamp(0, state.duration);
            await _castManager.seek(newPos);
          },
        ),

        // 音量增大
        IconButton(
          icon: const Icon(Icons.volume_up, color: Colors.white70),
          onPressed: () async {
            final newVol = (state.volume + 10).clamp(0, 100);
            await _castManager.setVolume(newVol);
          },
        ),
      ],
    );
  }

  String _getStatusText(CastStatus status) {
    switch (status) {
      case CastStatus.idle:
        return '空闲';
      case CastStatus.searching:
        return '搜索中...';
      case CastStatus.connecting:
        return '连接中...';
      case CastStatus.connected:
        return '已连接';
      case CastStatus.casting:
        return '投屏中...';
      case CastStatus.playing:
        return '播放中';
      case CastStatus.paused:
        return '已暂停';
      case CastStatus.buffering:
        return '缓冲中...';
      case CastStatus.disconnecting:
        return '断开中...';
      case CastStatus.error:
        return '发生错误';
    }
  }

  Color _getStatusColor(CastStatus status) {
    switch (status) {
      case CastStatus.playing:
        return const Color(0xFF4CAF50);
      case CastStatus.paused:
        return Colors.orange;
      case CastStatus.buffering:
        return Colors.blue;
      case CastStatus.error:
        return Colors.red;
      default:
        return Colors.white70;
    }
  }

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
