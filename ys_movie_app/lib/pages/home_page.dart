/// 文件名：home_page.dart
/// 作者：杰哥（by：杰哥 / qq：2711793818）
/// 创建日期：2025-12-16
/// 作用：首页（顶部分类菜单 + 推荐/分类列表）
/// 解释：你打开 App 第一眼看到的页面，顶部能切分类，下面是内容。
/// 开发者：杰哥网络科技 (qq: 2711793818)

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
import '../services/theme_provider.dart';
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
  int _loadingIndex = -1; // 当前正在加载的分类索引

  // ── 下拉刷新 ──
  final Map<int, GlobalKey<RefreshIndicatorState>> _refreshKeys = {};

  // ── 轮播图 ──
  List<dynamic> _bannerList = [];

  // ── 搜索热词 ──
  List<String> _hotWords = [];

  // ── 通知栏 ──
  List<dynamic> _announcements = [];

  // ── 缓存 ──
  final Map<int, List<dynamic>> _contentCache = {};
  final Map<int, int> _pageCache = {};
  final Map<int, bool> _hasMoreCache = {};

  // ── 滚动监听 ──
  final ScrollController _scrollController = ScrollController();

  // ── 分类菜单字体大小 ──
  double _homeTypeFontSize = 14;

  // ── 防抖 ──
  Timer? _tabDebounce;

  // ── 缓存 key ──
  static const String _cacheKeyTabs = 'home_tabs_cache';
  static const String _cacheKeyBanner = 'home_banner_cache';
  static const String _cacheKeyHotWords = 'home_hotwords_cache';
  static const String _cacheKeyAnnouncements = 'home_announcements_cache';
  static const String _cacheKeyContentPrefix = 'home_content_cache_';
  static const String _cacheKeyPagePrefix = 'home_page_cache_';
  static const String _cacheKeyHasMorePrefix = 'home_hasmore_cache_';
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCachedData().then((_) {
      if (_tabs.isEmpty) {
        _loadTabs();
      } else {
        _tabController = TabController(
          length: _tabs.length,
          vsync: this,
          initialIndex: _currentTabIndex,
        );
        _tabController.addListener(_onTabChanged);
        _loadContent(_currentTabIndex, refresh: true);
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _homeTypeFontSize = prefs.getDouble('home_type_font_size') ?? 14;
    });
  }

  // ── 缓存读写 ──
  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();

    // Tabs
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

    // Banner
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

    // HotWords
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

    // Announcements
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

    // Content cache for each tab
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

    // 修复：确保 _currentTabIndex 不超出范围
    if (_tabs.isNotEmpty && _currentTabIndex >= _tabs.length) {
      _currentTabIndex = 0;
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();

    // Tabs
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

    // Banner
    if (_bannerList.isNotEmpty) {
      await prefs.setString(
        _cacheKeyBanner,
        jsonEncode({
          'time': DateTime.now().toIso8601String(),
          'list': _bannerList,
        }),
      );
    }

    // HotWords
    if (_hotWords.isNotEmpty) {
      await prefs.setString(
        _cacheKeyHotWords,
        jsonEncode({
          'time': DateTime.now().toIso8601String(),
          'words': _hotWords,
        }),
      );
    }

    // Announcements
    if (_announcements.isNotEmpty) {
      await prefs.setString(
        _cacheKeyAnnouncements,
        jsonEncode({
          'time': DateTime.now().toIso8601String(),
          'list': _announcements,
        }),
      );
    }

    // Content cache
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
  Future<void> _loadTabs() async {
    setState(() => _isLoadingTabs = true);
    try {
      final api = context.read<MacApi>();
      // 使用 getAppInit 获取分类列表（优先使用插件接口）
      final initData = await api.getAppInit();
      final list = initData['type_list'] as List<dynamic>? ?? [];
      
      if (list.isNotEmpty) {
        _tabs = ['推荐', ...list.map((e) => e['type_name'].toString())];
        _tabIds = [0, ...list.map((e) => int.tryParse('${e['type_id']}') ?? 0)];

        _tabController = TabController(length: _tabs.length, vsync: this);
        _tabController.addListener(_onTabChanged);

        // 加载推荐内容
        _loadContent(0, refresh: true);
        _loadBanner();
        _loadHotWords();
        _loadAnnouncements(initData['notice']);

        _saveCache();
      } else {
        // 修复：如果分类列表为空，设置一个默认的推荐分类，避免 TabBarView 崩溃
        _tabs = ['推荐'];
        _tabIds = [0];
        _tabController = TabController(length: _tabs.length, vsync: this);
        _tabController.addListener(_onTabChanged);
        _loadContent(0, refresh: true);
      }
    } catch (e) {
      debugPrint('加载分类失败: $e');
      // 修复：异常时也设置默认分类，避免 TabBarView 崩溃
      _tabs = ['推荐'];
      _tabIds = [0];
      _tabController = TabController(length: _tabs.length, vsync: this);
      _tabController.addListener(_onTabChanged);
      _loadContent(0, refresh: true);
    } finally {
      setState(() => _isLoadingTabs = false);
    }
  }

  // ── 加载轮播图 ──
  Future<void> _loadBanner() async {
    try {
      final api = context.read<MacApi>();
      // 使用 getBanner 获取轮播图（优先使用插件接口）
      final bannerList = await api.getBanner();
      if (bannerList.isNotEmpty) {
        setState(() {
          _bannerList = bannerList;
        });
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
      // 使用 getHotKeywords 获取热词（优先使用插件接口）
      final keywords = await api.getHotKeywords();
      if (keywords.isNotEmpty) {
        setState(() {
          _hotWords = keywords;
        });
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
        setState(() {
          _announcements = [notice];
        });
        _saveCache();
        return;
      }

      final api = context.read<MacApi>();
      final initData = await api.getAppInit();
      final n = initData['notice'];
      if (n != null) {
        setState(() {
          _announcements = [n];
        });
        _saveCache();
      }
    } catch (e) {
      debugPrint('加载通知失败: $e');
    }
  }

  // ── Tab 切换 ──
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;

    final index = _tabController.index;
    if (index == _currentTabIndex) return;

    // 防抖
    _tabDebounce?.cancel();
    _tabDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _currentTabIndex = index);
      _loadContent(index, refresh: true);
    });
  }

  // ── 加载内容 ──
  Future<void> _loadContent(int index, {bool refresh = false}) async {
    if (_isLoadingContent && _loadingIndex == index) return;

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

      // 检查缓存
      if (!refresh &&
          _contentCache.containsKey(index) &&
          _contentCache[index]!.isNotEmpty) {
        // 数据已经在缓存中，_buildContentList 会直接读取缓存
        setState(() {});
        return;
      }

      List<dynamic> list = [];
      
      // 推荐页（index == 0）优先使用 getAppInit 返回的 recommend_list
      if (index == 0) {
        try {
          final initData = await api.getAppInit();
          final recommendList = initData['recommend_list'] as List<dynamic>? ?? [];
          if (recommendList.isNotEmpty) {
            list = recommendList;
          }
        } catch (e) {
          debugPrint('加载推荐列表失败: $e');
        }
      }
      
      // 如果没有推荐数据，使用 getFiltered 获取
      if (list.isEmpty) {
        final currentPage = _pageCache[index] ?? 1;
        list = await api.getFiltered(
          typeId: typeId == 0 ? null : typeId,
          page: currentPage,
          limit: 20,
          orderby: 'time',
        );
      }

      if (list.isNotEmpty) {
        setState(() {
          // 更新缓存，每个分类独立存储
          final existingList = refresh ? [] : (_contentCache[index] ?? []);
          _contentCache[index] = [...existingList, ...list];
          _hasMoreCache[index] = list.length >= 20;
          _pageCache[index] = (_pageCache[index] ?? 1) + 1;
        });

        _saveCache();
      } else {
        // 没有数据，标记为没有更多
        setState(() {
          _hasMoreCache[index] = false;
        });
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

  // ── 滚动监听 ──
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final hasMore = _hasMoreCache[_currentTabIndex] ?? true;
      if (!_isLoadingContent && hasMore) {
        _loadContent(_currentTabIndex);
      }
    }
  }

  // ── 下拉刷新 ──
  Future<void> _onRefresh() async {
    await _loadContent(_currentTabIndex, refresh: true);
    await _loadBanner();
    await _loadHotWords();
    await _loadAnnouncements();
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
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // ── 搜索栏 ──
              SliverToBoxAdapter(
                child: _buildSearchBar(isDark),
              ),

              // ── 分类 Tab ──
              SliverToBoxAdapter(
                child: _isLoadingTabs
                    ? _buildTabShimmer()
                    : _buildTabBar(isDark),
              ),

              // ── 轮播图（仅在推荐页显示） ──
              if (_currentTabIndex == 0 && _bannerList.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildBanner(),
                ),

              // ── 通知栏 ──
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
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _hotWords.isNotEmpty
                    ? '搜索: ${_hotWords[Random().nextInt(_hotWords.length)]}'
                    : '搜索你想看的视频...',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                  fontSize: 14,
                ),
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
                child: Text(
                  '热搜',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
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
        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        labelStyle: TextStyle(
          fontSize: _homeTypeFontSize,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: (_homeTypeFontSize - 2).clamp(10, 30),
          fontWeight: FontWeight.normal,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            width: 3,
            color: Theme.of(context).colorScheme.primary,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 12),
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
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 8,
          itemBuilder: (_, __) => Container(
            width: 60,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  // ── 轮播图 ──
  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SlideBanner(
          images: _bannerList.map((e) => (e['poster'] ?? e['image'] ?? e['vod_pic'] ?? '').toString()).toList(),
          onTap: (index) {
            final item = _bannerList[index];
            final vodId = '${item['id'] ?? item['vod_id'] ?? ''}';
            if (vodId.isEmpty || vodId == '0') return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailPage(vodId: vodId),
              ),
            );
          },
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
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.campaign,
            color: Theme.of(context).colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _announcements.isNotEmpty
                  ? _announcements[0]['title'].toString()
                  : '',
              style: TextStyle(
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── 内容列表 ──
  Widget _buildContentList(int index) {
    // 使用缓存中的数据，每个分类独立
    final contentList = _contentCache[index] ?? [];
    final hasMore = _hasMoreCache[index] ?? true;
    // 只有当前分类正在加载时才显示加载状态
    final isLoadingThisCategory = _isLoadingContent && _loadingIndex == index;
    
    return RefreshIndicator(
      key: _refreshKeys.putIfAbsent(index, () => GlobalKey<RefreshIndicatorState>()),
      onRefresh: _onRefresh,
      child: contentList.isEmpty && isLoadingThisCategory
          ? _buildContentShimmer()
          : contentList.isEmpty
              ? _buildEmptyView()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: contentList.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= contentList.length) {
                      return _buildLoadMoreIndicator();
                    }
                    return _buildContentCard(contentList[i]);
                  },
                ),
    );
  }

  // ── 内容卡片 ──
  Widget _buildContentCard(dynamic item) {
    return GestureDetector(
      onTap: () {
        final vodId = item['id']?.toString() ?? '';
        if (vodId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailPage(vodId: vodId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item['poster'] ?? '',
                width: 120,
                height: 160,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[200],
                  width: 120,
                  height: 160,
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  width: 120,
                  height: 160,
                  child: const Icon(Icons.movie),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item['year'] ?? ''} · ${item['area'] ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '导演: ${item['director'] ?? '未知'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '主演: ${item['actor'] ?? '未知'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 骨架屏 ──
  Widget _buildContentShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
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
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无内容',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ── 加载更多指示器 ──
  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
