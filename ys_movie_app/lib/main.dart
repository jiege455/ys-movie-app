import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api.dart';
import 'services/theme_provider.dart';
import 'services/cast/cast_manager.dart';
import 'pages/home_page.dart';
import 'pages/detail_page.dart';
import 'pages/search_page.dart';
import 'pages/profile_page.dart';
import 'pages/main_page.dart'; // 引入主页

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFFF), // 天空蓝
          primary: const Color(0xFF00BFFF), // 天空蓝主色
          secondary: const Color(0xFF87CEEB), // 浅天空蓝
          surface: Colors.white,
          background: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        dialogBackgroundColor: Colors.white,
        useMaterial3: true,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent, // 移除 M3 的表面色调
        ),
        dialogTheme: const DialogTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFFF), // 天空蓝
          primary: const Color(0xFF00BFFF), // 天空蓝主色
          secondary: const Color(0xFF87CEEB), // 浅天空蓝
          brightness: Brightness.dark,
          surface: const Color(0xFF0A1A2A),
        ),
        scaffoldBackgroundColor: const Color(0xFF051018), // 深天空蓝背景
        cardColor: const Color(0xFF0A1A2A),
        dialogBackgroundColor: const Color(0xFF0A1A2A),
        useMaterial3: true,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF051018),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF0A1A2A),
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: const DialogTheme(
          backgroundColor: Color(0xFF0A1A2A),
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF0A1A2A),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      themeMode: themeProvider.themeMode,
      routes: {
        '/': (_) => const MainPage(), // 入口改为 MainPage
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
