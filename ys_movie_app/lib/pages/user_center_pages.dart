import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/store.dart';
import '../config.dart';
import 'vod_list_page.dart';

// 开发者：杰哥
// 作用：用户中心子页面集合（VIP中心、积分记录、推广邀请、我的收藏）
// 解释：把这三个相关的页面放在一起，方便管理。

// ================== VIP 会员中心 ==================

class VipPage extends StatefulWidget {
  const VipPage({super.key});

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  bool _loading = true;
  Map<String, dynamic> _user = {};
  List<Map<String, dynamic>> _vipGroups = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      final data = await api.getUserVipCenter();
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _user = data['user'];
          _vipGroups = data['vip_group_list'];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy(int index) async {
    final api = context.read<MacApi>();
    final group = _vipGroups[index];
    final price = group['group_points_day'] ?? 0;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('确认购买 ${group['group_name']}?'),
        content: const Text('需要消耗积分'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认支付')),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await api.buyVip(index: index);
    if (!mounted) return;
    
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('购买成功')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? '购买失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('会员中心')),
      body: TexturedBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary.withOpacity(0.8),
                            scheme.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.slate500.withOpacity(0.3) : AppColors.slate100,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              (_user['user_name'] ?? 'U').substring(0, 1).toUpperCase(),
                              style: TextStyle(fontSize: 30, color: scheme.primary),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _user['user_name'] ?? '用户',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppColors.primaryLight : Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '当前等级：${_user['group_name'] ?? '普通会员'}',
                                  style: TextStyle(color: isDark ? AppColors.slate300 : Colors.white.withOpacity(0.9)),
                                ),
                                Text(
                                  '剩余积分：${_user['user_points'] ?? 0}',
                                  style: TextStyle(color: isDark ? AppColors.slate300 : Colors.white.withOpacity(0.9)),
                                ),
                                Text(
                                  '到期时间：${_user['user_end_time'] != 0 ? DateTime.fromMillisecondsSinceEpoch((_user['user_end_time'] ?? 0) * 1000).toString().substring(0,10) : '永久'}',
                                  style: TextStyle(color: isDark ? AppColors.slate300 : Colors.white.withOpacity(0.9)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('会员套餐', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.onSurface)),
                    ),
                    const SizedBox(height: 12),
                    if (_vipGroups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('暂无套餐配置', style: TextStyle(color: scheme.onSurface.withOpacity(0.6))),
                      ),
                    
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _vipGroups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final item = _vipGroups[i];
                        final name = item['group_name'] ?? '套餐$i';
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            title: Text(name, style: TextStyle(color: scheme.onSurface)),
                            trailing: ElevatedButton(
                              onPressed: () => _buy(i),
                              child: const Text('购买'),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}


// ================== 积分记录 ==================

class PointsPage extends StatefulWidget {
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String _intro = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      final data = await api.getUserPointsLogs(page: 1);
      if (!mounted) return;
      setState(() {
        _logs = data['plogs'];
        _intro = data['intro'];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _watchAd() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.pop(context);

    final api = context.read<MacApi>();
    final res = await api.watchRewardAd();
    
    if (!mounted) return;
    if (res['success'] == true) {
       await showDialog(
         context: context,
         builder: (_) => AlertDialog(
           title: const Text('恭喜'),
           content: Text('观看广告成功，获得 ${res['points']} 积分！'),
           actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('开心'))],
         ),
       );
       _load();
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? '观看失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的积分'),
        actions: [
          TextButton.icon(
            onPressed: _watchAd,
            icon: const Icon(Icons.play_circle_fill, color: AppColors.warning, size: 16),
            label: Text('看广告赚积分', style: TextStyle(color: scheme.onSurface.withOpacity(0.8), fontSize: 12)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TexturedBackground(
        child: Column(
          children: [
            if (_intro.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                color: isDark ? AppColors.warning.withOpacity(0.1) : AppColors.warning.withOpacity(0.05),
                child: Text(_intro, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
              ),
            Expanded(
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty 
                    ? Center(child: Text('暂无积分记录', style: TextStyle(color: scheme.onSurface.withOpacity(0.6))))
                    : ListView.separated(
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _logs[i];
                          final points = item['plog_points'] ?? 0;
                          final isAdd = (int.tryParse('$points') ?? 0) > 0;
                          return ListTile(
                            title: Text(item['plog_remark'] ?? '积分变动', style: TextStyle(color: scheme.onSurface)),
                            subtitle: Text(
                              item['plog_time'] != null 
                                  ? DateTime.fromMillisecondsSinceEpoch((int.tryParse('${item['plog_time']}') ?? 0) * 1000).toString().substring(0, 19)
                                  : '',
                              style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
                            ),
                            trailing: Text(
                              '${isAdd ? '+' : ''}$points',
                              style: TextStyle(
                                color: isAdd ? AppColors.error : AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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

// ================== 推广邀请 ==================

class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  String _myCode = '...';
  String _inviteLink = '';
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String _intro = '';
  int _count = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      final data = await api.getInviteLogs(page: 1);
      final info = await api.getUserInfoSummary();
      
      if (!mounted) return;
      setState(() {
        _logs = data['invite_logs'];
        _count = int.tryParse('${data['invite_count'] ?? 0}') ?? 0;
        _intro = data['intro'];
        
        final uid = info?['user_id'];
        if (uid != null) {
           _myCode = '$uid';
           
           final config = api.appConfig;
           String siteUrl = config['site_url']?.toString() ?? '';
           
           if (siteUrl.isEmpty) {
             final uri = Uri.tryParse(AppConfig.baseUrl);
             if (uri != null) {
               final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
               String path = uri.path;
               if (path.contains('api.php')) {
                 path = path.split('api.php').first;
               }
               if (path.endsWith('/')) {
                 path = path.substring(0, path.length - 1);
               }
               siteUrl = '$origin$path';
             } else {
               final baseUrl = AppConfig.baseUrl.replaceAll('/api.php', '');
               siteUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
             }
           }
           
           if (siteUrl.endsWith('/')) {
             siteUrl = siteUrl.substring(0, siteUrl.length - 1);
           }
           
           _inviteLink = '$siteUrl/index.php/user/reg.html?uid=$uid';
        } else {
           _myCode = info?['user_name'] ?? '登录后查看';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('推广邀请')),
      body: TexturedBackground(
        child: Column(
          children: [
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(24),
               color: scheme.primary,
               child: Column(
                 children: [
                   Text('累计邀请人数', style: TextStyle(color: isDark ? AppColors.slate300 : Colors.white.withOpacity(0.85))),
                   const SizedBox(height: 8),
                   Text('$_count', style: TextStyle(color: isDark ? AppColors.primaryLight : Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 24),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     decoration: BoxDecoration(
                       color: isDark ? AppColors.slate50 : Colors.white.withOpacity(0.9),
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text('我的邀请码：$_myCode', style: TextStyle(color: isDark ? AppColors.slate600 : AppColors.slate700)),
                         const SizedBox(width: 8),
                         Text('复制分享', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold)),
                       ],
                     ),
                   ).isValidGesture(onTap: () {
                      if (_inviteLink.isEmpty && _myCode == '...') {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在获取推广链接，请稍后...')));
                         return;
                      }
                      final text = '【${AppConfig.appName}】诚邀您加入！\n'
                          '海量高清影视免费看，无广告更流畅。\n'
                          '--------------------\n'
                          '我的邀请码：$_myCode\n'
                          '注册地址：$_inviteLink\n'
                          '--------------------\n'
                          '赶快点击链接注册吧！';
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('推广文案已复制')));
                   }),
                 ],
               ),
             ),
             if (_intro.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: isDark ? AppColors.warning.withOpacity(0.1) : AppColors.warning.withOpacity(0.05),
                child: Text(_intro, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
              ),
            Expanded(
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty 
                    ? Center(child: Text('暂无邀请记录', style: TextStyle(color: scheme.onSurface.withOpacity(0.6))))
                    : ListView.separated(
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _logs[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: scheme.primary.withOpacity(0.15),
                              child: Icon(Icons.person, size: 20, color: scheme.primary),
                            ),
                            title: Text(item['user_name'] ?? '匿名用户', style: TextStyle(color: scheme.onSurface)),
                            subtitle: Text(
                              '注册时间：${item['user_reg_time'] != null ? DateTime.fromMillisecondsSinceEpoch((int.tryParse('${item['user_reg_time']}') ?? 0) * 1000).toString().substring(0,10) : ''}',
                              style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
                            ),
                            trailing: const Text('奖励已发', style: TextStyle(fontSize: 12, color: AppColors.success)),
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

extension GestureDetectorExt on Widget {
  Widget isValidGesture({required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: this);
  }
}

// ================== 我的收藏 ==================

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<MacApi>();
    final isLogin = await api.checkLogin();
    List<Map<String, dynamic>> items = [];
    if (isLogin) {
       try { items = await api.getFavs(); } catch(_) {}
    } else {
       final favStrings = await StoreService.getFavorites();
       items = favStrings.map((e) {
         final parts = e.split('|');
         return {
           'id': parts[0],
           'title': parts.length > 1 ? parts[1] : '',
           'poster': parts.length > 2 ? parts[2] : '',
         };
       }).toList();
    }
    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return VodListPage(title: '我的收藏', items: _items!);
  }
}
