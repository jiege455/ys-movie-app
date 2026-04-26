// by：杰哥 
// qq： 2711793818
// 修复历史记录刷新问题

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/store.dart';
import '../services/api.dart';
import '../services/theme_provider.dart';
import 'detail_page.dart';
import 'vod_list_page.dart';
import 'history_page.dart';
import 'feedback_center_page.dart';
import 'auth_bottom_sheet.dart';
import 'download_page.dart';
import 'user_center_pages.dart';
import 'find_page.dart';
import 'settings_page.dart';
import '../services/cache_service.dart';

/**
 * 开发者：杰哥
 * 作用：我的页面，个人中心，上面是头像积分，中间是历史记录，下面是常用功能。
 * 小白解释：个人中心，上面是头像积分，中间是历史记录，下面是常用功能。
 */
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  // 本地数据
  List<String> favs = [];
  List<String> hist = [];
  
  // 云端数据
  List<Map<String, dynamic>> cloudFavs = [];
  List<Map<String, dynamic>> cloudHist = [];

  bool loading = true;
  bool isLoggedIn = false;
  Map<String, dynamic>? userInfo; // 用户信息缓存
  String _versionLabel = 'V1.0.0';
  bool _checkingUpdate = false;
  bool _hideVersion = false;
  bool _hideMineBg = false;
  int _noticeCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVersionLabel();
      _loadPageSetting();
      _checkLogin();
    });
  }

  // 添加 RouteAware 监听不太方便，直接在 build 中依赖状态，或者在 push 返回时 await

  Future<void> _loadPageSetting() async {
    try {
      final api = context.read<MacApi>();
      final initData = await api.getAppInit();
      final rawPageSetting = initData['app_page_setting'];
      if (rawPageSetting is! Map) return;
      final inner = (rawPageSetting['app_page_setting'] is Map)
          ? (rawPageSetting['app_page_setting'] as Map)
          : rawPageSetting;

      final hideVersionRaw = inner['app_page_version_hide'];
      final hideMineBgRaw = inner['app_page_mine_bg_hide'];

      final hideVersion = (hideVersionRaw is bool)
          ? hideVersionRaw
          : (int.tryParse('${hideVersionRaw ?? 0}') ?? 0) == 1;
      final hideMineBg = (hideMineBgRaw is bool)
          ? hideMineBgRaw
          : (int.tryParse('${hideMineBgRaw ?? 0}') ?? 0) == 1;
      final noticeCount = int.tryParse('${initData['notice_count'] ?? 0}') ?? 0;

      if (!mounted) return;
      setState(() {
        _hideVersion = hideVersion;
        _hideMineBg = hideMineBg;
        _noticeCount = noticeCount;
      });
    } catch (_) {}
  }

  /// 开发者：杰哥
  /// 作用：读取 App 版本号并显示在“我的”页底部
  /// 小白解释：方便你看当前装的是哪个版本，升级后也能确认是否生效。
  Future<void> _loadVersionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        final build = info.buildNumber.trim();
        _versionLabel = build.isEmpty ? 'V${info.version}' : 'V${info.version}+$build';
      });
    } catch (_) {}
  }

  /// 开发者：杰哥
  /// 作用：检查版本更新并提示下载
  /// 小白解释：去后台问一下有没有新版本，有就弹窗告诉你下载地址。
  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final api = context.read<MacApi>();
      final update = await api.getAppUpdate();
      if (!mounted) return;
      Navigator.of(context).pop();

      if (update == null || (update['version_name'] ?? '').toString().isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('当前已是最新版本')));
        return;
      }

      final versionName = (update['version_name'] ?? '').toString();
      final desc = (update['description'] ?? '').toString().trim();
      final size = (update['app_size'] ?? '').toString().trim();
      final isForce = update['is_force'] == true;
      final url = ((update['browser_download_url'] ?? '').toString().trim().isNotEmpty)
          ? (update['browser_download_url'] ?? '').toString().trim()
          : (update['download_url'] ?? '').toString().trim();

      await showDialog(
        context: context,
        barrierDismissible: !isForce,
        builder: (_) {
          return AlertDialog(
            title: Text('发现新版本 $versionName'),
            content: SingleChildScrollView(
              child: Text([
                if (size.isNotEmpty) '大小：$size MB',
                if (desc.isNotEmpty) '更新内容：\n$desc',
                if (url.isNotEmpty) '\n下载地址：\n$url',
              ].join('\n')),
            ),
            actions: [
              if (!isForce)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              TextButton(
                onPressed: () async {
                  if (url.isEmpty) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('后台未配置下载地址')),
                    );
                    return;
                  }

                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (ok) {
                      if (context.mounted) Navigator.of(context).pop();
                      return;
                    }
                  }

                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制下载链接，请用浏览器打开')),
                    );
                  }
                },
                child: const Text('立即更新'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('检查升级失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  /// 检查登录状态并加载数据
  Future<void> _checkLogin() async {
    setState(() => loading = true);
    try {
      final api = context.read<MacApi>();
      isLoggedIn = await api.checkLogin();
      await _loadData();
    } catch (e) {
      isLoggedIn = false;
      await _loadData();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// 公开的刷新方法，供外部（如 MainPage）调用
  Future<void> refresh() async {
    // 刷新时顺便检查一下登录状态，确保同步
    try {
      final api = context.read<MacApi>();
      isLoggedIn = await api.checkLogin();
    } catch (_) {}
    
    await _loadData();
    if (mounted) setState(() {});
  }

  /// 开发者：杰哥
  /// 作用：加载我的页所需的数据（优先本地，其次云端）
  /// 小白解释：先把本地的收藏和历史读出来，如果你登录了再去试一下服务器那边。
  Future<void> _loadData() async {
    // 本地数据始终加载，保证即便云端失败功能也可用
    favs = await StoreService.getFavorites();
    hist = await StoreService.getHistory();

    // 登录状态下再尝试云端接口，失败时自动降级到本地
    if (isLoggedIn) {
      try {
        final api = context.read<MacApi>();
        cloudFavs = await api.getFavs();
        cloudHist = await api.getHistory();
        
        // 获取完整的用户信息（包括积分、会员状态等）
        final mineInfo = await api.getMineInfo();
        if (mineInfo != null) {
          userInfo = {
            'name': mineInfo['user_name'] ?? '用户',
            'group': mineInfo['group_name'] ?? '普通会员',
            'points': mineInfo['user_points'] ?? 0,
            'is_vip': mineInfo['is_vip'] ?? false,
            'user_portrait': mineInfo['user_portrait'],
          };
          // 更新未读消息数量
          if (mounted) {
            setState(() {
              _noticeCount = mineInfo['user_notice_unread_count'] ?? 0;
            });
          }
        } else {
          // 降级：只获取用户名
          final name = await api.getUserName();
          userInfo = {'name': name, 'group': '普通会员', 'points': 0, 'is_vip': false};
        }
      } catch (e) {
        print('加载云端数据失败: $e');
        // 降级：只获取用户名
        try {
          final api = context.read<MacApi>();
          final name = await api.getUserName();
          userInfo = {'name': name, 'group': '普通会员', 'points': 0, 'is_vip': false};
        } catch (_) {
          userInfo = {'name': '用户', 'group': '普通会员', 'points': 0, 'is_vip': false};
        }
      }
    }
  }

  void _showLoginDialog() {
    showAuthBottomSheet(
      context,
      onLoginSuccess: () {
        // 登录成功后刷新页面状态
        _checkLogin();
      },
    );
  }

  Future<void> _switchTheme() async {
    final themeProvider = context.read<ThemeProvider>();
    await showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('选择主题'),
        backgroundColor: Theme.of(context).cardColor, // 修复：使用卡片颜色作为背景，适配深色模式
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              themeProvider.setThemeStyle('light');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已切换为粉白')));
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('粉白'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              themeProvider.setThemeStyle('blue_black');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已切换为蓝黑')));
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('蓝黑'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    setState(() => loading = true);
    // 实际清理
    await CacheService.clearCache();
    
    await Future.delayed(const Duration(milliseconds: 500)); // 稍微展示一下清理过程
    
    if (mounted) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清理')));
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 整理历史数据列表：优先云端历史（若有），否则使用本地
    final historyList = (isLoggedIn && cloudHist.isNotEmpty)
        ? cloudHist.map((v) {
            return {
              'id': v['id']?.toString() ?? '',
              'title': v['title'] ?? '',
              'poster': v['poster'] ?? '',
              'progress': '',
              'progressVal': 0.0,
            };
          }).toList()
        : hist.map((e) {
      final parts = e.split('|');
      String progress = '';
      double progressVal = 0.0;
      
      if (parts.length > 4) {
         try {
           final dt = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[4]));
           progress = '${dt.month}月${dt.day}日 ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
         } catch (_) {}
      }
      
      if (parts.length > 5) {
        try {
          final sec = int.parse(parts[5]);
          if (sec > 0) {
             progress = '观看至 ${_formatDuration(Duration(seconds: sec))}';
             progressVal = 0.5; // 既然有进度，就给个模拟进度条显示
          }
        } catch (_) {}
      }
      
      return {
        'id': parts[0],
        'title': parts.length > 1 ? parts[1] : '',
        'poster': parts.length > 2 ? parts[2] : '',
        'url': parts.length > 3 ? parts[3] : '',
        'progress': progress, 
        'progressVal': progressVal,
      };
    }).toList();

    return Scaffold(
      // backgroundColor: const Color(0xFFF5F5F5), // Removed hardcoded color
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 顶部头部
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 30, left: 24, right: 24),
              decoration: _hideMineBg
                  ? BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor)
                  : BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark 
                            ? [const Color(0xFF1565C0).withOpacity(0.5), const Color(0xFF0B1724)]
                            : [Theme.of(context).colorScheme.primary.withOpacity(0.2), Theme.of(context).colorScheme.primary.withOpacity(0.05), Colors.white],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
              child: Column(
                children: [
                  // 顶部用户信息区域（包含设置按钮）
                  Row(
                    children: [
                      // 头像
                      GestureDetector(
                        onTap: isLoggedIn ? null : _showLoginDialog,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary, // 统一使用主题色（粉色）
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.1).round()), blurRadius: 10)],
                            // 修复：使用 DecorationImage 确保图片完美填充圆形，避免歪斜
                            image: isLoggedIn && userInfo?['user_portrait'] != null
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(userInfo!['user_portrait']),
                                    fit: BoxFit.cover,
                                  )
                                : const DecorationImage(
                                    image: AssetImage('assets/images/logo.png'),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          alignment: Alignment.center,
                          child: null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 用户名与VIP
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: isLoggedIn ? null : _showLoginDialog,
                              child: Text(
                                isLoggedIn ? (userInfo?['name'] ?? '用户') : '点击登录',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Removed hardcoded color
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (isLoggedIn)
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VipPage())),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(4)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        userInfo?['is_vip'] == true 
                                          ? (userInfo?['group'] ?? 'VIP会员')
                                          : (userInfo?['group'] ?? '普通会员'),
                                        style: TextStyle(
                                          fontSize: 10, 
                                          color: userInfo?['is_vip'] == true ? Colors.amber[700] : (isDark ? Colors.white70 : Colors.black54),
                                          fontWeight: userInfo?['is_vip'] == true ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      Icon(Icons.arrow_forward_ios, size: 8, color: isDark ? Colors.white70 : Colors.black54),
                                    ],
                                  ),
                                ),
                              )
                            else
                              const Text('登录同步云端数据', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      // 设置按钮（放回这里，与登录信息并列）
                      IconButton(
                        icon: const Icon(Icons.settings), // Removed hardcoded color
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 统计数据
                  Row(
                    children: [
                      _buildStatItem('0', '邀请', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvitePage()))),
                      const SizedBox(width: 24),
                      _buildStatItem(isLoggedIn ? '${userInfo?['points'] ?? 0}' : '0', '积分', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PointsPage()))),
                    ],
                  ),
                ],
              ),
            ),
            
            // 主体内容
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // 登录卡片 (已移除，改用点击头像弹窗登录)
                    // if (!isLoggedIn) ...

                    // 观看历史卡片（整体缩小一点）
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage()));
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('观看历史', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Row(
                                  children: const [
                                    Text('全部', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (historyList.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: Text('暂无观看历史', style: TextStyle(color: Colors.grey))),
                            )
                          else
                            SizedBox(
                              height: 110, // 缩略图高度（缩小）
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: historyList.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (ctx, i) {
                                  final item = historyList[i];
                                  return GestureDetector(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vodId: item['id']))).then((_) => refresh()),
                                    child: SizedBox(
                                      width: 120, // 卡片宽度缩小
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  CachedNetworkImage(
                                                    imageUrl: item['poster'],
                                                    fit: BoxFit.cover,
                                                    placeholder: (_, __) => Container(color: Colors.grey[200]),
                                                    errorWidget: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                                                  ),
                                                  // 进度条
                                                  if ((item['progressVal'] as double? ?? 0) > 0)
                                                    Positioned(
                                                      bottom: 0, left: 0, right: 0,
                                                      child: LinearProgressIndicator(
                                                        value: item['progressVal'] as double? ?? 0,
                                                        backgroundColor: Colors.white30,
                                                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                                                        minHeight: 2,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item['title'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            item['progress'] ?? '继续观看',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 功能网格卡片
                    Container(
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10), // 减少水平内边距
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        mainAxisSpacing: 10, // 减小间距
                        crossAxisSpacing: 10, // 减小间距
                        childAspectRatio: 0.9, // 调整比例，让内容更紧凑
                        children: [
                          _buildGridIcon(Icons.favorite_border, '我的收藏', onTap: () async {
                             // 如果是本地，从 Store 获取；如果是云端，从 API 获取
                             List<Map<String, dynamic>> items = [];
                             if (isLoggedIn) {
                                items = cloudFavs;
                             } else {
                                final favStrings = await StoreService.getFavorites();
                                items = favStrings.map((e) {
                                  final parts = e.split('|');
                                  return {
                                    'id': parts[0],
                                    'title': parts.length > 1 ? parts[1] : '',
                                    'poster': parts.length > 2 ? parts[2] : '',
                                  };
                                }).toList();
                             }
                             if (!mounted) return;
                             Navigator.push(context, MaterialPageRoute(builder: (_) => VodListPage(title: '我的收藏', items: items)));
                          }),
                          _buildGridIcon(Icons.download_outlined, '我的缓存', onTap: () async {
                             // 读取缓存列表
                             final cacheStrings = await StoreService.getCache();
                             final cachedList = cacheStrings.map((e) {
                                final parts = e.split('|');
                                if (parts.length < 3) return null;
                                return {
                                  'id': parts[0],
                                  'title': parts[1],
                                  'poster': parts[2],
                                  'url': parts.length > 3 ? parts[3] : '',
                                  'progress': '已缓存',
                                };
                             }).whereType<Map<String, dynamic>>().toList();
                             
                             if (!mounted) return;
                             Navigator.push(context, MaterialPageRoute(builder: (_) => VodListPage(title: '我的缓存', items: cachedList)));
                          }),
                          _buildGridIcon(Icons.downloading_rounded, '下载管理', onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadPage()));
                          }),
                          _buildGridIcon(Icons.search, '求片找片', onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const FindPage())).then((_) => refresh());
                          }),
                          _buildGridIcon(Icons.feedback_outlined, '反馈报错', onTap: () {
                             if (isLoggedIn) {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackPage()));
                             } else {
                               _showLoginDialog();
                             }
                          }),
                          Stack(
                            alignment: Alignment.center, // 确保 Stack 居中
                            children: [
                              Positioned.fill( // 填充整个格子
                                child: _buildGridIcon(Icons.notifications_none, '消息中心', onTap: () {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageCenterPage()));
                                }),
                              ),
                              if (_noticeCount > 0)
                                Positioned(
                                  top: 5, // 微调红点位置
                                  right: 20,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '$_noticeCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          _buildGridIcon(Icons.color_lens_outlined, '主题换肤', onTap: _switchTheme),
                          _buildGridIcon(Icons.share_outlined, '分享好友', onTap: () {
                             // 简单复制链接
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分享链接已复制')));
                          }),
                          _buildGridIcon(Icons.system_update_alt, '检查升级', onTap: _checkUpdate),
                          _buildGridIcon(Icons.cleaning_services_outlined, '清理缓存', onTap: _clearCache),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    if (!_hideVersion)
                      Text('$_versionLabel @ 杰哥影视', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Removed hardcoded color
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildGridIcon(IconData icon, String label, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('功能开发中'))),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: isDark ? Colors.white70 : Colors.black87),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
