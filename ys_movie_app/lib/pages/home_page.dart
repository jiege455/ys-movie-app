/// 文件名：home_page.dart
/// 作者：杰哥（by：杰哥 / qq：2711793818）
/// 创建日期：2025-12-16
/// 作用：首页（顶部分类菜单 + 推荐/分类列表）
/// 解释：你打开 App 第一眼看到的页面，顶部能切分类，下面是内容。
// by：杰哥 
// qq： 2711793818
// 修复首页分类显示问题

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:async';
import '../services/api.dart';
import '../services/store.dart';
import '../config.dart';
import 'search_page.dart';
import 'detail_page.dart';
import 'history_page.dart';
import 'feedback_center_page.dart';
import 'ranking_page.dart';
import 'topic_page.dart';
import 'week_page.dart';
import 'find_link_page.dart';
import 'download_page.dart';

enum LoadStatus { loading, success, failure }

/**
 * 开发者：杰哥
 * 作用：首页（重构版），使用 TabBarView + KeepAlive 实现页面缓存，避免重复加载
 * 解释：现在切换分类不会重新加载了，而且加载更流畅。
 */
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabCtrl;
  List<String> _tabs = ['推荐'];

  // 对应分类ID（会在启动时从接口动态校验并更新）
  Map<String, dynamic> _tabIds = {
    '推荐': 0,
  };

  LoadStatus _menuStatus = LoadStatus.loading;
  
  final Map<int, LoadStatus> _tabLoadStatus = {};
  final Map<int, double> _tabLoadProgress = {};
  bool _topNoticeChecked = false;
  String _searchHint = '搜索名称 简介';
  double _homeTypeFontSize = 17;
  bool _showHomepageTypeIndicator = true;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    final shouldDefer = phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.transientCallbacks || phase == SchedulerPhase.midFrameMicrotasks;
    if (shouldDefer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(fn);
      });
      return;
    }
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 检查是否从启动页跳转且已加载过数据
      final args = ModalRoute.of(context)?.settings.arguments;
      final fromSplash = args is Map && args['fromSplash'] == true;
      
      _loadTabsFromCache().then((_) {
        // 如果是首次启动（从 Splash 来），且 API 缓存中已有数据（Splash 已请求过），
        // 则直接使用缓存数据更新 UI，避免二次加载
        if (fromSplash) {
           final api = context.read<MacApi>();
           // 这里的 false 表示不强制刷新，直接拿内存/磁盘缓存
           api.getAppInit(force: false).then((data) {
              if (data.isNotEmpty) {
                 _updateTabsFromData(data);
              } else {
                 _loadTabsFromServer();
              }
           });
        } else {
           _loadTabsFromServer();
        }
      });
    });
  }

  void _updateTabsFromData(Map<String, dynamic> data) {
    if (!mounted) return;
    
    // 更新 Tabs
    final typeList = data['type_list'] as List? ?? [];
    if (typeList.isNotEmpty) {
       final newTabs = ['推荐'];
       final newIds = <String, dynamic>{'推荐': 0};
       
       for (var item in typeList) {
          final name = item['type_name'].toString();
          final id = item['type_id'];
          if (!newTabs.contains(name)) {
             newTabs.add(name);
             newIds[name] = id;
          }
       }
       
       _safeSetState(() {
          _tabs = newTabs;
          _tabIds = newIds;
          _tabCtrl = TabController(length: _tabs.length, vsync: this);
          _tabCtrl.addListener(_onTabChanged);
          _menuStatus = LoadStatus.success;
       });
       
       // 更新其他配置（如搜索提示、字体大小等）
       if (data['app_page_setting'] != null) {
          final setting = data['app_page_setting'];
          _safeSetState(() {
             _searchHint = setting['search_hot_text'] ?? '搜索名称 简介';
             _homeTypeFontSize = double.tryParse('${setting['app_home_type_font_size'] ?? 17}') ?? 17;
             _showHomepageTypeIndicator = setting['app_show_homepage_type_indicator'] == 1;
          });
       }
    }
  }

  Future<void> _loadTabsFromCache() async {
    try {
      final cache = await StoreService.getHomeTabsCache();
      if (cache != null && mounted) {
        final cachedTabs = (cache['tabs'] as List).cast<String>();
        final cachedIds = cache['tabIds'] as Map<String, dynamic>;
        
        if (cachedTabs.isNotEmpty) {
           _safeSetState(() {
             _tabs = cachedTabs;
             _tabIds = cachedIds;
             _tabCtrl = TabController(length: _tabs.length, vsync: this);
             _tabCtrl.addListener(_onTabChanged);
             _menuStatus = LoadStatus.success;
           });
        }
      }
    } catch (_) {}
  }

  /// 开发者：杰哥
  /// 作用：Tab 切换时刷新顶部加载状态展示
  /// 解释：你点了“电视剧/电影”等分类时，这里会切换到对应的加载状态。
  void _onTabChanged() {
    if (!_tabCtrl.indexIsChanging && mounted) {
      _safeSetState(() {});
    }
  }

  /// 开发者：杰哥
  /// 作用：从接口读取分类列表
  /// 解释：强制请求后台动态分类，不使用任何本地缓存，确保数据一致性。
  Future<void> _loadTabsFromServer({int retryCount = 0}) async {
    final api = context.read<MacApi>();
    if (!mounted) return;
    bool? appTabTopicEnabled;
    
    // 仅在首次加载且无缓存时显示loading
    if (retryCount == 0 && _tabs.length <= 1) {
      _safeSetState(() {
        _menuStatus = LoadStatus.loading;
      });
    }

    try {
      // 2. 核心：优先使用 APP 初始化接口获取分类（支持隐藏分类）
      print('Home Tabs: Requesting App Init for Type List...');
      List<Map<String, dynamic>> finalTypeList = [];
      
      try {
         final initData = await api.getAppInit(force: false);
         // 开发者：杰哥
         // 修复：处理 API 返回的 closed 状态，防止初始化失败
         // 注意：即使 initData 为空，也可能是因为 API 失败但我们有 getPluginTypeList 兜底
         
         // 解析页面配置
         // ... (保留配置解析逻辑)
         WidgetsBinding.instance.addPostFrameCallback((_) async {
           final rawNotice = initData['notice'];
           if (rawNotice != null) {
             _maybeShowTopNotice(rawNotice);
           } else {
             try {
               final api2 = context.read<MacApi>();
               final list = await api2.getNoticeList(page: 1);
               if (list.isNotEmpty) {
                 _maybeShowTopNotice(list.first);
               }
             } catch (_) {}
           }
            // 版本更新：进入首页后立即检查
            final rawUpdate = initData['update'];
            if (rawUpdate != null) {
              await _maybeShowUpdate(rawUpdate);
            } else {
              try {
                final api2 = context.read<MacApi>();
                final upd = await api2.getAppUpdate();
                if (upd != null) {
                  await _maybeShowUpdate(upd);
                }
              } catch (_) {}
            }
         });
         final rawPageSetting = initData['app_page_setting'];
         
         // 优先尝试 app_tab_setting_list (自定义Tab，包含Rank/Week/Topic)
         List tabList = const [];
         if (rawPageSetting is Map && rawPageSetting['app_tab_setting_list'] is List) {
            tabList = (rawPageSetting['app_tab_setting_list'] as List);
         } else {
            final inner = (rawPageSetting is Map && rawPageSetting['app_page_setting'] is List)
                ? (rawPageSetting['app_page_setting'] as List)
                : (initData['app_tab_setting_list'] is List ? (initData['app_tab_setting_list'] as List) : const []);
            tabList = inner;
         }
         // 读取专题开关（若明确为0，则不进行后续自动补充）
         if (rawPageSetting is Map) {
            final inner = (rawPageSetting['app_page_setting'] is Map)
                ? (rawPageSetting['app_page_setting'] as Map)
                : rawPageSetting;
            final topicSwitch = inner['app_tab_topic'];
            if (topicSwitch != null) {
              appTabTopicEnabled = (topicSwitch is bool)
                  ? topicSwitch
                  : (int.tryParse('$topicSwitch') ?? 0) == 1;
            }
         }
         if (tabList.isNotEmpty) {
            finalTypeList = tabList
                .whereType<Map>()
                .map((e) {
                  // 兼容插件返回的 type 数值：0=rank,1=week,2=find,3=topic
                  String type;
                  final rawType = e['type'];
                  if (rawType is int) {
                    switch (rawType) {
                      case 0: type = 'rank'; break;
                      case 1: type = 'week'; break;
                      case 2: type = 'find'; break;
                      case 3: type = 'topic'; break;
                      default: type = '$rawType';
                    }
                  } else {
                    type = (rawType ?? '').toString().trim();
                    if (type == '0') type = 'rank';
                    else if (type == '1') type = 'week';
                    else if (type == '2') type = 'find';
                    else if (type == '3') type = 'topic';
                  }
                  final name = (e['name'] ?? e['type_name'] ?? '').toString().trim();
                  if (type.isEmpty && name.isEmpty) return null;
                  if (type == 'find') {
                    final url = (e['url'] ?? '').toString();
                    return {'type_id': url.isNotEmpty ? 'find|$url' : 'find', 'type_name': name.isNotEmpty ? name : '发现'};
                  }
                  if (type == 'rank' || type == 'week' || type == 'topic') {
                    return {'type_id': type, 'type_name': name.isNotEmpty ? name : (type == 'rank' ? '排行' : type == 'week' ? '排期' : '专题')};
                  }
                  // 非特殊页，忽略由此接口返回的纯分类ID（保持后续 type_list 合并）
                  return null;
                })
                .whereType<Map<String, dynamic>>()
                .toList();
         }

         if (rawPageSetting is Map) {
            final inner = (rawPageSetting['app_page_setting'] is Map)
                ? (rawPageSetting['app_page_setting'] as Map)
                : rawPageSetting;
            final hint = (rawPageSetting['search_vod_rule'] ?? inner['search_vod_rule'])?.toString().trim();
            final showIndicatorRaw = inner['app_page_homepage_indicator'];
            final typeSizeRaw = inner['app_page_homepage_type_size'];
            final showIndicator = (showIndicatorRaw is bool)
                ? showIndicatorRaw
                : (int.tryParse('${showIndicatorRaw ?? 0}') ?? 0) == 1;
            final typeSizeVal = double.tryParse('${typeSizeRaw ?? ''}');
            
            // 开发者：杰哥
            // 修复：读取首页Banner切换时长设置
            final bannerTimeRaw = inner['app_page_homepage_banner_time'] ?? inner['app_page_banner_time'];
            final bannerTime = int.tryParse('${bannerTimeRaw ?? 10}') ?? 10;
            
            _safeSetState(() {
              if (hint != null && hint.isNotEmpty) _searchHint = hint;
              _showHomepageTypeIndicator = showIndicator;
              if (typeSizeVal != null && typeSizeVal >= 10 && typeSizeVal <= 30) {
                _homeTypeFontSize = typeSizeVal;
              }
            });
            
            // 将 bannerTime 传递给 HomeRecommendTab (通过 key 或者 全局状态，或者在 HomeRecommendTab 内部重新读取)
            // 由于 HomeRecommendTab 是独立 State，最好在 build 时传入
            // 这里暂存到 StoreService 或者 update widget?
            // 简单起见，我们在 HomeRecommendTab 内部 _loadData 时再次读取这个值。
         }

         final typeList = (initData['type_list'] as List?) ?? [];
         if (typeList.isNotEmpty) {
            // 调试输出：统计启用与总分类数量
            try {
              int total = typeList.length;
              int enabledCount = 0;
              for (final e in typeList.whereType<Map>()) {
                final enabledRaw = e['enabled'] ?? e['is_enabled'] ?? e['status'] ?? e['type_status'] ?? e['is_open'];
                final bool enabled = enabledRaw == null
                    ? true
                    : (enabledRaw is bool ? enabledRaw : (int.tryParse('$enabledRaw') ?? 0) == 1);
                if (enabled) enabledCount++;
              }
              print('Home Tabs: type_list total=$total, enabled=$enabledCount');
            } catch (_) {}
            finalTypeList = typeList
              .whereType<Map>()
              .where((e) {
                final enabledRaw = e['enabled'] ?? e['is_enabled'] ?? e['status'] ?? e['type_status'] ?? e['is_open'];
                if (enabledRaw == null) return true; // 无字段则默认显示
                if (enabledRaw is bool) return enabledRaw;
                return (int.tryParse('$enabledRaw') ?? 0) == 1;
              })
              .map((e) => {
                'type_id': e['type_id'],
                'type_name': e['type_name']
              })
              .toList();
          
          // 开发者：杰哥
          // 作用：按照指定顺序排序分类 (电视剧 > 电影 > 动漫 > 综艺 > 短剧)
          finalTypeList.sort((a, b) {
            final nameA = (a['type_name'] ?? '').toString().trim();
            final nameB = (b['type_name'] ?? '').toString().trim();
            final order = ['电视剧', '电影', '动漫', '综艺', '短剧'];
            int indexA = order.indexOf(nameA);
            int indexB = order.indexOf(nameB);
            
            // 如果名字包含关键词（如“推荐电视剧”），也算匹配
            if (indexA == -1) {
               for (int i = 0; i < order.length; i++) {
                 if (nameA.contains(order[i])) {
                   indexA = i;
                   break;
                 }
               }
            }
            if (indexB == -1) {
               for (int i = 0; i < order.length; i++) {
                 if (nameB.contains(order[i])) {
                   indexB = i;
                   break;
                 }
               }
            }

            if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
            if (indexA != -1) return -1;
            if (indexB != -1) return 1;
            return 0;
          });
         }
      } catch (e) {
         print("Init Data Error: $e");
      }

      if (finalTypeList.isEmpty) {
        try {
          finalTypeList = await api.getPluginTypeList();
        } catch (_) {}
      }

      // 3. 构建 Tabs
      // 额外兜底：如果后台已开启专题但 app_tab_setting_list 未返回“专题”，则主动补充
      try {
        final bool hasTopicTab = finalTypeList.any((e) {
          final id = '${e['type_id'] ?? ''}';
          final name = '${e['type_name'] ?? ''}';
          return id == 'topic' || name.contains('专题');
        });
        // 仅当未显式关闭专题时才进行自动补充
        if (!hasTopicTab && appTabTopicEnabled != false) {
          final topics = await api.getTopicList(page: 1);
          if (topics.isNotEmpty) {
            finalTypeList.insert(0, {'type_id': 'topic', 'type_name': '专题'});
          }
        }
      } catch (_) {}
      final newTabs = <String>['推荐'];
      final newIds = <String, dynamic>{'推荐': 0};
      final usedKeys = <String>{'推荐'};

      for (final t in finalTypeList) {
        // id 可能是 int (分类ID) 或 String (rank/week/topic)
        final rawId = t['type_id'];
        var id = 0;
        String? specialId;
        
        if (rawId is int) {
          id = rawId;
        } else if (rawId is String) {
           if (int.tryParse(rawId) != null) {
             id = int.parse(rawId);
           } else {
             specialId = rawId; // "rank", "week", "topic"
           }
        }
        
        var name = (t['type_name'] ?? '').toString().trim();
        // 如果既不是有效数字ID，也不是特殊ID，跳过
        if (id <= 0 && (specialId == null || specialId.isEmpty)) continue;
        if ((id == 0 && specialId == null) || name == '推荐') continue;

        // 防止同名
        if (usedKeys.contains(name)) {
          name = '$name(${specialId ?? id})';
        }
        if (usedKeys.contains(name)) continue;

        usedKeys.add(name);
        newTabs.add(name);
        newIds[name] = specialId ?? id;
      }
      
      print('Home Tabs: Final Tabs: $newTabs');

      // 4. 如果没有任何分类：保持“推荐”，并显示失败状态（引导重试）
      if (newTabs.length <= 1) {
        if (retryCount < 3) {
          print('Home Tabs: Empty list, retrying... ($retryCount)');
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          _loadTabsFromServer(retryCount: retryCount + 1);
          return;
        }

        _safeSetState(() {
          _menuStatus = LoadStatus.failure;
        });
        return;
      }

      // 5. 更新 TabController
      if (newTabs.length != _tabs.length || !_tabs.every((element) => newTabs.contains(element))) {
          final oldCtrl = _tabCtrl;
          final oldIndex = oldCtrl.index;
          oldCtrl.removeListener(_onTabChanged);
          
          final newCtrl = TabController(length: newTabs.length, vsync: this);
          newCtrl.addListener(_onTabChanged);
          // 尝试保持当前选中的索引，如果越界则归零
          newCtrl.index = oldIndex.clamp(0, newTabs.length - 1);

          _safeSetState(() {
            _tabs = newTabs;
            _tabIds = newIds;
            _tabCtrl = newCtrl;
            _menuStatus = LoadStatus.success;
          });
          
          // 保存缓存
          StoreService.setHomeTabsCache(_tabs, _tabIds);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            oldCtrl.dispose();
          });
      } else {
          _safeSetState(() {
             _menuStatus = LoadStatus.success;
          });
      }

      // 6. 预加载
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preloadAllTabs();
      });

    } catch (e, st) {
      print('Home Tabs Load Failed: $e');
      print(st);
      
      if (retryCount < 3) {
        print('Home Tabs: Exception, retrying... ($retryCount)');
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        _loadTabsFromServer(retryCount: retryCount + 1);
        return;
      }

      _safeSetState(() {
        _menuStatus = LoadStatus.failure;
      });
    }
  }

  /// 开发者：杰哥
  /// 作用：首页启动时弹出置顶公告（同一条只弹一次）
  /// 解释：后台设置了置顶公告，你打开 App 会弹出来看一眼。
  Future<void> _maybeShowTopNotice(dynamic raw) async {
    if (_topNoticeChecked) return;
    _topNoticeChecked = true;

    if (raw is! Map) return;
    final id = int.tryParse('${raw['id'] ?? 0}') ?? 0;
    if (id <= 0) return;

    final isForce = raw['is_force'] == true || raw['is_force'] == 1 || raw['force'] == 1 || '${raw['is_force']}' == '1';

    // 开发者：杰哥
    // 逻辑修复：
    // 1. 如果后台设置了“强制提醒”(isForce)，则无视任何记录，每次必弹。
    // 2. 如果是普通公告，则检查本地记录，只有未读过（ID变化）才弹。
    if (isForce) {
      // 强制提醒：不检查本地记录，也不写入本地记录（或者写入也没关系，因为下次还会弹）
      // 直接弹窗
    } else {
      final lastShown = await StoreService.getTopNoticeShownId();
      if (lastShown == id) return;
    }
    
    // 记录已读ID
    // 逻辑修正：
    // 1. 如果是强制提醒(isForce)，每次都要弹，所以不记录已读（或者记录了也不影响上面的判断，因为上面 isForce 会跳过检查）。
    // 2. 如果是非强制提醒，默认也每次弹，除非用户手动点击了“不再提示”。
    
    // 所以这里先不要自动写入 StoreService.setTopNoticeShownId(id)

    if (!mounted) return;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = (raw['title'] ?? '').toString().trim();
    final subTitle = (raw['sub_title'] ?? '').toString().trim();
    final time = (raw['create_time'] ?? '').toString().trim();
    final content = _stripHtml((raw['content'] ?? '').toString().trim());

    if (title.isEmpty && content.isEmpty) return;
    
    bool doNotRemind = false;

    // 只有非强制提醒才允许点击外部关闭
    await showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return WillPopScope(
              onWillPop: () async => !isForce,
              child: Dialog(
                backgroundColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. 顶部标题图（渐变背景 + 图标）
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            top: -20,
                            child: Icon(Icons.notifications, size: 100, color: Colors.white.withOpacity(0.2)),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.campaign, size: 40, color: Theme.of(context).colorScheme.onPrimary),
                                const SizedBox(height: 8),
                                Text(title.isEmpty ? '系统公告' : title, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 2. 内容区域
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subTitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(subTitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                            ),
                          if (time.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 12),
                              child: Text(time, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                            ),
                          const Divider(),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 250),
                            child: SingleChildScrollView(
                              child: Text(
                                content,
                                style: TextStyle(fontSize: 15, height: 1.6, color: Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                          ),
                          
                          // 只有非强制提醒，才显示“不再提示”选项
                        ],
                      ),
                    ),

                    // 3. 底部按钮
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          if (!isForce) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  StoreService.setTopNoticeShownId(id);
                                  Navigator.of(context).pop();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('不再提醒', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                 Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('我知道了'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ), 
            ); // End of WillPopScope
          },
        );
      },
    );
  }

  /// 开发者：杰哥
  /// 作用：进入首页时自动弹出版本更新提示（后台配置了新版本）
  /// 解释：你提交了新版本，用户一进 App 就会弹窗提醒更新。
  Future<void> _maybeShowUpdate(dynamic raw) async {
    if (raw is! Map) return;
    final versionName = (raw['version_name'] ?? '').toString().trim();
    final versionCode = (raw['version_code'] ?? '').toString().trim();
    final desc = (raw['description'] ?? '').toString().trim();
    final size = (raw['app_size'] ?? '').toString().trim();
    final isForce = raw['is_force'] == true || raw['is_force'] == 1;
    final url = ((raw['browser_download_url'] ?? '').toString().trim().isNotEmpty)
        ? (raw['browser_download_url'] ?? '').toString().trim()
        : (raw['download_url'] ?? '').toString().trim();

    if (versionName.isEmpty && versionCode.isEmpty) return;

    // 同一版本只提示一次
    // 开发者：杰哥
    // 逻辑修复：
    // 1. 如果后台设置了“强制更新”(isForce)，每次启动都弹，且无法关闭（barrierDismissible=false）。
    // 2. 如果是普通更新，用户要求“每次进入APP也显示”，直到更新为止。
    //    也就是不再记录“忽略”的版本，只要当前版本低于新版本，每次启动都弹。
    
    // 当前 App 版本号
    String currentVersion = '';
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version; // 形如 1.0.0
    } catch (_) {}
    // 简单比较规则：如果后台给了 version_code，优先用它；否则比较 version_name 文本不相等也提示
    bool shouldPrompt = true;
    if (versionCode.isNotEmpty) {
      shouldPrompt = true; // 后台已声明更新，直接提示
    } else if (currentVersion.isNotEmpty) {
      shouldPrompt = versionName != currentVersion;
    }
    if (!shouldPrompt) return;

    // await StoreService.setLastUpdateCode(versionCode.isNotEmpty ? versionCode : versionName); // 不再记录忽略版本
    if (!mounted) return;

    // 只有非强制更新才显示 "barrierDismissible: true" (用户可点击外部关闭)
    // 强制更新必须是 false
    await showDialog(
      context: context,
      barrierDismissible: !isForce, 
      builder: (_) {
        return WillPopScope( // 拦截返回键
          onWillPop: () async => !isForce,
        child: Dialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 顶部 Header (火箭图标 + 渐变)
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Icon(Icons.rocket_launch, size: 140, color: Colors.white.withOpacity(0.15)),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rocket_launch, color: Theme.of(context).colorScheme.onPrimary, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        versionName.isEmpty ? '发现新版本' : '发现新版本 $versionName',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. 更新内容
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (size.isNotEmpty)
                     Padding(
                       padding: const EdgeInsets.only(bottom: 12),
                       child: Row(
                         children: [
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('安装包大小：$size', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                            ),
                          ],
                        ),
                      ),
                  Text('更新内容：', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Text(
                        desc.isNotEmpty ? desc : '修复已知问题，优化用户体验',
                        style: TextStyle(fontSize: 15, height: 1.6, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. 底部按钮 (强制更新时不显示“稍后”)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
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
                            if (context.mounted && !isForce) Navigator.of(context).pop();
                            return;
                          }
                        }
                        if (context.mounted && !isForce) Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: const Text('立即更新', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (!isForce) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('暂不更新', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
        ), // End of WillPopScope
      );
      },
    );
  }

  /// 开发者：杰哥
  /// 作用：把公告内容里的 HTML 标签去掉，避免弹窗里看着乱
  /// 解释：后台公告可能带 <p> 这些标签，弹窗里我们只显示文字。
  String _stripHtml(String input) {
    if (input.isEmpty) return input;
    var s = input.replaceAll(RegExp(r'<[^>]*>'), '');
    s = s.replaceAll('&nbsp;', ' ');
    s = s.replaceAll('&amp;', '&');
    s = s.replaceAll('&lt;', '<');
    s = s.replaceAll('&gt;', '>');
    s = s.replaceAll(RegExp(r'\\s+'), ' ').trim();
    return s;
  }
  
  void _preloadAllTabs() {
    final api = context.read<MacApi>();
    for (var id in _tabIds.values) {
      if (id is! int) continue; // 跳过特殊页面
      if (id == 0) continue; // 推荐页单独处理
      // 预加载第一页
      api.getFiltered(typeId: id, limit: 21);
    }
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTabLoadChanged({required int typeId, required LoadStatus status, required double progress}) {
    _tabLoadStatus[typeId] = status;
    _tabLoadProgress[typeId] = progress;
    _safeSetState(() {});
  }

  Widget _buildMenuLoadIndicator() {
    // 用户要求隐藏加载条
    if (_menuStatus == LoadStatus.loading) {
       return const SizedBox(height: 2); 
    }
    
    if (_menuStatus == LoadStatus.failure) {
      return Container(
        height: 30,
        alignment: Alignment.center,
        color: Colors.red[50],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('分类加载失败', style: TextStyle(fontSize: 12, color: Colors.red)),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _loadTabsFromServer,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 20)),
              child: const Text('重试', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    // 隐藏 Tab 加载条
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      // backgroundColor: Colors.white, // 移除硬编码，使用主题色
      body: Stack(
        children: [
          // 背景渐变
          Container(
            height: 320,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                    ? [const Color(0xFF1565C0).withOpacity(0.5), const Color(0xFF0B1724)]
                    : [Theme.of(context).colorScheme.primary.withOpacity(0.2), Theme.of(context).colorScheme.primary.withOpacity(0.05), Colors.white],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 顶部区域 (搜索 + TabBar)
                Column(
                  children: [
                    // 搜索栏
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())),
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E2A3A) : const Color(0xFFF0F0F0),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                  children: [
                                    Icon(Icons.search, size: 18, color: isDark ? Colors.white38 : Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      _searchHint,
                                      style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
                            child: Icon(Icons.history, color: isDark ? Colors.white70 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TabBar(
                          controller: _tabCtrl,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          padding: EdgeInsets.zero,
                          labelColor: Theme.of(context).colorScheme.primary,
                          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                          labelStyle: TextStyle(
                            fontSize: _homeTypeFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          unselectedLabelStyle: TextStyle(
                            fontSize: (_homeTypeFontSize - 2).clamp(10, 30),
                            fontWeight: FontWeight.normal,
                          ),
                          indicator: const BoxDecoration(),
                          dividerColor: Colors.transparent,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                          tabs: _tabs.map((t) => Tab(text: t)).toList(),
                        ),
                    ),
                    _buildMenuLoadIndicator(),
                  ],
                ),

                // 内容区域
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: _tabs.map((tab) {
                      final id = _tabIds[tab];
                      
                      if (tab == '推荐') {
                        return HomeRecommendTab(
                          onLoadChanged: (status, progress) {
                            // 推荐页加载状态不影响顶部条
                          },
                        );
                      } 
                      
                      if (id is String) {
                        if (id == 'rank') return const RankingPage();
                        if (id == 'week') return const WeekPage();
                        if (id == 'topic') return const TopicPage();
                        if (id.startsWith('find')) {
                          final parts = id.split('|');
                          final url = parts.length > 1 ? parts.sublist(1).join('|') : '';
                          return FindLinkPage(title: tab, url: url);
                        }
                      }
                      
                      // 默认作为分类处理
                      return HomeCategoryTab(
                        key: ValueKey('tab_$tab'),
                        typeId: (id is int) ? id : 0,
                        typeName: tab,
                        onLoadChanged: (typeId, status, progress) {
                          _onTabLoadChanged(typeId: typeId, status: status, progress: progress);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================== 推荐页 Tab ==================

class HomeRecommendTab extends StatefulWidget {
  final void Function(LoadStatus status, double progress)? onLoadChanged;
  const HomeRecommendTab({super.key, this.onLoadChanged});

  @override
  State<HomeRecommendTab> createState() => _HomeRecommendTabState();
}

class _HomeRecommendTabState extends State<HomeRecommendTab> with AutomaticKeepAliveClientMixin {
  bool loading = true;
  double _progress = 0;
  List<Map<String, dynamic>> banners = [];
  Map<String, dynamic>? homeAdvert;
  List<Map<String, dynamic>> iconAdverts = [];
  List<Map<String, dynamic>> items = []; // 热播
  List<Map<String, dynamic>> typeRecommends = []; // 分类推荐

  final PageController _bannerCtrl = PageController();
  int _bannerIndex = 0;
  Timer? _bannerTimer;
  int _bannerIntervalSeconds = 10;
  double _bannerAspectRatio = 16 / 9; // 默认比例

  @override
  bool get wantKeepAlive => true; // 保持状态，不重复加载

  @override
  void initState() {
    super.initState();
    _tryLoadCache();
    _loadData();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    super.dispose();
  }

  void _startProgress() {
    _progress = 0;
    widget.onLoadChanged?.call(LoadStatus.loading, _progress);
  }

  /// 开发者：杰哥
  /// 作用：根据第一张轮播图自动调整比例
  /// 解释：用户希望轮播图高度能自适应后台上传的图片。
  void _adjustBannerRatio() {
    if (banners.isEmpty) return;
    final first = banners.first;
    final url = first['poster'];
    if (url == null || url.toString().isEmpty) return;

    // 尝试获取图片尺寸
    try {
      final provider = CachedNetworkImageProvider(url.toString());
      provider.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((ImageInfo info, bool syncCall) {
          if (!mounted) return;
          final w = info.image.width;
          final h = info.image.height;
          if (w > 0 && h > 0) {
            final ratio = w / h;
            // 限制比例范围，防止过高或过矮 (1.0 ~ 3.0)
            if (ratio >= 1.0 && ratio <= 3.0) {
              if ((_bannerAspectRatio - ratio).abs() > 0.1) {
                setState(() => _bannerAspectRatio = ratio);
              }
            }
          }
        }, onError: (dyn, stack) {
          // ignore error
        }),
      );
    } catch (_) {}
  }

  /// 文件名：home_page.dart
  /// 作者：杰哥（by：杰哥 / qq：2711793818）
  /// 创建日期：2025-12-23
  /// 作用：尝试读取首页缓存并立即展示，减少首屏转圈
  /// 解释：先把以前的数据拿出来垫着，网络再慢也不空白。
  Future<void> _tryLoadCache() async {
    try {
      final cache = await StoreService.getHomePageCache();
      if (cache.isEmpty) return;
      final cachedBanners = (cache['banners'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
      final cachedItems = (cache['items'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
      final cachedTypeRecs = (cache['typeRecommends'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        banners = cachedBanners;
        items = cachedItems;
        typeRecommends = cachedTypeRecs;
        loading = false;
      });
      if (banners.isNotEmpty) _startBannerTimer();
    } catch (_) {
      // ignore
    }
  }

  void _finishProgress({required bool success}) {
    _progress = 1.0;
    widget.onLoadChanged?.call(success ? LoadStatus.success : LoadStatus.failure, _progress);
  }

  Future<void> _loadData({bool force = false}) async {
    final api = context.read<MacApi>();
    
    // 优化：只有当没有任何数据时才显示全屏Loading，否则静默刷新（避免闪烁）
    if (items.isEmpty && banners.isEmpty) {
      if (mounted) setState(() => loading = true);
      _startProgress();
    }

    bool ok = true;
    List<Map<String, dynamic>> firstItems = []; // 修复：定义 firstItems
    
    try {
      // 并行请求：AppInit（轮播图依赖）
      // 解决“轮播图不显示”和“加载慢”的问题
      final initFuture = api.getAppInit(force: force);
      
      // 1. 等待配置加载完成
      // 杰哥：优先使用插件返回的 recommend_list (初始化接口直接返回的推荐列表)
      // 解释：用户在插件后台配置了“首页热播”规则，数据会包含在 init 接口里，直接用这个最准。
      try {
        final initData = await initFuture;
        if (initData['recommend_list'] is List && (initData['recommend_list'] as List).isNotEmpty) {
           firstItems = (initData['recommend_list'] as List).cast<Map<String, dynamic>>();
           print('Home Page: Loaded ${firstItems.length} items from Plugin Init (recommend_list)');
        }
      } catch (e) {
        print('Home Page: Failed to load from Init: $e');
      }
      
      // 2. 如果插件初始化没带数据，才尝试根据 level 去单独拉取
      if (firstItems.isEmpty) {
        final configLevel = api.hotLevel;
        print('Home Page: Loading by Level $configLevel...');
        try {
          final recList = await api.getRecommended(level: configLevel, limit: 12);
          if (recList.isNotEmpty) {
            firstItems = recList;
          }
        } catch (_) {}
      }
      
      // 杰哥：用户要求只显示后台配置等级的视频，不进行任何兜底
      if (firstItems.isNotEmpty) {
        // 修复“影子数据”：直接替换，确保没有脏数据
        if (mounted) {
           setState(() {
             items = List.from(firstItems); // 创建副本
             if (items.isNotEmpty && banners.isEmpty) loading = false; // 如果有列表了，先取消转圈
           });
        }
      }

      // 2. 处理 App Init (轮播图 & 广告)
      List<Map<String, dynamic>> customBanners = [];
      List<Map<String, dynamic>> customIcons = [];

      try {
        final initData = await initFuture;
        final appInitData = initData;
        
        // 读取 Banner 切换时长 - 使用统一配置getter
        final bannerInterval = api.homepageBannerInterval;
        if (bannerInterval > 0) _bannerIntervalSeconds = bannerInterval;

        // 3. 加载广告配置 (Home Advert & Icon Advert)
        if (initData['home_advert'] is Map && api.isHomeInsertAdOpen) {
           homeAdvert = initData['home_advert'];
        }
        if (initData['icon_advert'] is List) {
           iconAdverts = (initData['icon_advert'] as List).cast<Map<String, dynamic>>();
        }

        // 优先从 advert_list (自定义广告) 中提取
        // 杰哥：聚合所有可能的广告字段，确保不错过任何自定义广告
        List<dynamic> advertGroups = [];
        if (appInitData['advert_list'] is List) advertGroups.addAll(appInitData['advert_list']);
        if (appInitData['custom_ads'] is List) advertGroups.addAll(appInitData['custom_ads']);
        if (appInitData['ads'] is List) advertGroups.addAll(appInitData['ads']);
        if (appInitData['home_banner'] is List) advertGroups.addAll(appInitData['home_banner']);
        if (appInitData['slide_list'] is List) advertGroups.addAll(appInitData['slide_list']); // 增加 slide_list
        if (appInitData['focus_list'] is List) advertGroups.addAll(appInitData['focus_list']); // 增加 focus_list

        for (var group in advertGroups) {
          if (group is! Map) continue;
          
          final name = (group['name'] ?? group['type_name'] ?? '').toString();
          final list = group['list'] ?? group['data']; // 广告列表
          
          if (list is List) {
             // 分组模式：判断是轮播还是图标
             // 杰哥：放宽条件，只要不是明确的“图标”或“导航”，都尝试放入 Banner
             bool isIconGroup = name.contains('图标') || name.contains('导航') || name.toLowerCase().contains('icon') || name.contains('金刚区');
             
             if (isIconGroup) {
               customIcons.addAll(list.cast<Map<String, dynamic>>());
             } else {
               // 默认为 Banner (包括“首页轮播”、“置顶”、“广告”以及未命名分组)
               customBanners.addAll(list.cast<Map<String, dynamic>>());
             }
          } else if (group['advert_pic'] != null || group['pic'] != null || group['poster'] != null || group['img'] != null || group['vod_pic'] != null || group['slide_pic'] != null) {
             // 扁平模式：直接作为 Banner
             customBanners.add(group as Map<String, dynamic>);
          }
        }
        
        // 开发者：杰哥
        // 补充：如果 customBanners 为空，尝试使用 banner_list (MacCMS 标准/插件返回的轮播)
        if (customBanners.isEmpty && appInitData['banner_list'] is List) {
           final list = appInitData['banner_list'] as List;
           if (list.isNotEmpty) {
             customBanners.addAll(list.cast<Map<String, dynamic>>());
           }
        }

        // 仅使用自定义广告作为 Banner
        if (customBanners.isNotEmpty) {
           final newBanners = customBanners.map((e) {
               final id = e['advert_id'] ?? e['id'] ?? e['link'] ?? e['vod_id'] ?? e['slide_id'] ?? '';
               final title = e['advert_name'] ?? e['title'] ?? e['name'] ?? e['vod_name'] ?? e['slide_name'] ?? '';
               final pic = e['advert_pic'] ?? e['pic'] ?? e['img'] ?? e['poster'] ?? e['vod_pic'] ?? e['slide_pic'] ?? '';
               final url = e['advert_url'] ?? e['url'] ?? e['link'] ?? e['vod_link'] ?? e['slide_url'] ?? '';
               return {
                 'id': '$id',
                 'title': '$title',
                 'poster': api.fixUrl('$pic'),
                 'url': '$url',
                 'type': 'advert',
                 'data': e,
               };
           }).toList();
           
           if (mounted) setState(() => banners = newBanners);
        } else {
           if (mounted) setState(() => banners = []);
        }

        // 页面设置广告数据已在前面通过 initData 加载完毕，此处不再重复解析
      
        // 处理自定义图标广告 (Merge into iconAdverts)
        if (customIcons.isNotEmpty) {
            final parsedIcons = customIcons.map((e) {
               final id = e['advert_id'] ?? e['id'] ?? '';
               final title = e['advert_name'] ?? e['title'] ?? '';
               final pic = e['advert_pic'] ?? e['pic'] ?? '';
               final url = e['advert_url'] ?? e['url'] ?? '';
               return {
                 'id': '$id',
                 'title': '$title',
                 'poster': api.fixUrl('$pic'),
                 'url': '$url',
               };
            }).toList();
            
            // 杰哥：自定义图标优先
            iconAdverts = parsedIcons;
        }
      
      } catch (e) {
        print("Init Data Error: $e");
      }
      
      // 开发者：杰哥
      // 修复：仅使用自定义广告作为 Banner，移除所有兜底逻辑 (level 9/1)
      // 用户要求：如果自定义广告为空，则不显示轮播图
      /*
      if (banners.isEmpty) {
         try {
           // 1. 优先尝试 Level 9 (轮播/置顶)
           var bannerList = await api.getRecommended(level: 9, limit: 5);
           
           // 2. 如果 Level 9 没有数据，尝试 Level 1 (普通推荐) 作为强力兜底
           if (bannerList.isEmpty) {
              bannerList = await api.getRecommended(level: 1, limit: 5);
           }

           if (bannerList.isNotEmpty) {
              final fallbackBanners = bannerList.map((v) => {
                 'id': v['id'],
                 'title': v['title'],
                 'poster': v['poster'],
                 'url': '',
                 'type': 'banner',
              }).toList();
              if (mounted) setState(() => banners = fallbackBanners);
           }
         } catch (_) {}
      }
      */

      if (banners.isNotEmpty) _startBannerTimer();

      // 3. 构造分类推荐（自动读取后台分类，无需硬编码）
      try {
        List<Map<String, dynamic>> newTypeRecommends = [];

        final initData = await initFuture;
        final typeList = (initData['type_list'] as List?) ?? [];
        
        // 自动提取后台启用的分类（排除"全部"和特殊页面）
        final sections = <Map<String, dynamic>>[];
        for (final t in typeList.whereType<Map>()) {
          final id = int.tryParse('${t['type_id'] ?? 0}') ?? 0;
          final name = (t['type_name'] ?? '').toString().trim();
          // 跳过"全部"和无效分类
          if (id <= 0 || name.isEmpty || name == '全部') continue;
          sections.add({'type_id': id, 'type_name': name});
        }

        final futures = <Future<void>>[];
        final resultsBySection = <int, List<Map<String, dynamic>>>{};
        for (var i = 0; i < sections.length; i++) {
          final sec = sections[i];
          final tid = sec['type_id'] as int;
          if (tid > 0) {
            futures.add(api.getFiltered(typeId: tid, limit: 9).then((list) {
              if (list.length > 9) list = list.take(9).toList();
              resultsBySection[i] = list;
            }).catchError((_) {
              resultsBySection[i] = [];
            }));
          }
        }
        await Future.wait(futures);
        for (var i = 0; i < sections.length; i++) {
          final sec = sections[i];
          final list = resultsBySection[i];
          if (list != null && list.isNotEmpty) {
            newTypeRecommends.add({
              'type_name': '${sec['type_name']}推荐',
              'key': sec['type_name'],
              'items': list.map((m) => {
                'id': m['id'],
                'title': m['title'],
                'poster': m['poster'],
                'year': m['year'] ?? '',
              }).toList()
            });
          }
        }
        
        if (mounted) {
          setState(() {
            typeRecommends = newTypeRecommends;
          });
        }
      } catch (e) {
        print('Type recommend failed: $e');
      }

    } catch (e) {
      print('Recommend Load Error: $e');
      ok = false;
    } finally {
      if (mounted) setState(() => loading = false);
      // 写入缓存，便于下次快速展示
      try {
        await StoreService.setHomePageCache({
          'banners': banners,
          'items': items,
          'typeRecommends': typeRecommends,
        });
      } catch (_) {}
      _finishProgress(success: ok);
    }
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer =
        Timer.periodic(Duration(seconds: _bannerIntervalSeconds), (timer) {
      if (!mounted || banners.isEmpty) return;
      _bannerIndex++;
      if (_bannerIndex >= banners.length) {
        _bannerIndex = 0;
        _bannerCtrl.jumpToPage(0);
      } else {
        _bannerCtrl.animateToPage(
          _bannerIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _goDetail(String id) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vodId: id)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (loading && items.isEmpty && banners.isEmpty) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }

    if (!loading && items.isEmpty && banners.isEmpty && homeAdvert == null && iconAdverts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('暂无推荐数据', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('重试'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DownloadPage())),
              icon: const Icon(Icons.download_done),
              label: const Text('查看离线缓存'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(force: true),
      color: Theme.of(context).colorScheme.primary,
      child: CustomScrollView(
        slivers: [
          // 轮播图
          if (banners.isNotEmpty)
            SliverToBoxAdapter(
              child: AspectRatio(
                aspectRatio: _bannerAspectRatio,
                child: PageView.builder(
                      controller: _bannerCtrl,
                      itemCount: banners.length,
                      onPageChanged: (i) => _bannerIndex = i,
                      itemBuilder: (_, i) {
                        final item = banners[i];
                        return GestureDetector(
                          onTap: () async {
                             final url = (item['url'] ?? '').toString();
                             if (url.isNotEmpty && url.startsWith('http')) {
                                final uri = Uri.parse(url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                             } else {
                                _goDetail(item['id']);
                             }
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: item['poster'],
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.grey[200]),
                                errorWidget: (_, __, ___) => Container(color: Colors.grey[200]),
                              ),
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withAlpha((255 * 0.8).round()),
                                        Colors.transparent
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'],
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.play_arrow, size: 16, color: Colors.white),
                                                SizedBox(width: 4),
                                                Text('立即播放', style: TextStyle(color: Colors.white, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // 轮播图指示器
                if (banners.length > 1)
                  Container(
                    height: 30,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: banners.asMap().entries.map((entry) {
                        return Container(
                          width: _bannerIndex == entry.key ? 20 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _bannerIndex == entry.key
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.withAlpha(128),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

          // Home Advert (Below Banner)
          if (homeAdvert != null)
             SliverToBoxAdapter(
               child: GestureDetector(
                 onTap: () async {
                   final url = (homeAdvert!['url'] ?? '').toString();
                   if (url.isNotEmpty) {
                     // 简单处理：如果是 http 链接则跳转浏览器，否则可能是 vod_id
                     if (url.startsWith('http')) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                     } else {
                        // 尝试作为 vod_id 跳转
                        _goDetail(homeAdvert!['id']);
                     }
                   } else {
                     _goDetail(homeAdvert!['id']);
                   }
                 },
                 child: Container(
                   margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                   height: 100, // 高度可调
                   child: ClipRRect(
                     borderRadius: BorderRadius.circular(8),
                     child: CachedNetworkImage(
                       imageUrl: homeAdvert!['poster'],
                       fit: BoxFit.cover,
                       placeholder: (_, __) => Container(color: Colors.grey[200]),
                       errorWidget: (_, __, ___) => const SizedBox.shrink(),
                     ),
                   ),
                 ),
               ),
             ),
          
          // Icon Adverts (Grid)
          if (iconAdverts.isNotEmpty)
             SliverPadding(
               padding: const EdgeInsets.all(8),
               sliver: SliverGrid(
                 delegate: SliverChildBuilderDelegate(
                   (ctx, i) {
                     final item = iconAdverts[i];
                     return GestureDetector(
                       onTap: () => _goDetail(item['id']),
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Expanded(
                             child: ClipRRect(
                               borderRadius: BorderRadius.circular(8),
                               child: CachedNetworkImage(
                                 imageUrl: item['poster'],
                                 fit: BoxFit.cover,
                               ),
                             ),
                           ),
                           const SizedBox(height: 4),
                           Text(
                             item['title'],
                             maxLines: 1,
                             overflow: TextOverflow.ellipsis,
                             style: const TextStyle(fontSize: 12),
                           ),
                         ],
                       ),
                     );
                   },
                   childCount: iconAdverts.length,
                   ),
                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                   crossAxisCount: 5, 
                   mainAxisSpacing: 8,
                   crossAxisSpacing: 8,
                   childAspectRatio: 0.8,
                 ),
               ),
             ),

          // 热门推荐标题
          if (items.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '热门推荐',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Row(
                        children: [
                          Text('更多', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                          Icon(Icons.arrow_forward_ios, size: 12, color: isDark ? Colors.white54 : Colors.black54),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          // 热门推荐横向滑动
          if (items.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return GestureDetector(
                      onTap: () => _goDetail(item['id']),
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
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
                                  placeholder: (_, __) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                                  errorWidget: (_, __, ___) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.broken_image)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['title'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            if (item['score'] != null && item['score'].toString().isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 12, color: Colors.orange),
                                  Text('${item['score']}', style: const TextStyle(fontSize: 11, color: Colors.orange)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // 继续观看区域
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '继续观看',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
                    child: Row(
                      children: [
                        Text('更多', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                        Icon(Icons.arrow_forward_ios, size: 12, color: isDark ? Colors.white54 : Colors.black54),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (ctx, i) {
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2A3A) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                          child: Container(
                            width: 80,
                            height: double.infinity,
                            color: Colors.grey[300],
                            child: const Icon(Icons.movie, color: Colors.grey),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '视频标题 ${i + 1}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '观看到第 ${i + 1} 集',
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: 0.3 + (i * 0.15),
                                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 分类推荐
          for (var section in typeRecommends) ...[
             SliverToBoxAdapter(
               child: Padding(
                 padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(
                       section['type_name'],
                       style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                     ),
                     GestureDetector(
                       onTap: () {
                         // 跳转到对应分类
                         final tabName = (section['key'] ?? '').toString();
                         final parent = context.findAncestorStateOfType<_HomePageState>();
                         if (parent != null && tabName.isNotEmpty) {
                           // 尝试在 Tabs 中查找包含该名称的 Tab
                           // section['key'] 是短名字 (如 '动漫')
                           // _tabs 可能是 '动漫' 或 '动漫(4)'
                           final targetIndex = parent._tabs.indexWhere((t) => t.contains(tabName));
                           if (targetIndex >= 0) {
                             parent._tabCtrl.animateTo(targetIndex);
                           } else {
                             // 如果首页 Tab 没找到，可以跳转到 SearchPage 或者 VodListPage
                             // 这里简单提示
                             // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请在顶部菜单切换查看更多')));
                           }
                         }
                       },
                       child: Row(
                         children: [
                           Text(
                             '查看更多',
                             style: TextStyle(
                               fontSize: 12,
                               color: isDark ? Colors.white54 : Colors.black54,
                             ),
                           ),
                           Icon(
                             Icons.arrow_forward_ios,
                             size: 12,
                             color: isDark ? Colors.white54 : Colors.black54,
                           ),
                         ],
                       ),
                     ),
                   ],
                 ),
               ),
             ),
             SliverPadding(
               padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
               sliver: SliverGrid(
                 delegate: SliverChildBuilderDelegate(
                   (ctx, i) => _buildGridItem(section['items'][i]),
                   childCount: (section['items'] as List).length,
                 ),
                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                   crossAxisCount: 3, 
                   mainAxisSpacing: 10,
                   crossAxisSpacing: 10,
                   childAspectRatio: 0.65, 
                 ),
               ),
             ),
          ],
          
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }



  Widget _buildGridItem(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _goDetail(item['id']),
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
                placeholder: (_, __) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                errorWidget: (_, __, ___) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.broken_image)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item['title'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ================== 分类页 Tab (带筛选和分页) ==================

class HomeCategoryTab extends StatefulWidget {
  final int typeId;
  final String typeName;
  final void Function(int typeId, LoadStatus status, double progress)? onLoadChanged;

  const HomeCategoryTab({super.key, required this.typeId, required this.typeName, this.onLoadChanged});

  @override
  State<HomeCategoryTab> createState() => _HomeCategoryTabState();
}

class _HomeCategoryTabState extends State<HomeCategoryTab> with AutomaticKeepAliveClientMixin {
  bool loading = true;
  List<Map<String, dynamic>> items = [];

  double _progress = 0;
  
  // 分页
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // 筛选
  String _selType = '全部';
  String _selArea = '全部';
  String _selLang = '全部';
  String _selYear = '全部';
  String _selSort = '最新';

  // 筛选数据源
  final Map<String, List<String>> _filterTypes = {
    '电视剧': ['全部', '古装', '战争', '青春偶像', '喜剧', '家庭', '犯罪', '动作', '奇幻', '剧情'],
    '电影': ['全部', '动作', '喜剧', '爱情', '科幻', '恐怖', '剧情', '战争', '记录'],
    '动漫': ['全部', '热血', '科幻', '美少女', '魔幻', '经典', '励志', '少儿'],
    '综艺': ['全部', '脱口秀', '真人秀', '选秀', '美食', '旅游', '汽车'],
  };
  final List<String> _filterAreas = ['全部', '大陆', '香港', '台湾', '韩国', '日本', '美国', '泰国', '英国', '法国'];
  final List<String> _filterLangs = ['全部', '国语', '英语', '粤语', '闽南语', '韩语', '日语', '法语'];
  final List<String> _filterYears = ['全部', '2025', '2024', '2023', '2022', '2021', '2020', '2019', '2018'];
  final List<String> _filterSorts = ['最新', '最热', '最赞', '日榜', '周榜', '月榜'];

  String _canonicalTypeName(String name) {
    final s = name.trim();
    if (s.isEmpty) return s;
    final lower = s.toLowerCase();
    if (s.contains('电影') || s.contains('影片') || s.contains('院线')) return '电影';
    if (s.contains('电视剧') || s.contains('连续剧') || s.contains('剧集') || s.contains('网剧') || lower == 'tv') return '电视剧';
    if (s.contains('综艺')) return '综艺';
    if (s.contains('动漫') || s.contains('动画')) return '动漫';
    return s;
  }

  @override
  bool get wantKeepAlive => true; // 保持状态

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore) {
          _loadData(loadMore: true);
        }
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startProgress() {
    _progress = 0;
    widget.onLoadChanged?.call(widget.typeId, LoadStatus.loading, _progress);
  }

  void _finishProgress({required bool success}) {
    _progress = 1.0;
    widget.onLoadChanged?.call(widget.typeId, success ? LoadStatus.success : LoadStatus.failure, _progress);
  }

  Future<void> _loadData({bool loadMore = false}) async {
    final api = context.read<MacApi>();

    bool ok = true;
    
    if (loadMore) {
      if (!mounted) return;
      setState(() => _isLoadingMore = true);
    } else {
      if (mounted) setState(() => loading = true);
      _page = 1;
      _hasMore = true;
      _startProgress();
    }

    try {
      String orderBy = 'time';
      if (_selSort == '最热') orderBy = 'hits';
      if (_selSort == '最赞') orderBy = 'score';
      if (_selSort == '日榜') orderBy = 'hits_day';
      if (_selSort == '周榜') orderBy = 'hits_week';
      if (_selSort == '月榜') orderBy = 'hits_month';

      final newItems = await api.getFiltered(
        typeId: widget.typeId,
        clazz: _selType,
        area: _selArea,
        lang: _selLang,
        year: _selYear,
        orderby: orderBy,
        page: _page,
        limit: 21,
      );
      
      // 过滤无播放源的视频
      // 开发者：杰哥
      // 修复：部分接口（如插件列表）可能不返回 play_url，导致此处误删所有数据。
      // 已移除客户端过滤，确保列表有数据显示。

      if (mounted) {
        if (loadMore) {
          if (newItems.isEmpty) {
            _hasMore = false;
          } else {
            items.addAll(newItems);
            _page++;
            if (newItems.length < 21) _hasMore = false;
          }
        } else {
          // 如果筛选结果为空且不是默认状态，自动回退到全部数据
          if (newItems.isEmpty && (_selType != '全部' || _selArea != '全部' || _selLang != '全部' || _selYear != '全部')) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无相关资源，已自动显示全部数据')));
             setState(() {
               _selType = '全部';
               _selArea = '全部';
               _selLang = '全部';
               _selYear = '全部';
               // 保留排序设置
             });
             // 重新加载全部数据
             _loadData();
             return;
          }
          
          items = newItems;
          if (items.length < 21) {
             _hasMore = false;
          }
          if (items.isNotEmpty) _page++;
        }
      }
    } catch (e) {
      print('Category Load Error: $e');
      ok = false;
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          _isLoadingMore = false;
        });
      }
      if (!loadMore) {
        _finishProgress(success: ok);
      }
    }
  }

  void _onFilterChanged() {
    _loadData();
  }

  void _goDetail(String id) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vodId: id)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 始终构建 CustomScrollView，即使 items 为空，也要显示筛选栏
    // 如果 items 为空且不是 loading，显示空状态提示
    
    Widget content;
    if (!loading && items.isEmpty) {
      content = SliverToBoxAdapter(
        child: Container(
          height: 300,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const Icon(Icons.sentiment_dissatisfied, size: 48, color: Colors.grey),
               const SizedBox(height: 16),
               const Text('暂无数据', style: TextStyle(color: Colors.grey)),
               const SizedBox(height: 16),
               ElevatedButton(onPressed: _loadData, child: const Text('刷新')),
            ],
          ),
        ),
      );
    } else {
      content = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _buildGridItem(items[i]),
            childCount: items.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, 
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.65, 
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Theme.of(context).colorScheme.primary,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 筛选区
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                   // 隐藏加载进度条
                   if (loading && false) 
                     Padding(
                       padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                       child: Row(
                         children: [
                           Expanded(
                             child: ClipRRect(
                               borderRadius: BorderRadius.circular(99),
                               child: LinearProgressIndicator(
                                  value: _progress.clamp(0.0, 0.95),
                                  minHeight: 4,
                                  color: Theme.of(context).colorScheme.primary,
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                ),
                             ),
                           ),
                           const SizedBox(width: 8),
                           Text('${(_progress * 100).clamp(0, 99).round()}%', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                         ],
                       ),
                     ),
                   if (_filterTypes.containsKey(_canonicalTypeName(widget.typeName)))
                     _buildFilterRow(_filterTypes[_canonicalTypeName(widget.typeName)]!, _selType, (val) { setState(() => _selType = val); _onFilterChanged(); }),
                   _buildFilterRow(_filterAreas, _selArea, (val) { setState(() => _selArea = val); _onFilterChanged(); }),
                   _buildFilterRow(_filterLangs, _selLang, (val) { setState(() => _selLang = val); _onFilterChanged(); }),
                   _buildFilterRow(_filterYears, _selYear, (val) { setState(() => _selYear = val); _onFilterChanged(); }),
                   _buildFilterRow(_filterSorts, _selSort, (val) { setState(() => _selSort = val); _onFilterChanged(); }),
                ],
              ),
            ),
          ),
          
          // 内容区域 (网格或空状态)
          content,
          
          // 加载更多提示
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          if (!_hasMore && items.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('没有更多数据了', style: TextStyle(color: Colors.grey))),
              ),
            ),
            
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildGridItem(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _goDetail(item['id']),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item['poster'],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    errorWidget: (_, __, ___) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.broken_image)),
                  ),
                ),
                Positioned(
                  bottom: 4, right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                    child: Text(item['year'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item['title'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(List<String> options, String selected, Function(String) onSelect) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: options.map((opt) {
          final active = selected == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(opt),
              selected: active,
              onSelected: (_) => onSelect(opt),
              labelStyle: TextStyle(
                color: active ? Theme.of(context).colorScheme.primary : (isDark ? Colors.grey[400] : Colors.black54), 
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal
              ),
              backgroundColor: Colors.transparent,
              selectedColor: isDark ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Theme.of(context).colorScheme.surfaceVariant,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}
