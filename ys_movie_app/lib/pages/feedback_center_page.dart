/**
/// 鏂囦欢鍚嶏細feedback_center_page.dart
/// 浣滆€咃細鏉板摜
/// 鍒涘缓鏃ユ湡锛?025-12-28
/// 璇存槑锛氬弽棣堟姤閿欍€佹眰鐗囨壘鐗囥€佹秷鎭腑蹇冿紙绯荤粺鍏憡涓庝釜浜烘秷鎭級椤甸潰鍚堥泦
/// by锛氭澃鍝? qq锛?711793818
 */
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import '../services/api.dart';

/**
/// 寮€鍙戣€咃細鏉板摜
/// 浣滅敤锛氬寘鍚弽棣堛€佹眰鐗囧拰娑堟伅涓績鐨勯〉闈㈤泦鍚?/// 瑙ｉ噴锛氳繖閲屾墦鍖呬簡"鍙嶉鎶ラ敊"銆?姹傜墖鎵剧墖"銆?娑堟伅涓績"涓変釜鍔熻兘椤甸潰
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
      _contentCtrl.text = '【视频报错】\n影片：{widget.vodName}\nID：{widget.vodId}\n问题描述：';
    }
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氭彁浜ゅ弽棣堝埌鍚庣
/// 瑙ｉ噴锛氱偣"鎻愪氦鍙嶉"鏃舵妸鍐呭鍙戠粰鏈嶅姟鍣?
  Future<void> _submit() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入反馈内容')));
      return;
    }

    final api = context.read<MacApi>();
    
// 妫€鏌ョ櫥褰?
    final isLogin = await api.checkLogin();
    if (!isLogin) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
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
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('反馈已提交，感谢支持')));
      } else {
        ScaffoldMessenger.of(context)
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('提交失败，请稍后重试')));
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
        // 浣跨敤涓婚榛樿閰嶈壊
      ),
      body: TexturedBackground(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 椤堕儴鎻愮ず鍗＄墖
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
            const Text('如遇播放卡顿、资源失效或有功能建议，请在此留言，我们会尽快处理'),
                      style: TextStyle(fontSize: 14, color: scheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
            decoration: const InputDecoration(labelText: '问题描述'),
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
            '请详细描述您遇到的问题，例如：\n1. 某部影片第几集无法播放\n2. 画面卡顿或声音不同步\n3. 希望增加的新功能...',
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
                child: const Text('提交反馈'),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/**
/// 寮€鍙戣€咃細鏉板摜
/// 浣滅敤锛氭眰鐗囬〉闈紝鎶婃壘涓嶅埌鐨勫奖鐗囧悕绉版彁浜ょ粰鍚庡彴
/// 瑙ｉ噴锛氭兂鐪嬬殑鐗囧瓙杩欓噷鎶ョ粰鍚庡彴锛岃绔欓暱甯綘鎵? */
class RequestMoviePage extends StatefulWidget {
  const RequestMoviePage({super.key});

  @override
  State<RequestMoviePage> createState() => _RequestMoviePageState();
}

class _RequestMoviePageState extends State<RequestMoviePage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  bool _submitting = false;

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氭彁浜ゆ眰鐗囪姹傚埌鍚庣
  /// 瑙ｉ噴锛氭妸鐗囧悕鍜屽娉ㄥ彂鍒版湇鍔″櫒
  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final remark = _remarkCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入片名')));
      return;
    }

    final api = context.read<MacApi>();

