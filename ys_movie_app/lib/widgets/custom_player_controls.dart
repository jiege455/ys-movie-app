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