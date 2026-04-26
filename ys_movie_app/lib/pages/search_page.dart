import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api.dart';
import '../services/store.dart';
import 'detail_page.dart';

/**
 * 开发者：杰哥
 * 作用：搜索页面，包含热搜词和搜索结果
 * 解释：专门用来找片子的地方，输入名字就能搜出来。
 */
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<String> _hotKeywords = [];
  List<String> _histories = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false; // 是否执行过搜索

  @override
  void initState() {
    super.initState();
    _loadHotKeywords();
    _loadHistories();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 加载热搜词
  Future<void> _loadHotKeywords() async {
    final api = context.read<MacApi>();
    try {
      final keywords = await api.getHotKeywords();
      if (mounted) {
        setState(() {
          _hotKeywords = keywords;
        });
      }
    } catch (e) {
      print('Load Hot Keywords Error: $e');
    }
  }

  // 加载搜索历史
  Future<void> _loadHistories() async {
    _histories = await StoreService.getSearchHistory();
    if (mounted) setState(() {});
  }

  // 执行搜索
  Future<void> _doSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;
    
    // 如果是点击热搜词，填入输入框
    if (_controller.text != keyword) {
      _controller.text = keyword;
    }

    setState(() {
      _loading = true;
      _searched = true;
      _results = [];
    });

    // 收起键盘
    FocusScope.of(context).unfocus();

    // 保存搜索历史
    await StoreService.addSearchKeyword(keyword);
    await _loadHistories();

    final api = context.read<MacApi>();
    try {
      final results = await api.searchByName(keyword);
      if (mounted) {
        setState(() {
          _results = results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? Colors.white12 : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: _doSearch,
            autofocus: true,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: '请输入影片名...',
              hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey),
              contentPadding: const EdgeInsets.only(top: 8), // 微调垂直位置
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _doSearch(_controller.text),
            child: Text('搜索', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 如果还没搜索，显示热搜
    if (!_searched) {
      return _buildSearchLanding();
    }

    // 如果搜了没结果
    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无资源', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // 显示结果列表
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailPage(vodId: item['id']),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 140,
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Colors.white,
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
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: item['poster'],
                    width: 100,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: const Icon(Icons.movie),
                    ),
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
                        Text(
                          item['title'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text('评分：${item['score']}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                        Text(
                          [
                            if ((item['year'] ?? '').toString().isNotEmpty) '${item['year']}',
                            if ((item['area'] ?? '').toString().isNotEmpty) '${item['area']}',
                            if ((item['lang'] ?? '').toString().isNotEmpty) '${item['lang']}',
                          ].join('/'),
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey),
                        ),
                        Text(
                          item['overview']
                              .toString()
                              .replaceAll(RegExp(r'<[^>]*>'), ''), // 去除HTML标签
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                        ),
                        if ((item['actor'] ?? '').toString().isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _splitActors(item['actor']).map((name) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white12 : const Color(0xFFF3E5F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(name, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary)),
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

  Widget _buildSearchLanding() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 大家都在搜 (Hot Search) - Top
          if (_hotKeywords.isNotEmpty) ...[
            const Text('大家都在搜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(_hotKeywords.length, (index) {
                final keyword = _hotKeywords[index];
                // 生成随机鲜艳颜色
                final color = [
                  Colors.redAccent, Colors.orangeAccent, Colors.blueAccent, 
                  Colors.greenAccent, Colors.purpleAccent, Colors.teal, 
                  Colors.pinkAccent, Colors.amber
                ][index % 8].withOpacity(0.15);
                final textColor = [
                  Colors.red, Colors.orange[800]!, Colors.blue, 
                  Colors.green[700]!, Colors.purple, Colors.teal[700]!, 
                  Colors.pink, Colors.amber[900]!
                ][index % 8];

                return InkWell(
                  onTap: () => _doSearch(keyword),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      keyword, 
                      style: TextStyle(
                        color: isDark ? Colors.white70 : textColor,
                        fontSize: 13,
                      )
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
          ],

          // 2. 搜索历史 (History) - Bottom, Vertical List
          if (_histories.isNotEmpty) ...[
            Row(
              children: [
                const Text('搜索历史', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await StoreService.clearSearchHistory();
                    _loadHistories();
                  },
                  child: Text('清空', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 0),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _histories.length,
              itemBuilder: (context, index) {
                final kw = _histories[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history, size: 20, color: Colors.grey),
                  title: Text(kw, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () async {
                      await StoreService.removeSearchKeyword(kw);
                      _loadHistories();
                    },
                  ),
                  onTap: () => _doSearch(kw),
                );
              },
            ),
          ],
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
        .split(RegExp(r'[、,，\s]+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return parts.take(6).toList();
  }
}
