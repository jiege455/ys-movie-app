import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api.dart';
import 'vod_list_page.dart';

class TopicPage extends StatefulWidget {
  final String title;
  const TopicPage({super.key, this.title = '专题'});

  @override
  State<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends State<TopicPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _topics = [];

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
      final list = await api.getTopicList(page: 1);
      if (!mounted) return;
      setState(() => _topics = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openTopic(Map<String, dynamic> topic) async {
    final id = int.tryParse('${topic['id'] ?? 0}') ?? 0;
    if (id <= 0) return;
    final api = context.read<MacApi>();
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final vods = await api.getTopicVodList(topicId: id, page: 1);
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      
      if (vods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该专题暂无内容')));
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VodListPage(title: (topic['title'] ?? '专题').toString(), items: vods),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _topics.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('暂无专题')),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, // 两列布局
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.2, // 横向卡片比例
                      ),
                      itemCount: _topics.length,
                      itemBuilder: (ctx, i) {
                        final t = _topics[i];
                        final title = (t['title'] ?? '').toString();
                        final overview = (t['overview'] ?? '').toString();
                        final poster = (t['poster'] ?? '').toString();
                        
                        return GestureDetector(
                          onTap: () => _openTopic(t),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Row(
                              children: [
                                AspectRatio(
                                  aspectRatio: 1.0,
                                  child: CachedNetworkImage(
                                    imageUrl: poster,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: const Center(child: Icon(Icons.image, size: 20, color: AppColors.slate400)),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: const Center(child: Icon(Icons.broken_image, size: 20, color: AppColors.slate400)),
                                    ),
                                  ),
                                ),
                                
                                // Text (Right)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14, 
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Expanded(
                                          child: Text(
                                            overview.isEmpty ? '暂无简介' : overview,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? AppColors.slate400 : AppColors.slate400,
                                              height: 1.2,
                                            ),
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
                      },
                    ),
            ),
    );
  }
}