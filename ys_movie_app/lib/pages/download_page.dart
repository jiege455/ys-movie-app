import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/store.dart';
import 'detail_page.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await StoreService.getDownloads();
    final list = <Map<String, dynamic>>[];
    for (final e in raw) {
      final parts = e.split('|');
      if (parts.length < 4) continue;
      final id = parts[0];
      final title = parts.length > 1 ? parts[1] : '';
      final poster = parts.length > 2 ? parts[2] : '';
      final url = parts.length > 3 ? parts[3] : '';
      final savePath = parts.length > 4 ? parts[4] : '';
      final progress = double.tryParse(parts.length > 5 ? parts[5] : '') ?? 0.0;
      final status = parts.length > 6 ? parts[6] : '';
      final speed = parts.length > 7 ? parts[7] : '';
      final ts = int.tryParse(parts.length > 8 ? parts[8] : '') ?? 0;
      list.add({
        'id': id,
        'title': title,
        'poster': poster,
        'url': url,
        'savePath': savePath,
        'progress': progress.clamp(0.0, 1.0),
        'status': status,
        'speed': speed,
        'ts': ts,
      });
    }
    list.sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));
    if (!mounted) return;
    setState(() {
      _tasks = list;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    if (_tasks.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('确认清空'),
          content: const Text('确定清空全部下载任务吗？\n不会影响已缓存的视频。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C27B0), foregroundColor: Colors.white),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await StoreService.clearDownloads();
    if (!mounted) return;
    setState(() => _tasks.clear());
  }

  Future<void> _removeOne(Map<String, dynamic> task) async {
    final id = (task['id'] ?? '').toString();
    if (id.isEmpty) return;
    final savePath = (task['savePath'] ?? '').toString();
    await StoreService.removeDownload(id);
    if (savePath.isNotEmpty) {
      try {
        final f = File(savePath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _tasks.removeWhere((e) => (e['id'] ?? '').toString() == id);
    });
  }

  String _statusText(String status) {
    switch (status) {
      case 'downloading':
        return '下载中';
      case 'failed':
        return '失败';
      case 'cancelled':
        return '已取消';
      case 'done':
        return '已完成';
      default:
        return status.isEmpty ? '未知' : status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载管理'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Text('暂无下载任务', style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF9C27B0),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    itemBuilder: (ctx, i) {
                      final t = _tasks[i];
                      final id = (t['id'] ?? '').toString();
                      final title = (t['title'] ?? '').toString();
                      final poster = (t['poster'] ?? '').toString();
                      final progress = (t['progress'] as double?) ?? 0.0;
                      final status = (t['status'] ?? '').toString();
                      final speed = (t['speed'] ?? '').toString();

                      String vodId = id;
                      if (vodId.contains('_')) vodId = vodId.split('_').first;

                      return GestureDetector(
                        onTap: vodId.isEmpty
                            ? null
                            : () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vodId: vodId)));
                              },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha((255 * 0.06).round()), blurRadius: 8),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: poster,
                                  width: 56,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: Colors.grey[200]),
                                  errorWidget: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.movie)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3E5F5),
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            _statusText(status),
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF9C27B0)),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            speed,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        value: status == 'downloading' ? progress.clamp(0.0, 1.0) : progress.clamp(0.0, 1.0),
                                        minHeight: 6,
                                        color: const Color(0xFF9C27B0),
                                        backgroundColor: const Color(0xFFF3E5F5),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(progress * 100).clamp(0, 100).round()}%',
                                      style: const TextStyle(fontSize: 11, color: Colors.black45),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '移除',
                                icon: const Icon(Icons.close),
                                onPressed: () => _removeOne(t),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

