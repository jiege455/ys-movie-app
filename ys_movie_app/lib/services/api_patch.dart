/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 作用：API扩展补丁，用于修复getHotKeywords方法
/// 解释：由于原文件过大，通过extension方式扩展功能

import 'api.dart';

extension MacApiPatch on MacApi {
  /// 修复后的获取热搜关键词方法
  /// 优先使用后台 system_hot_search 配置
  Future<List<String>> getHotKeywordsFixed() async {
    // 1. 优先从 AppInit 获取 (后台配置的搜索热词)
    final data = await getAppInit();
    if (data.isNotEmpty && data['hot_search_list'] != null) {
       final list = (data['hot_search_list'] as List);
       if (list.isNotEmpty) {
         return list.map((e) => e.toString()).toList();
       }
    }

    // 2. 使用后台 system_hot_search 配置（逗号分隔）
    final hotSearchStr = hotSearch;
    if (hotSearchStr.isNotEmpty) {
      final list = hotSearchStr.split(',').where((e) => e.trim().isNotEmpty).toList();
      if (list.isNotEmpty) return list;
    }

    // 3. 如果后台没配置热词，则自动获取"周热播"前10名的标题作为热搜
    try {
      final hotVideos = await getHot(page: 1);
      if (hotVideos.isNotEmpty) {
        return hotVideos.take(10).map((v) => v['title'].toString()).toList();
      }
    } catch (_) {}

    // 4. 最后的兜底
    return ['繁花', '庆余年', '斗破苍穹', '雪中悍刀行', '完美世界', '吞噬星空'];
  }
}
