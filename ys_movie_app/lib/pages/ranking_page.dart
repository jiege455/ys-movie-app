import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api.dart';
import 'detail_page.dart';
// by：杰哥 
// qq： 2711793818

/**
 * 开发者：杰哥
 * 作用：排行榜页面，实现日榜、周榜、月榜切换
 * 小白解释：这里看大家都在看什么，分今天、这周、这月最火的。
 */
class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> with SingleTickerProviderStateMixin {
  final List<String> _tabs = ['日榜', '周榜', '月榜'];
  TabController? _tabController;
  bool _loadingSetting = true;
  int _rankListType = 0;
  List<Map<String, dynamic>> _typeList = const [];
  int _selectedTypeId = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSetting();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadSetting() async {
    try {
      final api = context.read<MacApi>();
      final initData = await api.getAppInit();
      final rawPageSetting = initData['app_page_setting'];
      int rankType = 0;
      if (rawPageSetting is Map) {
        final inner = (rawPageSetting['app_page_setting'] is Map)
            ? (rawPageSetting['app_page_setting'] as Map)
            : rawPageSetting;
        rankType = int.tryParse('${inner['app_page_rank_list_type'] ?? 0}') ?? 0;
      }

      List<Map<String, dynamic>> types = [];
      final rawTypeList = initData['type_list'];
      if (rawTypeList is List) {
        types = rawTypeList
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .where((e) => (int.tryParse('${e['type_id'] ?? 0}') ?? 0) > 0)
            .toList();
      }

      final selectedId = (types.isNotEmpty)
          ? (int.tryParse('${types.first['type_id'] ?? 0}') ?? 0)
          : 0;

      if (!mounted) return;
      setState(() {
        _rankListType = rankType;
        _typeList = types;
        _selectedTypeId = selectedId;
        _loadingSetting = false;

        if (_rankListType == 0) {
          _tabController ??= TabController(length: _tabs.length, vsync: this);
        } else {
          _tabController?.dispose();
          _tabController = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSetting = false;
      });
    }
  }

  String _rankOrderBy() {
    if (_rankListType == 1) return 'hits_day';
    if (_rankListType == 2) return 'hits_week';
    if (_rankListType == 3) return 'hits_month';
    if (_rankListType == 4) return 'hits';
    return 'hits_week';
  }

  @override
  Widget build(BuildContext context) {
    final tabCtrl = _tabController;
    final primaryColor = Theme.of(context).colorScheme.primary;
    // 开发者：杰哥网络科技 (qq: 2711793818)
    // 修复：统一使用 scaffoldBackgroundColor，与首页/我的页面保持一致
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        // 修复：移除渐变背景，使用纯色与首页/我的页面保持一致
        color: bgColor,
        child: SafeArea(
          child: Column(
            children: [
              // 顶部标题（移除搜索框）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '排行榜',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              if (_loadingSetting)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_rankListType == 0 && tabCtrl != null) ...[
                Container(
                  height: 48,
                  alignment: Alignment.center,
                  child: TabBar(
                    controller: tabCtrl,
                    labelColor: primaryColor,
                    unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                    indicatorColor: primaryColor,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    tabs: _tabs.map((e) => Tab(text: e)).toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: tabCtrl,
                    children: const [
                      _RankingList(orderBy: 'hits_day'),
                      _RankingList(orderBy: 'hits_week'),
                      _RankingList(orderBy: 'hits_month'),
                    ],
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      // 开发者：杰哥网络科技 (qq: 2711793818)
                      // 修复：使用主题色，避免硬编码白色
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF15202B) : Colors.white.withAlpha((255 * 0.7).round()),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: _selectedTypeId == 0 ? null : _selectedTypeId,
                              hint: const Text('选择分类'),
                              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                              dropdownColor: isDark ? const Color(0xFF15202B) : Colors.white,
                              items: _typeList.map((t) {
                                final id = int.tryParse('${t['type_id'] ?? 0}') ?? 0;
                                final name = (t['type_name'] ?? '').toString();
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _selectedTypeId = v);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 开发者：杰哥网络科技 (qq: 2711793818)
                      // 修复：使用主题色，避免硬编码白色
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF15202B) : Colors.white.withAlpha((255 * 0.7).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _rankListType == 4 ? '总榜' : (_rankListType == 1 ? '日榜' : (_rankListType == 2 ? '周榜' : '月榜')),
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _RankingList(
                    orderBy: _rankOrderBy(),
                    typeId: _selectedTypeId == 0 ? null : _selectedTypeId,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingList extends StatefulWidget {
  final String orderBy;
  final int? typeId;
  const _RankingList({required this.orderBy, this.typeId});

  @override
  State<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends State<_RankingList> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 延时一下等待 Context 稳定，特别是刚进入页面时
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    
    final api = context.read<MacApi>();
    // 首次加载显示 loading，后续刷新不全屏 loading
    if (items.isEmpty) setState(() => loading = true);
    
    try {
      // 这里的 typeId 可以根据实际情况调整，不传就是全部分类
      List<Map<String, dynamic>> res = await api.getFiltered(
        typeId: widget.typeId,
        orderby: widget.orderBy,
        limit: 20,
      );
      
      // 自动降级：如果日榜/周榜无数据，尝试获取全部（hits）避免空白
      if (res.isEmpty && widget.orderBy.contains('_')) {
        print('Rank empty for ${widget.orderBy}, fallback to total hits');
        res = await api.getFiltered(
          typeId: widget.typeId,
          orderby: 'hits',
          limit: 20,
        );
      }
      
      if (mounted) {
        setState(() {
          items = res;
        });
      }
    } catch (e) {
      print('Rank Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!loading && items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!loading && items.isEmpty) {
          setState(() {
            loading = true;
          });
          _loadData();
        }
      });
    }
    if (loading) return const Center(child: CircularProgressIndicator());
    
    // 即使为空也允许刷新
    Widget content;
    if (items.isEmpty) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_dissatisfied, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('暂无数据，请尝试刷新', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            // 开发者：杰哥网络科技 (qq: 2711793818)
            // 修复：使用主题色，避免硬编码紫色
            ElevatedButton.icon(
              onPressed: () {
                 setState(() => loading = true);
                 _loadData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('点我刷新'),
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 20, left: 16, right: 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vodId: item['id']))),
            child: // 开发者：杰哥网络科技 (qq: 2711793818)
              // 修复：使用主题色，避免硬编码白色
              Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 140,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.05).round()),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 海报
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                    child: CachedNetworkImage(
                      imageUrl: item['poster'],
                      width: 100,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey[200]),
                      errorWidget: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.movie)),
                    ),
                  ),
                  // 信息
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // 开发者：杰哥网络科技 (qq: 2711793818)
                          // 修复：使用主题文字颜色
                          Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                          Text('评分：${item['score']}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                          Text(
                            [
                              if ((item['year'] ?? '').toString().isNotEmpty) '${item['year']}',
                              if ((item['area'] ?? '').toString().isNotEmpty) '${item['area']}',
                              if ((item['lang'] ?? '').toString().isNotEmpty) '${item['lang']}',
                            ].join('/'),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            (() {
                              final raw = (item['overview'] ?? '').toString();
                              final base = raw.isEmpty ? '暂无简介' : raw;
                              final noTags = base.replaceAll(RegExp(r'<[^>]*>'), '');
                              return noTags
                                  .replaceAll('&nbsp;', ' ')
                                  .replaceAll('&amp;', '&')
                                  .replaceAll('&quot;', '"')
                                  .replaceAll('&#39;', '\'');
                            })(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          if ((item['actor'] ?? '').toString().isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _splitActors(item['actor']).map((name) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E5F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(name, style: const TextStyle(fontSize: 10, color: Color(0xFF6A1B9A))),
                                );
                              }).toList(),
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
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Stack(
        children: [
          // 确保 ListView 充满以支持下拉
          items.isEmpty ? ListView(children: [SizedBox(height: MediaQuery.of(context).size.height, child: content)]) : content,
        ],
      ),
    );
  }

  List<String> _splitActors(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return const [];
    final parts = s
        .replaceAll('主演：', '')
        .replaceAll('主演:', '')
        .split(RegExp(r'[、,，\\s]+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return parts.take(4).toList();
  }
}
