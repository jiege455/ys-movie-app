import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api.dart';
import 'detail_page.dart';

class WeekPage extends StatefulWidget {
  final String title;
  const WeekPage({super.key, this.title = '每周排期'});

  @override
  State<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends State<WeekPage> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final List<int> _weeks = [1, 2, 3, 4, 5, 6, 7];
  final List<String> _weekNames = const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  
  // 自动定位到今天
  int _initialIndex = 0;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday; // 1=Mon, 7=Sun
    _initialIndex = today - 1;
    _tabCtrl = TabController(length: _weeks.length, vsync: this, initialIndex: _initialIndex);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: isDark ? Theme.of(context).cardColor : Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white70 : Colors.black87,
              indicatorSize: TabBarIndicatorSize.label,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: Theme.of(context).colorScheme.primary,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: _weekNames.map((e) {
                return Tab(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    child: Text(e),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: _weeks.map((w) => _WeekList(week: w)).toList(),
      ),
    );
  }
}

class _WeekList extends StatefulWidget {
  final int week;
  const _WeekList({required this.week});

  @override
  State<_WeekList> createState() => _WeekListState();
}

class _WeekListState extends State<_WeekList> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      final list = await api.getVodWeekList(week: widget.week, page: 1);
      if (!mounted) return;
      setState(() => _items = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('暂无排期数据', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('刷新')),
          ],
        ),
      );
    }
    
    // 使用 GridView 展示封面
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final it = _items[i];
          final title = (it['title'] ?? '').toString();
          final remarks = (it['overview'] ?? '').toString();
          final poster = (it['poster'] ?? '').toString();
          
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailPage(vodId: (it['id'] ?? '').toString())),
              );
            },
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
                          imageUrl: poster,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                          errorWidget: (_, __, ___) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.broken_image)),
                        ),
                        if (remarks.isNotEmpty)
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.black87],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Text(
                                remarks,
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
