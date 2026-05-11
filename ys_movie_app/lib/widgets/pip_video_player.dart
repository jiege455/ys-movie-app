/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 作用：基于 flutter_pip_player 的可拖拽画中画视频播放器组件
/// 特性：边缘吸附、播放控制、快退/快进、状态切换

import 'package:flutter/material.dart';
import 'package:flutter_pip_player/pip_player.dart';
import 'package:flutter_pip_player/pip_controller.dart';
import 'package:flutter_pip_player/models/pip_settings.dart';

/// 画中画视频播放器组件
class PipVideoPlayer extends StatefulWidget {
  final Widget videoContent;
  final String title;
  final VoidCallback? onClose;
  final VoidCallback? onExpand;
  final ValueChanged<bool>? onPlayPause;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final bool initialPlaying;
  final bool enableSnap;

  const PipVideoPlayer({
    super.key,
    required this.videoContent,
    this.title = '',
    this.onClose,
    this.onExpand,
    this.onPlayPause,
    this.onRewind,
    this.onForward,
    this.initialPlaying = true,
    this.enableSnap = true,
  });

  @override
  State<PipVideoPlayer> createState() => _PipVideoPlayerState();
}

class _PipVideoPlayerState extends State<PipVideoPlayer> {
  late final PipController _pipController;
  late bool _isPlaying;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.initialPlaying;
    _pipController = PipController(
      isSnaping: widget.enableSnap,
      title: widget.title,
      settings: PipSettings(
        collapsedWidth: 200,
        collapsedHeight: 120,
        expandedWidth: 350,
        expandedHeight: 280,
        borderRadius: BorderRadius.circular(12),
        backgroundColor: Colors.black,
        progressBarColor: Colors.cyan,
        animationDuration: const Duration(milliseconds: 300),
        animationCurve: Curves.easeOutQuart,
      ),
    );
    _pipController.show();
  }

  @override
  void dispose() {
    _pipController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PipPlayer(
      controller: _pipController,
      content: widget.videoContent,
      customControls: StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateInner) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: Icons.replay_10,
                  onTap: () => widget.onRewind?.call(),
                ),
                _buildControlButton(
                  icon: _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 40,
                  onTap: () {
                    setStateInner(() => _isPlaying = !_isPlaying);
                    _togglePlayPause();
                    widget.onPlayPause?.call(_isPlaying);
                  },
                ),
                _buildControlButton(
                  icon: Icons.forward_10,
                  onTap: () => widget.onForward?.call(),
                ),
              ],
            ),
          );
        },
      ),
      onClose: () {
        _pipController.hide();
        widget.onClose?.call();
      },
      onExpand: () {
        _pipController.expand();
        widget.onExpand?.call();
      },
      onTap: () => _pipController.toggleExpanded(),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 28,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}
