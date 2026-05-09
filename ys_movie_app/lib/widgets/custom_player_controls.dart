/// 文件名：custom_player_controls.dart
/// 作者：杰哥（by：杰哥 / qq：2711793818）
/// 创建日期：2026-01-17
/// 作用：BetterPlayer 自定义控制器 UI 实现
/// 解释：仿照截图实现的顶部栏、底部栏、锁定按钮、侧边菜单等功能。
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:better_player/better_player.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../services/cast/cast_manager.dart';
import '../widgets/cast_dialog.dart';
import '../widgets/cast_controls.dart';
import '../services/player_settings.dart';

class CustomPlayerControls extends StatefulWidget {
  final BetterPlayerController? controller;
  final Function(bool visibility)? onControlsVisibilityChanged;
  final String title;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onShowEpisodes;
  final VoidCallback? onShowSources;
  final VoidCallback? onShowSpeed;
  final VoidCallback? onShowSkip;
  final VoidCallback? onDanmakuToggle;
  // 新增数据参数，用于在内部构建 BottomSheet
  final List<dynamic>? episodes;
  final int? currentEpisodeIndex;
  final List<dynamic>? sources;
  final int? currentSourceIndex;
  final Function(int index)? onSourceSelected;
  final Function(int index)? onEpisodeSelected;

  const CustomPlayerControls({
    Key? key,
    this.controller,
    this.onControlsVisibilityChanged,
    required this.title,
    this.onNextEpisode,
    this.onShowEpisodes,
    this.onShowSources,
    this.onShowSpeed,
    this.onShowSkip,
    this.onDanmakuToggle,
    this.episodes,
    this.currentEpisodeIndex,
    this.sources,
    this.currentSourceIndex,
    this.onSourceSelected,
    this.onEpisodeSelected,
  }) : super(key: key);

  @override
  State<CustomPlayerControls> createState() => _CustomPlayerControlsState();
}

class _CustomPlayerControlsState extends BetterPlayerControlsState<CustomPlayerControls> {
  BetterPlayerController? _controller;
  VideoPlayerValue? _latestValue;
  Timer? _hideTimer;
  Timer? _initTimer;
  bool _controlsVisible = true;
  bool _isLocked = false;

  // 电量与时间
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  Timer? _timeTimer;
  StreamSubscription? _batterySubscription;
  String _currentTime = '';

  // 亮度与音量
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _isSlidingVolume = false;
  bool _isSlidingBrightness = false;
double? _brightnessStart;
double? _volumeStart;
bool _isLongPressing = false;
  double _preLongPressSpeed = 1.0;

  // 投屏状态
  final CastManager _castManager = CastManager();
  bool _isCasting = false;
  VoidCallback? _castStatusListener;

  // 定时关闭
  Timer? _sleepTimer;
  int _sleepMinutes = 0; // 0=关闭
  String _sleepTimeLeft = '';

  // 开发者：杰哥网络科技 (qq: 2711793818)
  // 水平拖拽快进快退 - 记录起始状态
  Duration? _dragStartPosition;
  double? _dragStartX;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      _controller?.betterPlayerConfiguration.controlsConfiguration ??
      const BetterPlayerControlsConfiguration();

