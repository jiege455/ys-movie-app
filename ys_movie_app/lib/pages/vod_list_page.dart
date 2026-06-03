import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'detail_page.dart';
import '../services/store.dart';
import '../services/api.dart';
import 'dart:io';

/**
/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 作用：通用视频列表页，用于展示收藏、历史记录等
/// 修复：收藏页面支持长按删除和取消收藏
 */
class VodListPage extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onClear;

  const VodListPage({
    super.key,
    required this.title,
    required this.items,
    this.onClear,
  });

  @override
  State<VodListPage> createState() => _VodListPageState();
}

class _VodListPageState extends State<VodListPage> {
  late List<Map<String, dynamic>> _items;
  final Set<String> _selectedIds = {};
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(widget.items);
  }

  bool get _isCachePage {
    if (widget.title.contains('缓存')) return true;
    for (final it in _items) {
      final u = (it['url'] ?? '').toString();
      if (u.contains('JiegeMovie') || u.contains('\\') || u.contains('/')) {
        return true;
      }
    }
    return false;
  }

  bool get _isFavPage => widget.title.contains('收藏');

  String _cacheRootPath() {
    for (final it in _items) {
      final u = (it['url'] ?? '').toString();
      if (u.isEmpty) continue;
      try {
        final f = File(u);
        return f.parent.path;
      } catch (_) {
        return u;
      }
    }
    return '';
  }

  void _toggleSelectMode({bool? enabled}) {
    setState(() {
      _selectMode = enabled ?? !_selectMode;
      if (!_selectMode) _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) {
        _selectMode = false;
      }
    });
  }

  Future<bool> _confirmDelete({required int count}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text(_isCachePage
              ? '确定删除选中的 $count 条缓存记录吗？\n会同时尝试删除本地文件'
              : '确定取消选中的 $count 条收藏吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return ok ?? false;
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final ok = await _confirmDelete(count: _selectedIds.length);
    if (!ok) return;

    if (_isFavPage) {
      // 收藏页面：调用API取消收藏
      final api = context.read<MacApi>();
      for (final id in _selectedIds) {
        try {
          await api.deleteFavByVodId(id);
        } catch (_) {}
      }
    } else if (_isCachePage) {
      // 缓存页面：删除本地文件
      final ids = _selectedIds.toList();
      await StoreService.removeCaches(ids);

      for (final it in _items) {
        final id = (it['id'] ?? '').toString();
        if (!_selectedIds.contains(id)) continue;
        final u = (it['url'] ?? '').toString();
        if (u.isEmpty) continue;
        try {
          final f = File(u);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _items.removeWhere((it) => _selectedIds.contains((it['id'] ?? '').toString()));
      _selectedIds.clear();
      _selectMode = false;
    });
  }

  Future<void> _clearAllCache() async {
    if (_items.isEmpty) return;
    final ok = await _confirmDelete(count: _items.length);
    if (!ok) return;

    if (_isFavPage) {
      // 收藏页面：逐个取消收藏
      final api = context.read<MacApi>();
      for (final it in _items) {
        final id = (it['id'] ?? '').toString();
        if (id.isEmpty) continue;
        try {
          await api.deleteFavByVodId(id);
        } catch (_) {}
      }
    } else if (_isCachePage) {
      final ids = _items.map((e) => (e['id'] ?? '').toString()).where((e) => e.isNotEmpty).toList();
      await StoreService.removeCaches(ids);

      for (final it in _items) {
        final u = (it['url'] ?? '').toString();
        if (u.isEmpty) continue;
        try {
          final f = File(u);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _items.clear();
      _selectedIds.clear();
      _selectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rootPath = _cacheRootPath();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isCachePage || _isFavPage)
            IconButton(
              icon: Icon(_selectMode ? Icons.close : Icons.checklist),
              tooltip: _selectMode ? '退出多选' : '多选',
              onPressed: () => _toggleSelectMode(),
            ),
          if ((_isCachePage || _isFavPage) && !_selectMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: _isFavPage ? '清空收藏' : '清空缓存',
              onPressed: _clearAllCache,
            ),
          if ((_isCachePage || _isFavPage) && _selectMode)
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined),
              tooltip: _isFavPage ? '取消选中收藏' : '删除选中',
              onPressed: _deleteSelected,
            ),
          if (widget.onClear != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '清空',
              onPressed: widget.onClear,
            ),
        ],
      ),
      body: TexturedBackground(
        child: _items.isEmpty
            ? const Center(child: Text('暂无数据', style: TextStyle(color: AppColors.slate400)))
            : Column(
              children: [
                if (_isCachePage && rootPath.isNotEmpty)
                  Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
                    '存储路径：$rootPath',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      final id = (item['id'] ?? '').toString();
                      final selected = _selectedIds.contains(id);

                      void handleTap() {
                        if (_selectMode) {
                          _toggleSelected(id);
                          return;
                        }
                        final rawId = id;
                        final vodId = rawId.contains('_') ? rawId.split('_').first : rawId;
                        if (vodId.isEmpty) return;
                        final localUrl = _isCachePage ? (item['url'] ?? '').toString() : '';
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(
                          vodId: vodId,
                          localPlayUrl: localUrl.isNotEmpty ? localUrl : null,
                          initialTitle: (item['title'] ?? '').toString(),
                          initialPoster: (item['poster'] ?? '').toString(),
                        )));
                      }

                      return GestureDetector(
                        onLongPress: (_isCachePage || _isFavPage)
                            ? () {
                                if (!_selectMode) {
                                  setState(() {
                                    _selectMode = true;
                                    _selectedIds.add(id);
                                  });
                                }
                              }
                            : null,
                        onTap: handleTap,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          height: 100,
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: selected
                                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1)
                                : null,
                            boxShadow: selected ? [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                blurRadius: 6,
                              )
                            ] : [
                              BoxShadow(
                                color: Theme.of(context).dividerColor.withOpacity(0.3),
                                blurRadius: 4,
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              if (_isCachePage || _isFavPage)
                                Padding(
                                  padding: const EdgeInsets.only(left: 10, right: 6),
                                  child: Icon(
                                    selected ? Icons.check_circle : (_selectMode ? Icons.radio_button_unchecked : (_isFavPage ? Icons.favorite : Icons.download_done)),
                                    color: selected ? Theme.of(context).colorScheme.primary : (isDark ? AppColors.slate500 : AppColors.slate600),
                                  ),
                                ),
                              ClipRRect(
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                                child: CachedNetworkImage(
                                  imageUrl: (item['poster'] ?? '').toString(),
                                  width: 70,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (ctx, _) => Container(color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkElevated : AppColors.slate200),
                                  errorWidget: (ctx, _, ___) => Container(color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkElevated : AppColors.slate200, child: const Icon(Icons.movie)),
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
                                        (item['title'] ?? '').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                      ),
                                      const SizedBox(height: 6),
                                      if (item['progress'] != null)
                                        Text(
                                          '${item['progress']}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                                        ),
                                      if (_isCachePage)
                                        Text(
                                          (item['url'] ?? '').toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.slate500 : AppColors.slate600),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Icon(Icons.play_circle_outline, color: Theme.of(context).colorScheme.primary, size: 30),
                              const SizedBox(width: 16),
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
    );
  }
}
