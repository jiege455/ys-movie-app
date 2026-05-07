import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/store.dart';
import 'detail_page.dart';

/**
/// 开发者：杰哥
/// 作用：播放记录页面
/// 解释：显示你看过的片子，点一下接着看
 */
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes";
    }
    return "$twoDigitMinutes:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Future<void> _loadHistory() async {
    // 每次进入页面都重新加载最新数据
    final list = await StoreService.getHistory();
    // list items are "id|title|poster|url|timestamp|position"
    final parsed = list.map((e) {
      final parts = e.split('|');
      if (parts.length < 3) return null;
      String progress = '';
      if (parts.length > 5) {
         try {
           final sec = int.parse(parts[5]);
           if (sec > 0) progress = '观看至 ${_formatDuration(Duration(seconds: sec))}';
         } catch (_) {}
      }
      
      return {
        'id': parts[0],
        'title': parts[1],
        'poster': parts[2],
        'time': parts.length > 4 ? parts[4] : '',
        'progress': progress,
      };
    }).whereType<Map<String, String>>().toList();
    
    if (mounted) {
      setState(() {
        _history = parsed;
      });
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放记录', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await StoreService.clearHistory();
              _loadHistory();
            },
          ),
        ],
      ),
      body: _history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text('暂无播放记录', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (ctx, i) {
                final item = _history[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: item['poster']!,
                        width: 50,
                        height: 70,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                        errorWidget: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.movie)),
                      ),
                    ),
                    title: Text(
                      item['title']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item['progress'] != null && item['progress']!.isNotEmpty)
                            Text(item['progress']!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                          Text(
                            '上次观看于${_formatTime(item['time'])}',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ),
                    trailing: Icon(Icons.play_circle_outline, color: Theme.of(context).colorScheme.primary),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(vodId: item['id']!)));
                    },
                  ),
                );
              },
            ),
    );
  }
}
