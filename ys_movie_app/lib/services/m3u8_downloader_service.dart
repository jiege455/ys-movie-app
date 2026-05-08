/// 文件名：m3u8_downloader_service.dart
/// 开发者：杰哥网络科技（by：杰哥 / qq：2711793818）
/// 创建日期：2025-01-03 | 修复日期：2026-05-06
/// 作用：M3U8 视频下载服务（增强版）
/// 升级内容：
/// 1. 移植开源项目 m3u8-dl 的核心逻辑：动态线程池并发 + 智能重试。
/// 2. 解决旧版傻瓜式分批下载导致的卡顿和失败问题。
/// 3. 离线缓存模式：不合并 MP4，保留原始 TS 分片目录结构，生成本地 index.m3u8，实现标准 HLS 离线播放。
/// 4. 存储路径：使用 ApplicationDocumentsDirectory (应用私有文档目录)，卸载应用时自动清除，不污染相册。
/// 5. 新增：CancelToken 支持取消下载。
/// 6. 新增：下载事件流（Stream），下载管理页面可实时监听进度。

import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadEvent {
  final String taskId;
  final double progress;
  final String status;
  final String speed;
  final String? savePath;
  final String? errorMsg;

  const DownloadEvent({
    required this.taskId,
    required this.progress,
    required this.status,
    this.speed = '',
    this.savePath,
    this.errorMsg,
  });
}

class M3u8DownloaderService {
  static final M3u8DownloaderService _instance = M3u8DownloaderService._internal();
  factory M3u8DownloaderService() => _instance;
  M3u8DownloaderService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  final Map<String, CancelToken> _activeCancelTokens = {};
  final Map<String, String> _activeTaskIds = {};

  final StreamController<DownloadEvent> _eventController =
      StreamController<DownloadEvent>.broadcast();

  Stream<DownloadEvent> get downloadEventStream => _eventController.stream;

  bool isDownloading(String taskId) {
    return _activeCancelTokens.containsKey(taskId);
  }

  List<String> get activeTaskIds => _activeTaskIds.keys.toList();

  void cancelDownload(String taskId) {
    final token = _activeCancelTokens.remove(taskId);
    if (token != null && !token.isCancelled) {
      token.cancel('用户取消下载');
    }
    _activeTaskIds.remove(taskId);
    _emitEvent(taskId, 0, 'cancelled', '已取消');
  }

  void cancelAllDownloads() {
    for (final taskId in _activeCancelTokens.keys.toList()) {
      cancelDownload(taskId);
    }
  }

  void dispose() {
    cancelAllDownloads();
    _eventController.close();
  }

