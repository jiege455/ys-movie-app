import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api.dart';
import 'services/theme_provider.dart';
import 'services/cast/cast_manager.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'pages/detail_page.dart';
import 'pages/search_page.dart';
import 'pages/profile_page.dart';
import 'pages/main_page.dart';

/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 作用：应用入口，配置全局状态和路由
/// 小白解释：这里就是APP从哪里开始跑，以及页面怎么跳转。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 配置图片内存缓存：防止首页大量图片导致内存溢出
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;

  // 初始化投屏管理器
  await CastManager().initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<MacApi>(create: (_) => MacApi()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// 小白解释：这是APP的壳子，包住所有页面
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: '狐狸影视',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      routes: {
        '/': (_) => const MainPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/detail/') == true) {
          final id = settings.name!.split('/').last;
          return MaterialPageRoute(builder: (_) => DetailPage(vodId: id));
        }
        if (settings.name == '/search') {
          return MaterialPageRoute(builder: (_) => const SearchPage());
        }
        if (settings.name == '/profile') {
          return MaterialPageRoute(builder: (_) => const ProfilePage());
        }
        return MaterialPageRoute(builder: (_) => const HomePage());
      },
    );
  }
}
