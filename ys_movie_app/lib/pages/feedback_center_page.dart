/**
/// 文件名：feedback_center_page.dart
/// 作者：杰哥
/// 创建日期：2025-12-28
/// 说明：反馈报错、求片找片、消息中心（系统公告与个人消息）页面合集
/// by：杰哥  qq：2711793818
 */
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import '../services/api.dart';

/**
/// 开发者：杰哥
/// 作用：包含反馈、求片和消息中心的页面集合
/// 解释：这里打包了"反馈报错"、"求片找片"、"消息中心"三个功能页面
 */
class FeedbackPage extends StatefulWidget {
  final String? vodId;
  final String? vodName;
  const FeedbackPage({super.key, this.vodId, this.vodName});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _contentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.vodName != null) {
      _contentCtrl.text = '【视频报错】\n影片：${widget.vodName}\nID：${widget.vodId}\n问题描述：';
    }
  }

  /// 开发者：杰哥
  /// 作用：提交反馈到后端
  /// 解释：点"提交反馈"时把内容发给服务器
  Future<void> _submit() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入反馈内容')));
      return;
    }

    final api = context.read<MacApi>();
    
    // 检查登录
    final isLogin = await api.checkLogin();
    if (!isLogin) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }

    if (api.containsFilterWord(text)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('内容包含敏感词，请修改')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final ok = await api.sendSuggest(text);
      if (!mounted) return;
      if (ok) {
        _contentCtrl.clear();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('反馈已提交，感谢支持')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('提交失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('反馈报错'),
        // 使用主题默认配色
      ),
      body: TexturedBackground(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部提示卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withOpacity(0.30)),
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates, color: scheme.primary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '如遇播放卡顿、资源失效或有功能建议，请在此留言，我们会尽快处理',
                      style: TextStyle(fontSize: 14, color: scheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '问题描述',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withOpacity(0.12)),
              ),
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                expands: true,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  hintText: '请详细描述您遇到的问题，例如：\n1. 某部影片第几集无法播放\n2. 画面卡顿或声音不同步\n3. 希望增加的新功能...',
                  hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 4,
                ),
                child: _submitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                    : const Text('提交反馈', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/**
/// 开发者：杰哥
/// 作用：求片页面，把找不到的影片名称提交给后台
/// 解释：想看的片子这里报给后台，让站长帮你找
 */
class RequestMoviePage extends StatefulWidget {
  const RequestMoviePage({super.key});

  @override
  State<RequestMoviePage> createState() => _RequestMoviePageState();
}

class _RequestMoviePageState extends State<RequestMoviePage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  bool _submitting = false;

  /// 开发者：杰哥
  /// 作用：提交求片请求到后端
  /// 解释：把片名和备注发到服务器
  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final remark = _remarkCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入片名')));
      return;
    }

    final api = context.read<MacApi>();

    // 检查登录
    final isLogin = await api.checkLogin();
    if (!isLogin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录后提交求片')));
      return;
    }

    if (api.containsFilterWord(name) || api.containsFilterWord(remark)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('内容包含敏感词，请修改')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final ok = await api.sendFind(name: name, remark: remark);
      if (!mounted) return;
      if (ok) {
        _nameCtrl.clear();
        _remarkCtrl.clear();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('求片已提交，耐心等待处理')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('提交失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('求片找片'),
        // 使用主题默认配色
      ),
      body: TexturedBackground(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部提示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withOpacity(0.30)),
              ),
              child: Row(
                children: [
                  Icon(Icons.movie_filter, color: scheme.primary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '想看的片子找不到？告诉我片名，站长帮你找！\n提交后请留意消息中心的"求片回复"',
                      style: TextStyle(fontSize: 14, color: scheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('影片名称（必填）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withOpacity(0.12)),
              ),
              child: TextField(
                controller: _nameCtrl,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  hintText: '准确的片名更容易找到',
                  hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.search, color: scheme.onSurface.withOpacity(0.4)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('备注说明（选填）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withOpacity(0.12)),
              ),
              child: TextField(
                controller: _remarkCtrl,
                maxLines: null,
                expands: true,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  hintText: '例如：希望能有4K画质、国语配音、或者具体哪一集..',
                  hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 4,
                ),
                child: _submitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                    : const Text('提交求片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/**
/// 开发者：杰哥
/// 作用：消息中心，包括系统公告和个人消息
/// 解释：这里能看到后台发的公告和对你反馈、求片的回复
 */
class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({super.key});

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息中心'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '系统公告'),
            Tab(text: '我的消息'),
          ],
        ),
      ),
      body: TexturedBackground(child: TabBarView(
        controller: _tabCtrl,
        children: const [
          _NoticeListTab(),
          _UserNoticeTab(),
        ],
      ),
    );
  }
}

/**
/// 开发者：杰哥
/// 作用：系统公告Tab
/// 解释：展示站长在后台发的公告
 */
class _NoticeListTab extends StatefulWidget {
  const _NoticeListTab();

  @override
  State<_NoticeListTab> createState() => _NoticeListTabState();
}

class _NoticeListTabState extends State<_NoticeListTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  /// 开发者：杰哥
  /// 作用：从接口加载公告列表
  /// 解释：向服务器拉取公告数据
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      final list = await api.getNoticeList(page: 1);
      if (!mounted) return;
      setState(() => _items = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无公告'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final item = _items[i];
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoticeDetailPage(
                        noticeId: int.tryParse('${item['id']}') ?? 0,
                        title: item['title'] ?? '',
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.notifications, color: Theme.of(context).colorScheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] ?? '',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['create_time'] ?? '',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                        ],
                      ),
                      if ((item['sub_title'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, left: 44),
                          child: Text(
                            item['sub_title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.72)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/**
/// 开发者：杰哥
/// 作用：个人消息Tab（反馈、求片回复）
/// 解释：后台对你提交的反馈、求片的回复都在这里
 */
class _UserNoticeTab extends StatefulWidget {
  const _UserNoticeTab();

  @override
  State<_UserNoticeTab> createState() => _UserNoticeTabState();
}

class _UserNoticeTabState extends State<_UserNoticeTab>
    with SingleTickerProviderStateMixin {
  late TabController _innerCtrl;
  List<Map<String, dynamic>> _suggestList = [];
  List<Map<String, dynamic>> _findList = [];
  bool _loading = true;
  // 分页与滚动控制
  final ScrollController _suggestCtrl = ScrollController();
  final ScrollController _findCtrl = ScrollController();
  int _suggestPage = 1;
  int _findPage = 1;
  bool _suggestHasMore = true;
  bool _findHasMore = true;
  bool _loadingMoreSuggest = false;
  bool _loadingMoreFind = false;

  @override
  void initState() {
    super.initState();
    _innerCtrl = TabController(length: 2, vsync: this);
    // 监听滚动，靠近底部自动加载更多
    _suggestCtrl.addListener(() {
      if (_suggestHasMore &&
          !_loadingMoreSuggest &&
          _suggestCtrl.position.pixels >=
              _suggestCtrl.position.maxScrollExtent - 60) {
        _loadMoreSuggest();
      }
    });
    _findCtrl.addListener(() {
      if (_findHasMore &&
          !_loadingMoreFind &&
          _findCtrl.position.pixels >= _findCtrl.position.maxScrollExtent - 60) {
        _loadMoreFind();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _innerCtrl.dispose();
    _suggestCtrl.dispose();
    _findCtrl.dispose();
    super.dispose();
  }

  /// 开发者：杰哥
  /// 作用：同时拉取反馈和求片的消息
  /// 解释：一次性从服务器把两类消息都取回来
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      // 重置分页状态
      _suggestPage = 1;
      _findPage = 1;
      _suggestHasMore = true;
      _findHasMore = true;
      final suggest = await api.getUserNoticeList(type: 1, page: _suggestPage);
      final find = await api.getUserNoticeList(type: 2, page: _findPage);
      if (!mounted) return;
      setState(() {
        _suggestList = suggest;
        _findList = find;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 开发者：杰哥
  /// 作用：加载更多"反馈回复"
  /// 解释：向后端请求下一页反馈回复并追加到列表
  Future<void> _loadMoreSuggest() async {
    if (_loadingMoreSuggest || !_suggestHasMore) return;
    setState(() => _loadingMoreSuggest = true);
    try {
      final api = context.read<MacApi>();
      final next = _suggestPage + 1;
      final res = await api.getUserNoticeList(type: 1, page: next);
      if (!mounted) return;
      if (res.isEmpty) {
        setState(() => _suggestHasMore = false);
      } else {
        setState(() {
          _suggestPage = next;
          _suggestList.addAll(res);
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMoreSuggest = false);
    }
  }

  /// 开发者：杰哥
  /// 作用：加载更多"求片回复"
  /// 解释：向后端请求下一页求片回复并追加到列表
  Future<void> _loadMoreFind() async {
    if (_loadingMoreFind || !_findHasMore) return;
    setState(() => _loadingMoreFind = true);
    try {
      final api = context.read<MacApi>();
      final next = _findPage + 1;
      final res = await api.getUserNoticeList(type: 2, page: next);
      if (!mounted) return;
      if (res.isEmpty) {
        setState(() => _findHasMore = false);
      } else {
        setState(() {
          _findPage = next;
          _findList.addAll(res);
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMoreFind = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        TabBar(
          controller: _innerCtrl,
          labelColor: Theme.of(context).colorScheme.onSurface,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: '反馈回复'),
            Tab(text: '求片回复'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _innerCtrl,
            children: [
              _buildList(
                _suggestList,
                emptyText: '暂无反馈回复',
                controller: _suggestCtrl,
                hasMore: _suggestHasMore,
                loadingMore: _loadingMoreSuggest,
              ),
              _buildList(
                _findList,
                emptyText: '暂无求片回复',
                controller: _findCtrl,
                hasMore: _findHasMore,
                loadingMore: _loadingMoreFind,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 开发者：杰哥
  /// 作用：渲染一类消息列表
  /// 解释：把某一类消息按列表方式显示出来
  Widget _buildList(
    List<Map<String, dynamic>> list, {
    required String emptyText,
    ScrollController? controller,
    bool hasMore = false,
    bool loadingMore = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    if (list.isEmpty) {
      return Center(child: Text(emptyText, style: TextStyle(color: scheme.onSurface.withOpacity(0.6))));
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        controller: controller,
        padding: const EdgeInsets.all(16),
        itemCount: list.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          if (hasMore && i == list.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: loadingMore
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    loadingMore ? '加载中...' : '已到底部',
                    style: TextStyle(color: scheme.onSurface.withOpacity(0.6), fontSize: 12),
                  ),
                ],
              ),
            );
          }
          final item = list[i];
          final hasReply = (item['reply_content'] ?? '').toString().isNotEmpty;
          
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (hasReply ? AppColors.error : scheme.primary).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: hasReply ? AppColors.error : scheme.primary),
                      ),
                      child: Text(
                        hasReply ? '管理员已回复' : '待处理',
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          color: hasReply ? AppColors.error : scheme.primary
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['create_time'] ?? '',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item['title'] ?? '',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.onSurface),
                ),
                if ((item['content'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      item['content'] ?? '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (hasReply) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings, size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              '管理员回复',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['reply_content'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface.withOpacity(0.85),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/**
/// 开发者：杰哥
/// 作用：公告详情页
/// 解释：点一条公告后显示完整内容
 */
class NoticeDetailPage extends StatefulWidget {
  final int noticeId;
  final String title;
  const NoticeDetailPage({super.key, required this.noticeId, required this.title});

  @override
  State<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<NoticeDetailPage> {
  String _content = '';
  bool _loading = true;

  /// 开发者：杰哥
  /// 作用：加载公告详情
  /// 解释：根据ID向服务器索取完整公告内容
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      final data = await api.getNoticeDetail(widget.noticeId);
      if (!mounted) return;
      setState(() => _content = (data?['content'] ?? '').toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HtmlWidget(
                  _content,
                  textStyle: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurface,
                    height: 1.6,
                  ),
                ),
              ),
            ),
    );
  }
}

/**
/// 开发者：杰哥
/// 作用：反馈中心入口页面，提供三个功能的切换入口
/// 解释：统一入口，方便用户切换功能
 */
class FeedbackCenterPage extends StatelessWidget {
  const FeedbackCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('帮助与反馈')),
      body: TexturedBackground(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            context,
            icon: Icons.feedback,
            title: '反馈报错',
            subtitle: '遇到问题？告诉我们',
            color: scheme.primary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackPage())),
          ),
          const SizedBox(height: 12),
          _buildCard(
            context,
            icon: Icons.movie_filter,
            title: '求片找片',
            subtitle: '找不到想看的影片？',
            color: AppColors.warning,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestMoviePage())),
          ),
          const SizedBox(height: 12),
          _buildCard(
            context,
            icon: Icons.message,
            title: '消息中心',
            subtitle: '查看公告和回复',
            color: AppColors.success,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageCenterPage())),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.primary.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface)),
        subtitle: Text(subtitle, style: TextStyle(color: scheme.onSurface.withOpacity(0.6))),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurface.withOpacity(0.4)),
        onTap: onTap,
      ),
    );
  }
}
