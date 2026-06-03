/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 作用：首页（顶部分类菜单 + Banner + 热门推荐九宫格 + 分类六宫格 + 内容网格）

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../pages/detail_page.dart';
import '../pages/search_page.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/keep_alive_wrapper.dart';
import '../widgets/slide_banner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ── Tab 控制器 ──
  late TabController _tabController;

  // ── 数据 ──
  List<String> _tabs = [];
  List<int> _tabIds = [];
  int _currentTabIndex = 0;

  // ── 加载状态 ──
  bool _isLoadingTabs = true;
  bool _isLoadingContent = false;
  int _loadingIndex = -1;

  // ── 下拉刷新 ──
  final Map<int, GlobalKey<RefreshIndicatorState>> _refreshKeys = {};

  // ── 轮播图 ──
  List<dynamic> _bannerList = [];

  // ── 搜索热词 ──
  List<String> _hotWords = [];

  // ── 通知栏 ──
  List<dynamic> _announcements = [];

  // ── 轮播图当前索引 ──
  int _bannerCurrentIndex = 0;

  // ── 热门推荐 ──
  List<dynamic> _hotRecommendList = [];

  // ── 分类推荐（每个分类的推荐列表六宫格） ──
  final List<Map<String, dynamic>> _categoryRecommends = [];

  // ── 显示返回顶部按钮 ──
  bool _showScrollToTop = false;

  // ── 缓存 ──
  final Map<int, List<dynamic>> _contentCache = {};
  final Map<int, int> _pageCache = {};
  final Map<int, bool> _hasMoreCache = {};

  // ── 滚动监听 ──
  final ScrollController _scrollController = ScrollController();

  // ── 分类菜单字体大小 ──
  double _homeTypeFontSize = 14;

  // ── 筛选状态 ──
  Map<String, List<String>> _facets = {'years': [], 'areas': [], 'classes': []};
  String _currentOrderby = 'time';
  String? _selectedYear;
  String? _selectedArea;
  String? _selectedClass;
  String? _selectedLang;

  // ── 防抖 ──
  Timer? _tabDebounce;

  // ── 缓存 key ──
  static const String _cacheKeyTabs = 'home_tabs_cache';
  static const String _cacheKeyBanner = 'home_banner_cache';
  static const String _cacheKeyHotWords = 'home_hotwords_cache';
  static const String _cacheKeyAnnouncements = 'home_announcements_cache';
  static const String _cacheKeyHotRecommend = 'home_hot_recommend_cache';
  static const String _cacheKeyContentPrefix = 'home_content_cache_';
  static const String _cacheKeyPagePrefix = 'home_page_cache_';
  static const String _cacheKeyHasMorePrefix = 'home_hasmore_cache_';
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _loadCachedData().then((_) {
      if (_tabs.isNotEmpty) {
        setState(() => _isLoadingTabs = false);
        _tabController = TabController(
          length: _tabs.length,
          vsync: this,
          initialIndex: _currentTabIndex,
        );
        _tabController.addListener(_onTabChanged);
      }
      _loadTabs();
    });
  }

  // ── 缓存读写 ──
  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();

    final tabsJson = prefs.getString(_cacheKeyTabs);
    if (tabsJson != null) {
      try {
        final data = jsonDecode(tabsJson);
        final cacheTime = DateTime.parse(data['time']);
        if (DateTime.now().difference(cacheTime) < _cacheValidDuration) {
          _tabs = List<String>.from(data['tabs']);
          _tabIds = List<int>.from(data['tabIds']);
          _currentTabIndex = data['currentTabIndex'] ?? 0;
        }
      } catch (_) {}
    }

    final bannerJson = prefs.getString(_cacheKeyBanner);
    if (bannerJson != null) {
      try {
        final data = jsonDecode(bannerJson);
        final cacheTime = DateTime.parse(data['time']);
        if (DateTime.now().difference(cacheTime) < _cacheValidDuration) {
          _bannerList = data['list'];
        }
      } catch (_) {}
    }

    final hotWordsJson = prefs.getString(_cacheKeyHotWords);
    if (hotWordsJson != null) {
      try {
        final data = jsonDecode(hotWordsJson);
        final cacheTime = DateTime.parse(data['time']);
        if (DateTime.now().difference(cacheTime) < _cacheValidDuration) {
          _hotWords = List<String>.from(data['words']);
        }
      } catch (_) {}
    }

    final announcementsJson = prefs.getString(_cacheKeyAnnouncements);
    if (announcementsJson != null) {
      try {
        final data = jsonDecode(announcementsJson);
        final cacheTime = DateTime.parse(data['time']);
        if (DateTime.now().difference(cacheTime) < _cacheValidDuration) {
          _announcements = data['list'];
        }
      } catch (_) {}
    }

    final hotRecommendJson = prefs.getString(_cacheKeyHotRecommend);
    if (hotRecommendJson != null) {
      try {
        final data = jsonDecode(hotRecommendJson);
        final cacheTime = DateTime.parse(data['time']);
        if (DateTime.now().difference(cacheTime) < _cacheValidDuration) {
          _hotRecommendList = data['list'];
        }
      } catch (_) {}
    }

    for (int i = 0; i < _tabIds.length; i++) {
      final contentJson = prefs.getString('$_cacheKeyContentPrefix$_tabIds[i]');
      if (contentJson != null) {
        try {
          final data = jsonDecode(contentJson);
          final cacheTime = DateTime.parse(data['time']);
          if (DateTime.now().difference(cacheTime) < _cacheValidDuration) {
            _contentCache[i] = List<dynamic>.from(data['list']);
            _pageCache[i] = data['page'] ?? 1;
            _hasMoreCache[i] = data['hasMore'] ?? true;
          }
        } catch (_) {}
      }
    }

    if (_tabs.isNotEmpty && _currentTabIndex >= _tabs.length) {
      _currentTabIndex = 0;
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();

    if (_tabs.isNotEmpty) {
      await prefs.setString(
        _cacheKeyTabs,
        jsonEncode({
          'time': DateTime.now().toIso8601String(),
          'tabs': _tabs,
          'tabIds': _tabIds,
          'currentTabIndex': _currentTabIndex,
        }),
      );
    }

    if (_bannerList.isNotEmpty) {
      await prefs.setString(
        _cacheKeyBanner,
        jsonEncode({
          'time': DateTime.now().toIso8601String(),
          'list': _bannerList,
        }),
      );
    }

    if (_hotWords.isNotEmpty) {
      await prefs.setString(
        _cacheKeyHotWords,
        jsonEncode({
          'time': DateTime.now().toIso8601String(),
          'words': _hotWords,
        }),
      );
    }

    if (_announcements.isNotEmpty) {
      await prefs.setString(
        _cacheKeyAnnouncements,
        jsonEncode({
          'time': DateTime.now().toIso8601String(),
          'list': _announcements,
        }),
      );
    }

    if (_hotRecommendList.isNotEmpty) {
      await prefs.setString(
        _cacheKeyHotRecommend,
        jsonEncode({
          'time': DateTime.now().toIso8601String(),
          'list': _hotRecommendList,
        }),
      );
    }

    for (final entry in _contentCache.entries) {
      final tabId = _tabIds[entry.key];
      await prefs.setString(
        '$_cacheKeyContentPrefix$tabId',
        jsonEncode({
          'time': DateTime.now().toIso8601String(),
          'list': entry.value,
          'page': _pageCache[entry.key] ?? 1,
          'hasMore': _hasMoreCache[entry.key] ?? true,
        }),
      );
    }
  }

  // ── 加载分类 ──
  bool _isLoadingTabsActive = false;
  Future<void> _loadTabs() async {
    if (_isLoadingTabsActive) return;
    _isLoadingTabsActive = true;
    final hasExistingTabs = _tabs.isNotEmpty;
    if (!hasExistingTabs) {
      setState(() => _isLoadingTabs = true);
    }
    try {
      final api = context.read<MacApi>();
      final initData = await api.getAppInit();
      final list = initData['type_list'] as List<dynamic>? ?? [];

      final fontSize = double.tryParse('${initData['home_type_font_size'] ?? 14}') ?? 14;
      if (fontSize > 0) {
        _homeTypeFontSize = fontSize.clamp(10, 30);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('home_type_font_size', _homeTypeFontSize);
      }

      if (list.isNotEmpty) {
        _tabs = ['推荐', ...list.where((e) => e['type_name'].toString() != '全部').map((e) => e['type_name'].toString())];
        _tabIds = [0, ...list.where((e) => e['type_name'].toString() != '全部').map((e) => int.tryParse('${e['type_id']}') ?? 0)];

        if (hasExistingTabs) {
          _tabController.removeListener(_onTabChanged);
          _tabController.dispose();
        }
        _tabController = TabController(length: _tabs.length, vsync: this);
        _tabController.addListener(_onTabChanged);

        _loadContent(0, refresh: true);
        _loadBanner();
        _loadHotWords();
        _loadFacets();
        _loadAnnouncements(initData['notice']);
        _loadHotRecommend();
        _loadCategoryRecommends(list);

        for (int i = 1; i < _tabs.length && i <= 3; i++) {
          _loadContent(i, refresh: true);
        }

        _saveCache();
      } else {
        _tabs = ['推荐'];
        _tabIds = [0];
        if (hasExistingTabs) {
          _tabController.removeListener(_onTabChanged);
          _tabController.dispose();
        }
        _tabController = TabController(length: _tabs.length, vsync: this);
        _tabController.addListener(_onTabChanged);
        _loadContent(0, refresh: true);
      }
    } catch (e) {
      debugPrint('加载分类失败: $e');
      _tabs = ['推荐'];
      _tabIds = [0];
      if (hasExistingTabs) {
        _tabController.removeListener(_onTabChanged);
        _tabController.dispose();
      }
      _tabController = TabController(length: _tabs.length, vsync: this);
      _tabController.addListener(_onTabChanged);
      _loadContent(0, refresh: true);
    } finally {
      _isLoadingTabsActive = false;
      setState(() => _isLoadingTabs = false);
    }
  }

  // ── 加载轮播图 ──
  Future<void> _loadBanner() async {
    try {
      final api = context.read<MacApi>();
      final bannerList = await api.getBanner();
      if (bannerList.isNotEmpty) {
        setState(() => _bannerList = bannerList);
        _saveCache();
      }
    } catch (e) {
      debugPrint('加载轮播图失败: $e');
    }
  }

  // ── 加载热词 ──
  Future<void> _loadHotWords() async {
    try {
      final api = context.read<MacApi>();
      final keywords = await api.getHotKeywords();
      if (keywords.isNotEmpty) {
        setState(() => _hotWords = keywords);
        _saveCache();
      }
    } catch (e) {
      debugPrint('加载热词失败: $e');
    }
  }

  // ── 加载通知 ──
  Future<void> _loadAnnouncements([dynamic notice]) async {
    try {
      if (notice != null) {
        setState(() => _announcements = [notice]);
        _saveCache();
        return;
      }
      final api = context.read<MacApi>();
      final initData = await api.getAppInit();
      final n = initData['notice'];
      if (n != null) {
        setState(() => _announcements = [n]);
        _saveCache();
      }
    } catch (e) {
      debugPrint('加载通知失败: $e');
    }
  }

  // ── 加载筛选项（从 CMS 扩展分类获取） ──
  Future<void> _loadFacets([int? typeId]) async {
    try {
      final api = context.read<MacApi>();
      final targetTypeId = typeId ?? (_tabIds.isNotEmpty && _tabIds.length > 1 ? _tabIds[1] : 1);
      if (targetTypeId <= 0) return;

      List<String> _parseList(dynamic value) {
        if (value == null) return [];
        if (value is List) return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        final str = value.toString().trim();
        if (str.isEmpty) return [];
        return str.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      Map<String, List<String>>? _extractFromExtend(dynamic extend) {
        if (extend is! Map) return null;
        final result = <String, List<String>>{
          'years': _parseList(extend['year']),
          'areas': _parseList(extend['area']),
          'classes': _parseList(extend['class']),
        };
        final langs = _parseList(extend['lang']);
        if (langs.isNotEmpty) result['langs'] = langs;
        if (result['years']!.isNotEmpty || result['areas']!.isNotEmpty || result['classes']!.isNotEmpty) {
          return result;
        }
        return null;
      }

      // 优先从 init 缓存的 type_list 中提取分类扩展数据
      try {
        final initData = await api.getAppInit();
        final typeList = initData['type_list'] as List? ?? [];
        for (final t in typeList) {
          if (t is! Map) continue;
          if (t['type_id'] == targetTypeId) {
            final facets = _extractFromExtend(t['type_extend']);
            if (facets != null) { setState(() => _facets = facets); return; }
          }
        }
        // 收不到匹配的分类数据，尝试顶层 type_extend
        final topFacets = _extractFromExtend(initData['type_extend']);
        if (topFacets != null) { setState(() => _facets = topFacets); return; }
      } catch (_) {}

      // 收不到 init 数据，调用 API
      final facets = await api.getFacets(typeId1: targetTypeId);
      if (facets['years'] != null || facets['areas'] != null || facets['classes'] != null) {
        setState(() => _facets = facets);
      }
    } catch (e) {
      debugPrint('加载筛选项失败: $e');
    }
  }

  // ── 清除筛选 ──
  void _clearFilters() {
    setState(() {
      _selectedYear = null;
      _selectedArea = null;
      _selectedClass = null;
      _selectedLang = null;
      _currentOrderby = 'time';
      _loadContent(_currentTabIndex, refresh: true);
    });
  }

  // ── 筛选变化回调 ──
  void _onFilterChanged() {
    _loadContent(_currentTabIndex, refresh: true);
  }

  // ── 加载热门推荐 ──
  Future<void> _loadHotRecommend() async {
    try {
      final api = context.read<MacApi>();
      final list = await api.getFiltered(
        typeId: null,
        page: 1,
        limit: 9,
        orderby: 'hits',
      );
      if (list.isNotEmpty) {
        setState(() => _hotRecommendList = list);
        _saveCache();
      }
    } catch (e) {
      debugPrint('加载热门推荐失败: $e');
    }
  }

  // ── 加载分类推荐（每个分类6条热门数据，并行加载） ──
  Future<void> _loadCategoryRecommends(List<dynamic> typeList) async {
    _categoryRecommends.clear();
    final api = context.read<MacApi>();

    final validTypes = <Map<String, dynamic>>[];
    for (final t in typeList) {
      if (t is! Map) continue;
      final typeName = t['type_name']?.toString() ?? '';
      final typeId = int.tryParse('${t['type_id']}') ?? 0;
      if (typeName == '全部' || typeName.isEmpty || typeId <= 0) continue;
      validTypes.add({'name': typeName, 'typeId': typeId});
    }

    final futures = validTypes.map((t) async {
      try {
        final items = await api.getFiltered(
          typeId: t['typeId'] as int,
          page: 1,
          limit: 6,
          orderby: 'hits',
        );
        return {'name': t['name'], 'typeId': t['typeId'], 'items': items};
      } catch (e) {
        debugPrint('加载分类 ${t['name']} 推荐失败: $e');
        return {'name': t['name'], 'typeId': t['typeId'], 'items': <dynamic>[]};
      }
    }).toList();

    final results = await Future.wait(futures);
    for (final r in results) {
      final items = r['items'] as List<dynamic>;
      if (items.isNotEmpty) {
        _categoryRecommends.add(r);
      }
    }

    if (_categoryRecommends.isNotEmpty && mounted) setState(() {});
  }

  // ── Tab 切换 ──
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;
    if (index == _currentTabIndex) return;
    setState(() => _currentTabIndex = index);
    _tabDebounce?.cancel();
    _tabDebounce = Timer(const Duration(milliseconds: 150), () {
      _loadContent(index, refresh: true);
      if (index > 0 && _tabIds.length > index) {
        _loadFacets(_tabIds[index]);
      }
    });
  }

  // ── 加载内容（refresh=刷新页, loadMore=加载下一页） ──
  Future<void> _loadContent(int index, {bool refresh = false, bool loadMore = false}) async {
    if (_isLoadingContent && _loadingIndex == index && !loadMore) return;
    if (index >= _tabIds.length) return;

    final hasCache = _contentCache.containsKey(index) && _contentCache[index]!.isNotEmpty;

    setState(() {
      _isLoadingContent = true;
      _loadingIndex = index;
    });
    try {
      final api = context.read<MacApi>();
      final typeId = _tabIds[index];
      if (refresh) {
        _pageCache[index] = 1;
        _hasMoreCache[index] = true;
      }
      if (!refresh && !loadMore && hasCache) {
        setState(() {});
        return;
      }
      List<dynamic> list = [];
      if (index == 0 && !loadMore) {
        try {
          final initData = await api.getAppInit();
          final recommendList = initData['recommend_list'] as List<dynamic>? ?? [];
          if (recommendList.isNotEmpty) list = recommendList;
        } catch (e) {
          debugPrint('加载推荐列表失败: $e');
        }
      }
      if (list.isEmpty) {
        final currentPage = _pageCache[index] ?? 1;
        list = await api.getFiltered(
          typeId: typeId == 0 ? null : typeId,
          page: currentPage,
          limit: 9,
          orderby: _currentOrderby,
          year: _selectedYear,
          area: _selectedArea,
          lang: _selectedLang,
          clazz: _selectedClass,
        );
      }
      if (list.isNotEmpty) {
        setState(() {
          final existingList = refresh ? [] : (_contentCache[index] ?? []);
          _contentCache[index] = [...existingList, ...list];
          _hasMoreCache[index] = list.length >= 9;
          _pageCache[index] = (_pageCache[index] ?? 1) + 1;
        });
        _saveCache();
      } else {
        setState(() => _hasMoreCache[index] = false);
      }
    } catch (e) {
      debugPrint('加载内容失败: $e');
    } finally {
      if (_loadingIndex == index) {
        setState(() {
          _isLoadingContent = false;
          _loadingIndex = -1;
        });
      }
    }
  }

  // ── 滚动监听（NotificationListener） ──
  bool _onScrollNotification(ScrollNotification notification, int index) {
    if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
      final hasMore = _hasMoreCache[index] ?? true;
      if (!_isLoadingContent && hasMore) {
        _loadContent(index, loadMore: true);
      }
    }
    final show = notification.metrics.pixels > 500;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
    return false;
  }

  // ── 下拉刷新 ──
  Future<void> _onRefresh() async {
    await _loadContent(_currentTabIndex, refresh: true);
    await _loadBanner();
    await _loadHotWords();
    await _loadAnnouncements();
    await _loadHotRecommend();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _tabDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.slate50,
      body: TexturedBackground(
        child: SafeArea(
          child: Stack(
            children: [
              NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _buildSearchBar(isDark),
              ),

              SliverToBoxAdapter(
                child: _isLoadingTabs
                    ? _buildTabShimmer()
                    : _buildTabBar(isDark),
              ),

              SliverToBoxAdapter(
                child: AnimatedBuilder(
                  animation: _tabController.animation!,
                  builder: (context, child) {
                    final double animValue = _tabController.animation!.value;
                    final bool nearRecommend = animValue < 0.12;
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.hardEdge,
                      child: nearRecommend
                          ? const SizedBox(width: double.infinity)
                          : Opacity(
                              opacity: animValue.clamp(0.0, 1.0),
                              child: _buildFilterBar(isDark),
                            ),
                    );
                  },
                ),
              ),

              if (_announcements.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildAnnouncementBar(isDark),
                ),
            ];
          },
          body: _isLoadingTabs
              ? _buildContentShimmer()
              : TabBarView(
                  controller: _tabController,
                  children: _tabs.asMap().entries.map((entry) {
                    return KeepAliveWrapper(
                      child: _buildContentList(entry.key),
                    );
                  }).toList(),
                ),
          ),
          if (_showScrollToTop)
            Positioned(
              bottom: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.06),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.5),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
      ),
    );
  }

  // ── 搜索栏 ──
  Widget _buildSearchBar(bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchPage()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _hotWords.isNotEmpty
                    ? '搜索: ${_hotWords[Random().nextInt(_hotWords.length)]}'
                    : '搜索你想看的视频...',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_hotWords.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('热搜', style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                )),
              ),
          ],
        ),
      ),
    );
  }

  // ── Tab 栏 ──
  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        labelStyle: TextStyle(fontSize: _homeTypeFontSize, fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(
          fontSize: (_homeTypeFontSize - 2).clamp(10, 30),
          fontWeight: FontWeight.normal,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: Theme.of(context).colorScheme.primary),
        ),
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        tabs: _tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  // ── Tab 骨架屏 ──
  Widget _buildTabShimmer() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 8,
          itemBuilder: (_, __) => Container(
            width: 60,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ),
    );
  }

  // ── 筛选栏 ──
  Widget _buildFilterBar(bool isDark) {
    final hasFilter = _selectedYear != null || _selectedArea != null || _selectedClass != null || _selectedLang != null || _currentOrderby != 'time';
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterRow(
            label: '排序',
            items: const ['最新', '最热', '最赞'],
            selected: {'time': '最新', 'hits': '最热', 'score': '最赞'}[_currentOrderby] ?? '最新',
            primary: primary,
            isDark: isDark,
            onChanged: (v) {
              final m = {'最新': 'time', '最热': 'hits', '最赞': 'score'};
              setState(() => _currentOrderby = m[v] ?? 'time');
              _onFilterChanged();
            },
          ),
          const SizedBox(height: 6),
          _buildFilterRow(
            label: '年份',
            items: ['全部', ..._facets['years'] ?? []],
            selected: _selectedYear ?? '全部',
            primary: primary,
            isDark: isDark,
            onChanged: (v) {
              setState(() => _selectedYear = v == '全部' ? null : v);
              _onFilterChanged();
            },
          ),
          const SizedBox(height: 6),
          _buildFilterRow(
            label: '地区',
            items: ['全部', ..._facets['areas'] ?? []],
            selected: _selectedArea ?? '全部',
            primary: primary,
            isDark: isDark,
            onChanged: (v) {
              setState(() => _selectedArea = v == '全部' ? null : v);
              _onFilterChanged();
            },
          ),
          const SizedBox(height: 6),
          _buildFilterRow(
            label: '类型',
            items: ['全部', ..._facets['classes'] ?? []],
            selected: _selectedClass ?? '全部',
            primary: primary,
            isDark: isDark,
            onChanged: (v) {
              setState(() => _selectedClass = v == '全部' ? null : v);
              _onFilterChanged();
            },
          ),
          if ((_facets['langs'] ?? []).isNotEmpty) ...[            const SizedBox(height: 6),
            _buildFilterRow(
              label: '语言',
              items: ['全部', ..._facets['langs'] ?? []],
              selected: _selectedLang ?? '全部',
              primary: primary,
              isDark: isDark,
              onChanged: (v) {
                setState(() => _selectedLang = v == '全部' ? null : v);
                _onFilterChanged();
              },
            ),
          ],
          if (hasFilter) ...[            const SizedBox(height: 8),
            GestureDetector(
              onTap: _clearFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, size: 14, color: primary),
                    const SizedBox(width: 4),
                    Text('重置筛选', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRow({
    required String label,
    required List<String> items,
    required String selected,
    required Color primary,
    required bool isDark,
    required Function(String) onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: items.map((item) {
                final isSel = item == selected;
                return GestureDetector(
                  onTap: () => onChanged(item),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSel
                          ? primary.withOpacity(0.15)
                          : (isDark ? AppColors.darkCard : AppColors.slate50),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSel ? primary : (isDark ? AppColors.slate700.withOpacity(0.4) : AppColors.slate200.withOpacity(0.6)),
                        width: isSel ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                        color: isSel ? primary : (isDark ? AppColors.slate300 : AppColors.slate600),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── 轮播图（全宽+文字叠加+标题跟随轮播） ──
  Widget _buildBanner() {
    final safeIndex = _bannerCurrentIndex.clamp(0, _bannerList.length - 1);
    final currentItem = _bannerList.isNotEmpty ? _bannerList[safeIndex] : null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      height: 220,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
        children: [
          Positioned.fill(
            child: SlideBanner(
              images: _bannerList.map((e) => (e['poster'] ?? e['image'] ?? e['vod_pic'] ?? '').toString()).toList(),
              onTap: (index) {
                final item = _bannerList[index];
                final vodId = '${item['id'] ?? item['vod_id'] ?? ''}';
                if (vodId.isEmpty || vodId == '0') return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vodId: vodId)));
              },
              onPageChanged: (index) {
                setState(() => _bannerCurrentIndex = index);
              },
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentItem != null ? (currentItem['title'] ?? currentItem['vod_name'] ?? '') : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  currentItem != null ? (currentItem['remarks'] ?? currentItem['vod_remarks'] ?? '') : '',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ── 通知栏 ──
  Widget _buildAnnouncementBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign, color: Theme.of(context).colorScheme.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _announcements.isNotEmpty ? _announcements[0]['title'].toString() : '',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── 热门推荐九宫格 ──
  Widget _buildHotRecommendSection(bool isDark) {
    if (_hotRecommendList.isEmpty) return const SizedBox.shrink();
    final itemCount = _hotRecommendList.length.clamp(0, 9);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('热门推荐', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.65,
            ),
            itemCount: itemCount,
            itemBuilder: (ctx, i) {
              final item = _hotRecommendList[i];
              return _buildHotRecommendCard(item);
            },
          ),
        ],
      ),
    );
  }

  // ── 热门推荐卡片 ──
  Widget _buildHotRecommendCard(dynamic item) {
    return GestureDetector(
      onTap: () {
        final vodId = item['id']?.toString() ?? '';
        if (vodId.isEmpty) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vodId: vodId)));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: item['poster'] ?? '',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    memCacheHeight: 600,
                    placeholder: (ctx, _) => Container(color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkElevated : AppColors.slate200),
                    errorWidget: (ctx, _, ___) => Container(color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkElevated : AppColors.slate200, child: const Icon(Icons.broken_image)),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.slate900.withOpacity(0.54),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(item['year'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item['title'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── 各分类推荐六宫格 ──
  Widget _buildCategorySections(bool isDark) {
    if (_categoryRecommends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _categoryRecommends.map((cat) {
        final name = cat['name'] as String;
        final items = cat['items'] as List<dynamic>;
        final typeId = cat['typeId'] as int;
        final displayItems = items.take(6).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Text(
                      '$name推荐',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        final catIndex = _tabIds.indexOf(typeId);
                        if (catIndex > 0) _tabController.animateTo(catIndex);
                      },
                      child: Row(
                        children: [
                          Text('更多', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                          Icon(Icons.arrow_forward_ios, size: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: displayItems.length,
                  itemBuilder: (ctx, i) {
                    final item = displayItems[i];
                    return _buildCategoryItemCard(item);
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryItemCard(dynamic item) {
    return GestureDetector(
      onTap: () {
        final vodId = item['id']?.toString() ?? '';
        if (vodId.isEmpty) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vodId: vodId)));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: item['poster'] ?? '',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    memCacheHeight: 600,
                    placeholder: (ctx, _) => Container(color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkElevated : AppColors.slate200),
                    errorWidget: (ctx, _, ___) => Container(color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkElevated : AppColors.slate200, child: const Icon(Icons.broken_image)),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.slate900.withOpacity(0.54),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(item['year'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item['title'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── 内容列表 ──
  Widget _buildContentList(int index) {
    final contentList = _contentCache[index] ?? [];
    final hasMore = _hasMoreCache[index] ?? true;
    final isLoadingThisCategory = _isLoadingContent && _loadingIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showFooter = contentList.isNotEmpty && !isLoadingThisCategory;

    if (index == 0) {
      return RefreshIndicator(
        key: _refreshKeys.putIfAbsent(index, () => GlobalKey<RefreshIndicatorState>()),
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            if (_bannerList.isNotEmpty)
              SliverToBoxAdapter(child: _buildBanner()),
            if (_hotRecommendList.isNotEmpty)
              SliverToBoxAdapter(child: _buildHotRecommendSection(isDark)),
            if (_categoryRecommends.isNotEmpty)
              SliverToBoxAdapter(child: _buildCategorySections(isDark)),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) => _onScrollNotification(n, index),
      child: RefreshIndicator(
        key: _refreshKeys.putIfAbsent(index, () => GlobalKey<RefreshIndicatorState>()),
        onRefresh: _onRefresh,
        child: contentList.isEmpty && isLoadingThisCategory
            ? _buildContentShimmer()
            : contentList.isEmpty
                ? _buildEmptyView()
                : CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.65,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _buildGridItem(contentList[i]),
                            childCount: contentList.length,
                          ),
                        ),
                      ),
                      if (showFooter)
                        SliverToBoxAdapter(
                          child: hasMore ? _buildLoadMoreFooter() : _buildNoMoreFooter(),
                        ),
                    ],
                  ),
      ),
    );
  }

  // ── 网格卡片 ──
  Widget _buildGridItem(dynamic item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        final vodId = item['id']?.toString() ?? '';
        if (vodId.isEmpty) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vodId: vodId)));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item['poster'] ?? '',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (ctx, _) => Container(color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkElevated : AppColors.slate200),
                    errorWidget: (ctx, _, ___) => Container(color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkElevated : AppColors.slate200, child: const Icon(Icons.broken_image)),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.slate900.withOpacity(0.54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(item['year'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item['title'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── Sliver 骨架屏网格 ──
  Widget _buildShimmerGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.65,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, __) => Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          highlightColor: Theme.of(context).colorScheme.surface,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        childCount: 9,
      ),
    );
  }

  // ── 骨架屏 ──
  Widget _buildContentShimmer() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      highlightColor: Theme.of(context).colorScheme.surface,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.65,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ── 空视图 ──
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('暂无内容', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 16)),
        ],
      ),
    );
  }

  // ── 加载更多指示器（全宽footer，不在网格内） ──
  Widget _buildLoadMoreFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }

  // ── 没有更多了提示 ──
  Widget _buildNoMoreFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Text(
        '—— 没有更多了 ——',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
        ),
      ),
    );
  }
}