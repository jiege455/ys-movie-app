import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api.dart';
import '../services/store.dart';
import 'detail_page.dart';

/**
/// 开发者：杰哥
/// 作用：搜索页面，包含热搜词和搜索结果
/// 解释：专门用来找片子的地方，输入名字就能搜出来�?
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
  bool _searched = false; // 是否执行过搜�?

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

  // 加载热搜�?
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
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: _doSearch,
            autofocus: true,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: '请输入影片名...',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
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

    // 如果还没搜索，显示热�?
    if (!_searched) {
      return _buildSearchLanding();
    }

    // 如果搜了没结�?
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('暂无资源', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
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
                    placeholder: (_, __) => Container(color: isDark ? AppColors.darkElevated : AppColors.slate200),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? AppColors.darkElevated : AppColors.slate200,
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
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          [
                            if ((item['year'] ?? '').toString().isNotEmpty) '${item['year']}',
                            if ((item['area'] ?? '').toString().isNotEmpty) '${item['area']}',
                            if ((item['lang'] ?? '').toString().isNotEmpty) '${item['lang']}',
                          ].join('/'),
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate300 : AppColors.slate400),
                        ),
                        Text(
                          item['overview']
                              .toString()
                              .replaceAll(RegExp(r'<[^>]*>'), ''), // 去除HTML标签
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate500 : AppColors.slate400),
                        ),
                        if ((item['actor'] ?? '').toString().isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _splitActors(item['actor']).map((name) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.slate700.withOpacity(0.12) : Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
          // 1. 大家都在�?(Hot Search) - Top
          if (_hotKeywords.isNotEmpty) ...[
            const Text('大家都在�?, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(_hotKeywords.length, (index) {
                final keyword = _hotKeywords[index];
                // 生成随机鲜艳颜色
                final color = [
                  AppColors.error, AppColors.warning, AppColors.primary, 
                  AppColors.success, AppColors.primaryDark, AppColors.primaryAccent, 
                  AppColors.primaryLight, AppColors.warning
                ][index % 8].withOpacity(0.15);
                final textColor = [
                  AppColors.error, AppColors.warning, AppColors.primary, 
                  AppColors.success, AppColors.primaryDark, AppColors.primaryAccent, 
                  AppColors.primaryLight, AppColors.warning
                ][index % 8];

                return InkWell(
                  onTap: () => _doSearch(keyword),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate700.withOpacity(0.1) : color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      keyword, 
                      style: TextStyle(
                        color: isDark ? AppColors.slate300 : textColor,
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
                  leading: const Icon(Icons.history, size: 20, color: AppColors.slate400),
                  title: Text(kw, style: TextStyle(color: isDark ? AppColors.slate300 : AppColors.slate900)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.slate400),
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
        .replaceAll('主演�?, '')
        .replaceAll('主演:', '')
        .split(RegExp(r'[�?，\s]+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return parts.take(6).toList();
  }
}
