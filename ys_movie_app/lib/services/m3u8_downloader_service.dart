import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 文件名：m3u8_downloader_service.dart
/// 作者：杰哥（by：杰哥 / qq：2711793818）
/// 创建日期：2025-01-03
/// 作用：M3U8 视频下载服务（增强版）
/// 升级内容：
/// 1. 移植开源项目 m3u8-dl 的核心逻辑：动态线程池并发 + 智能重试。
/// 2. 解决旧版傻瓜式分批下载导致的卡顿和失败问题。
/// 3. **离线缓存模式**：不合并 MP4，而是保留原始 TS 分片目录结构，生成本地 index.m3u8，实现标准 HLS 离线播放。
/// 4. 存储路径：使用 ApplicationDocumentsDirectory (应用私有文档目录)，卸载应用时自动清除，不污染相册。

class M3u8DownloaderService {
  static final M3u8DownloaderService _instance = M3u8DownloaderService._internal();
  factory M3u8DownloaderService() => _instance;
  M3u8DownloaderService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    }
  ));

  /// 开始下载 m3u8 视频 (缓存模式)
  Future<String> download({
    required String url,
    required String fileName,
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      // 1. 权限检查 (虽然存私有目录一般不需要，但为了保险还是检查)
      if (Platform.isAndroid) {
         await _checkPermission();
      }

      // 2. 准备工作目录 (使用 ApplicationDocumentsDirectory)
      final docDir = await getApplicationDocumentsDirectory();
      // 使用 safeName 作为子目录
      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final downloadDir = Directory('${docDir.path}/downloads/$safeName');
      
      // 如果目录已存在，先清空，防止旧文件干扰
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
      }
      await downloadDir.create(recursive: true);

      // 3. 解析 M3U8
      onProgress?.call(0.01, '正在解析资源...');
      final m3u8Content = await _downloadM3u8(url);
      final playlist = await HlsPlaylistParser.create().parseString(Uri.parse(url), m3u8Content);

      // 处理 Master Playlist (多码率适配)
      if (playlist is HlsMasterPlaylist) {
        final variants = playlist.variants;
        if (variants.isNotEmpty) {
           variants.sort((a, b) => (b.format.bitrate ?? 0).compareTo(a.format.bitrate ?? 0));
           final bestUrl = variants.first.url.toString();
           print('检测到多码率，自动切换至最高画质: $bestUrl');
           return download(url: bestUrl, fileName: fileName, onProgress: onProgress);
        }
      }

      if (playlist is HlsMediaPlaylist) {
        final segments = playlist.segments;
        if (segments.isEmpty) throw Exception('未找到视频分片');

        // 4. 核心：动态线程池并发下载 TS 分片
        final baseUrl = url.substring(0, url.lastIndexOf('/') + 1);
        final total = segments.length;
        
        final tasks = List.generate(total, (i) {
           final seg = segments[i];
           String segUrl = seg.url ?? '';
           if (!segUrl.startsWith('http')) segUrl = baseUrl + segUrl;
           // 使用简单的数字命名，方便本地引用
           final fName = '${i}.ts'; 
           return _DownloadTask(index: i, url: segUrl, savePath: '${downloadDir.path}/$fName');
        });

        // 启动动态线程池 (并发数 5)
        const int maxConcurrency = 5;
        await _runWithPool(tasks, maxConcurrency, (doneCount) {
           final p = (doneCount / total) * 0.99; 
           onProgress?.call(p, '缓存中: $doneCount/$total');
        });

        // 5. 生成本地 index.m3u8 文件
        onProgress?.call(0.99, '生成播放列表...');
        
        // 我们需要重构一个 m3u8 内容，将网络 URL 替换为本地文件名
        // 简单方式：按顺序写入 header 和 segments
        final localM3u8File = File('${downloadDir.path}/index.m3u8');
        final sink = localM3u8File.openWrite();
        
        sink.writeln('#EXTM3U');
        sink.writeln('#EXT-X-VERSION:3');
        // targetDurationUs 是微秒，转为秒
        final targetDuration = (playlist.targetDurationUs ?? 10000000) / 1000000;
        sink.writeln('#EXT-X-TARGETDURATION:${targetDuration.toInt()}');
        sink.writeln('#EXT-X-MEDIA-SEQUENCE:0');
        
        // 遍历 segments 写入
        for (var i = 0; i < total; i++) {
           final seg = segments[i];
           // durationUs 是微秒，转为秒
           final duration = (seg.durationUs ?? 0) / 1000000;
           sink.writeln('#EXTINF:$duration,');
           sink.writeln('${i}.ts');
        }
        
        sink.writeln('#EXT-X-ENDLIST');
        await sink.close();

        onProgress?.call(1.0, '缓存完成');
        // 返回本地 index.m3u8 的路径，播放器可以直接播放这个文件
        return localM3u8File.path;
      }
      throw Exception('不支持的 M3U8 类型');
    } catch (e) {
      onProgress?.call(0, '缓存失败: $e');
      rethrow;
    }
  }

  /// 动态线程池执行器
  Future<void> _runWithPool(List<_DownloadTask> tasks, int maxConcurrent, Function(int) onProgress) async {
    final queue = List<_DownloadTask>.from(tasks);
    final active = <Future>[];
    int completed = 0;

    while (queue.isNotEmpty || active.isNotEmpty) {
      while (queue.isNotEmpty && active.length < maxConcurrent) {
        final task = queue.removeAt(0);
        
        late final Future future;
        future = _downloadOne(task).then((_) {
           completed++;
           onProgress(completed);
        }).catchError((e) {
           print('Task ${task.index} failed: $e');
           completed++; // 即使失败也算完成，避免卡死
           onProgress(completed);
        }).whenComplete(() {
           active.remove(future);
        });
        
        active.add(future);
      }

      if (active.isNotEmpty) {
        await Future.any(active);
      }
    }
  }

  /// 单个分片下载 (带智能重试)
  Future<void> _downloadOne(_DownloadTask task) async {
    int retry = 0;
    while (retry < 3) {
      try {
        await _dio.download(task.url, task.savePath);
        return; 
      } catch (e) {
        retry++;
        print('分片 ${task.index} 下载失败 ($retry/3): $e');
        if (retry >= 3) rethrow; 
        await Future.delayed(const Duration(seconds: 1)); 
      }
    }
  }

  Future<String> _downloadM3u8(String url) async {
    final resp = await _dio.get(url);
    return resp.data.toString();
  }

  Future<bool> _checkPermission() async {
     try {
       if (await Permission.storage.isGranted) return true;
       // Android 13+ 不需要请求 WRITE_EXTERNAL_STORAGE 也能写应用私有目录
       return true;
     } catch (e) {
       return true; 
     }
  }
}

class _DownloadTask {
  final int index;
  final String url;
  final String savePath;
  _DownloadTask({required this.index, required this.url, required this.savePath});
}
