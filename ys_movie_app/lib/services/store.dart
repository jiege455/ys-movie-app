/// 文件名：store.dart
/// 作者：杰哥（by：杰哥 / qq：2711793818）
/// 创建日期：2025-12-16
/// 作用：本地存储（收藏、历史、缓存、播放进度、播放器设置）
/// 解释：把“看过、收藏/缓存/播放设置”记在手机里，重启也不会丢
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 开发者：杰哥
/// 作用：本地收藏/历史存储
/// 解释：把“我喜欢的”和“我看过的”记在手机里，先不接后端也能用
class StoreService {
  static const _favKey = 'fav_list';
  static const _hisKey = 'history_list';
  static const _searchKey = 'search_history';
  static const _cacheKey = 'cache_list'; // 缓存列表
  static const _downloadKey = 'download_list'; // 下载任务列表
  static const _progressPrefix = 'progress:'; // progress:<id>|<url>
  static const _playerSettingPrefix = 'player_setting:'; // player_setting:<key>
  static const _playSelPrefix = 'play_sel:'; // play_sel:<vodId>
  static const _topNoticeShownIdKey = 'top_notice_shown_id';
  static const _homePageCacheKey = 'home_page_cache'; // 首页缓存（banners/items/typeRecommends）
  static const _homeTabsCacheKey = 'home_tabs_cache'; // 首页分类Tab缓存
  static const _lastUpdateCodeKey = 'last_update_code'; // 上次提示过的版本号

  /// 保存首页分类Tab缓存
  static Future<void> setHomeTabsCache(List<String> tabs, Map<String, dynamic> tabIds) async {
    final sp = await SharedPreferences.getInstance();
    final data = {
      'tabs': tabs,
      'tabIds': tabIds,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    await sp.setString(_homeTabsCacheKey, jsonEncode(data));
  }

  /// 读取首页分类Tab缓存
  static Future<Map<String, dynamic>?> getHomeTabsCache() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_homeTabsCacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 添加缓存（真实下载记录）
  /// 格式: id|title|poster|filePath|timestamp
  static Future<void> addCache(Map<String, dynamic> item) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_cacheKey) ?? [];
    final id = item['id']?.toString() ?? '';
    final url = item['url']?.toString() ?? '';

    if (id.isEmpty) return;

    // 移除旧记录
    list.removeWhere((e) => e.startsWith('$id|'));

    list.insert(0, '${item['id']}|${item['title'] ?? ''}|${item['poster'] ?? ''}|$url|${DateTime.now().millisecondsSinceEpoch}');

