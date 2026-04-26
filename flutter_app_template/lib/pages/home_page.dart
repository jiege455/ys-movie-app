import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';

/**
 * 开发者：杰哥
 * 作用：首页，展示热门视频，顶部搜索，三列卡片网格
 * 解释：打开APP第一个页面，看热门的，搜想看的。
 */
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> items = [];
  bool loading = false;
  String keyword = '';

  @override
  void initState() {
    super.initState();
    _loadHot();
  }

  /// 拉热门数据：小白理解为“去后台拿二十条”
  Future<void> _loadHot() async {
    final api = context.read<MacApi>();
    setState(() => loading = true);
    try {
      items = await api.getHot(page: 1);
    } finally {
      setState(() => loading = false);
    }
  }

  /// 搜索：小白理解为“按名字找”
  Future<void> _search() async {
    if (keyword.trim().isEmpty) return;
    final api = context.read<MacApi>();
    setState(() => loading = true);
    try {
      items = await api.searchByName(keyword.trim());
    } finally {
      setState(() => loading = false);
    }
  }

  void _goDetail(String id) {
    Navigator.pushNamed(context, '/detail/$id');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶部搜索
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '搜影视、演员…',
                  filled: true,
                  fillColor: Color(0xFFF3F4F6),
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(999))),
                ),
                onChanged: (v) => keyword = v,
                onSubmitted: (_) => _search(),
              ),
            ),
            // 内容区
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.red))
                  : items.isEmpty
                      ? const Center(child: Text('暂无数据'))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2 / 3,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final it = items[i];
                            return GestureDetector(
                              onTap: () => _goDetail(it['id']),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 封面
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        (it['poster'] as String?)?.isNotEmpty == true
                                            ? it['poster'] as String
                                            : 'https://via.placeholder.com/300x450?text=No+Image',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // 标题
                                  Text(
                                    it['title'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  // 年份与评分
                                  Text(
                                    '${it['year'] ?? ''}  ⭐ ${((it['score'] ?? 0) as double).toStringAsFixed(1)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      // 底部导航（占位）
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.red,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '发现'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: '分类'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
