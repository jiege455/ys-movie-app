/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 缓存服务 - 负责清理APP各类缓存（图片缓存、网络缓存、数据库缓存等）
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CacheService {
  /// 开发者：杰哥网络科技 (qq: 2711793818)
  /// 作用：彻底清理所有缓存（图片缓存+临时文件+flutter_cache_manager缓存）
  /// 解释：把APP积攒的封面图、详情图、临时下载文件等统统删掉
  static Future<void> clearCache() async {
    // 1. 清理 CachedNetworkImage 的图片缓存（封面图、Banner图等）
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}

    // 2. 清理临时目录
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (final entity in tempDir.listSync(recursive: false)) {
          try {
            if (entity is File) {
              entity.deleteSync();
            } else if (entity is Directory) {
              entity.deleteSync(recursive: true);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 3. 清理应用缓存目录
    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (cacheDir.existsSync()) {
        for (final entity in cacheDir.listSync(recursive: false)) {
          try {
            if (entity is File) {
              entity.deleteSync();
            } else if (entity is Directory) {
              entity.deleteSync(recursive: true);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// 开发者：杰哥网络科技 (qq: 2711793818)
  /// 作用：获取当前缓存大小（MB）
  /// 解释：算一下临时目录、缓存目录+flutter_cache_manager各占了多少空间
  static Future<double> getCacheSize() async {
    double totalSize = 0.0;

    // 1. flutter_cache_manager 缓存
    try {
      final cacheStore = await DefaultCacheManager().getFileFromCache('');
      if (cacheStore != null) {
        // 更准确的方式：获取所有缓存文件大小
        try {
          final tempDir = await getTemporaryDirectory();
          final cacheDataDir = Directory('${tempDir.path}/libCachedImageData');
          if (cacheDataDir.existsSync()) {
            totalSize += await _getDirSize(cacheDataDir);
          }
        } catch (_) {}
      }
    } catch (_) {}

    // 2. 临时目录
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        totalSize += await _getDirSize(tempDir);
      }
    } catch (_) {}

    // 3. 缓存目录
    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (cacheDir.existsSync()) {
        totalSize += await _getDirSize(cacheDir);
      }
    } catch (_) {}

    // 转换为MB
    return totalSize / (1024 * 1024);
  }

  /// 计算目录及子目录总大小（字节）
  static Future<double> _getDirSize(Directory dir) async {
    double size = 0.0;
    try {
      final list = dir.listSync(recursive: true);
      for (final entity in list) {
        if (entity is File) {
          try {
            size += entity.lengthSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return size;
  }
}
