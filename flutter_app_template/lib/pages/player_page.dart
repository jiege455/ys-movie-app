import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import 'package:better_player/better_player.dart';

/**
 * 开发者：杰哥
 * 作用：播放页，移动端直接播，Windows桌面做联调提示
 * 解释：手机上直接看；电脑上如果是 m3u8，就提示用手机调试。
 */
class PlayerPage extends StatefulWidget {
  final String vodId;
  const PlayerPage({super.key, required this.vodId});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  Map<String, dynamic>? detail;
  String? playUrl;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final api = context.read<MacApi>();
    final info = await api.getDetail(widget.vodId);
    setState(() {
      detail = info;
      final list = (info?['play_list'] as List?) ?? [];
      if (list.isNotEmpty) {
        final firstSource = list.first as Map;
        final episodes = (firstSource['urls'] as List?) ?? [];
        if (episodes.isNotEmpty) {
          playUrl = (episodes.first as Map)['url'] as String?;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<MacApi>();
    if (detail == null || playUrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.red)));
    }

    final isM3u8 = playUrl!.toLowerCase().contains('.m3u8');
    if (!api.isMobile && isM3u8) {
      return Scaffold(
        appBar: AppBar(title: const Text('播放')),
        body: Center(
          child: Text(
            '桌面环境不支持 m3u8 播放，请使用手机（Android/iOS）运行调试。\n播放地址：\n$playUrl',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      playUrl!,
      liveStream: isM3u8,
    );

    return Scaffold(
      body: SafeArea(
        child: BetterPlayer(
          controller: BetterPlayerController(
            const BetterPlayerConfiguration(
              autoPlay: true,
              fit: BoxFit.contain,
              controlsEnabled: true,
              aspectRatio: 16 / 9,
            ),
          ),
          dataSource: dataSource,
        ),
      ),
    );
  }
}
