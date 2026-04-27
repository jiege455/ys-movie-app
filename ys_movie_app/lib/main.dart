import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api.dart';
import 'services/theme_provider.dart';
import 'pages/home_page.dart';
import 'pages/detail_page.dart';
import 'pages/search_page.dart';
import 'pages/profile_page.dart';
import 'pages/main_page.dart'; // 引入主页

/**
 * 开发者：杰哥
 * 作用：应用入口，配置全局状态和路由
 * 小白解释：这里就是APP从哪里开始跑，以及页面怎么跳转。
 */
void main() {
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
          seedColor: Colors.pink,
          primary: Colors.pink,
          secondary: Colors.pinkAccent,
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
          surfaceTintColor: Colors.transparent, // 移除 M3 的粉色表面色调
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
          seedColor: Colors.pink, // 统一深色模式也为粉色主题
          primary: Colors.pink,
          secondary: Colors.pinkAccent,
          brightness: Brightness.dark,
          surface: const Color(0xFF15202B),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1724), // 深蓝背景，不再是纯黑
        cardColor: const Color(0xFF15202B),
        dialogBackgroundColor: const Color(0xFF15202B),
        useMaterial3: true,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1724),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF15202B),
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: const DialogTheme(
          backgroundColor: Color(0xFF15202B),
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF15202B),
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