  @override
  BetterPlayerController? get betterPlayerController => _controller;

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
    _initBattery();
    _initVolumeBrightness();
    _initCastManager();
  }

  void _initCastManager() {
    _castStatusListener = () {
      if (mounted) {
        setState(() {
          _isCasting = _castManager.isCasting;
        });
      }
    };
    _castManager.castStatus.addListener(_castStatusListener!);
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isLocked) {
        setState(() => _controlsVisible = false);
        widget.onControlsVisibilityChanged?.call(false);
      }
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _initBattery() {
    _battery.batteryLevel.then((v) {
      if (mounted) setState(() => _batteryLevel = v);
    });
    _batterySubscription = _battery.onBatteryStateChanged.listen((state) async {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    });
  }

  void _initVolumeBrightness() {
    try {
      FlutterVolumeController.getVolume().then((v) {
        if (mounted) setState(() => _volume = v ?? 0.5);
      });
      FlutterVolumeController.addListener((v) {
        if (mounted) setState(() => _volume = v);
      });
      ScreenBrightness().current.then((v) {
        if (mounted) setState(() => _brightness = v);
      });
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final old = _controller;
    final cur = widget.controller;
    if (old != cur) {
      old?.removeEventsListener(_onPlayerEvent);
      _controller = cur;
    }
    _controller?.addEventsListener(_onPlayerEvent);
    if (_latestValue == null) {
      _initTimer?.cancel();
      _initTimer = Timer(const Duration(milliseconds: 300), () {
        _refreshLatestValue();
      });
    }
  }

  void _refreshLatestValue() {
    final v = _controller?.videoPlayerController?.value;
    if (v != null && mounted) setState(() => _latestValue = v);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.initialized ||
        event.betterPlayerEventType == BetterPlayerEventType.play) {
      _refreshLatestValue();
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
      if (mounted) _latestValue = _controller?.videoPlayerController?.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Stack(
          children: [
            if (!_controlsVisible)
              Positioned(bottom: 0, left: 0, right: 0, child: _buildMiniProgressBar()),
            if (_controlsVisible) ...[
              _buildTopBar(),
              Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
            ],
            if (_controlsVisible)
              Positioned(left: 16, top: MediaQuery.of(context).size.height * 0.35, child: _buildLockButton()),
            if (_isLocked)
              Positioned(left: 16, top: MediaQuery.of(context).size.height * 0.35, child: _buildLockButton()),
            // 开发者：杰哥网络科技 (qq: 2711793818)
            // 音量/亮度变化视觉反馈
            if (_isSlidingVolume || _isSlidingBrightness)
              Center(child: _buildVolumeBrightnessOverlay()),
            // 水平拖拽时间指示
            if (_dragStartPosition != null && (_isSlidingVolume || _isSlidingBrightness) == false)
              Center(child: _buildSeekOverlay()),
            // 定时提示
            if (_sleepMinutes > 0)
              Positioned(top: 60, right: 16, child: _buildSleepIndicator()),
          ],
        ),
      ),
    );
  }

  void _handleTap() {
    if (_isLocked) return;
    setState(() => _controlsVisible = !_controlsVisible);
    widget.onControlsVisibilityChanged?.call(_controlsVisible);
    if (_controlsVisible) _startHideTimer();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (!_controlsVisible) return;
    _isLongPressing = true;
    if (_controller?.videoPlayerController?.value.isPlaying == true) {
      _preLongPressSpeed = _controller!.videoPlayerController!.value.speed;
      _controller!.videoPlayerController!.setSpeed(2.0);
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    // 开发者：杰哥网络科技 (qq: 2711793818)
    // 长按拖拽快进快退
    if (!_isLongPressing) return;
    final dx = details.localOffsetFromOrigin.dx;
    if (_dragStartX == null) {
      _dragStartX = dx;
      _dragStartPosition = _latestValue?.position;
    }
    final delta = dx - _dragStartX!;
    final w = MediaQuery.of(context).size.width;
    final dur = _latestValue?.duration ?? Duration.zero;
    if (dur.inMilliseconds == 0) return;
    final seekMs = (delta / w * dur.inMilliseconds).round();
    var newPos = _dragStartPosition! + Duration(milliseconds: seekMs);
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > dur) newPos = dur;
    _controller?.videoPlayerController?.seekTo(newPos);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_isLongPressing) {
      _controller?.videoPlayerController?.setSpeed(_preLongPressSpeed);
    }
    _isLongPressing = false;
    _dragStartX = null;
    _dragStartPosition = null;
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_isLocked) return;
    final w = MediaQuery.of(context).size.width;
    if (details.localPosition.dx < w / 2) {
      _isSlidingBrightness = true;
      _brightnessStart = _brightness;
    } else {
      _isSlidingVolume = true;
      _volumeStart = _volume;
    }
    setState(() {});
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final h = MediaQuery.of(context).size.height;
    final delta = details.primaryDelta ?? 0;
    if (_isSlidingBrightness) {
      _brightness = (_brightnessStart! - delta / h).clamp(0.05, 1.0);
      try { ScreenBrightness().setScreenBrightness(_brightness); } catch (_) {}
    } else if (_isSlidingVolume) {
      _volume = (_volumeStart! - delta / h).clamp(0.0, 1.0);
      try { FlutterVolumeController.setVolume(_volume); } catch (_) {}
    }
    setState(() {});
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _isSlidingBrightness = false;
      _isSlidingVolume = false;
    });
  }

  String _formatTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildVolumeBrightnessOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_isSlidingBrightness) ...[
          const Icon(Icons.brightness_6, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text('${(_brightness * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
        if (_isSlidingVolume) ...[
          const Icon(Icons.volume_up, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text('${(_volume * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ]),
    );
  }

  Widget _buildSeekOverlay() {
    final pos = _latestValue?.position ?? Duration.zero;
    final dur = _latestValue?.duration ?? Duration.zero;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
      child: Text('${_formatTime(pos)} / ${_formatTime(dur)}',
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSleepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
      child: Text('定时: ${_sleepTimeLeft.isNotEmpty ? _sleepTimeLeft : '$_sleepMinutes分钟'}',
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  Widget _buildMiniProgressBar() {
    final pos = _latestValue?.position ?? Duration.zero;
    final dur = _latestValue?.duration ?? Duration.zero;
    final progress = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
    return LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.white24,
      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16, bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent])),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (_controller?.isFullScreen == true) {
                  _controller?.exitFullScreen();
                } else {
                  Navigator.pop(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_currentTime, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
              ]),
            ),
            _buildBatteryIcon(),
            const SizedBox(width: 8),
            if (widget.onDanmakuToggle != null)
              GestureDetector(
                onTap: widget.onDanmakuToggle,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.subtitles, color: Colors.white, size: 18)),
              ),
            if (widget.onShowSkip != null)
              GestureDetector(
                onTap: widget.onShowSkip,
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.skip_next, color: Colors.white, size: 18)),
              ),
            if (widget.episodes != null && widget.episodes!.isNotEmpty)
              GestureDetector(
                onTap: _showBottomEpisodesSheet,
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.list, color: Colors.white, size: 18)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final duration = _latestValue?.duration ?? Duration.zero;
    final position = _latestValue?.position ?? Duration.zero;
    final isPlaying = _latestValue?.isPlaying ?? false;
    final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent])),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withOpacity(0.2),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (v) {
              final newPos = Duration(milliseconds: (duration.inMilliseconds * v).round());
              _controller?.videoPlayerController?.seekTo(newPos);
            },
          ),
        ),
        Row(children: [
          GestureDetector(
            onTap: () {
              if (isPlaying) {
                _controller?.videoPlayerController?.pause();
              } else {
                _controller?.videoPlayerController?.play();
              }
            },
            child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32)),
          const SizedBox(width: 8),
          Text(_formatTime(position), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
          Text(' / ${_formatTime(duration)}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const Spacer(),
          if (widget.onShowSpeed != null)
            GestureDetector(
              onTap: widget.onShowSpeed,
              child: const Padding(padding: EdgeInsets.only(right: 12),
                  child: Text('倍速', style: TextStyle(color: Colors.white, fontSize: 13)))),
          if (widget.onShowSources != null)
            GestureDetector(
              onTap: widget.onShowSources,
              child: const Padding(padding: EdgeInsets.only(right: 12),
                  child: Text('清晰度', style: TextStyle(color: Colors.white, fontSize: 13)))),
          GestureDetector(
            onTap: () => _controller?.toggleFullScreen(),
            child: const Icon(Icons.fullscreen, color: Colors.white, size: 24)),
        ]),
      ]),
    );
  }

  Widget _buildLockButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _isLocked = !_isLocked);
        if (_isLocked) {
          _hideTimer?.cancel();
        } else {
          _startHideTimer();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(8)),
        child: Icon(_isLocked ? Icons.lock : Icons.lock_open, color: Colors.white, size: 20)),
    );
  }

  Widget _buildBatteryIcon() {
    IconData icon = Icons.battery_full;
    if (_batteryLevel <= 20) icon = Icons.battery_alert;
    else if (_batteryLevel <= 40) icon = Icons.battery_2_bar;
    else if (_batteryLevel <= 60) icon = Icons.battery_3_bar;
    else if (_batteryLevel <= 80) icon = Icons.battery_4_bar;
    else if (_batteryLevel <= 99) icon = Icons.battery_5_bar;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white.withOpacity(0.7), size: 16),
      const SizedBox(width: 2),
      Text('$_batteryLevel%', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
    ]);
  }

  // 选集面板
  bool _isAscending = true;

  void _showBottomEpisodesSheet() {
    final raw = widget.episodes ?? [];
    final eps = raw.whereType<Map<String, dynamic>>().toList();
    if (eps.isEmpty) return;
    if (_isAscending) {
      eps.sort((a, b) => (int.tryParse('${a['num'] ?? a['nid'] ?? 0}') ?? 0)
          .compareTo(int.tryParse('${b['num'] ?? b['nid'] ?? 0}') ?? 0));
    } else {
      eps.sort((a, b) => (int.tryParse('${b['num'] ?? b['nid'] ?? 0}') ?? 0)
          .compareTo(int.tryParse('${a['num'] ?? a['nid'] ?? 0}') ?? 0));
    }
    final total = eps.length;
    final currentIdx = widget.currentEpisodeIndex ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (_, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: const BoxDecoration(
              color: Color(0xEE111827),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8), width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('选集 ($total)', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: Icon(_isAscending ? Icons.arrow_downward : Icons.arrow_upward,
                        color: AppColors.slate300, size: 16),
                    label: Text(_isAscending ? '正序' : '倒序',
                        style: const TextStyle(color: AppColors.slate300, fontSize: 13)),
                    onPressed: () => setSheetState(() => _isAscending = !_isAscending),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      backgroundColor: Colors.white.withOpacity(0.06),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)))),
                ]),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.2),
                  itemCount: eps.length,
                  itemBuilder: (ctx, i) {
                    final ep = eps[i];
                    final epNum = ep['num'] ?? ep['nid'] ?? (i + 1);
                    final epName = (ep['name'] ?? ep['title'] ?? '').toString();
                    final isSelected = i == currentIdx;
                    return GestureDetector(
                      onTap: () {
                        widget.onEpisodeSelected?.call(i);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                              ? AppColors.primary.withOpacity(0.5)
                              : Colors.white.withOpacity(0.08),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$epNum',
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.primaryLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              epName.replaceAll('$epNum', '').trim().isEmpty 
                                ? '第${epNum}集' 
                                : epName.replaceAll('$epNum', '').replaceAll('第', '').replaceAll('集', '').trim(),
                              style: TextStyle(
                                color: isSelected ? Colors.white.withOpacity(0.85) : AppColors.slate400,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _timeTimer?.cancel();
    _sleepTimer?.cancel();
    _batterySubscription?.cancel();
    _castManager.castStatus.removeListener(_castStatusListener!);
    _castManager.dispose();
    _controller?.removeEventsListener(_onPlayerEvent);
    super.dispose();
  }
}