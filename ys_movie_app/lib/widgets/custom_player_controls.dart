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

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _initBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
      _batterySubscription = _battery.onBatteryStateChanged.listen((state) async {
        final level = await _battery.batteryLevel;
        if (mounted) setState(() => _batteryLevel = level);
      });
    } catch (_) {}
  }

  Future<void> _initVolumeBrightness() async {
    try {
      _volume = (await FlutterVolumeController.getVolume()) ?? 0.5;
      _brightness = await ScreenBrightness().current;
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    final oldController = _controller;
    _controller = widget.controller ?? BetterPlayerController.of(context);
    
    if (oldController != _controller) {
      _dispose();
      _initialize();
    }
    super.didChangeDependencies();
  }

  void _initialize() {
    _controller?.videoPlayerController?.addListener(_updateState);
    _updateState();
    if (_controller?.betterPlayerConfiguration.autoPlay == true) {
      _startHideTimer();
    }
  }

  void _dispose() {
    _controller?.videoPlayerController?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _timeTimer?.cancel();
    _batterySubscription?.cancel();
    _sleepTimer?.cancel();
  }

  void _updateState() {
    if (mounted) {
      setState(() {
        _latestValue = _controller?.videoPlayerController?.value;
      });
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controlsVisible) {
        setState(() => _controlsVisible = false);
        widget.onControlsVisibilityChanged?.call(false);
      }
    });
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      widget.onControlsVisibilityChanged?.call(true);
    }
    _startHideTimer();
  }

  void _toggleVisibility() {
    setState(() => _controlsVisible = !_controlsVisible);
    widget.onControlsVisibilityChanged?.call(_controlsVisible);
    if (_controlsVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  @override
  void dispose() {
    // 移除投屏状态监听器，防止内存泄漏
    if (_castStatusListener != null) {
      _castManager.castStatus.removeListener(_castStatusListener!);
      _castStatusListener = null;
    }
    _dispose();
    super.dispose();
  }

  // 统一的右侧边栏显示方法 (全屏时)
  void _showRightSideSheet(Widget child) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: AppColors.slate900.withOpacity(0.54),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xEE111827),
              border: Border(left: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: SafeArea(child: child),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(anim1),
          child: child,
        );
      },
    );
  }

  // 构建统一的选中样式列表项
  Widget _buildSheetItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.slate700.withOpacity(0.12) : Colors.transparent, // 选中背景
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.success : AppColors.slate300, // 选中绿色
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // 定时关闭设置
  void _showSleepTimerSheet() {
    final isFullScreen = _controller?.isFullScreen == true;
    final options = [0, 15, 30, 45, 60, 90]; // 分钟

    final content = StatefulBuilder(
      builder: (ctx, setStateInner) => Column(
        children: [
           Padding(
            padding: const EdgeInsets.all(16),
            child: const Text('定时关闭', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              children: options.map((min) {
                final isSelected = _sleepMinutes == min;
                String title = min == 0 ? '不开启' : '$min 分钟';
                if (min > 0 && isSelected && _sleepTimeLeft.isNotEmpty) {
                  title += ' ($_sleepTimeLeft)';
                }
                
                return _buildSheetItem(
                  title: title,
                  isSelected: isSelected,
                  onTap: () {
                    _setSleepTimer(min);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );

    if (isFullScreen) {
      _showRightSideSheet(content);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (_) => SizedBox(height: 400, child: content),
      );
    }
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    setState(() {
      _sleepMinutes = minutes;
      _sleepTimeLeft = '';
    });

    if (minutes > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('将在 $minutes 分钟后暂停播放')));
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        if (mounted) {
           _controller?.pause();
           setState(() => _sleepMinutes = 0);
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('定时关闭时间已到，已暂停播放')));
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('定时关闭已取消')));
    }
  }

  // 倍速选择
  void _showSpeedSheet() {
    final isFullScreen = _controller?.isFullScreen == true;
    // 按照用户要求的顺序: 3.0 -> 0.75
    final speeds = [3.0, 2.0, 1.5, 1.25, 1.0, 0.75];
    
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: const Text('倍速选择', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView(
            children: speeds.map((speed) {
              final currentSpeed = _controller?.videoPlayerController?.value.speed ?? 1.0;
              final isSelected = (currentSpeed - speed).abs() < 0.01;
              String title = speed == 1.0 ? '正常' : '${speed}X';
              
              return _buildSheetItem(
                title: title,
                isSelected: isSelected,
                onTap: () {
                  _controller?.setSpeed(speed);
                  PlayerSettings().setSpeed(speed);
                  setState(() {});
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ),
      ],
    );

    if (isFullScreen) {
      _showRightSideSheet(content);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (_) => SizedBox(height: 400, child: content),
      );
    }
  }

  // 选集
  void _showEpisodeSheet() {
    if (widget.episodes == null || widget.episodes!.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无选集信息')));
       return;
    }
    
    final isFullScreen = _controller?.isFullScreen == true;
    bool isAscending = true; // 局部排序状态
    
    // 分页逻辑
    final int total = widget.episodes!.length;
    final int pageSize = 50; 
    final int pageCount = (total / pageSize).ceil();
    
    // 计算初始页码
    int initialPage = 0;
    if (widget.currentEpisodeIndex != null) {
       initialPage = (widget.currentEpisodeIndex! / pageSize).floor();
    }
    int currentPage = initialPage;
    
    final builder = StatefulBuilder(
      builder: (ctx, setStateSheet) {
        // 计算当前页的数据
        final int startIdx = currentPage * pageSize;
        final int endIdx = (startIdx + pageSize > total) ? total : startIdx + pageSize;
        final pageEpisodes = widget.episodes!.sublist(startIdx, endIdx);
        
        final displayList = isAscending ? pageEpisodes : pageEpisodes.reversed.toList();
            
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('选集 ($total)', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: Icon(isAscending ? Icons.arrow_downward : Icons.arrow_upward, color: AppColors.slate300, size: 16),
                    label: Text(isAscending ? '正序' : '倒序', style: const TextStyle(color: AppColors.slate300, fontSize: 13)),
                    onPressed: () {
                      setStateSheet(() => isAscending = !isAscending);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      backgroundColor: Colors.white.withOpacity(0.06),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
            // 分页 Tabs
            if (pageCount > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: List.generate(pageCount, (p) {
                    final s = p * pageSize + 1;
                    final e = (p + 1) * pageSize;
                    final endStr = e > total ? total : e;
                    final isSel = p == currentPage;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$s-$endStr', style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w600 : FontWeight.normal)),
                        selected: isSel,
                        onSelected: (v) {
                          if (v) setStateSheet(() => currentPage = p);
                        },
                        selectedColor: AppColors.success,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.slate300, fontSize: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: isSel ? AppColors.success.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            if (pageCount > 1) const SizedBox(height: 10),
            
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.3,   // 杰哥：调高比例让格子更高，显示集号+名称
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: displayList.length,
                itemBuilder: (ctx, index) {
                  final ep = displayList[index];
                  int originalIndex;
                  if (isAscending) {
                     originalIndex = startIdx + index;
                  } else {
                     originalIndex = endIdx - 1 - index;
                  }
                  
                  final epNum = originalIndex + 1;
                  final epName = ep['name'] ?? '$epNum';
                  final isSelected = originalIndex == widget.currentEpisodeIndex;
                  
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onEpisodeSelected?.call(originalIndex);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.success.withOpacity(0.85) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected 
                              ? AppColors.success.withOpacity(0.6) 
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
                                color: isSelected ? Colors.white : AppColors.cyan400,
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
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }
    );

    if (isFullScreen) {
      _showRightSideSheet(builder);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (_) => SizedBox(height: MediaQuery.of(context).size.height * 0.6, child: builder),
      );
    }
  }
  
  // 弹幕设置面板
  void _showDanmakuSettingsSheet() {
    final isFullScreen = _controller?.isFullScreen == true;
    final settings = PlayerSettings(); // 单例

    final content = StatefulBuilder(
      builder: (ctx, setStateInner) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: const Text('弹幕设置', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('弹幕字号', style: TextStyle(color: AppColors.slate300)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFontSizeBtn(settings, 14.0, 'A', setStateInner), // 小
                    _buildFontSizeBtn(settings, 18.0, 'A', setStateInner), // 中
                    _buildFontSizeBtn(settings, 24.0, 'A', setStateInner), // 大
                  ],
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    const Text('显示区域', style: TextStyle(color: AppColors.slate300)),
                    const Spacer(),
                    Text('${(settings.danmakuArea * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.success,
                    inactiveTrackColor: AppColors.slate700.withOpacity(0.24),
                    thumbColor: Colors.white,
                    overlayColor: AppColors.success.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: settings.danmakuArea,
                    min: 0.25,
                    max: 1.0,
                    divisions: 3,
                    onChanged: (v) {
                      setStateInner(() => settings.setDanmakuArea(v));
                    },
                  ),
                ),
                
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('透明度', style: TextStyle(color: AppColors.slate300)),
                    const Spacer(),
                    Text('${(settings.danmakuOpacity * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.success,
                    inactiveTrackColor: AppColors.slate700.withOpacity(0.24),
                    thumbColor: Colors.white,
                    overlayColor: AppColors.success.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: settings.danmakuOpacity,
                    min: 0.1,
                    max: 1.0,
                    onChanged: (v) {
                      setStateInner(() => settings.setDanmakuOpacity(v));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isFullScreen) {
      _showRightSideSheet(content);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (_) => SizedBox(height: 400, child: content),
      );
    }
  }

  Widget _buildFontSizeBtn(PlayerSettings settings, double size, String label, StateSetter setStateInner) {
    final isSel = settings.danmakuFontSize == size;
    // 视觉上根据 size 调整 label 大小
    double displaySize = 16;
    if (size == 14.0) displaySize = 14;
    if (size == 24.0) displaySize = 20;

    return InkWell(
      onTap: () {
        setStateInner(() => settings.setDanmakuFontSize(size));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? AppColors.slate700.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSel ? Border.all(color: AppColors.success) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? AppColors.success : AppColors.slate300,
            fontSize: displaySize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 线路
  void _showSourceSheet() {
     if (widget.sources == null || widget.sources!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无其他线路')));
        return;
     }
     final isFullScreen = _controller?.isFullScreen == true;
     
     final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: const Text('切换线路', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
               children: List.generate(widget.sources!.length, (i) {
                  final isSel = i == widget.currentSourceIndex;
                  return _buildSheetItem(
                    title: widget.sources![i]['show'] ?? '默认源',
                    isSelected: isSel,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSourceSelected?.call(i);
                    },
                  );
               }),
            ),
          ),
        ],
     );
     
     if (isFullScreen) {
       _showRightSideSheet(content);
     } else {
       showModalBottomSheet(
       context: context,
       backgroundColor: Theme.of(context).colorScheme.surface,
       builder: (_) => SizedBox(height: 300, child: content),
     );
    }
  }

  // 跳过片头片尾 (复用 PlayerSettings)
  void _showSkipSheet() {
    final isFullScreen = _controller?.isFullScreen == true;
    final settings = PlayerSettings(); // 单例
    
    final content = StatefulBuilder(
      builder: (ctx, setStateInner) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('跳过片头片尾', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Switch(
                      value: settings.enableSkip,
                      onChanged: (v) => setStateInner(() => settings.setEnableSkip(v)),
                      activeColor: Colors.white,
                      activeTrackColor: AppColors.success,
                    ),
                  ],
                ),
                const Text('配置将在下次观看时生效', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildSkipSlider(setStateInner, '片头时长', settings.skipIntro, (v) => settings.setSkipIntro(v)),
                const SizedBox(height: 24),
                _buildSkipSlider(setStateInner, '片尾时长', settings.skipOutro, (v) => settings.setSkipOutro(v)),
              ],
            ),
          ),
        ],
      ),
    );

    if (isFullScreen) {
      _showRightSideSheet(content);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (_) => SizedBox(height: 300, child: content),
      );
    }
  }

  Widget _buildSkipSlider(StateSetter setStateInner, String label, int value, Function(int) onChanged) {
    const greenColor = AppColors.success;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text('${value}s', style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
             activeTrackColor: greenColor,
             inactiveTrackColor: AppColors.slate700.withOpacity(0.24),
             thumbColor: Colors.white,
             trackHeight: 4,
             overlayColor: greenColor.withOpacity(0.2),
             thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8), // 增大滑块便于拖动
             overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0, max: 300,
            onChanged: (v) {
              setStateInner(() => onChanged(v.toInt()));
            },
          ),
        ),
      ],
    );
  }

  // 投屏 Dialog
  void _showCastDialog() {
    final url = _controller?.betterPlayerDataSource?.url ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('视频地址为空，无法投屏')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => CastDialog(
        videoUrl: url,
        title: widget.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_latestValue == null) return const SizedBox.shrink();

    // 开发者：杰哥网络科技 (qq: 2711793818)
    // 修复：PiP模式下使用IgnorePointer让Flutter控制UI不拦截点击事件
    // 系统PiP窗口自带原生控制，Flutter层只需显示但不拦截手势
    final bool isPipMode = _latestValue?.isPip ?? false;

    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () {
        _toggleVisibility();
      },
      onDoubleTap: () {
        if (_isLocked) return;
        if (_controller?.isPlaying() == true) {
          _controller?.pause();
        } else {
          _controller?.play();
        }
        cancelAndRestartTimer();
      },
      // 长按2倍速
      onLongPressStart: (_) {
        if (_isLocked) return;
        if (_controller?.isPlaying() == true) {
           setState(() => _isLongPressing = true);
           _preLongPressSpeed = _controller!.videoPlayerController!.value.speed;
           _controller!.setSpeed(2.0);
        }
      },
      onLongPressEnd: (_) {
        if (_isLocked) return;
        if (_isLongPressing) {
           setState(() => _isLongPressing = false);
           _controller!.setSpeed(_preLongPressSpeed);
        }
      },
      // 垂直滑动调节音量/亮度
      onVerticalDragStart: (details) {
        if (_isLocked) return;
        final dx = details.globalPosition.dx;
        if (dx < size.width / 2) {
          setState(() => _isSlidingBrightness = true);
        } else {
          setState(() => _isSlidingVolume = true);
        }
      },
      onVerticalDragUpdate: (details) async {
        if (_isLocked) return;
        final delta = details.primaryDelta! / -size.height; // 向上为正
        if (_isSlidingBrightness) {
          _brightness = (_brightness + delta).clamp(0.0, 1.0);
          await ScreenBrightness().setScreenBrightness(_brightness);
          setState(() {});
        } else if (_isSlidingVolume) {
          _volume = (_volume + delta).clamp(0.0, 1.0);
          await FlutterVolumeController.setVolume(_volume);
          setState(() {});
        }
      },
      onVerticalDragEnd: (_) {
        setState(() {
          _isSlidingBrightness = false;
          _isSlidingVolume = false;
        });
      },
      // 开发者：杰哥网络科技 (qq: 2711793818)
      // 修复：水平滑动快进快退 - 基于滑动比例映射到视频时长，而非像素直接当秒数
      onHorizontalDragStart: (details) {
        if (_isLocked) return;
        _dragStartPosition = _controller!.videoPlayerController!.value.position;
        _dragStartX = details.globalPosition.dx;
      },
      onHorizontalDragUpdate: (details) {
        if (_isLocked) return;
        final total = _controller!.videoPlayerController!.value.duration;
        if (total == null || _dragStartPosition == null || _dragStartX == null) return;
        final screenWidth = MediaQuery.of(context).size.width;
        final deltaX = details.globalPosition.dx - _dragStartX!;
        final seekDeltaMs = (deltaX / screenWidth * total.inMilliseconds).round();
        final seekTo = _dragStartPosition! + Duration(milliseconds: seekDeltaMs);
        if (seekTo >= Duration.zero && seekTo <= total) {
          _controller!.seekTo(seekTo);
        }
      },
      child: Container(
        color: Colors.transparent,
        // 开发者：杰哥网络科技
        // 修复：PiP模式下使用IgnorePointer，让系统原生控制按钮可以正常点击
        // 同时保持Flutter控制UI可见（透明），避免视频区域闪烁
        child: IgnorePointer(
          ignoring: isPipMode,
          child: Stack(
            children: [
              // 1. 锁定按钮
              if (_controlsVisible && (_controller?.isFullScreen == true) && !isPipMode)
                Positioned(
                  left: 30,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _buildLockButton()),
                ),

              // 2. 顶部栏
              if (_controlsVisible && !_isLocked && !isPipMode)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: _buildTopBar(),
                ),

              // 3. 底部栏
              if (_controlsVisible && !_isLocked && !isPipMode)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _buildBottomBar(),
                ),

              // 4. 投屏控制条（投屏状态下显示在顶部）
              if (_isCasting && !isPipMode)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 65,
                  left: 16, right: 16,
                  child: CastControls(
                    onStopCast: () {
                      setState(() => _isCasting = false);
                    },
                  ),
                ),

              // 5. 加载中
              if (_latestValue!.isBuffering && !isPipMode)
                 const Center(
                   child: SizedBox(
                     width: 50,
                     height: 50,
                     child: CircularProgressIndicator(
                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                       strokeWidth: 4,
                     ),
                   ),
                 ),

              // 6. 长按倍速提示
              if (_isLongPressing && !isPipMode)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.slate900.withOpacity(0.54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fast_forward, color: Colors.white),
                        SizedBox(width: 8),
                        Text('2倍速播放中', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),

              // 7. 亮度/音量 提示
              if ((_isSlidingBrightness || _isSlidingVolume) && !isPipMode)
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.slate900.withOpacity(0.54),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSlidingBrightness ? Icons.brightness_6 : Icons.volume_up,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _isSlidingBrightness ? _brightness : _volume,
                          backgroundColor: AppColors.slate700.withOpacity(0.24),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _isLocked = !_isLocked);
        cancelAndRestartTimer();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.slate900.withOpacity(0.54),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(
          _isLocked ? Icons.lock : Icons.lock_open,
          color: _isLocked ? AppColors.error : Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final isFullScreen = _controller?.isFullScreen == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
             isFullScreen ? AppColors.slate900.withOpacity(0.7) : AppColors.slate900.withOpacity(0.54), 
             Colors.transparent
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                 if (isFullScreen) {
                   _controller?.exitFullScreen();
                 } else {
                   Navigator.of(context).pop();
                 }
              },
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // 开发者：杰哥网络科技 (qq: 2711793818)
            // 修复：PiP按钮在竖屏和横屏都显示，不再仅限全屏模式
            _buildIconBtn(Icons.picture_in_picture_alt, () async {
               // 使用 BetterPlayer 自带 PiP
               if (_controller != null) {
                  try {
                     bool? isPipSupported = await _controller!.isPictureInPictureSupported();
                     if (isPipSupported == true) {
                       final pipKey = _controller!.betterPlayerGlobalKey;
                       if (pipKey != null) {
                         _controller!.enablePictureInPicture(pipKey);
                       } else {
                         if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('画中画初始化未完成，请稍后重试')));
                         }
                       }
                     } else {
                       if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('当前设备不支持画中画')));
                       }
                     }
                  } catch (e) {
                     if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('画中画启动失败: $e')));
                     }
                  }
               }
            }),
            if (isFullScreen) ...[
              _buildIconBtn(Icons.timer, _showSleepTimerSheet), // 新增定时关闭按钮
              _buildIconBtn(Icons.cast, _showCastDialog),
            ] else ...[
               _buildIconBtn(Icons.cast, _showCastDialog),
            ],
            
            const SizedBox(width: 16),
            if (isFullScreen)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.battery_std, color: Colors.white, size: 14),
                      const SizedBox(width: 2),
                      Text('$_batteryLevel%', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                  Text(_currentTime, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4), // 增加间距控制
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            onTap();
            cancelAndRestartTimer();
          },
          child: Padding(
            padding: const EdgeInsets.all(12), // 增大点击区域到 48x48
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  // 播放暂停按钮样式
  Widget _buildPlayPauseBtn(double size) {
    final isPlaying = _controller?.isPlaying() ?? false;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () {
          if (isPlaying) {
            _controller?.pause();
            _hideTimer?.cancel();
          } else {
            _controller?.play();
            cancelAndRestartTimer();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12), // 保持大点击区域
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
            color: Colors.white, 
            size: size
          ),
        ),
      ),
    );
  }

  // 下一集按钮样式
  Widget _buildNextEpBtn(double size) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () {
           widget.onNextEpisode?.call();
           cancelAndRestartTimer();
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent, // 下一集不需要背景，保持简洁
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(12), // 增大点击区域
          child: Icon(Icons.skip_next_rounded, color: Colors.white, size: size),
        ),
      ),
    );
  }

  // 辅助方法：计算缓冲进度
  double _calculateBufferedPercent() {
    if (_latestValue == null || _latestValue!.duration == null || _latestValue!.duration!.inMilliseconds == 0) {
      return 0.0;
    }
    final total = _latestValue!.duration!.inMilliseconds;
    double maxBuffered = 0;
    for (final range in _latestValue!.buffered) {
      if (range.end.inMilliseconds > maxBuffered) {
        maxBuffered = range.end.inMilliseconds.toDouble();
      }
    }
    return (maxBuffered / total).clamp(0.0, 1.0);
  }

  Widget _buildBottomBar() {
    final duration = _latestValue!.duration ?? Duration.zero;
    final position = _latestValue!.position;
    final isFullScreen = _controller?.isFullScreen == true;

    // 开发者：杰哥网络科技 (qq: 2711793818)
    // 优化：使用毫秒级精度计算进度比例，避免inSeconds截断导致进度条不准确
    final double currentProgress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds)
        : 0.0;
    // 拖动时显示拖动位置，否则显示当前播放位置
    final double displayProgress = _isDragging && _draggingValue != null
        ? _draggingValue!
        : currentProgress;

    // 根据总时长决定时间格式：≥1小时显示 HH:MM:SS，否则显示 MM:SS
    final bool showHours = duration.inHours > 0;
    // 拖动时显示预览时间
    final Duration displayPosition = _isDragging && _draggingValue != null
        ? Duration(milliseconds: (_draggingValue! * duration.inMilliseconds).round())
        : position;

    // 开发者：杰哥网络科技 (qq: 2711793818)
    // 竖屏时底部栏适配：根据屏幕宽度动态调整按钮和进度条大小
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isPortrait = screenWidth < 600;
    final double playBtnSize = isPortrait ? 32 : 28;
    final double fullscreenBtnSize = isPortrait ? 32 : 28;

    return Container(
      padding: EdgeInsets.fromLTRB(isFullScreen ? 12 : 8, 8, isFullScreen ? 12 : 8, isFullScreen ? 16 : 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            isFullScreen ? AppColors.slate900.withOpacity(0.85) : AppColors.slate900.withOpacity(0.54),
            Colors.transparent
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: isFullScreen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 开发者：杰哥网络科技 (qq: 2711793818)
            // 优化：进度条区域 - 支持拖动预览、精确seek
            _buildProgressBar(
              currentProgress: currentProgress,
              displayProgress: displayProgress,
              duration: duration,
              showHours: showHours,
              displayPosition: displayPosition,
              isFullScreen: isFullScreen,
              playBtnSize: playBtnSize,
              fullscreenBtnSize: fullscreenBtnSize,
            ),
            
            if (isFullScreen) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildPlayPauseBtn(40),
                  const SizedBox(width: 16),
                  _buildNextEpBtn(40),
                  const SizedBox(width: 16),
                  
                  // 弹幕开关
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        final settings = PlayerSettings();
                        if (!settings.danmakuUserEnabled && settings.danmakuEnabled == false) {
                          return;
                        }
                        settings.setDanmakuEnabled(!settings.danmakuUserEnabled);
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                           border: Border.all(color: PlayerSettings().danmakuEnabled ? AppColors.success : AppColors.slate500),
                           borderRadius: BorderRadius.circular(16),
                           color: PlayerSettings().danmakuEnabled ? AppColors.success.withOpacity(0.2) : Colors.transparent,
                        ),
                        child: Text('弹', style: TextStyle(
                          color: PlayerSettings().danmakuEnabled 
                            ? AppColors.success 
                            : (PlayerSettings().danmakuUserEnabled == false && PlayerSettings().danmakuEnabled == false)
                              ? AppColors.error
                              : Colors.white, 
                          fontSize: 12,
                        )),
                      ),
                    ),
                  ),
                  
                  _buildIconBtn(Icons.settings, _showDanmakuSettingsSheet),
                  
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        widget.onDanmakuToggle?.call();
                        cancelAndRestartTimer();
                      },
                      child: Container(
                        height: 36,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.slate700.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.centerLeft,
                        child: const Text('此刻你在想什么...', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                      ),
                    ),
                  ),
                  
                  _buildTextBtn('片头/尾', _showSkipSheet),
                  _buildTextBtn('播放源', _showSourceSheet),
                  _buildTextBtn('倍速', _showSpeedSheet),
                  _buildTextBtn('选集', _showEpisodeSheet),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 开发者：杰哥网络科技 (qq: 2711793818)
  // 优化：行业标准的进度条实现 - 支持拖动预览、精确seek、缓冲显示
  Widget _buildProgressBar({
    required double currentProgress,
    required double displayProgress,
    required Duration duration,
    required bool showHours,
    required Duration displayPosition,
    required bool isFullScreen,
    double playBtnSize = 28,
    double fullscreenBtnSize = 28,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 拖动预览时间气泡 - 跟随 thumb 位置
        if (_isDragging && _draggingValue != null) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final thumbX = constraints.maxWidth * _draggingValue!;
              return Stack(
                children: [
                  Positioned(
                    left: thumbX - 30,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.slate900,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.slate900.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _formatDuration(displayPosition, forceShowHours: showHours),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            if (!isFullScreen) ...[
              _buildPlayPauseBtn(playBtnSize),
              const SizedBox(width: 4),
            ],

            // 当前时间 - 拖动时显示预览时间，有气泡时隐藏避免重复
            SizedBox(
              width: isFullScreen ? (showHours ? 58 : 40) : (showHours ? 54 : 36),
              child: _isDragging
                  ? const SizedBox.shrink() // 拖动时有气泡显示，隐藏左侧时间
                  : Text(
                      _formatDuration(displayPosition, forceShowHours: showHours),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()], // 等宽数字，防止抖动
                      ),
                      textAlign: TextAlign.right,
                    ),
            ),
            const SizedBox(width: 4),

            // 进度条 - 使用 GestureDetector 实现更精确的点击和拖动
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double barHeight = isFullScreen ? 4.0 : 4.0;
                  final double thumbRadius = isFullScreen ? 8.0 : 6.0;

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (details) {
                      final box = context.findRenderObject() as RenderBox;
                      final localPos = box.globalToLocal(details.globalPosition);
                      final value = (localPos.dx / box.size.width).clamp(0.0, 1.0);
                      _onSeekStart(value);
                    },
                    onHorizontalDragUpdate: (details) {
                      final box = context.findRenderObject() as RenderBox;
                      final localPos = box.globalToLocal(details.globalPosition);
                      final value = (localPos.dx / box.size.width).clamp(0.0, 1.0);
                      _onSeekUpdate(value);
                    },
                    onHorizontalDragEnd: (details) {
                      if (_draggingValue != null) {
                        _onSeekEnd(_draggingValue!);
                      }
                    },
                    onTapDown: (details) {
                      final box = context.findRenderObject() as RenderBox;
                      final localPos = box.globalToLocal(details.globalPosition);
                      final value = (localPos.dx / box.size.width).clamp(0.0, 1.0);
                      _onSeekStart(value);
                      _onSeekEnd(value);
                    },
                    child: Container(
                      height: 32, // 增大点击区域
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // 背景轨道
                          Container(
                            height: barHeight,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.slate700.withOpacity(0.24),
                              borderRadius: BorderRadius.circular(barHeight / 2),
                            ),
                          ),
                          // 缓冲进度
                          Container(
                            height: barHeight,
                            width: constraints.maxWidth * _calculateBufferedPercent(),
                            decoration: BoxDecoration(
                              color: AppColors.slate500.withOpacity(0.38),
                              borderRadius: BorderRadius.circular(barHeight / 2),
                            ),
                          ),
                          // 播放进度
                          Container(
                            height: barHeight,
                            width: constraints.maxWidth * (_isDragging && _draggingValue != null ? _draggingValue! : displayProgress),
                            decoration: BoxDecoration(
                              color: _isDragging ? AppColors.success : AppColors.success,
                              borderRadius: BorderRadius.circular(barHeight / 2),
                              boxShadow: _isDragging ? [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ] : null,
                            ),
                          ),
                          // Thumb 指示器
                          Positioned(
                            left: (constraints.maxWidth * (_isDragging && _draggingValue != null ? _draggingValue! : displayProgress)) - (_isDragging ? thumbRadius * 1.3 : thumbRadius),
                            child: Container(
                              width: (_isDragging ? thumbRadius * 1.3 : thumbRadius) * 2,
                              height: (_isDragging ? thumbRadius * 1.3 : thumbRadius) * 2,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.slate900.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                  if (_isDragging)
                                    BoxShadow(
                                      color: AppColors.success.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 4),

            // 总时长 - 拖动时隐藏，保持界面简洁
            SizedBox(
              width: isFullScreen ? (showHours ? 58 : 40) : (showHours ? 54 : 36),
              child: _isDragging
                  ? const SizedBox.shrink()
                  : Text(
                      _formatDuration(duration, forceShowHours: showHours),
                      style: const TextStyle(
                        color: AppColors.slate300,
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()], // 等宽数字
                      ),
                      textAlign: TextAlign.left,
                    ),
            ),

            if (!isFullScreen) ...[
              const SizedBox(width: 2),
              IconButton(
                icon: Icon(Icons.fullscreen_rounded, color: Colors.white, size: fullscreenBtnSize),
                onPressed: () {
                  _controller?.toggleFullScreen();
                  cancelAndRestartTimer();
                },
              ),
            ]
          ],
        ),
      ],
    );
  }
  
  Widget _buildTextBtn(String text, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          onTap?.call();
          cancelAndRestartTimer();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  // 开发者：杰哥网络科技 (qq: 2711793818)
  // 统一格式化时间，根据总时长决定是否强制显示小时位，保证格式一致
  String _formatDuration(Duration d, {bool forceShowHours = false}) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).abs();
    final s = d.inSeconds.remainder(60).abs();
    if (h > 0 || forceShowHours) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // 开发者：杰哥网络科技 (qq: 2711793818)
  // 优化：进度条拖动状态管理，实现拖动预览功能
  double? _draggingValue;
  bool _isDragging = false;

  void _onSeekStart(double value) {
    setState(() {
      _isDragging = true;
      _draggingValue = value;
    });
    // 拖动时取消自动隐藏定时器
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _onSeekUpdate(double value) {
    setState(() => _draggingValue = value);
  }

  void _onSeekEnd(double value) {
    final duration = _latestValue?.duration;
    if (duration != null && duration.inMilliseconds > 0) {
      final seekMs = (value * duration.inMilliseconds).round();
      _controller?.seekTo(Duration(milliseconds: seekMs));
    }
    setState(() {
      _isDragging = false;
      _draggingValue = null;
    });
    cancelAndRestartTimer();
  }
}
