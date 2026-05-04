/// 文件名：detail_page.dart
/// 作者：杰哥（by：杰哥 / qq：2711793818）
/// 创建日期：2025-12-16
/// 作用：视频详情页（播放器 + 简介 + 选集 + 猜你喜欢）
/// 解释：核心页面，看片的地方。集成了播放器、选集、下载、收藏等功能。
// by：杰哥 
// qq： 2711793818
// 1. 修复画中画黑屏和按钮问题
// 2. 移除本地收藏，仅使用云端收藏
// 3. 修复下载逻辑

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player/better_player.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/api.dart';
import '../services/store.dart';
import '../services/player_settings.dart';
import '../services/m3u8_downloader_service.dart';
import '../widgets/comment_item.dart';
import '../widgets/custom_player_controls.dart';
import 'auth_bottom_sheet.dart';
import 'download_page.dart';
import 'feedback_center_page.dart';

class DetailPage extends StatefulWidget {
  final String vodId;
  final String? localPlayUrl;
  final String? initialTitle;
  final String? initialPoster;

  const DetailPage({
    super.key, 
    required this.vodId,
    this.localPlayUrl,
    this.initialTitle,
    this.initialPoster,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  bool loading = true;
  Map<String, dynamic> detail = {};
  
  // 播放器相关
  BetterPlayerController? _betterPlayerController;
  int _currentSourceIndex = 0;
  int _currentEpisodeIndex = 0;
  List<Map<String, dynamic>> _sources = [];
  List<Map<String, dynamic>> _episodes = [];
  
  // 错误重试
  bool _hasError = false;
  String _errorMsg = '';
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // 状态
  bool _isCollected = false;
  String _collectId = ''; // 云端收藏ID
  bool _isEpisodeAscending = true; // 选集排序
  
  // 猜你喜欢
  List<Map<String, dynamic>> _relatedList = [];
  List<Map<String, dynamic>> _comments = [];
  int _tabIndex = 0; // 0=详情,1=评论

  // 广告
  Map<String, dynamic>? _playerBelowAdvert;

  // 播放设置
  late PlayerSettings _playerSettings;
  
  // Notifiers
  final ValueNotifier<int> _episodeIndexNotifier = ValueNotifier(0);
  final ValueNotifier<int> _sourceIndexNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 开发者：杰哥
    // 优化：利用传入参数预填充数据，实现秒开体验
    if (widget.initialTitle != null) {
      detail['vod_name'] = widget.initialTitle;
    }
    if (widget.initialPoster != null) {
      detail['vod_pic'] = widget.initialPoster;
    }
    
    _playerSettings = PlayerSettings();
    // 开发者：杰哥网络科技 (qq: 2711793818)
    // 修复：根据后端配置强制控制弹幕开关
    _initDanmakuConfig();
    _loadData();
    // 加载广告
    _loadAdverts();
  }

  /// 开发者：杰哥网络科技 (qq: 2711793818)
  /// 作用：根据后端配置初始化弹幕开关
  void _initDanmakuConfig() {
    try {
      final api = context.read<MacApi>();
      _playerSettings.setDanmakuForceDisabled(!api.isDanmuEnabled);
    } catch (_) {}
  }

  /// 开发者：杰哥
  /// 作用：检查登录状态并执行操作，未登录则弹窗提示
  Future<void> _checkLoginAndRun(VoidCallback callback) async {
    final api = context.read<MacApi>();
    final isLogin = await api.checkLogin();
    if (isLogin) {
      callback();
    } else {
      if (!mounted) return;
      showAuthBottomSheet(
        context,
        onLoginSuccess: () {
          if (mounted) {
             setState(() {});
             _checkFavoriteStatus();
             api.checkLogin().then((ok) {
               if (ok) callback();
             });
          }
        }
      );
    }
  }

  String _fixAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    String cleanUrl = url.trim();
    if (cleanUrl.startsWith('http') || cleanUrl.startsWith('//')) {
      if (cleanUrl.startsWith('//')) return 'https:$cleanUrl';
      return cleanUrl;
    }
    
    // 获取 BaseUrl
    String baseUrl = AppConfig.baseUrl;
    if (baseUrl.contains('/api.php')) {
      baseUrl = baseUrl.split('/api.php').first;
    }
    if (!baseUrl.endsWith('/')) baseUrl += '/';
    
    // 处理相对路径
    if (cleanUrl.startsWith('/')) {
      cleanUrl = cleanUrl.substring(1);
    }
    
    return '$baseUrl$cleanUrl';
  }

