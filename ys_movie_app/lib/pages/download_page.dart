/// 文件名：download_page.dart
/// 开发者：杰哥网络科技（by：杰哥 / qq：2711793818）
/// 创建日期：2025-01-03 | 修复日期：2026-05-06
/// 作用：下载管理页面
/// 功能：展示所有下载任务、实时刷新进度、取消下载、播放已缓存视频

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../services/m3u8_downloader_service.dart';
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
  StreamSubscription<DownloadEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _load();
    _listenToDownloadEvents();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  void _listenToDownloadEvents() {
    final downloader = M3u8DownloaderService();
    _eventSub = downloader.downloadEventStream.listen((event) {
      if (!mounted) return;

      final idx = _tasks.indexWhere(
          (t) => (t['id'] ?? '').toString() == event.taskId);

      if (idx >= 0) {
        setState(() {
          _tasks[idx]['progress'] = event.progress;
          _tasks[idx]['status'] = event.status;
          _tasks[idx]['speed'] = event.speed;
          if (event.savePath != null && event.savePath!.isNotEmpty) {
            _tasks[idx]['savePath'] = event.savePath;
          }
        });

        if (event.status == 'done' || event.status == 'failed') {
          _persistTask(_tasks[idx]);
        }
      } else {
        _load();
      }
    });
  }

  Future<void> _load() async {
    final raw = await StoreService.getDownloads();
    final downloader = M3u8DownloaderService();
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

      if (status == 'downloading' && !downloader.isDownloading(id)) {
        await StoreService.upsertDownload({
          'id': id,
          'title': title,
          'poster': poster,
          'url': url,
          'savePath': savePath,
          'progress': 0,
          'status': 'cancelled',
          'speed': '下载中断',
          'ts': ts,
        });
      }

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

  Future<void> _persistTask(Map<String, dynamic> task) async {
    await StoreService.upsertDownload(task);
  }

  bool _isActuallyDownloading(String taskId) {
    if (taskId.isEmpty) return false;
    return M3u8DownloaderService().isDownloading(taskId);
  }

  Future<void> _clearAll() async {
    if (_tasks.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('确认清空'),
          content: const Text('确定清空全部下载任务吗？\n正在下载的任务将被取消。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: AppColors.primaryLight),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    final downloader = M3u8DownloaderService();
    for (final task in _tasks) {
      final id = (task['id'] ?? '').toString();
      downloader.cancelDownload(id);
    }

    await StoreService.clearDownloads();
    if (!mounted) return;
    setState(() => _tasks.clear());
  }

  Future<void> _removeOne(Map<String, dynamic> task) async {
    final id = (task['id'] ?? '').toString();
    final status = (task['status'] ?? '').toString();
    if (id.isEmpty) return;

    if (_isActuallyDownloading(id)) {
      M3u8DownloaderService().cancelDownload(id);
    }

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

  Future<void> _cancelOne(Map<String, dynamic> task) async {
    final id = (task['id'] ?? '').toString();
    if (id.isEmpty) return;
    M3u8DownloaderService().cancelDownload(id);

    if (!mounted) return;
    setState(() {
      final idx =
          _tasks.indexWhere((t) => (t['id'] ?? '').toString() == id);
      if (idx >= 0) {
        _tasks[idx]['status'] = 'cancelled';
        _tasks[idx]['speed'] = '已取消';
      }
    });
    await StoreService.upsertDownload({
      'id': id,
      'title': task['title'] ?? '',
      'poster': task['poster'] ?? '',
      'url': task['url'] ?? '',
      'savePath': task['savePath'] ?? '',
      'progress': task['progress'] ?? 0,
      'status': 'cancelled',
      'speed': '已取消',
      'ts': task['ts'] ?? DateTime.now().millisecondsSinceEpoch,
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

  Color _statusColor(String status) {
    switch (status) {
      case 'downloading':
        return AppColors.primary;
      case 'failed':
        return AppColors.error;
      case 'cancelled':
        return AppColors.warning;
      case 'done':
        return AppColors.success;
      default:
        return AppColors.slate400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

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
              ? const Center(
                  child: Text('暂无下载任务',
                      style: TextStyle(color: AppColors.slate400)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    itemBuilder: (ctx, i) {
                      final t = _tasks[i];
                      final id = (t['id'] ?? '').toString();
                      final title = (t['title'] ?? '').toString();
                      final poster = (t['poster'] ?? '').toString();
                      final progress =
                          (t['progress'] as double?) ?? 0.0;
                      final status = (t['status'] ?? '').toString();
                      final speed = (t['speed'] ?? '').toString();
                      final isDownloading = _isActuallyDownloading(id) ||
                          status == 'downloading';

                      String vodId = id;
                      if (vodId.contains('_')) {
                        vodId = vodId.split('_').first;
                      }

                      return GestureDetector(
                        onTap: status == 'done'
                            ? () {
                                final sp =
                                    (t['savePath'] ?? '').toString();
                                if (sp.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetailPage(
                                        vodId: vodId,
                                        localPlayUrl: sp,
                                        initialTitle: title,
                                        initialPoster: poster,
                                      ),
                                    ),
                                  );
                                }
                              }
                            : vodId.isEmpty
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DetailPage(vodId: vodId),
                                      ),
                                    );
                                  },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(10),
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
                                  placeholder: (_, __) =>
                                      Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.movie),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            _statusText(status),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  _statusColor(status),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            speed,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        value:
                                            progress.clamp(0.0, 1.0),
                                        minHeight: 6,
                                        color: isDownloading
                                            ? primaryColor
                                            : _statusColor(status),
                                        backgroundColor:
                                            primaryColor.withOpacity(0.1),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${(progress * 100).clamp(0, 100).round()}%',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (status == 'done')
                                          Text(
                                            '点击播放',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: primaryColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isDownloading)
                                IconButton(
                                  tooltip: '取消下载',
                                  icon: Icon(Icons.cancel,
                                      color: AppColors.error),
                                  onPressed: () => _cancelOne(t),
                                )
                              else
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