  Future<String> download({
    required String url,
    required String fileName,
    required String taskId,
    Function(double progress, String status)? onProgress,
  }) async {
    final cancelToken = CancelToken();
    _activeCancelTokens[taskId] = cancelToken;
    _activeTaskIds[taskId] = fileName;

    try {
      if (Platform.isAndroid) {
        await _checkPermission();
      }

      final docDir = await getApplicationDocumentsDirectory();
      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final downloadDir = Directory('${docDir.path}/downloads/$safeName');

      if (cancelToken.isCancelled) {
        _activeCancelTokens.remove(taskId);
        _activeTaskIds.remove(taskId);
        return '';
      }

      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
      }
      await downloadDir.create(recursive: true);

      if (cancelToken.isCancelled) return '';

      onProgress?.call(0.01, '正在解析资源...');
      _emitEvent(taskId, 0.01, 'downloading', '正在解析资源...');

      final m3u8Content = await _downloadM3u8(url, cancelToken);
      if (cancelToken.isCancelled) return '';

      final playlist = await HlsPlaylistParser.create()
          .parseString(Uri.parse(url), m3u8Content);

      if (playlist is HlsMasterPlaylist) {
        final variants = playlist.variants;
        if (variants.isNotEmpty) {
          variants.sort((a, b) =>
              (b.format.bitrate ?? 0).compareTo(a.format.bitrate ?? 0));
          final bestUrl = variants.first.url.toString();
          return download(
            url: bestUrl,
            fileName: fileName,
            taskId: taskId,
            onProgress: onProgress,
          );
        }
      }

      if (playlist is HlsMediaPlaylist) {
        final segments = playlist.segments;
        if (segments.isEmpty) throw Exception('未找到视频分片');

        final baseUrl = url.substring(0, url.lastIndexOf('/') + 1);
        final total = segments.length;

        final tasks = List.generate(total, (i) {
          final seg = segments[i];
          String segUrl = seg.url ?? '';
          if (!segUrl.startsWith('http')) segUrl = baseUrl + segUrl;
          final fName = '${i}.ts';
          return _DownloadTask(
              index: i, url: segUrl, savePath: '${downloadDir.path}/$fName');
        });

        const int maxConcurrency = 5;
        await _runWithPool(tasks, maxConcurrency, cancelToken, (doneCount) {
          if (cancelToken.isCancelled) return;
          final p = (doneCount / total) * 0.98;
          onProgress?.call(p, '缓存中: $doneCount/$total');
          _emitEvent(taskId, p, 'downloading', '缓存中: $doneCount/$total');
        });

        if (cancelToken.isCancelled) return '';

        onProgress?.call(0.99, '生成播放列表...');
        _emitEvent(taskId, 0.99, 'downloading', '生成播放列表...');

        final localM3u8File = File('${downloadDir.path}/index.m3u8');
        final sink = localM3u8File.openWrite();

        sink.writeln('#EXTM3U');
        sink.writeln('#EXT-X-VERSION:3');
        final targetDuration =
            (playlist.targetDurationUs ?? 10000000) / 1000000;
        sink.writeln('#EXT-X-TARGETDURATION:${targetDuration.toInt()}');
        sink.writeln('#EXT-X-MEDIA-SEQUENCE:0');

        for (var i = 0; i < total; i++) {
          final seg = segments[i];
          final duration = (seg.durationUs ?? 0) / 1000000;
          sink.writeln('#EXTINF:$duration,');
          sink.writeln('${i}.ts');
        }

        sink.writeln('#EXT-X-ENDLIST');
        await sink.close();

        onProgress?.call(1.0, '缓存完成');
        _emitEvent(taskId, 1.0, 'done', '已完成',
            savePath: localM3u8File.path);
        return localM3u8File.path;
      }
      throw Exception('不支持的 M3U8 类型');
    } catch (e) {
      if (cancelToken.isCancelled) return '';
      final errMsg = '缓存失败: $e';
      onProgress?.call(0, errMsg);
      _emitEvent(taskId, 0, 'failed', errMsg, errorMsg: errMsg);
      rethrow;
    } finally {
      _activeCancelTokens.remove(taskId);
      _activeTaskIds.remove(taskId);
    }
  }

  void _emitEvent(String taskId, double progress, String status, String speed,
      {String? savePath, String? errorMsg}) {
    if (!_eventController.isClosed) {
      _eventController.add(DownloadEvent(
        taskId: taskId,
        progress: progress,
        status: status,
        speed: speed,
        savePath: savePath,
        errorMsg: errorMsg,
      ));
    }
  }

  Future<void> _runWithPool(
    List<_DownloadTask> tasks,
    int maxConcurrent,
    CancelToken cancelToken,
    Function(int) onProgress,
  ) async {
    final queue = List<_DownloadTask>.from(tasks);
    final active = <Future>[];
    int completed = 0;

    while (queue.isNotEmpty || active.isNotEmpty) {
      if (cancelToken.isCancelled) return;

      while (queue.isNotEmpty && active.length < maxConcurrent) {
        if (cancelToken.isCancelled) return;
        final task = queue.removeAt(0);

        late final Future future;
        future = _downloadOne(task, cancelToken).then((_) {
          completed++;
          onProgress(completed);
        }).catchError((e) {
          if (!cancelToken.isCancelled) {
            completed++;
            onProgress(completed);
          }
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

  Future<void> _downloadOne(_DownloadTask task, CancelToken cancelToken) async {
    int retry = 0;
    while (retry < 3) {
      if (cancelToken.isCancelled) return;
      try {
        await _dio.download(task.url, task.savePath,
            cancelToken: cancelToken);
        return;
      } catch (e) {
        if (cancelToken.isCancelled) return;
        retry++;
        if (retry >= 3) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<String> _downloadM3u8(String url, CancelToken cancelToken) async {
    final resp = await _dio.get(url, cancelToken: cancelToken);
    return resp.data.toString();
  }

  Future<bool> _checkPermission() async {
    try {
      if (await Permission.storage.isGranted) return true;
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
  _DownloadTask(
      {required this.index, required this.url, required this.savePath});
}
