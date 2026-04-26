import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';

/**
 * 开发者：杰哥
 * 作用：详情页，展示标题、简介、类型、评分，并进入播放页
 * 解释：点卡片后的页面，可以点“播放”。
 */
class DetailPage extends StatefulWidget {
  final String vodId;
  const DetailPage({super.key, required this.vodId});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Map<String, dynamic>? detail;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final api = context.read<MacApi>();
    setState(() => loading = true);
    try {
      detail = await api.getDetail(widget.vodId);
    } finally {
      setState(() => loading = false);
    }
  }

  void _goPlay() {
    Navigator.pushNamed(context, '/player/${widget.vodId}');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.red)));
    }
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('详情')),
        body: const Center(child: Text('未找到该视频')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                (detail!['poster'] as String?)?.isNotEmpty == true
                    ? detail!['poster'] as String
                    : 'https://via.placeholder.com/500x750?text=No+Image',
                height: 240,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            // 标题与评分
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(detail!['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                Text('⭐ ${(detail!['score'] as double).toStringAsFixed(1)}', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            // 简介
            Text(detail!['overview'] ?? '暂无简介', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            // 播放按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _goPlay,
                icon: const Icon(Icons.play_arrow),
                label: const Text('立即播放'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
