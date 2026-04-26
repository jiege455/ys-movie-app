import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api.dart';
import 'pages/home_page.dart';
import 'pages/detail_page.dart';
import 'pages/player_page.dart';

/**
 * 开发者：杰哥
 * 作用：应用入口，配置全局状态和路由
 * 解释：这里就是APP从哪里开始跑，以及页面怎么跳转。
 */
void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<MacApi>(create: (_) => MacApi()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// 解释：这是APP的壳子，包住所有页面
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '影视App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => const HomePage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/detail/') == true) {
          final id = settings.name!.split('/').last;
          return MaterialPageRoute(builder: (_) => DetailPage(vodId: id));
        }
        if (settings.name?.startsWith('/player/') == true) {
          final id = settings.name!.split('/').last;
          return MaterialPageRoute(builder: (_) => PlayerPage(vodId: id));
        }
        return MaterialPageRoute(builder: (_) => const HomePage());
      },
    );
  }
}
