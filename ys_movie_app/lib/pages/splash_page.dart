import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api.dart';
import 'download_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  int _countdown = 3;
  Timer? _timer;
  Map<String, dynamic>? _startupAd;
  String _loadingText = '正在加载...';
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _checkNetworkAndInit();
  }

  Future<void> _checkNetworkAndInit() async {
    // 1. 检查网络状态
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
       // 无网络，直接跳转到离线缓存页面
       if (mounted) {
         // 先跳转到 Main，并传递参数让其打开 DownloadPage
         Navigator.of(context).pushReplacementNamed('/', arguments: {'initialRoute': '/download'});
       }
       return;
    }

    _initApp();
  }

  Future<void> _initApp() async {
    final api = context.read<MacApi>();

    // 1. 并行初始化：获取APP配置 + 最小等待计时
    // force=true 确保获取最新配置（包括启动页广告）
    // 如果无网络，getAppInit 内部会失败捕获，不影响流程
    final initFuture = api.getAppInit(force: true);
    final waitFuture = Future.delayed(const Duration(seconds: 3));

    try {
      await Future.wait([initFuture, waitFuture]);
      // 无论如何，直接进入主页（因为启动页广告功能已移除）
      if (mounted) _goMain();
    } catch (e) {
      // 出错也进入主页
      if (mounted) _goMain();
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
          _goMain();
        }
      });
    });
  }

  void _goMain() {
    Navigator.of(context).pushReplacementNamed('/', arguments: {'fromSplash': true});
  }

  void _onAdTap() {
    if (_startupAd != null && _startupAd!['link'].isNotEmpty) {
      final url = _startupAd!['link'];
      if (url.startsWith('http')) {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 如果有广告，显示广告页
    if (_startupAd != null) {
      return Scaffold(
        body: Stack(
          children: [
            // 广告图
            Positioned.fill(
              child: GestureDetector(
                onTap: _onAdTap,
                child: CachedNetworkImage(
                  imageUrl: _startupAd!['pic'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.white),
                  errorWidget: (context, url, error) => const SizedBox(),
                ),
              ),
            ),
            // 跳过按钮
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: GestureDetector(
                onTap: _goMain,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '跳过 $_countdown',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 默认启动页（Logo）
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              '狐狸影视',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _loadingText,
              style: TextStyle(color: _showError ? Colors.red : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey)),
            ),
            if (_showError)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ElevatedButton(
                  onPressed: _goMain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('直接进入'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
