import 'dart:io';
import 'package:dio/dio.dart';

/**
 * 开发者：杰哥
 * 作用：封装 MacCMS10 接口请求，把后端字段映射为前端易用结构
 * 解释：这就是“打电话给后台”的地方，拿列表、拿详情。
 */
class MacApi {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: '/api.php'),
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: { 'Content-Type': 'application/json' },
  ));

  /// 获取热播列表：小白理解为“拿热门视频卡片”
  Future<List<Map<String, dynamic>>> getHot({int page = 1}) async {
    final limit = 20;
    final offset = (page - 1) * limit;
    final resp = await _dio.get('/vod/get_list', queryParameters: {
      'offset': offset,
      'limit': limit,
      'orderby': 'hits_week',
    });
    final rows = (resp.data?['info']?['rows'] as List?) ?? [];
    return rows.map((v) => {
      'id': '${v['vod_id']}',
      'title': v['vod_name'] ?? '',
      'poster': v['vod_pic'] ?? '',
      'score': (v['vod_score'] ?? 0).toDouble(),
      'year': '${v['vod_year'] ?? ''}',
      'overview': v['vod_remarks'] ?? '',
    }).toList();
  }

  /// 搜索视频：小白理解为“按名字搜”
  Future<List<Map<String, dynamic>>> searchByName(String keyword) async {
    final resp = await _dio.get('/vod/get_list', queryParameters: {
      'vod_name': keyword,
      'limit': 20,
    });
    final rows = (resp.data?['info']?['rows'] as List?) ?? [];
    return rows.map((v) => {
      'id': '${v['vod_id']}',
      'title': v['vod_name'] ?? '',
      'poster': v['vod_pic'] ?? '',
      'score': (v['vod_score'] ?? 0).toDouble(),
      'year': '${v['vod_year'] ?? ''}',
      'overview': v['vod_remarks'] ?? '',
    }).toList();
  }

  /// 获取详情与播放列表：小白理解为“进详情页的一次性大包”
  Future<Map<String, dynamic>?> getDetail(String id) async {
    final resp = await _dio.get('/vod/get_detail', queryParameters: { 'vod_id': id });
    final info = resp.data?['info'];
    if (info == null) return null;
    return {
      'id': '${info['vod_id'] ?? id}',
      'title': info['vod_name'] ?? '',
      'poster': info['vod_pic'] ?? '',
      'score': (info['vod_score'] ?? 0).toDouble(),
      'year': '${info['vod_year'] ?? ''}',
      'overview': info['vod_blurb'] ?? info['vod_remarks'] ?? '',
      'play_list': info['vod_play_list'] ?? [],
    };
  }

  /// 判断是否移动端（安卓/苹果），用于播放器组件选择
  bool get isMobile => Platform.isAndroid || Platform.isIOS;
}
