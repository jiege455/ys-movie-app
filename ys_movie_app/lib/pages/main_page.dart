import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import 'home_page.dart';
import 'ranking_page.dart';
import 'profile_page.dart';
import 'week_page.dart';
import 'topic_page.dart';
import 'find_link_page.dart';

/**
 * 开发者：杰哥
 * 作用：主界面，包含底部导航栏和页面切换逻辑
 * 解释：APP 的大框架，底下那排按钮和页面切换都归我管。
 */
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final GlobalKey<ProfilePageState> _profileKey = GlobalKey<ProfilePageState>();

  late List<_NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    _navItems = [
      const _NavItem(label: '首页', icon: Icons.home_outlined, activeIcon: Icons.home, page: HomePage()),
      const _NavItem(label: '排行榜', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, page: RankingPage()),
      _NavItem(label: '我的', icon: Icons.person_outline, activeIcon: Icons.person, page: ProfilePage(key: _profileKey)),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRemoteTabs());
  }

  Future<void> _loadRemoteTabs() async {
    try {
      final api = context.read<MacApi>();
      // 获取缓存中的配置（启动页已刷新过，这里直接用缓存即可）
      final initData = await api.getAppInit(force: false);
      final raw = initData['app_page_setting'];
      if (raw is! Map) return;
      final dynamic tabListRaw = raw['app_tab_setting_list'] ?? (raw['app_page_setting'] is Map ? (raw['app_page_setting'] as Map)['app_tab_setting_list'] : null);
      final tabList = (tabListRaw is List) ? tabListRaw.whereType<Map>().toList() : const <Map>[];
      if (tabList.isEmpty) return;

      final items = <_NavItem>[
        const _NavItem(label: '首页', icon: Icons.home_outlined, activeIcon: Icons.home, page: HomePage()),
      ];

      // 强制添加专题页面 (如果后台没配置，默认也显示)
      bool hasTopic = false;

      for (final t in tabList) {
        final type = int.tryParse('${t['type'] ?? -1}') ?? -1;
        final name = (t['name'] ?? '').toString().trim();
        if (type == 0) {
          items.add(_NavItem(
            label: name.isEmpty ? '排行榜' : name,
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart,
            page: const RankingPage(),
          ));
          continue;
        }
        if (type == 1) {
          items.add(_NavItem(
            label: name.isEmpty ? '排期' : name,
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month,
            page: WeekPage(title: name.isEmpty ? '排期' : name),
          ));
          continue;
        }
        if (type == 2) {
          final url = (t['url'] ?? '').toString().trim();
          if (url.isEmpty) continue;
          items.add(_NavItem(
            label: name.isEmpty ? '发现' : name,
            icon: Icons.public_outlined,
            activeIcon: Icons.public,
            page: FindLinkPage(title: name.isEmpty ? '发现' : name, url: url),
          ));
          continue;
        }
        if (type == 3) {
          hasTopic = true;
          items.add(_NavItem(
            label: name.isEmpty ? '专题' : name,
            icon: Icons.auto_awesome_outlined,
            activeIcon: Icons.auto_awesome,
            page: TopicPage(title: name.isEmpty ? '专题' : name),
          ));
          continue;
        }
      }

      // 如果后台没开启专题，强制添加
      // 修复：用户要求如果后台关闭了专题，APP也不显示，所以移除强制添加逻辑
      /*
      if (!hasTopic) {
         items.add(const _NavItem(
            label: '专题',
            icon: Icons.auto_awesome_outlined,
            activeIcon: Icons.auto_awesome,
            page: TopicPage(title: '专题'),
         ));
      }
      */

      items.add(_NavItem(label: '我的', icon: Icons.person_outline, activeIcon: Icons.person, page: ProfilePage(key: _profileKey)));

      if (!mounted) return;
      setState(() {
        _navItems = items;
        if (_currentIndex >= _navItems.length) _currentIndex = 0;
      });
    } catch (_) {}
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _navItems.map((e) => e.page).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          
          // 如果切换到“我的”页面，强制刷新数据
          if (index < _navItems.length) {
             final item = _navItems[index];
             if (item.label == '我的' || item.page is ProfilePage) {
                _profileKey.currentState?.refresh();
             }
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: _navItems
            .map(
              (e) => BottomNavigationBarItem(
                icon: Icon(e.icon),
                activeIcon: Icon(e.activeIcon),
                label: e.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });
}