  @override
  void dispose() {
    try {
      _betterPlayerController?.dispose();
    } catch (_) {}
    _playerSettings.dispose();
    _episodeIndexNotifier.dispose();
    _sourceIndexNotifier.dispose();
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_betterPlayerController != null) {
      _betterPlayerController!.setAppLifecycleState(state);
    }
  }

  Future<void> _loadData() async {
    if (widget.localPlayUrl != null && widget.localPlayUrl!.isNotEmpty) {
      // 播放本地文件
      detail = {
        'vod_name': widget.initialTitle ?? '本地视频',
        'vod_pic': widget.initialPoster ?? '',
        'type_name': '缓存',
        'vod_year': '',
        'vod_area': '',
        'vod_actor': '',
        'vod_content': '本地缓存视频',
      };
      _sources = [{'urls': [{'name': '本地', 'url': widget.localPlayUrl}]}];
      _episodes = _sources[0]['urls'] as List<Map<String, dynamic>>;
      await _initPlayer();
      setState(() => loading = false);
      return;
    }

    final api = context.read<MacApi>();
    setState(() => loading = true);
    
    try {
      final res = await api.getDetail(widget.vodId);
      if (!mounted) return;
      
      detail = res ?? {};
      
      // 解析播放源（保持旧字段兼容）
      if (res != null && res['vod_play_list'] is List) {
        _sources = (res['vod_play_list'] as List).cast<Map<String, dynamic>>();
      } else {
        _sources = [];
      }
      
      // 读取历史记录
      int lastSourceIdx = 0;
      int lastEpIdx = 0;
      int lastPos = 0;
      
      // 优先读取详细的播放选择记录
      final lastSel = await StoreService.getLastPlaySelection(widget.vodId);
      if (lastSel != null) {
        lastSourceIdx = lastSel['sourceIndex'] ?? 0;
        lastEpIdx = lastSel['episodeIndex'] ?? 0;
      }

      // 读取进度
      try {
        final historyItem = await StoreService.getHistoryItem(widget.vodId);
        if (historyItem != null) {
          lastPos = historyItem['position'] ?? 0;
        }
      } catch (_) {}
      
      // 修正索引
      if (lastSourceIdx >= _sources.length) lastSourceIdx = 0;
      _currentSourceIndex = lastSourceIdx;
      _sourceIndexNotifier.value = _currentSourceIndex;
      
      if (_sources.isNotEmpty) {
        final urls = _sources[_currentSourceIndex]['urls'] as List?;
        if (urls != null) {
          _episodes = urls.cast<Map<String, dynamic>>();
        }
      }
      
      if (lastEpIdx >= _episodes.length) lastEpIdx = 0;
      _currentEpisodeIndex = lastEpIdx;
      _episodeIndexNotifier.value = _currentEpisodeIndex;
      
      // 开发者：杰哥
      // 优化：获取到详情数据后先刷新 UI，让用户看到文字信息，然后再初始化播放器
      if (mounted) setState(() {});

      // 初始化播放器
      await _initPlayer(startPosition: Duration(seconds: lastPos));
      
      // 检查收藏状态 (仅云端)
      _checkFavoriteStatus();
      
      // 加载猜你喜欢
      _loadRelated();

      setState(() => loading = false);
      
      // 写入历史记录 (更新访问时间)
      _saveHistory();
      
    } catch (e) {
      print('Detail Load Error: $e');
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  /// 开发者：杰哥
  /// 作用：仅检查云端收藏状态
  Future<void> _checkFavoriteStatus() async {
    final api = context.read<MacApi>();
    try {
      final res = await api.isCollected(widget.vodId);
      if (mounted) {
        setState(() {
          _isCollected = res == true;
          _collectId = '';
        });
      }
    } catch (e) {
      print('Check Fav Error: $e');
    }
  }

  /// 开发者：杰哥
  /// 作用：切换收藏状态 (仅云端)
  Future<void> _toggleCollect() async {
    _checkLoginAndRun(() async {
      final api = context.read<MacApi>();
      try {
        if (_isCollected) {
          // 取消收藏
          if (_collectId.isNotEmpty) {
             await api.deleteFav(_collectId);
          } else {
             await api.deleteFavByVodId(widget.vodId); 
          }
          if (mounted) {
            setState(() {
              _isCollected = false;
              _collectId = '';
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消收藏')));
          }
        } else {
          // 添加收藏
          final res = await api.addFav(widget.vodId);
          if (mounted) {
            setState(() {
              _isCollected = res['success'] == true;
              // 尝试获取 ID，如果不返回则为空
              _collectId = '${res['log_id'] ?? ''}';
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['msg'] ?? '操作完成'}')));
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    });
  }

  Future<void> _loadRelated() async {
    final api = context.read<MacApi>();
    try {
      final typeId = int.tryParse('${detail['type_id']}') ?? 0;
      if (typeId > 0) {
        // 用户要求只显示6个
        final list = await api.getFiltered(typeId: typeId, limit: 9);
        if (mounted) {
          setState(() {
            _relatedList = list.where((e) => '${e['id']}' != widget.vodId).take(6).toList();
          });
        }
      }
    } catch (_) {}
  }
  
  Future<void> _loadComments() async {
    final api = context.read<MacApi>();
    try {
      final list = await api.getComments(widget.vodId);
      final rawList = list.cast<Map<String, dynamic>>();
      
      // 1. 获取全局配置 (置顶评论 & 广告)
      final initData = await api.getAppInit(force: false);
      
      // 2. 处理置顶评论
      Map<String, dynamic>? pinnedComment;
      try {
         if (detail['official_comment'] != null && detail['official_comment'] is Map) {
             final off = detail['official_comment'];
             pinnedComment = {
                'user_name': off['user_name'] ?? '官方置顶',
                'user_portrait': _fixAvatarUrl(off['user_avatar'] ?? ''),
                'content': off['comment_content'] ?? off['comment'] ?? '欢迎评论~',
                'is_pinned': true,
                'up': 9999,
                'create_time': '置顶',
             };
         }

         if (pinnedComment == null) {
             Map<String, dynamic> setting = {};
             void mergeIfMap(dynamic data) {
                if (data is Map) {
                   setting.addAll(data as Map<String, dynamic>);
                }
             }

             if (initData['app_page_setting'] != null) {
                final ps = initData['app_page_setting'];
                mergeIfMap(ps);
                if (ps is Map && ps['app_page_setting'] is Map) {
                   mergeIfMap(ps['app_page_setting']);
                }
             }
             
             mergeIfMap(initData);
             if (initData['config'] != null) mergeIfMap(initData['config']);
             if (initData['system'] != null) mergeIfMap(initData['system']); 
             if (initData['app_comment_top'] != null) mergeIfMap(initData['app_comment_top']);
             if (initData['comment_top'] != null) mergeIfMap(initData['comment_top']); 
             
             if (initData['data'] is Map) {
                mergeIfMap(initData['data']);
                if (initData['data']['comment_top'] != null) {
                   mergeIfMap(initData['data']['comment_top']);
                }
             }

             var statusRaw = setting['app_comment_top_status'] ?? 
                             setting['comment_top_status'] ?? 
                             setting['system_config_top_comment_open'] ?? 
                             setting['system_config_top_comment_status'] ?? 
                             setting['status'];
             
             bool isOpen = false;
             if (statusRaw != null) {
                final s = statusRaw.toString().toLowerCase();
                isOpen = s == '1' || s == 'true' || s == 'on' || s == '开启';
             }
             
             if (isOpen) {
                pinnedComment = {
                   'user_name': setting['app_comment_top_name'] ?? setting['comment_top_name'] ?? setting['system_config_top_comment_nickname'] ?? setting['system_config_top_comment_name'] ?? '官方置顶',
                   'user_portrait': _fixAvatarUrl(setting['app_comment_top_avatar'] ?? setting['comment_top_avatar'] ?? setting['system_config_top_comment_avatar'] ?? setting['system_config_top_comment_avtar'] ?? ''),
                   'content': setting['app_comment_top_content'] ?? setting['comment_top_content'] ?? setting['system_config_top_comment_content'] ?? '欢迎评论~',
                   'is_pinned': true,
                   'up': 9999,
                   'create_time': '置顶',
                };
             }
         }
      } catch (_) {}
      
      // 3. 处理评论顶部广告
      Map<String, dynamic>? adComment;
      try {
         List<dynamic> ads = [];
         if (initData['custom_ads'] is List) ads.addAll(initData['custom_ads']);
         if (initData['advert_list'] is List) ads.addAll(initData['advert_list']);
         if (initData['ads'] is List) ads.addAll(initData['ads']);
         
         for (final ad in ads) {
            if (ad is! Map) continue;
            final name = (ad['name'] ?? ad['type_name'] ?? '').toString();
            final pos = (ad['position'] ?? '').toString(); 
            
            if (name.contains('评论') && (name.contains('顶') || pos == 'comment_top')) {
               final list = ad['list'] ?? ad['data'];
               if (list is List && list.isNotEmpty) {
                  final item = list.first;
                  if (item is Map) {
                     adComment = {
                        'user_name': item['name'] ?? item['title'] ?? '广告',
                        'user_portrait': item['pic'] ?? item['img'] ?? '',
                        'content': item['url'] ?? '', 
                        'is_ad': true, 
                        'ad_data': item,
                        'up': 0,
                     };
                  }
               }
               break; 
            }
         }
      } catch (_) {}

      final finalList = <Map<String, dynamic>>[];
      
      rawList.removeWhere((c) => c['is_pinned'] == true || c['id'] == 'official' || c['is_official'] == true);
      
      if (pinnedComment != null) {
          finalList.add(pinnedComment);
      }
      
      if (adComment != null) finalList.add(adComment);
      
      finalList.addAll(rawList);

      if (mounted) setState(() => _comments = finalList);
    } catch (_) {}
  }

  Future<void> _initPlayer({Duration startPosition = Duration.zero}) async {
    if (_episodes.isEmpty) return;
    
    setState(() {
       _hasError = false;
       _errorMsg = '';
    });

    final ep = _episodes[_currentEpisodeIndex];
    String url = ep['url'] ?? '';
    final parseApi = ep['parse_api'] ?? '';
    // 若有解析接口，进行解析得到直链
    if (parseApi.isNotEmpty) {
      try {
        final api = context.read<MacApi>();
        url = await api.resolvePlayUrl(url, parseApi: parseApi);
      } catch (e) {
        debugPrint("Parse Error: $e");
        _handleLoadError("解析地址失败: $e", startPosition);
        return;
      }
    }
    
    // 应用跳过片头设置
    if (_playerSettings.enableSkip && _playerSettings.skipIntro > 0) {
       if (startPosition.inSeconds < _playerSettings.skipIntro) {
          startPosition = Duration(seconds: _playerSettings.skipIntro);
       }
    }
    
    // 配置 BetterPlayer
    BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: false,
      fullScreenByDefault: false,
      allowedScreenSleep: false,
      // betterPlayerGlobalKey: _playerGlobalKey, // 该参数在当前版本不存在
      autoDetectFullscreenDeviceOrientation: true, // 开启自动检测方向 (适配短剧)
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.portraitUp,
      ],
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 42),
              const SizedBox(height: 16),
              Text(
                '播放失败: $errorMessage',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _initPlayer(startPosition: _betterPlayerController?.videoPlayerController?.value.position ?? Duration.zero);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
                child: const Text('重试', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      },
      controlsConfiguration: BetterPlayerControlsConfiguration(
        playerTheme: BetterPlayerTheme.custom,
        customControlsBuilder: (controller, onVisibilityChanged) {
          return CustomPlayerControls(
            controller: controller,
            onControlsVisibilityChanged: onVisibilityChanged,
            title: "${detail['vod_name'] ?? ''} ${_episodes.isNotEmpty ? _episodes[_currentEpisodeIndex]['name'] : ''}",
            onNextEpisode: _onNextEpisode,
            // 传递数据给 CustomPlayerControls
            episodes: _episodes,
            currentEpisodeIndex: _currentEpisodeIndex,
            sources: _sources,
            currentSourceIndex: _currentSourceIndex,
            onEpisodeSelected: (index) {
              _changeEpisode(index);
            },
            onSourceSelected: (index) {
              _changeSource(index);
            },
            onShowSkip: _showSkipSettingsDialog,
            onDanmakuToggle: () {
              _checkLoginAndRun(() {
                 _showDanmakuInputDialog();
              });
            },
            onShowSpeed: () {
               showModalBottomSheet(
                  context: context, 
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Container(
                     decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                     child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [0.5, 1.0, 1.25, 1.5, 2.0].map((speed) => ListTile(
                           title: Text('${speed}x', style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                           onTap: () {
                              _betterPlayerController?.setSpeed(speed);
                              Navigator.pop(ctx);
                           },
                           trailing: _betterPlayerController?.videoPlayerController?.value.speed == speed ? const Icon(Icons.check, color: Colors.blue) : null,
                        )).toList(),
                     ),
                  )
               );
            },
          );
        },
        enableSkips: true,
        enableFullscreen: true,
        enablePlayPause: true,
        enableProgressBar: true,
        enableProgressBarDrag: true,
        enableMute: true,
        enableOverflowMenu: true,
        enablePip: true,
        enableRetry: true,
        enablePlaybackSpeed: true,
        enableQualities: true,
        // 禁用 BetterPlayer 默认的加载 Loading，完全由 CustomPlayerControls 接管
        loadingWidget: const SizedBox.shrink(),
      ),
      // 占位符修改：移除 CachedNetworkImage，仅保留黑色背景
      placeholder: Container(
        color: Colors.black,
      ),
    );

    // 开发者：杰哥网络科技 (qq: 2711793818)
    // 优化：启用缓存、优化缓冲配置、支持后台播放通知
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      // videoFormat: BetterPlayerVideoFormat.hls, // 移除强制HLS
      // pipKey: 'pip_${url.hashCode}', // 该参数在当前版本不存在
      // userAgent: 'ys_movie_app/1.0', // 该参数在当前版本不存在
      notificationConfiguration: const BetterPlayerNotificationConfiguration(
        showNotification: true,
        title: "正在播放",
        author: "狐狸影视",
        imageUrl: "",
      ),
      // 开发者：杰哥网络科技
      // 优化：调整缓冲策略，平衡加载速度和流畅度
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 15000,        // 最小缓冲 15秒，保证流畅
        maxBufferMs: 50000,        // 最大缓冲 50秒
        bufferForPlaybackMs: 2500, // 起播缓冲 2.5秒，加快首帧
        bufferForPlaybackAfterRebufferMs: 5000, // 重缓冲 5秒
      ),
      // 开发者：杰哥网络科技
      // 优化：启用缓存，提升二次播放速度
      cacheConfiguration: const BetterPlayerCacheConfiguration(
        useCache: true,
        maxCacheSize: 200 * 1024 * 1024, // 200MB 缓存
        maxCacheFileSize: 50 * 1024 * 1024, // 50MB 单文件
      ),
    );

    // 如果控制器已存在，复用它以避免全屏黑屏
    if (_betterPlayerController != null) {
      try {
        _betterPlayerController!.pause();
        _betterPlayerController!.setupDataSource(dataSource);
        _betterPlayerController!.setBetterPlayerControlsConfiguration(
          betterPlayerConfiguration.controlsConfiguration
        );
        if (startPosition > Duration.zero) {
          _betterPlayerController!.seekTo(startPosition);
        }
      } catch (e) {
        debugPrint("Controller Reuse Error: $e");
        // 如果复用失败，回退到重新创建
        try { _betterPlayerController?.dispose(); } catch (_) {}
        _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
        _betterPlayerController!.setupDataSource(dataSource);
        _addControllerListeners();
      }
    } else {
      _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
      _betterPlayerController!.setupDataSource(dataSource);
      _addControllerListeners();
      
      if (startPosition > Duration.zero) {
        _betterPlayerController!.seekTo(startPosition);
      }
    }
    
    if (mounted) setState(() {});
  }

  void _addControllerListeners() {
    _betterPlayerController!.addEventsListener((event) {
      if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
         _onVideoProgress();
      } else if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
         _onNextEpisode();
      } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
         debugPrint("BetterPlayer Exception: ${event.parameters}");
         _handleLoadError("播放出错: ${event.parameters?['errorMessage'] ?? '未知错误'}", _betterPlayerController!.videoPlayerController!.value.position);
      }
    });
  }

  void _handleLoadError(String msg, Duration startPos) {
     if (_retryCount < _maxRetries) {
        _retryCount++;
        debugPrint("Retrying... $_retryCount");
        Future.delayed(const Duration(seconds: 1), () {
           if (mounted) _initPlayer(startPosition: startPos);
        });
     } else {
        if (mounted) {
           setState(() {
              _hasError = true;
              _errorMsg = msg;
           });
        }
     }
  }

  Future<void> _onRemind() async {
    _checkLoginAndRun(() async {
      final api = context.read<MacApi>();
      final res = await api.requestUpdate(widget.vodId);
      if (mounted) {
        if (res['success'] == true) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? '已提交催更请求，我们会尽快更新')));
        } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? '提交失败，请稍后重试')));
        }
      }
    });
  }
  
  void _onVideoProgress() {
    if (!mounted || _betterPlayerController == null) return;
    final val = _betterPlayerController!.videoPlayerController?.value;
    if (val == null) return;
    
    if (val.isPlaying && val.position.inSeconds % 5 == 0) { // 每5秒保存一次
       _saveHistory();
    }
    
    // 跳过片尾逻辑
    if (_playerSettings.enableSkip && _playerSettings.skipOutro > 0) {
       final pos = val.position.inSeconds;
       final dur = val.duration?.inSeconds ?? 0;
       if (dur > 0 && (dur - pos) <= _playerSettings.skipOutro) {
          // 防止重复触发，这里其实 _onNextEpisode 会切换视频，所以风险不大
          _onNextEpisode();
       }
    }
  }
  
  void _saveHistory() {
    if (_betterPlayerController == null) return;
    // Check if disposed
    try {
      final val = _betterPlayerController!.videoPlayerController?.value;
      if (val == null) return;
      
      final pos = val.position.inSeconds;
      StoreService.addHistory({
        'id': widget.vodId,
        'title': detail['vod_name'] ?? '',
        'poster': detail['vod_pic'] ?? '',
        'url': '',
        'position': pos,
      });
      StoreService.setLastPlaySelection(
        vodId: widget.vodId,
        sourceIndex: _currentSourceIndex,
        episodeIndex: _currentEpisodeIndex,
        episodeName: _episodes.isNotEmpty ? _episodes[_currentEpisodeIndex]['name'] : '',
      );
    } catch (_) {}
  }

  void _changeSource(int index) async {
    if (index == _currentSourceIndex) return;

    setState(() {
      _currentSourceIndex = index;
      final urls = _sources[index]['urls'] as List?;
      if (urls != null) {
        _episodes = urls.cast<Map<String, dynamic>>();
      }
      _currentEpisodeIndex = 0; // 重置集数
    });
    _sourceIndexNotifier.value = _currentSourceIndex;
    _episodeIndexNotifier.value = 0;
    _initPlayer();
  }

  void _changeEpisode(int index) async {
    if (index == _currentEpisodeIndex) return;
    
    setState(() {
      _currentEpisodeIndex = index;
    });
    _episodeIndexNotifier.value = index;
    _initPlayer();
  }

  void _onNextEpisode() {
    if (_currentEpisodeIndex < _episodes.length - 1) {
      _changeEpisode(_currentEpisodeIndex + 1);
    } else {
      // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已经是最后一集了')));
    }
  }

  Future<void> _loadAdverts() async {
    final api = context.read<MacApi>();
    if (!api.isDetailBannerAdOpen) return;
    try {
      final initData = await api.getAppInit(force: false);
      List<dynamic> ads = [];
      if (initData['custom_ads'] is List) ads.addAll(initData['custom_ads']);
      if (initData['advert_list'] is List) ads.addAll(initData['advert_list']);
      if (initData['ads'] is List) ads.addAll(initData['ads']);

      for (final ad in ads) {
        if (ad is! Map) continue;
        final name = (ad['name'] ?? ad['type_name'] ?? '').toString();
        final pos = (ad['position'] ?? '').toString();
        
        // Position 3: Player Below
        if (name.contains('播放器下') || pos == 'player_below' || pos == '3') {
           final list = ad['list'] ?? ad['data'];
           if (list is List && list.isNotEmpty) {
              final item = list.first;
              if (item is Map) {
                 if (mounted) {
                   setState(() {
                     _playerBelowAdvert = {
                       'id': '${item['advert_id'] ?? item['id'] ?? ''}',
                       'title': '${item['advert_name'] ?? item['name'] ?? ''}',
                       'poster': api.fixUrl('${item['advert_pic'] ?? item['pic'] ?? item['img'] ?? ''}'),
                       'url': '${item['advert_url'] ?? item['url'] ?? item['link'] ?? ''}',
                     };
                   });
                 }
              }
           }
        }
      }
    } catch (_) {}
  }

  Widget _buildAdWidget(Map<String, dynamic> ad) {
    return GestureDetector(
      onTap: () async {
        final url = (ad['url'] ?? '').toString();
        if (url.isNotEmpty) {
           if (url.startsWith('http')) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
           }
        }
      },
      child: AspectRatio(
        aspectRatio: 20 / 3, // Adjust as needed
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: ad['poster'],
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey[200]),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  /// 开发者：杰哥
  /// 作用：竖屏弹幕输入框
  void _showDanmakuInputDialog() {
    final TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发送弹幕'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '发个弹幕见证当下...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              
              final api = context.read<MacApi>();
              
              // 尝试直接通过 API 发送，BetterPlayer 暂未集成弹幕显示
              final res = await api.sendDanmaku(widget.vodId, text, time: _betterPlayerController?.videoPlayerController?.value.position.inSeconds ?? 0);
              if (res['success'] == true) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg']?.toString() ?? '弹幕发送成功')));
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg']?.toString() ?? '发送失败')));
              }
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  /// 开发者：杰哥
  /// 作用：显示美化的评论输入框 (底部弹窗)
  void _showCommentInputSheet() {
    final TextEditingController ctrl = TextEditingController();
    // 增加一个辅助变量
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('发表评论', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                minLines: 1, // 初始高度减小
                maxLines: 5,
                style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: '友善评论，理性发言...',
                  hintStyle: TextStyle(color: Theme.of(context).hintColor),
                  filled: true,
                  fillColor: isDark ? Colors.white12 : Colors.grey[200], // 更好的背景色
                  prefixIcon: null, // 移除不协调的图标
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20), // 圆角更大
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    
                    _checkLoginAndRun(() async {
                       final api = context.read<MacApi>();
                       final name = await api.getUserName();
                       final res = await api.sendComment(widget.vodId, text, name);
                       if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg']?.toString() ?? (res['success'] == true ? '评论发送成功' : '发送失败'))));
                         if (res['success'] == true) _loadComments();
                       }
                     });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('发送'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 使用主题颜色，适配亮色/深色模式
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 如果是深色模式，使用 Surface 颜色（深蓝），否则使用 Scaffold 背景色
    final bgColor = isDark ? Theme.of(context).colorScheme.surface : Theme.of(context).scaffoldBackgroundColor;
    final api = context.read<MacApi>();
    
    // 如果正在加载且没有预填充数据，显示骨架屏或Loading
    if (loading && detail['vod_name'] == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).textTheme.titleLarge?.color ?? Colors.black;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    final iconColor = isDark ? Colors.white54 : Colors.black54;
    final dividerColor = isDark ? Colors.white10 : Colors.black12;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand, // 确保 Stack 填满屏幕，使 Column 内的 Expanded 生效
        children: [
          SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                // 1. 播放器区域
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _betterPlayerController != null
                      ? BetterPlayer(controller: _betterPlayerController!)
                      : Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFF9C27B0)),
                          ),
                        ),
                ),
                
                // 2. 内容区域
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Tab栏
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: dividerColor)),
                          ),
                          child: Row(
                            children: [
                              _buildTabItem('详情', 0, primaryColor, iconColor),
                              if (api.isCommentOpen) ...[
                                const SizedBox(width: 24),
                                _buildTabItem('评论', 1, primaryColor, iconColor),
                              ],
                              const Spacer(),
                              // 竖屏弹幕发送入口
                              InkWell(
                                onTap: () {
                                   _checkLoginAndRun(() {
                                     _showDanmakuInputDialog();
                                   });
                                },
                                child: Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit, size: 14, color: subTextColor),
                                      const SizedBox(width: 6),
                                      Text('发个弹幕...', style: TextStyle(fontSize: 12, color: subTextColor)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              InkWell(
                                onTap: () => _showSkipSettingsDialog(),
                                child: Row(
                                  children: [
                                    Icon(Icons.tune, size: 16, color: subTextColor),
                                    const SizedBox(width: 4),
                                    Text('片头尾', style: TextStyle(fontSize: 12, color: subTextColor)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_tabIndex == 0) ...[
                          // 详情内容
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 视频信息区
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!api.isHideDetailPic)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: CachedNetworkImage(
                                          imageUrl: detail['vod_pic'] ?? '',
                                          width: 100,
                                          height: 140,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: cardColor),
                                          errorWidget: (_, __, ___) => Container(color: cardColor, child: Icon(Icons.broken_image, color: iconColor)),
                                        ),
                                      ),
                                    if (!api.isHideDetailPic) const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  detail['vod_name'] ?? '',
                                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => _showIntroSheet(context),
                                                child: Row(
                                                  children: [
                                                    Text('简介', style: TextStyle(fontSize: 12, color: subTextColor)),
                                                    Icon(Icons.chevron_right, size: 16, color: subTextColor),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            children: [
                                              _buildTag(detail['vod_year'], dividerColor, subTextColor),
                                              _buildTag(detail['vod_area'], dividerColor, subTextColor),
                                              _buildTag(detail['type_name'], dividerColor, subTextColor),
                                            ].whereType<Widget>().toList(),
                                          ),
                                          const SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _buildActionButton(
                                                icon: _isCollected ? Icons.favorite : Icons.favorite_border,
                                                label: '收藏',
                                                color: _isCollected ? Colors.red : subTextColor,
                                                onTap: _toggleCollect,
                                              ),
                                              _buildActionButton(
                                                icon: Icons.share_outlined,
                                                label: '分享',
                                                color: subTextColor,
                                                onTap: () {
                                                   final shareTxt = context.read<MacApi>().shareText;
                                                   Share.share(shareTxt.isNotEmpty ? shareTxt : '我在看：${detail['vod_name']}');
                                                },
                                              ),
                                              _buildActionButton(
                                                icon: Icons.download_outlined,
                                                label: '下载',
                                                color: subTextColor,
                                                onTap: _showDownloadSheet,
                                              ),
                                              _buildActionButton(
                                                icon: Icons.notifications_none,
                                                label: '催更',
                                                color: subTextColor,
                                                onTap: _onRemind,
                                              ),
                                              _buildActionButton(
                                                icon: Icons.chat_bubble_outline,
                                                label: '反馈',
                                                color: subTextColor,
                                                onTap: () {
                                                  _checkLoginAndRun(() {
                                                    Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackPage(vodId: widget.vodId, vodName: detail['vod_name'] ?? '')));
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('播放源', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                    const SizedBox(height: 12),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: List.generate(_sources.length, (i) {
                                          final isSel = i == _currentSourceIndex;
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 12),
                                            child: ActionChip(
                                              label: Text(_sources[i]['show'] ?? '默认源'),
                                              backgroundColor: isSel ? primaryColor : cardColor,
                                              labelStyle: TextStyle(color: isSel ? Colors.white : subTextColor),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              side: BorderSide.none,
                                              onPressed: () => _changeSource(i),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Text('选集', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                    const SizedBox(width: 8),
                                    if (_sources.isNotEmpty)
                                      Text(_sources[_currentSourceIndex]['show'] ?? '', style: TextStyle(fontSize: 12, color: subTextColor)),
                                    const Spacer(),
                                    InkWell(
                                      onTap: _showEpisodeSheet,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Row(
                                          children: [
                                            Text('全部 ${_episodes.length} >', style: TextStyle(fontSize: 12, color: subTextColor)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 50,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _episodes.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                                    itemBuilder: (ctx, i) => SizedBox(
                                      width: 80,
                                      child: _buildEpisodeBtn(i, primaryColor, cardColor),
                                    ),
                                  ),
                                ),
                                // Pos 3: 选集下方广告
                                if (_playerBelowAdvert != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: _buildAdWidget(_playerBelowAdvert!),
                                  ),
                                const SizedBox(height: 24),
                                if (_relatedList.isNotEmpty) ...[
                                  Text('猜你喜欢', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                  const SizedBox(height: 6),
                                  GridView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      childAspectRatio: 0.7,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                    itemCount: _relatedList.length,
                                    itemBuilder: (ctx, i) {
                                      final item = _relatedList[i];
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DetailPage(
                                            vodId: '${item['id']}',
                                            initialTitle: item['title'],
                                            initialPoster: item['poster'],
                                          )));
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: CachedNetworkImage(
                                                  imageUrl: item['poster'],
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  placeholder: (_, __) => Container(color: cardColor),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              item['title'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12, color: subTextColor),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ] else ...[
                          // 评论 Tab 内容
                          Padding(
                            padding: EdgeInsets.zero, // 修复：移除顶部间距，贴近置顶评论
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                Text('最新评论', style: TextStyle(fontSize: 14, color: subTextColor, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                InkWell(
                                  onTap: () {
                                     setState(() {
                                        // 简单倒序
                                        if (_comments.isNotEmpty) {
                                           _comments = _comments.reversed.toList();
                                        }
                                     });
                                  },
                                  child: Row(
                                    children: [
                                      Icon(Icons.sort, size: 14, color: subTextColor),
                                      const SizedBox(width: 4),
                                      Text('按时间', style: TextStyle(fontSize: 12, color: subTextColor)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                              ],
                            ),
                          ),
                          _comments.isEmpty
                              ? Container(
                                  height: 300,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.chat_bubble_outline, size: 48, color: subTextColor.withOpacity(0.5)),
                                      const SizedBox(height: 16),
                                      Text('暂无评论，快来抢沙发吧~', style: TextStyle(color: subTextColor)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: EdgeInsets.zero, // 修复：去除列表默认内边距，减少与标题的间隙
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _comments.length,
                                  itemBuilder: (ctx, i) {
                                    final c = _comments[i];
                                    final isPinned = '${c['is_pinned']}' == '1' || c['is_pinned'] == true || '${c['is_top']}' == '1';
                                    final isAd = c['is_ad'] == true;
                                    
                                    final rawAvatar = c['user_portrait'] ?? c['user_avatar'] ?? c['portrait'] ?? c['avatar'] ?? c['pic'] ?? '';
                                    final avatarUrl = _fixAvatarUrl(rawAvatar);
                                    final userName = c['user_name'] ?? c['user_nick'] ?? c['nickname'] ?? c['name'] ?? '匿名';
                                    final time = c['create_time'] ?? c['time'] ?? '';
                                    final content = c['content'] ?? '';
                                    
                                    return CommentItem(
                                      avatarUrl: avatarUrl,
                                      userName: userName,
                                      time: time,
                                      content: content,
                                      isPinned: isPinned,
                                      isAd: isAd,
                                      adData: isAd ? (c['ad_data'] as Map?)?.cast<String, dynamic>() : null,
                                    );
                                  },
                                ),
                        ],
                        
                        const SizedBox(height: 100), // 底部留白
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
            
            // 3. 底部输入框 (仅在评论 Tab 显示)
            if (_tabIndex == 1)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    // 修复：使用 bgColor 确保与页面背景一致（适配深色模式的深蓝色）
                    color: bgColor,
                    boxShadow: [
                       BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -1), blurRadius: 10),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _checkLoginAndRun(() => _showCommentInputSheet());
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16, color: subTextColor),
                                  const SizedBox(width: 8),
                                  Text('说点什么...', style: TextStyle(fontSize: 14, color: subTextColor)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // 构建选集按钮
  Widget _buildEpisodeBtn(int i, Color primary, Color card) {
    final isSel = i == _currentEpisodeIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white70 : Colors.black87; // 修复：浅色模式下使用深色文字
    
    return ElevatedButton(
      onPressed: () => _changeEpisode(i),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSel ? primary : card,
        foregroundColor: isSel ? Colors.white : defaultColor,
        padding: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        _episodes[i]['name'],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  // 辅助方法：构建 Tab 项
  Widget _buildTabItem(String label, int index, Color primary, Color defaultColor) {
    final isSel = _tabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _tabIndex = index);
        if (index == 1 && _comments.isEmpty) _loadComments();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              color: isSel ? primary : defaultColor,
            ),
          ),
          if (isSel)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  // 辅助方法：构建标签
  Widget? _buildTag(String? text, Color bgColor, Color textColor) {
    if (text == null || text.isEmpty) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: textColor)),
    );
  }

  // 辅助方法：构建功能按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 24, color: color ?? Colors.grey),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color ?? Colors.grey)),
        ],
      ),
    );
  }
  
  // 辅助方法：显示跳过设置弹窗
  void _showSkipSettingsDialog() {
    final bgColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateInner) {
          final s = _playerSettings;
          return Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('跳过设置', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                    Switch(
                      value: s.enableSkip,
                      onChanged: (val) {
                         setStateInner(() => s.setEnableSkip(val));
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    )
                  ],
                ),
                const SizedBox(height: 20),
                _buildSkipSlider(setStateInner, '片头', s.skipIntro, (v) => s.setSkipIntro(v), textColor),
                const SizedBox(height: 20),
                _buildSkipSlider(setStateInner, '片尾', s.skipOutro, (v) => s.setSkipOutro(v), textColor),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkipSlider(StateSetter setStateInner, String label, int value, Function(int) onChanged, Color textColor) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: textColor.withOpacity(0.7))),
        const SizedBox(width: 12),
        Text('${value}s', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0, max: 300,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (v) {
              setStateInner(() => onChanged(v.toInt()));
            },
          ),
        ),
      ],
    );
  }

  // 辅助方法：显示简介弹窗
  void _showIntroSheet(BuildContext context) {
    final bgColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // 顶部标题和关闭按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          detail['vod_name'] ?? '',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: subTextColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: subTextColor.withOpacity(0.1)),
                // 内容区域
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 详细信息字段
                      _buildIntroRow('导演', detail['vod_director'], textColor, subTextColor),
                      _buildIntroRow('主演', detail['vod_actor'], textColor, subTextColor),
                      _buildIntroRow('类型', detail['type_name'], textColor, subTextColor),
                      _buildIntroRow('地区', detail['vod_area'], textColor, subTextColor),
                      _buildIntroRow('年代', detail['vod_year'], textColor, subTextColor),
                      const SizedBox(height: 24),
                      // 简介正文
                      Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 12),
                      HtmlWidget(
                        detail['vod_content'] ?? '暂无简介',
                        textStyle: TextStyle(color: textColor.withOpacity(0.8), height: 1.5, fontSize: 14),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntroRow(String label, String? value, Color textColor, Color subTextColor) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label：', style: TextStyle(color: subTextColor, fontSize: 14)),
          Expanded(
            child: Text(value, style: TextStyle(color: textColor, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // 辅助方法：显示切换线路弹窗
  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('切换线路', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(_sources.length, (i) {
                final isSel = i == _currentSourceIndex;
                final primaryColor = Theme.of(context).colorScheme.primary;
                return ChoiceChip(
                  label: Text(_sources[i]['show'] ?? '默认源'),
                  selected: isSel,
                  selectedColor: primaryColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSel ? primaryColor : null,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _changeSource(i);
                      Navigator.pop(context);
                    }
                  },
                );
              }),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 辅助方法：显示选集弹窗
  void _showEpisodeSheet() {
    final bgColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateSheet) {
              return Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text('选集 (${_episodes.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                          const Spacer(),
                          // 排序按钮
                          InkWell(
                            onTap: () {
                              setStateSheet(() {
                                _isEpisodeAscending = !_isEpisodeAscending;
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(_isEpisodeAscending ? Icons.arrow_downward : Icons.arrow_upward, size: 16, color: subTextColor),
                                  const SizedBox(width: 4),
                                  Text(_isEpisodeAscending ? '正序' : '倒序', style: TextStyle(fontSize: 14, color: subTextColor)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.close, color: subTextColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: subTextColor.withOpacity(0.1)),
                    // Grid
                    Expanded(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _episodeIndexNotifier,
                        builder: (ctx, currentIdx, _) {
                          return GridView.builder(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 2.0,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                            itemCount: _episodes.length,
                            itemBuilder: (ctx, i) {
                              // 计算实际索引
                              final actualIndex = _isEpisodeAscending ? i : _episodes.length - 1 - i;
                              
                              final isSel = actualIndex == currentIdx;
                              final isDark = Theme.of(context).brightness == Brightness.dark;
                              final defaultColor = isDark ? Colors.white70 : Colors.black87;
                              
                              return ElevatedButton(
                                onPressed: () {
                                  _changeEpisode(actualIndex);
                                  Navigator.pop(context); // 选中后关闭弹窗
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSel ? primaryColor : Theme.of(context).scaffoldBackgroundColor,
                                  foregroundColor: isSel ? Colors.white : defaultColor,
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                  side: BorderSide(color: isSel ? Colors.transparent : subTextColor.withOpacity(0.2)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  _episodes[actualIndex]['name'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 开始下载任务
  void _showDownloadSheet() {
    final bgColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (_, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('视频下载', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      TextButton(
                        onPressed: () {
                           Navigator.pop(context);
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadPage()));
                        },
                        child: Text('查看缓存', style: TextStyle(color: subTextColor)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1.5,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: _episodes.length,
                    itemBuilder: (ctx, i) {
                      return InkWell(
                        onTap: () {
                          // 开始下载
                          _startDownload(_episodes[i], i);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: subTextColor.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 14, color: subTextColor),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _episodes[i]['name'], 
                                  style: TextStyle(fontSize: 12, color: textColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 开始下载任务
  Future<void> _startDownload(Map<String, dynamic> ep, int index) async {
    String url = ep['url'] ?? '';
    final name = ep['name'] ?? '';
    if (url.isEmpty) return;
    
    // 如果需要解析
    final parseApi = ep['parse_api'] ?? '';
    if (parseApi.isNotEmpty) {
      try {
        final api = context.read<MacApi>();
        url = await api.resolvePlayUrl(url, parseApi: parseApi);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('解析下载地址失败: $e')));
        return;
      }
    }

    // 构造唯一ID
    final taskId = '${widget.vodId}_$index';
    
    final title = detail['vod_name'] ?? '';
    final poster = detail['vod_pic'] ?? '';
    final fullTitle = '$title - $name';
    final ts = DateTime.now().millisecondsSinceEpoch;
    
    // 1. 初始化任务状态
    await StoreService.upsertDownload({
      'id': taskId,
      'title': fullTitle,
      'poster': poster,
      'url': url,
      'savePath': '',
      'progress': 0.0,
      'status': 'downloading',
      'speed': '0KB/s',
      'ts': ts,
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已加入下载队列: $name'),
        action: SnackBarAction(
          label: '查看缓存',
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadPage()));
          },
        ),
      ));
      Navigator.pop(context); // 关闭弹窗
    }

    // 2. 启动下载 (不 await，让其后台运行)
    try {
      M3u8DownloaderService().download(
        url: url,
        fileName: '${widget.vodId}_$index', // 使用ID作为文件名，避免特殊字符问题
        onProgress: (progress, statusText) {
          // 更新进度
          StoreService.upsertDownload({
            'id': taskId,
            'title': fullTitle,
            'poster': poster,
            'url': url,
            'savePath': '', // 还没下载完
            'progress': progress,
            'status': 'downloading',
            'speed': statusText, // 复用 speed 字段显示状态文本
            'ts': ts,
          });
        },
      ).then((savePath) {
        // 开发者：杰哥
        // 修复：如果 savePath 为空，说明被取消或失败，不应标记为完成
        if (savePath.isEmpty) return;
  
        // 下载完成
        StoreService.upsertDownload({
          'id': taskId,
          'title': fullTitle,
          'poster': poster,
          'url': url,
          'savePath': savePath,
          'progress': 1.0,
          'status': 'done',
          'speed': '已完成',
          'ts': ts,
        });
        // 写入本地缓存记录
        StoreService.addCache({
          'id': taskId, 
          'title': fullTitle,
          'poster': poster,
          'url': savePath,
        });
      }).catchError((e) {
        // 下载失败
        StoreService.upsertDownload({
          'id': taskId,
          'title': fullTitle,
          'poster': poster,
          'url': url,
          'savePath': '',
          'progress': 0.0,
          'status': 'failed',
          'speed': '失败: $e',
          'ts': ts,
        });
      });
    } catch (e) {
       // 防止同步错误
       print('Start download error: $e');
    }
  }
}