    await sp.setStringList(_cacheKey, list);
  }

  /// 获取缓存列表
  static Future<List<String>> getCache() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList(_cacheKey) ?? [];
  }

  static Future<void> clearCache() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_cacheKey);
  }

  static Future<void> removeCaches(List<String> ids) async {
    if (ids.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_cacheKey) ?? [];
    list.removeWhere((e) {
      for (final id in ids) {
        if (e.startsWith('$id|')) return true;
      }
      return false;
    });
    await sp.setStringList(_cacheKey, list);
  }

  /// 移除缓存
  static Future<void> removeCache(String id) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_cacheKey) ?? [];
    list.removeWhere((e) => e.startsWith('$id|'));
    await sp.setStringList(_cacheKey, list);
  }

  /// 开发者：杰哥
  /// 作用：新增/更新下载任务（用于展示下载进度）
  /// 解释：下载过程中会不断写入进度，方便"下载管理"页面实时刷新
  static Future<void> upsertDownload(Map<String, dynamic> task) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_downloadKey) ?? [];
    final id = task['id']?.toString() ?? '';
    if (id.isEmpty) return;
    list.removeWhere((e) => e.startsWith('$id|'));
    final title = (task['title'] ?? '').toString();
    final poster = (task['poster'] ?? '').toString();
    final url = (task['url'] ?? '').toString();
    final savePath = (task['savePath'] ?? '').toString();
    final progress = (task['progress'] ?? 0).toString();
    final status = (task['status'] ?? '').toString();
    final speed = (task['speed'] ?? '').toString();
    final ts = (task['ts'] ?? DateTime.now().millisecondsSinceEpoch).toString();
    list.insert(0, '$id|$title|$poster|$url|$savePath|$progress|$status|$speed|$ts');
    await sp.setStringList(_downloadKey, list);
  }

  /// 开发者：杰哥
  /// 作用：获取下载任务列表（字符串格式）
  /// 解释：给"下载管理"页面用
  static Future<List<String>> getDownloads() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList(_downloadKey) ?? [];
  }

  /// 开发者：杰哥
  /// 作用：删除单条下载任务
  /// 解释：只删记录，不一定删除文件（删除文件在页面里做）
  static Future<void> removeDownload(String id) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_downloadKey) ?? [];
    list.removeWhere((e) => e.startsWith('$id|'));
    await sp.setStringList(_downloadKey, list);
  }

  /// 开发者：杰哥
  /// 作用：清空全部下载任务
  /// 解释：清空下载列表，但不动已缓存文件
  static Future<void> clearDownloads() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_downloadKey);
  }

  /// 添加收藏
  static Future<void> addFavorite(Map<String, dynamic> item) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_favKey) ?? [];
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    // 去重
    if (!list.any((e) => e.startsWith('$id|'))) {
      list.insert(0, '${item['id']}|${item['title'] ?? ''}|${item['poster'] ?? ''}');
      await sp.setStringList(_favKey, list);
    }
  }

  /// 移除收藏
  static Future<void> removeFavorite(String id) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_favKey) ?? [];
    list.removeWhere((e) => e.startsWith('$id|'));
    await sp.setStringList(_favKey, list);
  }

  /// 检查是否已收藏
  static Future<bool> isFavorite(String id) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_favKey) ?? [];
    return list.any((e) => e.startsWith('$id|'));
  }

  /// 添加历史（存最近播放的集）
  /// 格式: id|title|poster|url|timestamp|position_seconds
  static Future<void> addHistory(Map<String, dynamic> item) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_hisKey) ?? [];
    final id = item['id']?.toString() ?? '';
    final url = item['url']?.toString() ?? '';
    final position = item['position']?.toString() ?? '0'; // 播放进度(秒)

    if (id.isEmpty) return;

    // 移除旧记录
    list.removeWhere((e) => e.startsWith('$id|'));

    list.insert(0, '${item['id']}|${item['title'] ?? ''}|${item['poster'] ?? ''}|$url|${DateTime.now().millisecondsSinceEpoch}|$position');

    // 最多保留100条
    if (list.length > 100) {
      list.removeRange(100, list.length);
    }
    await sp.setStringList(_hisKey, list);
  }

  /// 获取收藏
  static Future<List<String>> getFavorites() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList(_favKey) ?? [];
  }

  /// 获取历史
  static Future<List<String>> getHistory() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList(_hisKey) ?? [];
  }

  /// 获取历史记录详情
  static Future<Map<String, dynamic>?> getHistoryItem(String id) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_hisKey) ?? [];
    for (final item in list) {
      if (item.startsWith('$id|')) {
        final parts = item.split('|');
        if (parts.length >= 6) {
          return {
            'id': parts[0],
            'title': parts[1],
            'poster': parts[2],
            'url': parts[3],
            'timestamp': int.tryParse(parts[4]) ?? 0,
            'position': int.tryParse(parts[5]) ?? 0,
          };
        }
      }
    }
    return null;
  }

  /// 清空历史
  static Future<void> clearHistory() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_hisKey);
  }

  /// 开发者：杰哥
  /// 作用：新增搜索关键字到历史
  /// 解释：把你搜过的词记下来，方便下次一键搜索
  static Future<void> addSearchKeyword(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_searchKey) ?? [];
    list.removeWhere((e) => e == kw);
    list.insert(0, kw);
    if (list.length > 30) {
      list.removeRange(30, list.length);
    }
    await sp.setStringList(_searchKey, list);
  }

  /// 开发者：杰哥
  /// 作用：读取搜索历史关键字
  /// 解释：显示你最近搜过的词
  static Future<List<String>> getSearchHistory() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList(_searchKey) ?? [];
  }

  /// 开发者：杰哥
  /// 作用：删除某条搜索历史
  /// 解释：不想看到某个词就删掉它
  static Future<void> removeSearchKeyword(String keyword) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_searchKey) ?? [];
    list.removeWhere((e) => e == keyword);
    await sp.setStringList(_searchKey, list);
  }

  /// 开发者：杰哥
  /// 作用：清空搜索历史
  /// 解释：一键清空所有搜索记录
  static Future<void> clearSearchHistory() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_searchKey);
  }

  /// 保存播放进度（秒）
  static Future<void> setProgress({required String id, required String url, required int seconds}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('$_progressPrefix$id|$url', seconds);
  }

  /// 获取播放进度（秒）
  static Future<int> getProgress({required String id, required String url}) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt('$_progressPrefix$id|$url') ?? 0;
  }

  /// 开发者：杰哥
  /// 作用：获取上次弹过的置顶公告ID
  /// 解释：避免每次进首页都重复弹同一条公告
  static Future<int> getTopNoticeShownId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_topNoticeShownIdKey) ?? 0;
  }

  /// 开发者：杰哥
  /// 作用：保存已弹过的置顶公告ID
  /// 解释：记录一下这条公告已经提示过，下次就不弹了
  static Future<void> setTopNoticeShownId(int id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_topNoticeShownIdKey, id);
  }

  /// 开发者：杰哥
  /// 作用：读取上次提示过的版本号（用于避免重复弹窗）
  /// 解释：后台改了新版本才会再次弹提示，旧的就不弹了
  static Future<String> getLastUpdateCode() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_lastUpdateCodeKey) ?? '';
  }

  /// 开发者：杰哥
  /// 作用：保存已提示过的版本号
  /// 解释：记录一下这次版本号已经提醒过，下次就不重复弹
  static Future<void> setLastUpdateCode(String code) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_lastUpdateCodeKey, code);
  }

  /// 开发者：杰哥
  /// 作用：保存"上次播放选择"（线路 + 集数）
  /// 解释：你退出再进详情页，会自动回到你上次看的线路和集数
  static Future<void> setLastPlaySelection({required String vodId, required int sourceIndex, required int episodeIndex, String? episodeName}) async {
    final sp = await SharedPreferences.getInstance();
    final name = (episodeName ?? '').replaceAll('|', ' ');
    await sp.setString('$_playSelPrefix$vodId', '$sourceIndex|$episodeIndex|$name');
  }

  /// 开发者：杰哥
  /// 作用：读取"上次播放选择"（线路 + 集数）
  /// 解释：返回上次保存的线路序号和集数序号
  static Future<Map<String, dynamic>?> getLastPlaySelection(String vodId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('$_playSelPrefix$vodId');
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length < 2) return null;
    final sourceIndex = int.tryParse(parts[0]) ?? 0;
    final episodeIndex = int.tryParse(parts[1]) ?? 0;
    final name = parts.length > 2 ? parts.sublist(2).join('|') : '';
    return {
      'sourceIndex': sourceIndex,
      'episodeIndex': episodeIndex,
      'episodeName': name,
    };
  }

  /// 开发者：杰哥
  /// 作用：保存弹幕开关
  /// 解释：你关了弹幕，下次进来也保持关闭
  static Future<void> setDanmakuEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('${_playerSettingPrefix}danmaku_enabled', enabled);
  }

  /// 开发者：杰哥
  /// 作用：读取弹幕开关
  /// 解释：默认是开启弹幕
  static Future<bool> getDanmakuEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool('${_playerSettingPrefix}danmaku_enabled') ?? true;
  }

  /// 开发者：杰哥
  /// 作用：保存跳过片头秒数
  /// 解释：例如设置90秒，下次播放会自动从90秒处开始
  static Future<void> setSkipIntroSeconds(int seconds) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('${_playerSettingPrefix}skip_intro', seconds);
  }

  /// 开发者：杰哥
  /// 作用：读取跳过片头秒数
  /// 解释：默认0，表示不跳过
  static Future<int> getSkipIntroSeconds() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt('${_playerSettingPrefix}skip_intro') ?? 0;
  }

  /// 开发者：杰哥
  /// 作用：保存跳过片尾秒数
  /// 解释：播放到最后N秒会自动下一集
  static Future<void> setSkipEndingSeconds(int seconds) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('${_playerSettingPrefix}skip_ending', seconds);
  }

  /// 开发者：杰哥
  /// 作用：读取跳过片尾秒数
  /// 解释：默认0，表示不跳过
  static Future<int> getSkipEndingSeconds() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt('${_playerSettingPrefix}skip_ending') ?? 0;
  }

  /// 开发者：杰哥
  /// 作用：保存"是否启用片头片尾跳过"开关
  /// 解释：你开了跳过片头片尾，重启App也会记住
  static Future<void> setSkipEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('${_playerSettingPrefix}skip_enabled', enabled);
  }

  /// 开发者：杰哥
  /// 作用：读取"是否启用片头片尾跳过"开关
  /// 解释：读取你上次有没有打开跳过片头片尾
  static Future<bool> getSkipEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool('${_playerSettingPrefix}skip_enabled') ?? false;
  }

  /// 开发者：杰哥
  /// 作用：保存播放倍速
  /// 解释：把你常用倍速记下来
  static Future<void> setPlaybackSpeed(double speed) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('${_playerSettingPrefix}playback_speed', speed);
  }

  /// 开发者：杰哥
  /// 作用：读取播放倍速
  /// 解释：恢复你上次设置的倍速
  static Future<double> getPlaybackSpeed() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getDouble('${_playerSettingPrefix}playback_speed') ?? 1.0;
  }

  /// 开发者：杰哥
  /// 作用：保存手势快进快退灵敏度档位（0低/1中/2高）
  /// 解释：你滑动快进快退想要更大步进，就调高档位
  static Future<void> setSeekSensitivityLevel(int level) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('${_playerSettingPrefix}seek_sensitivity', level);
  }

  /// 开发者：杰哥
  /// 作用：读取手势快进快退灵敏度档位（0低/1中/2高）
  /// 解释：恢复上次的快进快退灵敏度
  static Future<int> getSeekSensitivityLevel() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt('${_playerSettingPrefix}seek_sensitivity') ?? 1;
  }

  /// 文件名：store.dart
  /// 作者：杰哥（by：杰哥 / qq：2711793818）
  /// 创建日期：2025-12-23
  /// 作用：保存首页数据缓存（轮播、热播、分类推荐）
  /// 解释：第一次打开太慢就用上次的数据垫着，避免一直转圈
  static Future<void> setHomePageCache(Map<String, dynamic> data) async {
    final sp = await SharedPreferences.getInstance();
    try {
      final payload = {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'banners': (data['banners'] as List?) ?? const [],
        'items': (data['items'] as List?) ?? const [],
        'typeRecommends': (data['typeRecommends'] as List?) ?? const [],
      };
      await sp.setString(_homePageCacheKey, jsonEncode(payload));
    } catch (_) {
      // ignore
    }
  }

  /// 文件名：store.dart
  /// 作者：杰哥（by：杰哥 / qq：2711793818）
  /// 创建日期：2025-12-23
  /// 作用：读取首页数据缓存（轮播、热播、分类推荐）
  /// 解释：能读到就先展示，网络好了再更新
  static Future<Map<String, dynamic>> getHomePageCache() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_homePageCacheKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
      // 容错：类型修复
      List<Map<String, dynamic>> toListMap(dynamic v) {
        if (v is List) {
          return v.map((e) => (e as Map).map((k, val) => MapEntry('$k', val))).cast<Map<String, dynamic>>().toList();
        }
        return <Map<String, dynamic>>[];
      }
      return {
        'ts': map['ts'] ?? 0,
        'banners': toListMap(map['banners']),
        'items': toListMap(map['items']),
        'typeRecommends': toListMap(map['typeRecommends']),
      };
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