// 妫€鏌ョ櫥褰?
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
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('求片已提交，耐心等待处理')));
      } else {
        ScaffoldMessenger.of(context)
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('提交失败，请稍后重试')));
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
        // 浣跨敤涓婚榛樿閰嶈壊
      ),
      body: TexturedBackground(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 椤堕儴鎻愮ず
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
            const Text('想看的片子找不到？告诉我片名，站长帮你找！\n提交后请留意消息中心的“求片回复”'),
                      style: TextStyle(fontSize: 14, color: scheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            hintText: '影片名称（必填）',
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
            '例如：希望能有4K画质、国语配音、或者具体哪一集。',
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
                child: const Text('提交求片'),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/**
/// 寮€鍙戣€咃細鏉板摜
/// 浣滅敤锛氭秷鎭腑蹇冿紝鍖呮嫭绯荤粺鍏憡鍜屼釜浜烘秷鎭?/// 瑙ｉ噴锛氳繖閲岃兘鐪嬪埌鍚庡彴鍙戠殑鍏憡鍜屽浣犲弽棣堛€佹眰鐗囩殑鍥炲
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
      ),
    );
  }
}

/**
/// 寮€鍙戣€咃細鏉板摜
/// 浣滅敤锛氱郴缁熷叕鍛奣ab
/// 瑙ｉ噴锛氬睍绀虹珯闀垮湪鍚庡彴鍙戠殑鍏憡
 */
class _NoticeListTab extends StatefulWidget {
  const _NoticeListTab();

  @override
  State<_NoticeListTab> createState() => _NoticeListTabState();
}

class _NoticeListTabState extends State<_NoticeListTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氫粠鎺ュ彛鍔犺浇鍏憡鍒楄〃
/// 瑙ｉ噴锛氬悜鏈嶅姟鍣ㄦ媺鍙栧叕鍛婃暟鎹?
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
/// 寮€鍙戣€咃細鏉板摜
/// 浣滅敤锛氫釜浜烘秷鎭疶ab锛堝弽棣堛€佹眰鐗囧洖澶嶏級
/// 瑙ｉ噴锛氬悗鍙板浣犳彁浜ょ殑鍙嶉銆佹眰鐗囩殑鍥炲閮藉湪杩欓噷
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
// 鍒嗛〉涓庢粴鍔ㄦ帶鍒?
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
// 鐩戝惉婊氬姩锛岄潬杩戝簳閮ㄨ嚜鍔ㄥ姞杞芥洿澶?
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

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氬悓鏃舵媺鍙栧弽棣堝拰姹傜墖鐨勬秷鎭?  /// 瑙ｉ噴锛氫竴娆℃€т粠鏈嶅姟鍣ㄦ妸涓ょ被娑堟伅閮藉彇鍥炴潵
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      // 閲嶇疆鍒嗛〉鐘舵€?      _suggestPage = 1;
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

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氬姞杞芥洿澶?鍙嶉鍥炲"
/// 瑙ｉ噴锛氬悜鍚庣璇锋眰涓嬩竴椤靛弽棣堝洖澶嶅苟杩藉姞鍒板垪琛?
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

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氬姞杞芥洿澶?姹傜墖鍥炲"
/// 瑙ｉ噴锛氬悜鍚庣璇锋眰涓嬩竴椤垫眰鐗囧洖澶嶅苟杩藉姞鍒板垪琛?
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
        child: const Center(child: Text('暂无反馈回复')),
                controller: _suggestCtrl,
                hasMore: _suggestHasMore,
                loadingMore: _loadingMoreSuggest,
              ),
              _buildList(
                _findList,
        child: const Center(child: Text('暂无求片回复')),
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

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氭覆鏌撲竴绫绘秷鎭垪琛?  /// 瑙ｉ噴锛氭妸鏌愪竴绫绘秷鎭寜鍒楄〃鏂瑰紡鏄剧ず鍑烘潵
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
/// 寮€鍙戣€咃細鏉板摜
/// 浣滅敤锛氬叕鍛婅鎯呴〉
/// 瑙ｉ噴锛氱偣涓€鏉″叕鍛婂悗鏄剧ず瀹屾暣鍐呭
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

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氬姞杞藉叕鍛婅鎯?  /// 瑙ｉ噴锛氭牴鎹甀D鍚戞湇鍔″櫒绱㈠彇瀹屾暣鍏憡鍐呭
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
      body: TexturedBackground(child: _loading
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
            ),
    );
  }
}

/**
/// 寮€鍙戣€咃細鏉板摜
/// 浣滅敤锛氬弽棣堜腑蹇冨叆鍙ｉ〉闈紝鎻愪緵涓変釜鍔熻兘鐨勫垏鎹㈠叆鍙?/// 瑙ｉ噴锛氱粺涓€鍏ュ彛锛屾柟渚跨敤鎴峰垏鎹㈠姛鑳? */
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
