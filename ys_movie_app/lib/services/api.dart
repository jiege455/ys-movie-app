/// 文件名：api.dart
/// 作者：杰哥（by：杰哥 / qq：2711793818）
/// 创建日期：2025-12-16
/// 作用：MacCMS10 接口封装（首页初始化、分类筛选、详情、评论、弹幕、登录等）
/// 解释：所有网络请求都从这里走，首页分类/详情/搜索都靠它。
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'dart:collection';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class _LruEntry<V> {
  final V value;
  final DateTime expiresAt;
  const _LruEntry({required this.value, required this.expiresAt});
}

class _LruCache<V> {
  final int capacity;
  final Duration ttl;
  final LinkedHashMap<String, _LruEntry<V>> _map = LinkedHashMap();
  _LruCache({required this.capacity, required this.ttl});
  V? get(String key) {
    final entry = _map.remove(key);
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) return null;
    _map[key] = entry;
    return entry.value;
  }
  void set(String key, V value) {
    _map.remove(key);
    _map[key] = _LruEntry(value: value, expiresAt: DateTime.now().add(ttl));
    while (_map.length > capacity) { _map.remove(_map.keys.first); }
  }
  void clear() { _map.clear(); }
}

class MacApi {
  static final MacApi _instance = MacApi._internal();
  factory MacApi() => _instance;
  MacApi._internal() { setup(); }
  late Dio _dio;
  late CookieJar _cookieJar;
  bool _initialized = false;
  String? _appUserToken;
  DateTime? _lastDetect;
  bool? _pluginFilterOk;
  bool? _customApiOk;
  bool? _standardApiOk;
  String _appOs = 'android';
  int _appVersionCode = 1;
  String _appVersionName = '1.0.0';

  void setup() {
    _dio = Dio(BaseOptions(
      baseUrl: rootUrl, connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8), responseType: ResponseType.json,
      validateStatus: (status) => status != null && status < 500,
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (AppConfig.baseUrl.contains('/api.php')) {
          final path = options.path;
          if (!path.startsWith('http') && !path.startsWith('/') &&
              (path.startsWith('jgappapi') || path.startsWith('provide'))) {
            options.path = 'api.php/$path';
          }
        }
        if (_appUserToken != null && _appUserToken!.isNotEmpty) {
          options.headers['app-user-token'] = _appUserToken;
        }
        options.headers.addAll(_headers);
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (response.data is String) {
          try {
            final str = (response.data as String).trim();
            if (str.startsWith('{') || str.startsWith('[')) {
              response.data = jsonDecode(str);
            } else if (str == 'closed') {
              throw DioException(requestOptions: response.requestOptions,
                error: 'closed', type: DioExceptionType.badResponse);
            }
          } catch (e) { print('JSON err: $e'); }
        }
        handler.next(response);
      },
      onError: (e, handler) { print('API Error: ${e.message}'); handler.next(e); },
    ));
  }

  String get rootUrl {
    String root;
    final base = AppConfig.baseUrl;
    if (base.contains('/api.php')) { root = base.split('/api.php').first; }
    else { root = base; }
    return root.endsWith('/') ? root : '$root/';
  }

  Future<void> init() async {
    if (_initialized) return;
    if (!kIsWeb) { _cookieJar = CookieJar(); _dio.interceptors.add(CookieManager(_cookieJar)); }
    final prefs = await SharedPreferences.getInstance();
    _appUserToken = prefs.getString('app_user_token');
    try {
      final baseRoot = rootUrl;
      final lastBase = prefs.getString('app_init_base') ?? '';
      if (lastBase.trim() != baseRoot.trim()) {
        await prefs.remove('app_init_json'); await prefs.remove('app_init_ts');
        await prefs.setString('app_init_base', baseRoot); _categoryCache.clear();
      }
    } catch (_) {}
    _appOs = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios', TargetPlatform.android => 'android', _ => 'android',
    };
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersionName = info.version;
      _appVersionCode = _parseJgAppVersionCode(_appVersionName);
      if (_appVersionCode <= 0) { _appVersionCode = int.tryParse(info.buildNumber) ?? 0; }
      if (_appVersionCode <= 0) { _appVersionCode = 1; }
    } catch (_) { if (_appVersionCode <= 0) _appVersionCode = 1; }
    _initialized = true;
  }

  Future<Map<String, bool>> detectInterfaces({bool force = false}) async {
    if (!force && _lastDetect != null && DateTime.now().difference(_lastDetect!) < const Duration(minutes: 5)) {
      return {'plugin': _pluginFilterOk ?? false, 'custom': _customApiOk ?? false, 'standard': _standardApiOk ?? false};
    }
    await init(); _lastDetect = DateTime.now();
    try { final resp = await _dio.get('jgappapi.index/typeFilterVodList', queryParameters: {'page':1,'limit':1,'sort':'最新'}); _pluginFilterOk = resp.statusCode==200 && resp.data is Map && (resp.data['code']==1); } catch (_) { _pluginFilterOk=false; }
    try { final resp = await _dio.get('${rootUrl}app_api.php', queryParameters: {'ac':'list','pg':1,'pagesize':1}); _customApiOk = resp.statusCode==200 && resp.data is Map && (resp.data['code']==1); } catch (_) { _customApiOk=false; }
    try { final resp = await _dio.get('provide/vod/', queryParameters: {'ac':'list','pg':1,'pagesize':1,'at':'json'}); _standardApiOk = resp.statusCode==200 && resp.data is Map; } catch (_) { _standardApiOk=false; }
    return {'plugin': _pluginFilterOk ?? false, 'custom': _customApiOk ?? false, 'standard': _standardApiOk ?? false};
  }

  Future<Map<String, dynamic>> register(String username, String password, {String verifyCode='', String inviteCode=''}) async {
    await init();
    try {
      try {
        final data = {'user_name':username,'password':password,'invite_code':inviteCode};
        if (verifyCode.isNotEmpty) data['verify'] = verifyCode;
        final resp = await _dio.post('jgappapi.index/appRegister', data: data, options: Options(contentType: Headers.formUrlEncodedContentType, headers: _headers));
        if (resp.statusCode==200 && resp.data is Map && resp.data['code']==1) return {'success':true,'info':resp.data['msg']??'注册成功'};
        else if (resp.data is Map && resp.data['msg']!=null) return {'success':false,'msg':resp.data['msg']};
      } catch (_) {}
      final customApiUrl = '${rootUrl}app_api.php';
      try {
        final data = {'user_name':username,'user_pwd':password,'user_pwd2':password};
        if (verifyCode.isNotEmpty) data['verify'] = verifyCode;
        if (inviteCode.isNotEmpty) data['invite_code'] = inviteCode;
        final resp = await _dio.post(customApiUrl, queryParameters: {'ac':'register'}, data: data);
        if (resp.statusCode==200 && resp.data is Map) {
          if (resp.data['code']==1) return {'success':true,'info':resp.data['msg']??'注册成功'};
          else return {'success':false,'msg':resp.data['msg']};
        }
      } catch (_) {}
      final url = '${rootUrl}/index.php/user/reg';
      final data = {'user_name':username,'user_pwd':password,'user_pwd2':password,'verify':verifyCode};
      if (inviteCode.isNotEmpty) data['invite_code'] = inviteCode;
      final resp = await _dio.post(url, data: data, options: Options(contentType: Headers.formUrlEncodedContentType, headers: {'X-Requested-With':'XMLHttpRequest'}));
      final respData = resp.data;
      if (respData is Map && respData['code']==1) return {'success':true,'info':respData['msg']??'注册成功'};
      else if (respData is Map) return {'success':false,'msg':respData['msg']??'注册失败'};
      else return {'success':false,'msg':'服务器返回非JSON格式'};
    } catch (e) { return {'success':false,'msg':'请求失败: $e'}; }
  }

  Future<bool> checkLogin({bool force=false}) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final hasToken = _appUserToken != null && _appUserToken!.isNotEmpty;
    if (force) {
      try {
        final resp = await _dio.get('jgappapi.index/userInfo');
        final code = int.tryParse('${resp.data['code']??0}')??0;
        if (resp.statusCode==200 && resp.data is Map && code==1) {
          try { final data=resp.data['data']; if (data is Map && data['user_info'] is Map) { final user=data['user_info'] as Map; if (user['user_name']!=null) await prefs.setString('user_name',user['user_name'].toString()); } } catch (_) {}
          return true;
        }
        await logout(); return false;
      } catch (_) { await logout(); return false; }
    }
    if (!hasToken) return false;
    try {
      final resp = await _dio.get('jgappapi.index/userInfo');
      final code = int.tryParse('${resp.data['code']??0}')??0;
      if (resp.statusCode==200 && resp.data is Map && code==1) return true;
      await logout(); return false;
    } catch (_) { return true; }
  }

  Future<void> _saveAppUserToken(String? token) async {
    if (token==null||token.isEmpty) return;
    _appUserToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_user_token', token);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    await init();
    try {
      final resp = await _dio.post('jgappapi.index/appLogin', data: {'user_name':username,'password':password}, options: Options(contentType: Headers.formUrlEncodedContentType, headers: _headers));
      final code = int.tryParse('${resp.data['code']??0}')??0;
      if (resp.statusCode==200 && resp.data is Map && code==1) {
        final data=resp.data['data']; String? token;
        if (data is Map) { if (data['user'] is Map) token=data['user']['auth_token']?.toString(); if (token==null||token.isEmpty) token=data['auth_token']?.toString(); if (token==null||token.isEmpty) token=data['token']?.toString(); }
        await _saveAppUserToken(token); final prefs=await SharedPreferences.getInstance(); await prefs.setString('user_name',username);
        return {'success':true,'info':resp.data['msg']??'登录成功'};
      }
    } catch (_) {}
    final customApiUrl='${rootUrl}app_api.php';
    try {
      final resp=await _dio.post(customApiUrl, queryParameters:{'ac':'login'}, data:{'user_name':username,'user_pwd':password});
      if (resp.statusCode==200 && resp.data is Map) {
        final code=int.tryParse('${resp.data['code']??0}')??0;
        if (code==1) { final prefs=await SharedPreferences.getInstance(); await prefs.setString('user_name',username); return {'success':true,'info':resp.data['msg']??'登录成功'}; }
        else return {'success':false,'msg':resp.data['msg']};
      }
    } catch (_) {}
    final url='${rootUrl}index.php/user/login';
    try {
      final resp=await _dio.post(url, data:{'user_name':username,'user_pwd':password}, options:Options(contentType:Headers.formUrlEncodedContentType, headers:{'X-Requested-With':'XMLHttpRequest','User-Agent':'Mozilla/5.0'}, validateStatus:(s)=>s!<500));
      final data=resp.data; final code=int.tryParse('${data['code']??0}')??0;
      if (data is Map && code==1) { final prefs=await SharedPreferences.getInstance(); await prefs.setString('user_name',username); return {'success':true,'info':data['msg']??'登录成功'}; }
      else return {'success':false,'msg':data is Map?data['msg']:'登录失败'};
    } catch (e) {
      try { final resp=await _dio.post('user/login', data:{'user_name':username,'user_pwd':password}); if (int.tryParse('${resp.data['code']??0}')??0==1) return {'success':true,'info':resp.data['info']}; } catch (_) {}
      return {'success':false,'msg':'登录请求失败: $e'};
    }
  }

  Future<void> logout() async {
    await init();
    if (!kIsWeb) await _cookieJar.deleteAll();
    final prefs=await SharedPreferences.getInstance();
    await prefs.remove('user_name'); await prefs.remove('app_user_token'); _appUserToken=null;
  }

  Future<String> getUserName() async { final prefs=await SharedPreferences.getInstance(); return prefs.getString('user_name')??'用户'; }

  Future<Map<String, dynamic>> addFav(String vodId) async {
    await init();
    try { final resp=await _dio.get('jgappapi.index/collect', queryParameters:{'vod_id':vodId}, options:Options(headers:_headers)); if (resp.statusCode==200&&resp.data is Map) { final code=int.tryParse('${resp.data['code']??1}')??1; final msg=(resp.data['data'] is Map)?(resp.data['data']['msg']?.toString()??''):(resp.data['msg']?.toString()??''); return {'success':code==1,'msg':msg.isNotEmpty?msg:(code==1?'收藏成功':'收藏失败')}; } } catch (_) {}
    try { final resp=await _dio.post('user/ulog_add', data:{'ulog_mid':1,'ulog_rid':vodId,'ulog_type':2}); final code=int.tryParse('${resp.data['code']??0}')??0; return {'success':code==1,'msg':resp.data['msg']??(code==1?'收藏成功':'收藏失败')}; } catch (e) { return {'success':false,'msg':'请求失败: $e'}; }
  }

  Future<bool> addHistory(String vodId) async { await init(); final resp=await _dio.post('user/ulog_add', data:{'ulog_mid':1,'ulog_rid':vodId,'ulog_type':4}); return resp.data['code']==1; }

  Future<List<Map<String, dynamic>>> getFavs({int page=1}) async {
    await init();
    try { final resp=await _dio.get('jgappapi.index/collectList', queryParameters:{'page':page}, options:Options(headers:_headers)); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; final rows=(data?['collect_list'] as List?)??[]; return rows.whereType<Map>().map((v){ final vod=(v['vod'] as Map?)??{}; return {'log_id':'${v['id']}','id':'${v['vod_id']}','title':vod['vod_name']?.toString()??'','poster':_fixUrl(vod['vod_pic']?.toString())}; }).toList(); } } catch (_) {}
    try { final resp=await _dio.get('user/ulog_list', queryParameters:{'ulog_mid':1,'ulog_type':2,'limit':100}); final rows=(resp.data?['info']?['rows'] as List?)??[]; return rows.map((v)=>{'log_id':'${v['ulog_id']}','id':'${v['ulog_rid']}','title':(v['data'] is Map?v['data']['name']:'')??'','poster':_fixUrl((v['data'] is Map?v['data']['pic']:'')?.toString())}).toList(); } catch (_) { return []; }
  }

  Future<Map<String, dynamic>> deleteFav(String logId, {String? vodId, String? ids}) async {
    await init();
    try { final effectiveIds=ids??(RegExp(r'^\d+$').hasMatch(logId)?logId:null); if ((vodId!=null&&vodId.isNotEmpty)||(effectiveIds!=null&&effectiveIds.isNotEmpty)) { final params=<String,dynamic>{}; if (effectiveIds!=null&&effectiveIds.isNotEmpty) params['ids']=effectiveIds; else params['vod_id']=vodId; final resp=await _dio.get('jgappapi.index/deleteCollect', queryParameters:params, options:Options(headers:_headers)); if (resp.statusCode==200&&resp.data is Map) { final code=int.tryParse('${resp.data['code']??1}')??1; final msg=resp.data['msg']?.toString()??''; return {'success':code==1,'msg':msg.isNotEmpty?msg:(code==1?'删除成功':'删除失败')}; } } } catch (_) {}
    try { final resp=await _dio.post('user/ulog_del', data:{'ids':logId,'type':2}); final code=int.tryParse('${resp.data['code']??0}')??0; return {'success':code==1,'msg':resp.data['msg']??(code==1?'删除成功':'删除失败')}; } catch (e) { return {'success':false,'msg':'请求失败: $e'}; }
  }

  Future<Map<String, dynamic>> deleteFavByVodId(String vodId) async {
    await init();
    try { final resp=await _dio.get('jgappapi.index/deleteCollect', queryParameters:{'vod_id':vodId}, options:Options(headers:_headers)); if (resp.statusCode==200&&resp.data is Map) { final code=int.tryParse('${resp.data['code']??1}')??1; return {'success':code==1,'msg':resp.data['msg']??'删除成功'}; } } catch (_) {}
    try { final favs=await getFavs(page:1); final item=favs.firstWhere((e)=>'${e['id']}'==vodId, orElse:()=>{}); if (item.isNotEmpty&&item['log_id']!=null) return await deleteFav(item['log_id']!); } catch (_) {}
    return {'success':false,'msg':'未找到收藏记录'};
  }

  Future<bool> isCollected(String vodId) async {
    await init();
    try { final resp=await _dio.get('jgappapi.index/isCollect', queryParameters:{'vod_id':vodId}, options:Options(headers:_headers)); if (resp.statusCode==200&&resp.data is Map) { final data=resp.data['data']; if (data is Map&&data['is_collect'] is bool) return data['is_collect'] as bool; if (data is bool) return data; } } catch (_) {}
    try { final favs=await getFavs(page:1); return favs.any((e)=>'${e['id']}'==vodId); } catch (_) { return false; }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    await init();
    final resp=await _dio.get('user/ulog_list', queryParameters:{'ulog_mid':1,'ulog_type':4,'limit':100});
    final rows=(resp.data?['info']?['rows'] as List?)??[];
    return rows.map((v)=>{'id':'${v['ulog_rid']}','title':v['data']['name']??'','poster':v['data']['pic']??''}).toList();
  }

  String fixUrl(String? url) {
    if (url==null||url.isEmpty) return '';
    if (url.contains('mac_turl')) return '';
    String finalUrl=url;
    if (!url.startsWith('http')) { final base=AppConfig.baseUrl; final root=base.split('/api.php').first; if (url.startsWith('/')) finalUrl='$root$url'; else finalUrl='$root/$url'; }
    if (AppConfig.baseUrl.startsWith('https://')&&finalUrl.startsWith('http://')) finalUrl=finalUrl.replaceFirst('http://','https://');
    return finalUrl;
  }
  String _fixUrl(String? url) => fixUrl(url);

  Future<List<Map<String, dynamic>>> getBanner() async {
    final data=await getAppInit();
    List<Map<String, dynamic>> banners=[];
    Map<String, dynamic> _parseBannerItem(dynamic v) => {'id':'${v['vod_id']??v['slide_id']??v['id']??''}','title':(v['vod_name']??v['slide_name']??v['title']??'').toString(),'poster':_fixUrl(v['vod_pic']??v['slide_pic']??v['poster']??v['img']??''),'type':(v['type_name']??v['type']??'').toString(),'url':(v['vod_link']??v['slide_url']??v['url']??'').toString()};
    void _tryParseField(String key) { try { final field=data[key]; if (field==null) return; if (field is List) { for(final item in field) { if (item is Map) banners.add(_parseBannerItem(item)); } } else if (field is Map) { banners.add(_parseBannerItem(field)); } } catch (_) {} }
    _tryParseField('banner_list'); if (banners.isEmpty) _tryParseField('home_banner');
    if (banners.isEmpty) _tryParseField('slide_list'); if (banners.isEmpty) _tryParseField('focus_list');
    if (banners.isEmpty) _tryParseField('advert_list');
    if (banners.isNotEmpty) return banners;
    try { final latest=await getFiltered(orderby:'time',limit:5); if (latest.isNotEmpty) return latest.map((e)=>{'id':e['id'],'title':e['title'],'poster':e['poster'],'type':e['type']??''}).toList(); } catch (e) { print('Banner fallback: $e'); }
    return [];
  }

  Future<List<Map<String, dynamic>>> getHot({int page=1}) async {
    const limit=20;
    try { final list=await getFiltered(page:page,limit:limit,orderby:'hits_week'); if (list.isNotEmpty) return list; } catch (_) {}
    await init();
    try { final resp=await _dio.get('provide/vod/', queryParameters:{'ac':'detail','pg':page,'pagesize':limit,'by':'hits_week','at':'json'}); if (resp.data is String&&resp.data.toString().trim()=='closed') return []; final rows=(resp.data?['list'] as List?)??[]; return rows.map((v)=>{'id':'${v['vod_id']??v['id']??0}','title':v['vod_name']??v['title']??'','poster':_fixUrl(v['vod_pic']??v['poster']??v['pic']),'score':double.tryParse('${v['vod_score']??v['score']??0}')??0.0,'year':'${v['vod_year']??v['year']??''}','overview':v['vod_remarks']??v['overview']??v['blurb']??''}).toList(); } catch (_) { return []; }
  }

  final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  Map<String, dynamic>? _initData;
  DateTime? _initDataAt;

  List<String> get filterWords { if (_initData!=null&&_initData!['filter_words'] is List) return (_initData!['filter_words'] as List).map((e)=>e.toString()).toList(); return []; }
  Map<String, dynamic> get appConfig { if (_initData!=null&&_initData!['config'] is Map) return _initData!['config'] as Map<String, dynamic>; return {}; }
  Map<String, dynamic> get appPageSetting { if (_initData!=null&&_initData!['app_page_setting'] is Map&&_initData!['app_page_setting']['app_page_setting'] is Map) return _initData!['app_page_setting']['app_page_setting'] as Map<String, dynamic>; return {}; }

  String get contactUrl => appConfig['app_contact_url']?.toString()??appConfig['kefu_url']?.toString()??'';
  String get contactText => appConfig['app_contact_text']?.toString()??'联系客服';
  String get shareText => appConfig['app_share_text']?.toString()??'推荐一款很好用的追剧APP，快来下载吧！';
  String get extraFindUrl => appConfig['app_extra_find_url']?.toString()??'';
  int get cacheTime => int.tryParse('${appConfig['init_cache_time']??60}')??60;
  bool get isCommentOpen { final dynamic val=appConfig['system_comment_status']??appConfig['app_comment_open']??appConfig['comment_open']??appConfig['comment_status']??1; return (int.tryParse('$val')??1)==1; }
  bool get isCommentAudit => (int.tryParse('${appConfig['system_comment_audit']??0}')??0)==1;
  bool get isRegOpen => (int.tryParse('${appConfig['system_register_user_status']??1}')??1)==1;
  bool get isRegVerify => (int.tryParse('${appConfig['system_reg_verify']??0}')??0)==1;
  bool get isRegWarter => (int.tryParse('${appConfig['system_reg_warter']??0}')??0)==1;
  int get regNum => int.tryParse('${appConfig['system_reg_num']??0}')??0;
  bool get isVpnDetect => appConfig['system_vpn_check_status']==true;
  int get trySee => int.tryParse('${appConfig['system_trysee']??0}')??0;
  bool get isDanmuEnabled => (int.tryParse('${appConfig['system_danmu_status']??1}')??1)==1;
  bool get isThirdDanmuEnabled => appConfig['system_third_danmu_status']==true;
  bool get isUserAvatarOpen => (int.tryParse('${appConfig['system_user_avatar_status']??1}')??1)==1;
  String get hotSearch => appConfig['system_hot_search']?.toString()??'';
  int get searchListType => int.tryParse('${appConfig['system_config_search_list_type']??1}')??1;
  String get aboutUsAvatar => appConfig['system_config_about_us_avatar_url']?.toString()??'';
  String get aboutUsContent => appConfig['system_config_about_us_content']?.toString()??'';
  int get bannerLevel => int.tryParse('${appConfig['system_banner_level']??9}')??9;
  int get hotLevel => int.tryParse('${appConfig['system_hot_level']??8}')??8;
  bool get isHideVersion => appPageSetting['app_page_version_hide']==true;
  bool get isHideDetailPic => appPageSetting['app_page_vod_detail_pic_hide']==true;
  bool get isHideMineBg => appPageSetting['app_page_mine_bg_hide']==true;
  int get homepageTypeSize => int.tryParse('${appPageSetting['app_page_homepage_type_size']??14}')??14;
  int get homepageBannerInterval => int.tryParse('${appPageSetting['app_page_homepage_banner_interval']??5}')??5;
  String get rankListType => appPageSetting['app_page_rank_list_type']?.toString()??'2';
  int get vodSourceType => int.tryParse('${appPageSetting['app_vod_source_type']??0}')??0;

  Set<String> get enabledParserNames {
    final config=appConfig;
    final raw=config['parse_list']??config['parse_api_list']??config['system_parse_list']??config['player_list']??config['play_list_config']??config['parser_config'];
    if (raw is! List||raw.isEmpty) return <String>{};
    return raw.whereType<Map>().where((m){ final en=m['enabled']??m['status']??m['is_open']??m['player_status']; if (en==null) return true; if (en is bool) return en; return (int.tryParse('$en')??0)==1; }).map((m)=>(m['name']??m['show']??m['player_name']??m['player']??'').toString()).toSet();
  }

  bool get isSplashAdOpen => appConfig['ad_splash_status']==true;
  bool get isHomeInsertAdOpen => appConfig['ad_home_page_insert_status']==true;
  bool get isMineBannerAdOpen => appConfig['ad_mine_page_banner_status']==true;
  bool get isDetailBannerAdOpen => appConfig['ad_detail_page_banner_status']==true;
  bool get isSearchBannerAdOpen => appConfig['ad_search_page_banner_status']==true;

  String get searchVodRule { if (_initData!=null&&_initData!['app_page_setting'] is Map) return (_initData!['app_page_setting'] as Map)['search_vod_rule']?.toString()??'搜索名称 简介'; return '搜索名称 简介'; }
  bool containsFilterWord(String text) { if (text.isEmpty) return false; for(final word in filterWords) { if (word.isNotEmpty&&text.contains(word)) return true; } return false; }

  Map<String, dynamic> get _headers => {'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36','X-Requested-With':'XMLHttpRequest','app-os':_appOs,'app-version-code':'$_appVersionCode'};

  int _parseJgAppVersionCode(String versionName) { final parts=versionName.split('.'); if (parts.length<3) return 0; final major=int.tryParse(parts[0])??0; final minor=int.tryParse(parts[1])??0; final patch=int.tryParse(parts[2])??0; return major*10000+minor*100+patch; }

  Future<Map<String, dynamic>> getAppInit({bool force=false}) async {
    if (!force&&_initData!=null&&_initDataAt!=null&&DateTime.now().difference(_initDataAt!)<const Duration(minutes:30)) return _initData!;
    await init();
    try { final disk=await _loadInitDataFromDisk(); if (!force&&disk!=null&&disk.isNotEmpty) { _initData=disk['data'] as Map<String, dynamic>; _initDataAt=DateTime.fromMillisecondsSinceEpoch(disk['ts'] as int); _refreshAppInitInBackground(); return _initData!; } } catch (_) {}
    _initData=null; _initDataAt=null;
    try {
      final resp=await _dio.get('jgappapi.index/init', options:Options(headers:_headers));
      if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) {
        final respMap=resp.data as Map; dynamic data=respMap['data'];
        if (data is String) { final raw=data.trim(); try { data=jsonDecode(utf8.decode(base64Decode(raw))); } catch (_) { try { data=jsonDecode(raw); } catch (_) { data=<String,dynamic>{}; } } }
        final Map dataMap=(data is Map)?data:<String,dynamic>{};
        dynamic rawTypeList=dataMap['type_list'];
        if (rawTypeList==null&&dataMap['data'] is Map) rawTypeList=dataMap['data']['type_list'];
        if (rawTypeList==null&&respMap['type_list']!=null) rawTypeList=respMap['type_list'];
        if (rawTypeList is String) { final raw=rawTypeList.trim(); try { rawTypeList=jsonDecode(utf8.decode(base64Decode(raw))); } catch (_) { try { rawTypeList=jsonDecode(raw); } catch (_) { rawTypeList=[]; } } }
        if (rawTypeList is Map) { final List<Map<String,dynamic>> mapped=[]; (rawTypeList as Map).forEach((k,v){ final id=int.tryParse('$k')??(int.tryParse('${(v as Map?)?['type_id']??0}')??0); if (v is Map) { final name=(v['type_name']??v['name']??'').toString().trim(); if (id>0&&name.isNotEmpty) mapped.add({'type_id':id,'type_name':name,'enabled':(v['enabled']??v['is_enabled']??v['status']??v['type_status']??v['is_open']??1)}); } else { final name='$v'.toString().trim(); if (id>0&&name.isNotEmpty) mapped.add({'type_id':id,'type_name':name,'enabled':1}); } }); rawTypeList=mapped; }
        var typeList=(rawTypeList is List)?rawTypeList:[];

        _initData={
          'config':dataMap['config'],
          'type_list':typeList.whereType<Map>().map((m){ final dynamic enabledRaw=m['enabled']??m['is_enabled']??m['status']??m['type_status']??m['is_open']; final bool enabled=enabledRaw==null?true:(enabledRaw is bool?enabledRaw:(int.tryParse('$enabledRaw')??0)==1); return {'type_id':m['type_id'],'type_name':(m['type_name']??'').toString().trim(),'enabled':enabled,'type_extend':m['type_extend']??m['extend']??null}; }).toList(),
          'type_extend':dataMap['type_extend']??dataMap['extend']??null,
          'app_page_setting':dataMap['app_page_setting'],
          'notice':(dataMap['notice'] is Map)?{'id':(dataMap['notice'] as Map)['id'],'title':(dataMap['notice'] as Map)['title']??'','sub_title':(dataMap['notice'] as Map)['sub_title']??'','create_time':(dataMap['notice'] as Map)['create_time']??'','content':(dataMap['notice'] as Map)['content']??'','is_force':((dataMap['notice'] as Map)['is_force']==true||(dataMap['notice'] as Map)['is_force']==1||'${(dataMap['notice'] as Map)['is_force']}'=='1')}:null,
          'update':(dataMap['update'] is Map)?{'version_name':(dataMap['update'] as Map)['version_name']?.toString()??'','version_code':(dataMap['update'] as Map)['version_code']?.toString()??'','download_url':(dataMap['update'] as Map)['download_url']?.toString()??'','browser_download_url':(dataMap['update'] as Map)['browser_download_url']?.toString()??'','app_size':(dataMap['update'] as Map)['app_size']?.toString()??'','description':(dataMap['update'] as Map)['description']?.toString()??'','is_force':((dataMap['update'] as Map)['is_force']==true||(dataMap['update'] as Map)['is_force']==1)}:null,
          'banner_list':((dataMap['banner_list'] as List?)??[]).whereType<Map>().map((v){ final id='${v['vod_id']??v['slide_id']??v['id']??''}'; final title=(v['vod_name']??v['slide_name']??v['title']??'').toString(); final pic=(v['vod_pic']??v['slide_pic']??v['poster']??v['img']??'').toString(); final url=(v['vod_link']??v['slide_url']??v['url']??'').toString(); return {'id':id,'title':title,'poster':_fixUrl(pic),'type':v['type_name']??'','url':url}; }).toList(),
          'recommend_list':((dataMap['recommend_list'] as List?)??[]).whereType<Map>().map((v)=>{'id':'${v['vod_id']??v['id']??0}','title':v['vod_name']??v['title']??'','poster':_fixUrl(v['vod_pic']??v['poster']??v['pic']),'score':double.tryParse('${v['vod_score']??v['score']??0}')??0.0,'year':'${v['vod_year']??v['year']??''}','overview':v['vod_remarks']??v['overview']??v['blurb']??'','area':v['vod_area']??v['area']??'','director':v['vod_director']??v['director']??'','actor':v['vod_actor']??v['actor']??''}).toList(),
          'type_recommend_list':typeList.whereType<Map>().where((t){ final id=int.tryParse('${t['type_id']??0}')??0; return id!=0&&t['recommend_list'] is List; }).map((t){ final typeId=t['type_id']; final typeName=(t['type_name']??'').toString().trim(); final recList=(t['recommend_list'] as List?)??[]; return {'type_id':typeId,'type_name':typeName,'list':recList.whereType<Map>().map((v)=>{'id':'${v['vod_id']}','title':v['vod_name']??'','poster':_fixUrl(v['vod_pic']),'overview':v['vod_remarks']??'','year':'${v['vod_year']??''}'}).toList()}; }).toList(),
          'home_advert':(dataMap['home_advert'] is Map)?{'id':'${dataMap['home_advert']['vod_id']}','title':dataMap['home_advert']['vod_name']??'','poster':_fixUrl(dataMap['home_advert']['vod_pic']),'url':dataMap['home_advert']['vod_link']??''}:null,
          'icon_advert':((dataMap['icon_advert'] as List?)??[]).whereType<Map>().map((v)=>{'id':'${v['vod_id']}','title':v['vod_name']??'','poster':_fixUrl(v['vod_pic']),'url':v['vod_link']??''}).toList(),
          'hot_search_list':_parseHotSearch(dataMap),
          'notice_count':int.tryParse('${dataMap['notice_count']??0}')??0,
          'filter_words':(dataMap['filter_words'] is String)?(dataMap['filter_words'] as String).split(',').where((e)=>e.isNotEmpty).toList():[],
          'advert_list':dataMap['advert_list']??respMap['advert_list'],
          'custom_ads':dataMap['custom_ads']??respMap['custom_ads'],
          'ads':dataMap['ads']??respMap['ads'],
          'home_banner':dataMap['home_banner']??respMap['home_banner'],
          'slide_list':dataMap['slide_list']??respMap['slide_list'],
          'focus_list':dataMap['focus_list']??respMap['focus_list'],
          'app_comment_top_status':dataMap['app_comment_top_status']??respMap['app_comment_top_status']??(dataMap['config'] is Map?dataMap['config']['app_comment_top_status']:null)??(dataMap['system'] is Map?dataMap['system']['app_comment_top_status']:null),
          'app_comment_top_name':dataMap['app_comment_top_name']??respMap['app_comment_top_name']??(dataMap['config'] is Map?dataMap['config']['app_comment_top_name']:null)??(dataMap['system'] is Map?dataMap['system']['app_comment_top_name']:null),
          'app_comment_top_avatar':dataMap['app_comment_top_avatar']??respMap['app_comment_top_avatar']??(dataMap['config'] is Map?dataMap['config']['app_comment_top_avatar']:null)??(dataMap['system'] is Map?dataMap['system']['app_comment_top_avatar']:null),
          'app_comment_top_content':dataMap['app_comment_top_content']??respMap['app_comment_top_content']??(dataMap['config'] is Map?dataMap['config']['app_comment_top_content']:null)??(dataMap['system'] is Map?dataMap['system']['app_comment_top_content']:null),
        };
        _initDataAt=DateTime.now(); _saveInitDataToDisk(_initData!); return _initData!;
      }
    } catch (_) {}
    try {
      final resp=await _dio.get('jgappapi.index/typeList', options:Options(headers:_headers));
      if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) {
        final data=(resp.data['data'] as Map?)??{};
        final typeList=(data['type_list'] as List?)??[];
        if (typeList.isNotEmpty) {
          _initData={'config':data['config'],'type_list':typeList.map((m){ final dynamic enabledRaw=m['enabled']??m['is_enabled']??m['status']??m['type_status']??m['is_open']; final bool enabled=enabledRaw==null?true:(enabledRaw is bool?enabledRaw:(int.tryParse('$enabledRaw')??0)==1); return {'type_id':m['type_id'],'type_name':(m['type_name']??'').toString().trim(),'enabled':enabled}; }).toList()};
          _initDataAt=DateTime.now(); _saveInitDataToDisk(_initData!); return _initData!;
        }
      }
    } catch (_) {}
    final customApiUrl='${rootUrl}app_api.php';
    try {
      final resp=await _dio.get(customApiUrl, queryParameters:{'ac':'init'}, options:Options(headers:_headers));
      if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) {
        final raw=resp.data as Map; final rawTypeList=(raw['type_list'] as List?)??[];
        final normalizedTypeList=rawTypeList.whereType<Map>().map((m){ final dynamic enabledRaw=m['enabled']??m['is_enabled']??m['status']??m['type_status']??m['is_open']; final bool enabled=enabledRaw==null?true:(enabledRaw is bool?enabledRaw:(int.tryParse('$enabledRaw')??0)==1); return {'type_id':m['type_id'],'type_name':(m['type_name']??'').toString().trim(),'enabled':enabled}; }).toList();
        _initData={...raw,if (raw['notice'] is Map) 'notice':{'id':(raw['notice'] as Map)['id'],'title':(raw['notice'] as Map)['title']??'','sub_title':(raw['notice'] as Map)['sub_title']??'','create_time':(raw['notice'] as Map)['create_time']??'','content':(raw['notice'] as Map)['content']??'','is_force':((raw['notice'] as Map)['is_force']==true||(raw['notice'] as Map)['is_force']==1||'${(raw['notice'] as Map)['is_force']}'=='1')},if (normalizedTypeList.isNotEmpty) 'type_list':normalizedTypeList};
        _initDataAt=DateTime.now(); _saveInitDataToDisk(_initData!); return _initData!;
      }
    } catch (e) { print('Init API Error: $e'); }
    _initData={'type_list':<Map<String,dynamic>>[]}; _initDataAt=DateTime.now(); _saveInitDataToDisk(_initData!); return _initData!;
  }

  Future<List<Map<String, dynamic>>> getPluginTypeList() async {
    await init();
    try {
      final resp=await _dio.get('jgappapi.index/typeList', options:Options(headers:_headers));
      if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) {
        final data=(resp.data['data'] as Map?)??{};
        dynamic raw=data['type_list']??data['list']??data['class'];
        if (raw is String) { final s=raw.trim(); try { raw=jsonDecode(utf8.decode(base64Decode(s))); } catch (_) { try { raw=jsonDecode(s); } catch (_) { raw=[]; } } }
        if (raw is Map) { final List<Map<String,dynamic>> mapped=[]; (raw as Map).forEach((k,v){ final id=int.tryParse('$k')??(int.tryParse('${(v as Map?)?['type_id']??0}')??0); if (v is Map) { final name=(v['type_name']??v['name']??'').toString().trim(); if (id>0&&name.isNotEmpty) mapped.add({'type_id':id,'type_name':name,'enabled':(v['enabled']??v['is_enabled']??v['status']??v['type_status']??v['is_open']??1)}); } else { final name='$v'.toString().trim(); if (id>0&&name.isNotEmpty) mapped.add({'type_id':id,'type_name':name,'enabled':1}); } }); raw=mapped; }
        if (raw is List) return raw.whereType<Map>().map((m){ final dynamic enabledRaw=m['enabled']??m['is_enabled']??m['status']??m['type_status']??m['is_open']; final bool enabled=enabledRaw==null?true:(enabledRaw is bool?enabledRaw:(int.tryParse('$enabledRaw')??0)==1); return {'type_id':m['type_id'],'type_name':(m['type_name']??'').toString().trim(),'enabled':enabled}; }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveInitDataToDisk(Map<String, dynamic> data) async { try { final prefs=await SharedPreferences.getInstance(); await prefs.setString('app_init_json',jsonEncode(data)); await prefs.setInt('app_init_ts',DateTime.now().millisecondsSinceEpoch); } catch (_) {} }
  Future<Map<String, dynamic>?> _loadInitDataFromDisk() async { try { final prefs=await SharedPreferences.getInstance(); final raw=prefs.getString('app_init_json'); final ts=prefs.getInt('app_init_ts')??0; if (raw==null||raw.isEmpty) return null; final Map<String,dynamic> data=jsonDecode(raw); if (data.isEmpty) return null; return {'data':data,'ts':ts}; } catch (_) { return null; } }
  Future<void> _refreshAppInitInBackground() async { try { final latest=await getAppInit(force:true); await _saveInitDataToDisk(latest); } catch (_) {} }

  Future<List<Map<String, dynamic>>> getVodWeekList({required int week, int page=1}) async {
    await init();
    try { final resp=await _dio.get('jgappapi.index/vodWeekList', queryParameters:{'week':week,'page':page}); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; final list=(data?['week_list'] as List?)??[]; return list.whereType<Map>().map((v){ final dynamic rawTypeId=v['type_id']??v['type_id_1']??v['type']; final int parsedTypeId=int.tryParse('$rawTypeId')??0; return {'id':'${v['vod_id']??v['id']??0}','title':v['vod_name']??v['title']??'','poster':_fixUrl(v['vod_pic']??v['poster']??v['pic']),'type_id':parsedTypeId,'type':v['type_name']??v['type']??'','score':double.tryParse('${v['vod_score']??v['score']??0}')??0.0,'year':'${v['vod_year']??v['year']??''}','overview':v['vod_remarks']??v['overview']??v['blurb']??''}; }).toList(); } } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getTopicList({int page=1}) async {
    await init();
    try { final resp=await _dio.get('jgappapi.index/topicList', queryParameters:{'page':page}); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; final list=(data?['topic_list'] as List?)??[]; return list.whereType<Map>().map((t){ return {'id':int.tryParse('${t['topic_id']??0}')??0,'title':(t['topic_name']??'').toString(),'poster':_fixUrl(t['topic_pic']),'overview':(t['topic_blurb']??'').toString(),'vod_names':(t['topic_vod_names']??'').toString()}; }).toList(); } } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getTopicVodList({required int topicId, int page=1}) async {
    await init();
    try { final resp=await _dio.get('jgappapi.index/topicVodList', queryParameters:{'topic_id':topicId,'page':page}); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; final list=(data?['topic_vod_list'] as List?)??[]; return list.whereType<Map>().map((v){ final dynamic rawTypeId=v['type_id']??v['type_id_1']??v['type']; final int parsedTypeId=int.tryParse('$rawTypeId')??0; return {'id':'${v['vod_id']??v['id']??0}','title':v['vod_name']??v['title']??'','poster':_fixUrl(v['vod_pic']??v['poster']??v['pic']),'type_id':parsedTypeId,'type':v['type_name']??v['type']??'','score':double.tryParse('${v['vod_score']??v['score']??0}')??0.0,'year':'${v['vod_year']??v['year']??''}','overview':v['vod_remarks']??v['overview']??v['blurb']??''}; }).toList(); } } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getStandardTypeList() async => _fetchStandardTypeList();

  Future<List<Map<String, dynamic>>> _fetchStandardTypeList() async {
    final list=<Map<String,dynamic>>[];
    try { final resp=await _dio.get('provide/vod/', queryParameters:{'ac':'list','pg':1,'pagesize':1,'at':'json'}); final raw=resp.data; final cls=(raw is Map)?raw['class']:null; if (cls is List) { for(final it in cls) { if (it is! Map) continue; final id=int.tryParse('${it['type_id']??it['typeid']??it['id']??it['type']}')??0; final pid=int.tryParse('${it['type_pid']??it['parent_id']??0}')??0; final name=(it['type_name']??it['typename']??it['name']??'').toString().trim(); if (id>0&&name.isNotEmpty) list.add({'type_id':id,'type_name':name,'type_pid':pid}); } } } catch (_) {}
    if (list.isNotEmpty) return list;
    try { final resp=await _dio.get('type/get_list', queryParameters:{'type_pid':0}); if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) { final info=(resp.data['info'] as Map?)??{}; final rows=(info['rows'] as List?)??[]; for(final it in rows) { if (it is! Map) continue; final id=int.tryParse('${it['type_id']??it['id']??it['type']}')??0; final name=(it['type_name']??it['name']??'').toString().trim(); if (id>0&&name.isNotEmpty) list.add({'type_id':id,'type_name':name,'type_pid':0}); } } } catch (_) {}
    if (list.isNotEmpty) return list;
    try { final resp=await _dio.get('type/get_all_list'); if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) { final info=(resp.data['info'] as Map?)??{}; final rows=info['rows']; if (rows is List) { for(final it in rows) { if (it is! Map) continue; final id=int.tryParse('${it['type_id']??it['id']??it['type']}')??0; final name=(it['type_name']??it['name']??'').toString().trim(); if (id>0&&name.isNotEmpty) list.add({'type_id':id,'type_name':name,'type_pid':0}); } } else if (rows is Map) { rows.forEach((k,v){ final id=int.tryParse('$k')??0; String name=''; if (v is Map) name=(v['type_name']??v['name']??'').toString().trim(); else name='$v'.toString().trim(); if (id>0&&name.isNotEmpty) list.add({'type_id':id,'type_name':name,'type_pid':0}); }); } } } catch (_) {}
    return list;
  }

  Future<List<Map<String, dynamic>>> _fetchStandardList({int? typeId, int page=1, int limit=20, String by='time'}) async {
    try {
      final params=<String,dynamic>{'ac':'list','pg':page,'pagesize':limit,'at':'json','by':by}; if (typeId!=null) params['t']=typeId;
      final resp=await _dio.get('provide/vod/', queryParameters:params);
      final list=(resp.data?['list'] as List?)??[];
      return list.map((v){ final dynamic rawTypeId=v['type_id']??v['type_id_1']??v['type']; final int parsedTypeId=int.tryParse('$rawTypeId')??0; return {'id':'${v['vod_id']??v['id']??0}','title':v['vod_name']??v['title']??'','poster':_fixUrl(v['vod_pic']??v['poster']??v['pic']),'type':v['type_name']??v['type']??'','type_id':parsedTypeId,'score':double.tryParse('${v['vod_score']??v['score']??0}')??0.0,'year':'${v['vod_year']??v['year']??''}','overview':v['vod_remarks']??v['overview']??v['blurb']??'','remarks':v['vod_remarks']??v['remarks']??'','blurb':v['vod_blurb']??v['blurb']??v['vod_content']??v['content']??'','area':v['vod_area']??v['area']??'','lang':v['vod_lang']??v['lang']??'','class':v['type_name']??v['vod_class']??v['class']??'','actor':v['vod_actor']??v['actor']??'','director':v['vod_director']??v['director']??'','play_url':v['vod_play_url']??v['play_url']??''}; }).toList();
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> getRecommended({required int level, int limit=6}) async {
    await init();
    try { try { final resp=await _dio.get('jgappapi.index/vodLevel', queryParameters:{'level':level,'page':1,'limit':limit}); if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) { final list=(resp.data['data']['list'] as List?)??[]; if (list.isNotEmpty) return list.map((v)=>{'id':'${v['vod_id']??v['id']??0}','title':v['vod_name']??v['title']??'','poster':_fixUrl(v['vod_pic']??v['poster']??v['pic']),'score':double.tryParse('${v['vod_score']??v['score']??0}')??0.0,'year':'${v['vod_year']??v['year']??''}','overview':v['vod_remarks']??v['overview']??v['blurb']??''}).toList(); } } catch (_) {}
    try { final fallback=await getFiltered(orderby:'time',limit:limit); if (fallback.isNotEmpty) return fallback.map((v)=>{'id':'${v['id']}','title':v['title']??'','poster':v['poster']??'','score':double.tryParse('${v['score']??0}')??0.0,'year':'${v['year']??''}','overview':v['overview']??''}).toList(); } catch (_) {}
    return []; } catch (_) { return []; }
  }

  List<String> _parseHotSearch(Map data) { dynamic raw=data['hot_search_list']??data['search_hot']; if (raw==null) return []; if (raw is List) return raw.map((e)=>e.toString()).toList(); if (raw is String) return raw.split(',').where((e)=>e.trim().isNotEmpty).toList(); return []; }

  Future<List<String>> getHotKeywords() async {
    final data=await getAppInit();
    if (data.isNotEmpty&&data['hot_search_list']!=null) { final list=(data['hot_search_list'] as List); if (list.isNotEmpty) return list.map((e)=>e.toString()).toList(); }
    try { final hotVideos=await getHot(page:1); if (hotVideos.isNotEmpty) return hotVideos.take(10).map((v)=>v['title'].toString()).toList(); } catch (_) {}
    return ['繁花','庆余年','斗破苍穹','雪中悍刀行','完美世界','吞噬星空'];
  }

  Future<List<Map<String, dynamic>>> searchByName(String keyword) async {
    if (_searchCache.containsKey(keyword)) return _searchCache[keyword]!;
    await init();
    try {
      final resp=await _dio.get('jgappapi.index/searchList', queryParameters:{'keywords':keyword,'page':1});
      if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) {
        final list=(resp.data['data']['search_list'] as List?)??[];
        final results=list.map((v){ return {'id':'${v['vod_id']??v['id']??0}','title':v['vod_name']??v['title']??'','poster':_fixUrl(v['vod_pic']??v['poster']??v['pic']),'score':double.tryParse('${v['vod_score']??v['score']??0}')??0.0,'year':'${v['vod_year']??v['year']??''}','overview':v['vod_remarks']??v['overview']??v['blurb']??'','area':v['vod_area']??v['area']??'','lang':v['vod_lang']??v['lang']??'','class':v['type_name']??v['vod_class']??v['class']??'','actor':v['vod_actor']??v['actor']??''}; }).toList();
        if (results.isNotEmpty) { _searchCache[keyword]=results; return results; }
      }
    } catch (_) {}
    try {
      final resp=await _dio.get('provide/vod/', queryParameters:{'ac':'videolist','wd':keyword,'pagesize':20,'at':'json'});
      if (resp.statusCode==200&&resp.data is Map) { final rows=(resp.data['list'] as List?)??[]; if (rows.isNotEmpty) { final results=rows.map((v)=>{'id':'${v['vod_id']??v['id']??0}','title':v['vod_name']??v['title']??'','poster':_fixUrl(v['vod_pic']??v['poster']??v['pic']),'score':double.tryParse('${v['vod_score']??v['score']??0}')??0.0,'year':'${v['vod_year']??v['year']??''}','overview':v['vod_content']??v['vod_blurb']??v['vod_remarks']??v['overview']??v['blurb']??'','area':v['vod_area']??v['area']??'','lang':v['vod_lang']??v['lang']??'','class':v['type_name']??v['vod_class']??v['class']??'','actor':v['vod_actor']??v['actor']??''}).toList(); _searchCache[keyword]=results; return results; } }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getDetail(String id) async {
    await init();
    try {
      final resp=await _dio.get('jgappapi.index/vodDetail', queryParameters:{'vod_id':id});
      if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) {
        dynamic data=resp.data['data'];
        if (data is String) { try { final raw=data.trim(); try { data=jsonDecode(utf8.decode(base64Decode(raw))); } catch (_) { data=jsonDecode(raw); } } catch (_) {} }
        if (data is Map) {
          final info=data['vod'];
          final playList=(data['vod_play_list'] as List).map((p){ final pi=(p['player_info'] as Map?)??{}; final show=(pi['app_name']??pi['app_show']??pi['appName']??pi['show']??'播放源').toString(); final parseType=pi['player_parse_type']; final isAdded=parseType=='1'||parseType==1||parseType==true; return {'show':show,'is_added':isAdded,'urls':(p['urls'] as List).map((u)=>{'name':u['name']??'正片','url':u['url']??'','parse_api':u['parse_api_url']??''}).toList()}; }).toList();
          final addedPlayList=playList.where((s)=>s['is_added']==true).toList();
          final effectiveList=addedPlayList.isNotEmpty?addedPlayList:playList;
          List<Map<String,dynamic>> finalPlayList=[];
          for(var source in effectiveList) { List<Map<String,dynamic>> eps=[]; final srcUrls=(source['urls'] as List?)??[]; for(var ep in srcUrls) { eps.add({'name':ep['name'],'url':_fixUrl(ep['url']),'parse_api':ep['parse_api']}); } finalPlayList.add({'show':source['show'],'urls':eps}); }
          final seenNames=<String>{}; final dedupedPlayList=<Map<String,dynamic>>[];
          for(final src in finalPlayList) { final name=(src['show']??'').toString(); if (seenNames.contains(name)) continue; seenNames.add(name); dedupedPlayList.add(src); }
          return {'id':'${info['vod_id']}','title':info['vod_name']??'','poster':_fixUrl(info['vod_pic']),'score':double.tryParse('${info['vod_score']??0}')??0.0,'year':'${info['vod_year']??''}','type_id':int.tryParse('${info['type_id']??0}')??0,'area':info['vod_area']??'','class':info['vod_class']??info['type_name']??'','director':info['vod_director']??'','actor':info['vod_actor']??'','overview':info['vod_blurb']??info['vod_remarks']??info['vod_content']??'','play_list':dedupedPlayList,'official_comment':data['official_comment'],'vod_name':info['vod_name']??'','vod_pic':_fixUrl(info['vod_pic']),'vod_year':'${info['vod_year']??''}','vod_area':info['vod_area']??'','type_name':info['type_name']??(info['vod_class']??''),'vod_actor':info['vod_actor']??'','vod_content':info['vod_content']??(info['vod_blurb']??info['vod_remarks']??''),'vod_play_list':dedupedPlayList};
        }
      }
    } catch (_) {}
    final customApiUrl='${rootUrl}app_api.php';
    try {
      final resp=await _dio.get(customApiUrl, queryParameters:{'ac':'detail','ids':id});
      if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) {
        final list=resp.data['list'];
        if (list is List&&list.isNotEmpty) {
          final info=list[0] as Map<String,dynamic>;
          final rawPlayList=info['vod_play_list'] as List? ?? [];
          final playList=rawPlayList.map((p){ final pm=p as Map<String,dynamic>; return {'show':pm['show']??'播放源','urls':(pm['urls'] as List?)?.map((u){ final um=u as Map<String,dynamic>; return {'name':um['name']??'正片','url':_fixUrl(um['url']??''),'parse_api':um['parse_api']??''}; }).toList()??[]}; }).toList();
          final seenNames2=<String>{}; final dedupedPlayList2=<Map<String,dynamic>>[];
          for(final src in playList) { final name=(src['show']??'').toString(); if (seenNames2.contains(name)) continue; seenNames2.add(name); dedupedPlayList2.add(src); }
          return {'id':'${info['vod_id']}','title':info['vod_name']??'','poster':_fixUrl(info['vod_pic']??''),'score':double.tryParse('${info['vod_score']??0}')??0.0,'year':'${info['vod_year']??''}','type_id':int.tryParse('${info['type_id']??0}')??0,'area':info['vod_area']??'','class':info['vod_class']??info['type_name']??'','director':info['vod_director']??'','actor':info['vod_actor']??'','overview':info['vod_blurb']??info['vod_remarks']??info['vod_content']??'','play_list':dedupedPlayList2,'vod_name':info['vod_name']??'','vod_pic':_fixUrl(info['vod_pic']??''),'vod_year':'${info['vod_year']??''}','vod_area':info['vod_area']??'','type_name':info['type_name']??(info['vod_class']??''),'vod_actor':info['vod_actor']??'','vod_content':info['vod_content']??(info['vod_blurb']??info['vod_remarks']??''),'vod_play_list':dedupedPlayList2};
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String> resolvePlayUrl(String url, {String? parseApi}) async {
    await init();
    if (parseApi==null||parseApi.isEmpty) return _fixUrl(url);
    try {
      String requestUrl=parseApi;
      final encoded=Uri.encodeComponent(url);
      if (requestUrl.contains('{url}')) { requestUrl=requestUrl.replaceAll('{url}',encoded); }
      else if (requestUrl.contains('jgappapi.index/vodParse')) { final resp=await _dio.get(requestUrl, queryParameters:{'url':url}, options:Options(responseType:ResponseType.json)); return _extractFinalUrl(resp.data)??_fixUrl(url); }
      else { if (requestUrl.contains('?')) { if (!RegExp('(?:^|[?&])url=').hasMatch(requestUrl)) requestUrl='$requestUrl&url=$encoded'; } else { requestUrl='$requestUrl?url=$encoded'; } }
      final resp=await _dio.get(requestUrl, options:Options(responseType:ResponseType.json));
      dynamic data=resp.data;
      if (data is String) { try { data=jsonDecode(data); } catch (_) { final match=RegExp("https?://[^\\s'\\\"<>]+").firstMatch(data); if (match!=null) return _fixUrl(match.group(0)!); } }
      final finalUrl=_extractFinalUrl(data); if (finalUrl!=null&&finalUrl.isNotEmpty) return _fixUrl(finalUrl);
    } catch (e) { debugPrint('err: $e'); }
    return _fixUrl(url);
  }

  String? _extractFinalUrl(dynamic data) {
    if (data is Map) { for(final key in ['url','play_url','real','m3u8','link']) { final v=data[key]; if (v is String&&v.isNotEmpty) return v; } if (data['json'] is String) { try { final inner=jsonDecode(data['json']); if (inner is Map) { for(final key in ['url','play_url','real','m3u8','link']) { final v=inner[key]; if (v is String&&v.isNotEmpty) return v; } } } catch (_) {} } }
    else if (data is String) { final match=RegExp("https?://[^\\s'\\\"<>]+").firstMatch(data); if (match!=null) return match.group(0); }
    return null;
  }

  String _mapSourceCodeToName(String code) {
    final c=code.toLowerCase().trim();
    const exact={'kkm3u8':'夸克资源','kkyun':'夸克云','quark':'夸克资源','lzm3u8':'量子资源','lzyun':'量子云','liangzi':'量子资源','ffm3u8':'非凡资源','ffyun':'非凡云','feifan':'非凡资源','xgm3u8':'西瓜资源','xigua':'西瓜资源','wjm3u8':'无尽资源','wuji':'无尽资源','tkm3u8':'天空资源','tiankong':'天空资源','dbm3u8':'百度资源','baidu':'百度资源','bjm3u8':'八戒资源','bajie':'八戒资源','xlm3u8':'新浪资源','xinlang':'新浪资源','hhm3u8':'豪华资源','snm3u8':'索尼资源','hnm3u8':'红牛资源'};
    if (exact.containsKey(c)) return exact[c]!;
    if (c.contains('liang')||c.contains('lz')) return '量子资源';
    if (c.contains('feifan')||c.contains('ff')) return '非凡资源';
    if (c.contains('xigua')||c.contains('xg')) return '西瓜资源';
    if (c.contains('quark')||c.contains('kk')) return '夸克资源';
    if (c.contains('tiankong')||c.contains('tk')) return '天空资源';
    if (c.contains('wuji')||c.contains('wj')) return '无尽资源';
    if (c.contains('baidu')||c.contains('db')) return '百度资源';
    if (c.contains('bajie')||c.contains('bj')) return '八戒资源';
    if (c.contains('xinlang')||c.contains('xl')) return '新浪资源';
    if (c.contains('m3u8')) return '高清资源';
    if (c.contains('yun')) return '云播资源';
    return code;
  }

  Future<Map<String, List<String>>> getFacets({int typeId1=1}) async {
    try {
      await init();
      final resp=await _dio.get('jgappapi.index/extendClass', queryParameters:{'typeid':typeId1});
      if (resp.statusCode==200) {
        dynamic data=resp.data; if (data is String) { try { data=jsonDecode(data); } catch (_) {} }
        Map<String,List<String>> result={'years':[],'areas':[],'classes':[]};
        Map? dataMap; if (data is Map) dataMap=(data['data'] is Map)?data['data']:data;
        if (dataMap!=null) {
          dynamic extendData=dataMap['type_extend']??dataMap['extend']??dataMap['vod_extend'];
          if (extendData is String&&extendData.isNotEmpty) { try { extendData=jsonDecode(extendData); } catch (_) {} }
          if (extendData is Map) { result['years']=_parseCommaList(extendData['year']); result['areas']=_parseCommaList(extendData['area']); result['classes']=_parseCommaList(extendData['class']); final langs=_parseCommaList(extendData['lang']); if (langs.isNotEmpty) result['langs']=langs; }
          final yrs=result['years']??[]; final ars=result['areas']??[]; final cls=result['classes']??[];
          if (yrs.isEmpty) result['years']=_parseCommaList(dataMap['year']??dataMap['years']??dataMap['year_list']);
          if (ars.isEmpty) result['areas']=_parseCommaList(dataMap['area']??dataMap['areas']??dataMap['area_list']);
          if (cls.isEmpty) result['classes']=_parseCommaList(dataMap['class']??dataMap['classes']??dataMap['class_list']);
          final dataLangs=_parseCommaList(dataMap['lang']??dataMap['langs']??dataMap['lang_list']);
          if (dataLangs.isNotEmpty&&(result['langs']==null||result['langs']!.isEmpty)) result['langs']=dataLangs;
        }
        if ((result['areas']??[]).isNotEmpty||(result['years']??[]).isNotEmpty||(result['classes']??[]).isNotEmpty) return result;
      }
    } catch (_) {}
    try {
      final initData=await getAppInit(); final typeList=initData['type_list'] as List? ?? [];
      for(final t in typeList) { if (t is! Map) continue; final tid=t['type_id']; if (tid!=typeId1) continue; dynamic ext=t['type_extend']??t['extend']; if (ext is String&&ext.isNotEmpty) { try { ext=jsonDecode(ext); } catch (_) {} } if (ext is Map) { final yrs=_parseCommaList(ext['year']); final ars=_parseCommaList(ext['area']); final cls=_parseCommaList(ext['class']); final lgs=_parseCommaList(ext['lang']); if (yrs.isNotEmpty||ars.isNotEmpty||cls.isNotEmpty) { final r=<String,List<String>>{'years':yrs,'areas':ars,'classes':cls}; if (lgs.isNotEmpty) r['langs']=lgs; return r; } } }
    } catch (_) {}
    return {'years':['2025','2024','2023','2022','2021','2020','2019','2018','2017'],'areas':['大陆','香港','台湾','美国','韩国','日本','泰国','英国','法国'],'classes':['动作','喜剧','爱情','科幻','恐怖','剧情','战争','纪录']};
  }

  List<String> _parseCommaList(dynamic value) { if (value==null) return []; if (value is List) return value.map((e)=>e.toString().trim()).where((e)=>e.isNotEmpty).toList(); final str=value.toString().trim(); if (str.isEmpty) return []; return str.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(); }

  final _LruCache<List<Map<String, dynamic>>> _categoryCache=_LruCache(capacity:200, ttl:const Duration(minutes:30));

  Future<List<Map<String, dynamic>>> getFiltered({int? typeId, String? year, String? area, String? lang, String? clazz, String orderby='time', int page=1, int limit=20}) async {
    await init();
    final cacheKey='$typeId-$year-$area-$lang-$clazz-$orderby-$page';
    final cached=_categoryCache.get(cacheKey); if (cached!=null) return cached;
    try {
      String sortParam='最新';
      if (orderby=='hits'||orderby=='最热') sortParam='最热';
      else if (orderby=='score'||orderby=='最赞') sortParam='最赞';
      else if (orderby.contains('hits_day')) sortParam='日榜';
      else if (orderby.contains('hits_week')) sortParam='周榜';
      else if (orderby.contains('hits_month')) sortParam='月榜';
      final params={'page':page,'limit':limit,'pagesize':limit,'sort':sortParam};
      if (typeId!=null) params['type_id']=typeId;
      if (year!=null&&year!='全部') params['year']=year;
      if (area!=null&&area!='全部') params['area']=area;
      if (lang!=null&&lang!='全部') params['lang']=lang;
      if (clazz!=null&&clazz!='全部') params['class']=clazz;
      final resp=await _dio.get('jgappapi.index/typeFilterVodList', queryParameters:params);
      if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) {
        dynamic data=resp.data['data'];
        if (data is String) { try { final decodedStr=utf8.decode(base64Decode(data)); data=jsonDecode(decodedStr); } catch (_) { data={}; } }
        if (data is Map) {
          final rawList=(data['recommend_list'] as List?)??(data['vod_list'] as List?)??(data['list'] as List?)??[];
          final results=rawList.map((v){ final dynamic rawTypeId=v['type_id']??v['type_id_1']??v['type']; final int parsedTypeId=int.tryParse('$rawTypeId')??0; return {'id':'${v['vod_id']??v['id']??0}','title':v['vod_name']??v['title']??'','poster':_fixUrl(v['vod_pic']??v['poster']??v['pic']),'type_id':parsedTypeId,'score':double.tryParse('${v['vod_score']??v['score']??0}')??0.0,'year':'${v['vod_year']??v['year']??''}','overview':v['vod_remarks']??v['overview']??v['blurb']??'','remarks':v['vod_remarks']??v['remarks']??'','blurb':v['vod_blurb']??v['blurb']??v['vod_content']??v['content']??'','area':v['vod_area']??v['area']??'','lang':v['vod_lang']??v['lang']??'','class':v['type_name']??v['vod_class']??v['class']??'','actor':v['vod_actor']??v['actor']??'','director':v['vod_director']??v['director']??'','play_url':v['vod_play_url']??v['play_url']??''}; }).toList();
          if (results.isNotEmpty) { final validated=_filterByTypeId(typeId,results,apiAlreadyFiltered:true); if (validated.isNotEmpty) { _categoryCache.set(cacheKey,validated); return validated; } }
        }
      }
    } catch (_) {}
    final customApiUrl='${rootUrl}app_api.php';
    try {
      final params={'ac':'list','pg':page,'pagesize':limit,'by':orderby};
      if (typeId!=null) params['t']=typeId;
      if (year!=null&&year!='全部') params['year']=year;
      if (area!=null&&area!='全部') params['area']=area;
      if (lang!=null&&lang!='全部') params['lang']=lang;
      if (clazz!=null&&clazz!='全部') params['class']=clazz;
      final resp=await _dio.get(customApiUrl, queryParameters:params);
      if (resp.statusCode==200&&resp.data is Map&&resp.data['code']==1) {
        final list=(resp.data['list'] as List?)??[];
        final results=list.map((item){ final v=item as Map<String,dynamic>; final dynamic rawTypeId=v['type_id']??v['type_id_1']??v['type']; final int parsedTypeId=int.tryParse('$rawTypeId')??0; return {'id':'${v['vod_id']??v['id']??0}','title':v['vod_name']??v['title']??'','poster':_fixUrl(v['vod_pic']??v['poster']??v['pic']),'type_id':parsedTypeId,'score':double.tryParse('${v['vod_score']??v['score']??0}')??0.0,'year':'${v['vod_year']??v['year']??''}','overview':v['vod_remarks']??v['overview']??v['blurb']??'','area':v['vod_area']??v['area']??'','lang':v['vod_lang']??v['lang']??'','class':v['type_name']??v['vod_class']??v['class']??'','actor':v['vod_actor']??v['actor']??'','director':v['vod_director']??v['director']??'','play_url':v['vod_play_url']??v['play_url']??''}; }).toList();
        if (results.isNotEmpty) { final validated=_filterByTypeId(typeId,results,apiAlreadyFiltered:true); if (validated.isNotEmpty) { _categoryCache.set(cacheKey,validated); return validated; } }
      }
    } catch (_) {}
    try { final list=await _fetchStandardList(typeId:typeId,page:page,limit:limit,by:orderby); final validated=_filterByTypeId(typeId,list,apiAlreadyFiltered:true); if (validated.isNotEmpty) { _categoryCache.set(cacheKey,validated); return validated; } } catch (_) {}
    return [];
  }

  List<Map<String, dynamic>> _filterByTypeId(int? typeId, List<Map<String, dynamic>> items, {bool apiAlreadyFiltered=false}) {
    if (typeId==null) return items;
    final filtered=items.where((e){ final raw=e['type_id']; final tid=int.tryParse('$raw')??0; if (tid==0) return apiAlreadyFiltered; return tid==typeId; }).toList();
    return filtered.isNotEmpty?filtered:[];
  }

  Future<Map<String, bool>> getInterfaceStatus() async => await detectInterfaces(force:true);
  bool get isWeb => kIsWeb;

  Future<List<Map<String, dynamic>>> getComments(String vodId) async {
    await init();
    try { final resp=await _dio.get('jgappapi.index/commentList', queryParameters:{'vod_id':vodId}); if (resp.data['code']==1) { final list=(resp.data['data']['comment_list'] as List); return list.map((c)=>{'id':c['comment_id'],'name':c['user_name']??'匿名','content':c['comment_content']??'','time':c['time_str']??'','avatar':_fixUrl(c['user_avatar']),'is_top':(c['comment_top']?.toString()=='1'||c['is_top']?.toString()=='1')}).toList(); } } catch (_) {}
    final customApiUrl='${rootUrl}app_api.php';
    try { final resp=await _dio.get(customApiUrl, queryParameters:{'ac':'get_comments','rid':vodId}); if (resp.data['code']==1) { final list=(resp.data['list'] as List); return list.map((c){ final m=c as Map<String,dynamic>; return {'id':m['id']??m['comment_id'],'name':m['name']??m['user_name']??'匿名','content':m['content']??m['comment_content']??'','time':m['time']??m['time_str']??'','avatar':_fixUrl(m['avatar']??m['user_avatar']),'is_top':(m['is_top']?.toString()=='1'||m['top']?.toString()=='1')}; }).toList(); } } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getDanmakus(String vodId) async {
    await init();
    try { final resp=await _dio.get('jgappapi.index/danmuList', queryParameters:{'vod_id':vodId}); if (resp.data['code']==1) { final list=(resp.data['data']['danmu_list'] as List); return list.map((d)=>{'id':d['danmu_id']??d['id']??0,'text':d['content']??'','color':d['color']??'#FFFFFF','time':d['time']??0}).toList(); } } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> sendComment(String vodId, String content, String nickname) async {
    await init();
    try { final resp=await _dio.post('jgappapi.index/sendComment', data:{'vod_id':vodId,'comment':content}); if (resp.data['code']==1) return {'success':true,'needAudit':false,'msg':'评论发送成功'}; if (resp.data['code']==2) return {'success':true,'needAudit':true,'msg':'评论已提交，审核通过后显示'}; return {'success':false,'needAudit':false,'msg':resp.data['msg']?.toString()??'发送失败'}; } catch (_) {}
    final customApiUrl='${rootUrl}app_api.php';
    try { final resp=await _dio.post(customApiUrl, queryParameters:{'ac':'add_comment'}, data:{'rid':vodId,'content':content,'name':nickname}); if (resp.data['code']==1) return {'success':true,'needAudit':false,'msg':'评论发送成功'}; return {'success':false,'needAudit':false,'msg':resp.data['msg']?.toString()??'发送失败'}; } catch (_) { return {'success':false,'needAudit':false,'msg':'网络错误'}; }
  }

  Future<Map<String, dynamic>> sendDanmaku(String vodId, String content, {String color='#FFFFFF', int time=0}) async {
    await init();
    try { final resp=await _dio.post('jgappapi.index/sendDanmu', data:{'vod_id':vodId,'danmu':content,'color':color,'time':time,'url_position':0}); if (resp.data['code']==1) return {'success':true,'needAudit':false,'msg':'弹幕发送成功'}; if (resp.data['code']==2) return {'success':true,'needAudit':true,'msg':'弹幕已提交，审核通过后显示'}; return {'success':false,'needAudit':false,'msg':resp.data['msg']?.toString()??'发送失败'}; } catch (_) { return {'success':false,'needAudit':false,'msg':'网络错误'}; }
  }

  Future<bool> sendSuggest(String content) async { await init(); try { final resp=await _dio.post('jgappapi.index/suggest', data:{'content':content}, options:Options(contentType:Headers.formUrlEncodedContentType, headers:_headers)); return resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1); } catch (_) { return false; } }
  Future<bool> sendFind({required String name, String remark=''}) async { await init(); try { final resp=await _dio.post('jgappapi.index/find', data:{'name':name,'remark':remark}, options:Options(contentType:Headers.formUrlEncodedContentType, headers:_headers)); return resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1); } catch (_) { return false; } }
  Future<Map<String, dynamic>> requestUpdate(String vodId) async { await init(); try { final resp=await _dio.get('jgappapi.index/requestUpdate', queryParameters:{'vod_id':vodId}); if (resp.statusCode==200&&resp.data is Map) { final code=resp.data['code']; return {'success':code==1||code=='1','msg':resp.data['msg']?.toString()??'未知错误'}; } return {'success':false,'msg':'网络请求失败: ${resp.statusCode}'}; } catch (e) { return {'success':false,'msg':'请求异常: $e'}; } }

  Future<List<Map<String, dynamic>>> getNoticeList({int page=1}) async { await init(); try { final resp=await _dio.get('jgappapi.index/noticeList', queryParameters:{'page':page}); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; final list=(data?['notice_list'] as List?)??[]; return list.map((e){ final m=e as Map<String,dynamic>; return {'id':m['id'],'title':m['title']??'','sub_title':m['sub_title']??'','create_time':m['create_time']??''}; }).toList(); } } catch (_) {} return []; }
  Future<Map<String, dynamic>?> getNoticeDetail(int noticeId) async { await init(); try { final resp=await _dio.get('jgappapi.index/noticeDetail', queryParameters:{'notice_id':noticeId}); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; final notice=(data?['notice'] as Map?)??{}; return {'id':notice['id'],'title':notice['title']??'','sub_title':notice['sub_title']??'','create_time':notice['create_time']??'','content':notice['content']??''}; } } catch (_) {} return null; }

  Future<Map<String, int>> getUserNoticeTypes() async { await init(); try { final resp=await _dio.get('jgappapi.index/userNoticeType'); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; return {'suggest_count':(data?['suggest_count']??0) as int,'find_count':(data?['find_count']??0) as int}; } } catch (_) {} return {'suggest_count':0,'find_count':0}; }

  Future<List<Map<String, dynamic>>> getUserNoticeList({required int type, int page=1}) async { await init(); try { final resp=await _dio.get('jgappapi.index/userNoticeList', queryParameters:{'page':page,'type':type}); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; final list=(data?['user_notice_list'] as List?)??[]; return list.whereType<Map>().map((m){ return {'id':m['id'],'title':(m['title']??'').toString(),'content':(m['content']??'').toString(),'reply_content':(m['reply_content']??'').toString(),'create_time':(m['create_time']??'').toString()}; }).toList(); } } catch (_) {} return []; }

  Future<Map<String, dynamic>> getInviteLogs({int page=1}) async { await init(); try { final resp=await _dio.get('jgappapi.index/inviteLogs', queryParameters:{'page':page}); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; return {'invite_logs':(data?['invite_logs'] as List? ?? []).cast<Map<String,dynamic>>(),'invite_count':data?['invite_count']??0,'intro':data?['intro']??''}; } } catch (_) {} return {'invite_logs':<Map<String,dynamic>>[],'invite_count':0,'intro':''}; }
  Future<Map<String, dynamic>> getUserPointsLogs({int page=1}) async { await init(); try { final resp=await _dio.get('jgappapi.index/userPointsLogs', queryParameters:{'page':page}); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; return {'plogs':(data?['plogs'] as List? ?? []).cast<Map<String,dynamic>>(),'user_points':data?['user_points']??0,'intro':data?['intro']??'','remain_watch_times':data?['remain_watch_times']??0}; } } catch (_) {} return {'plogs':<Map<String,dynamic>>[],'user_points':0,'intro':'','remain_watch_times':0}; }

  Future<Map<String, dynamic>?> getUserInfoSummary() async { await init(); try { final resp=await _dio.get('jgappapi.index/userInfo'); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; final user=(data?['user_info'] as Map?)??<String,dynamic>{}; return {'user_name':user['user_nick_name']??user['user_name']??'用户','group_name':user['group_name']??'普通会员','user_points':int.tryParse('${user['user_points']??0}')??0,'user_id':user['user_id'],'user_portrait':_fixUrl(user['user_portrait'])}; } } catch (_) {} return null; }
  Future<Map<String, dynamic>?> getMineInfo() async { await init(); try { final resp=await _dio.get('jgappapi.index/mineInfo'); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; final user=(data?['user'] as Map?)??<String,dynamic>{}; return {'user_info':user,'user_notice_unread_count':data?['user_notice_unread_count']??0,'user_name':user['user_nick_name']??user['user_name']??'用户','user_points':int.tryParse('${user['user_points']??0}')??0,'group_name':user['group_name']??'普通会员','user_portrait':_fixUrl(user['user_portrait']),'is_vip':user['group_id']!=null&&int.tryParse('${user['group_id']}')!=3}; } } catch (_) {} return null; }

  Future<List<Map<String, dynamic>>> getUserNotices({int page=1, int limit=20}) async { await init(); try { final resp=await _dio.get('jgappapi.index/userNoticeList', queryParameters:{'page':page,'limit':limit}); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; final list=(data?['list'] as List? ?? []); return list.cast<Map<String,dynamic>>(); } } catch (_) {} return []; }
  Future<Map<String, dynamic>?> getUserVipCenter() async { await init(); try { final resp=await _dio.get('jgappapi.index/userVipCenter'); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data'] as Map?; return {'user':(data?['user'] as Map?)??<String,dynamic>{},'vip_group_list':(data?['vip_group_list'] as List? ?? []).cast<Map<String,dynamic>>()}; } } catch (_) {} return null; }

  Future<Map<String, dynamic>?> getAppUpdate() async {
    await init();
    Map<String,dynamic>? normalize(Map raw) => {'version_name':raw['version_name']?.toString()??'','version_code':raw['version_code']?.toString()??'','download_url':raw['download_url']?.toString()??'','browser_download_url':raw['browser_download_url']?.toString()??'','app_size':raw['app_size']?.toString()??'','description':raw['description']?.toString()??'','is_force':raw['is_force']==true||raw['is_force']==1};
    try { final resp=await _dio.get('jgappapi.index/appUpdateV2', options:Options(headers:_headers)); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)&&resp.data['data'] is Map) return normalize(resp.data['data'] as Map); } catch (_) {}
    try { final resp=await _dio.get('jgappapi.index/appUpdate', options:Options(headers:_headers)); if (resp.statusCode==200&&resp.data is Map&&(resp.data['code']==1)) { final data=resp.data['data']; if (data is Map&&data['update'] is Map) return normalize(data['update'] as Map); } } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> buyVip({required int index}) async { await init(); try { final resp=await _dio.post('jgappapi.index/userBuyVip', data:{'index':index}, options:Options(contentType:Headers.formUrlEncodedContentType, headers:_headers)); if (resp.statusCode==200&&resp.data is Map) return {'success':resp.data['code']==1,'msg':resp.data['msg']??'','user':(resp.data['data']?['user'] as Map?)??<String,dynamic>{}}; } catch (_) {} return {'success':false,'msg':'购买失败，请稍后重试','user':<String,dynamic>{}}; }
  Future<Map<String, dynamic>> modifyPassword(String oldPwd, String newPwd) async { await init(); try { final resp=await _dio.post('jgappapi.index/modifyPassword', data:{'password':oldPwd,'new_password':newPwd}, options:Options(contentType:Headers.formUrlEncodedContentType, headers:_headers)); if (resp.statusCode==200&&resp.data is Map) return {'success':resp.data['code']==1,'msg':resp.data['msg']}; return {'success':false,'msg':'请求失败'}; } catch (e) { return {'success':false,'msg':'$e'}; } }
  Future<bool> modifyUserNickName(String nickname) async { await init(); try { final resp=await _dio.post('jgappapi.index/modifyUserNickName', data:{'user_nick_name':nickname}, options:Options(contentType:Headers.formUrlEncodedContentType, headers:_headers)); if (resp.data['code']==1) { final prefs=await SharedPreferences.getInstance(); await prefs.setString('user_name',nickname); return true; } return false; } catch (_) { return false; } }
  Future<Map<String, dynamic>> uploadAvatar(FormData formData) async { await init(); try { final resp=await _dio.post('jgappapi.index/appAvatarUpload', data:formData, options:Options(headers:_headers)); if (resp.data['code']==1) return {'success':true,'url':_fixUrl(resp.data['data']['user']['user_avatar'])}; else return {'success':false,'msg':resp.data['msg']}; } catch (e) { return {'success':false,'msg':'$e'}; } }
  Future<Map<String, dynamic>> watchRewardAd() async { await init(); try { final resp=await _dio.post('jgappapi.index/watchRewardAd', data:{'data':''}, options:Options(contentType:Headers.formUrlEncodedContentType, headers:_headers)); if (resp.data is Map&&resp.data['code']==1) return {'success':true,'points':resp.data['data']['points']??0}; return {'success':false,'msg':resp.data['msg']??'需要客户端配置AES加密密钥'}; } catch (_) { return {'success':false,'msg':'请求失败'}; } }
  Future<bool> reportComment(String commentId) async { await init(); try { final resp=await _dio.get('jgappapi.index/commentTipOff', queryParameters:{'comment_id':commentId}); return resp.data['code']==1; } catch (_) { return false; } }
  Future<bool> reportDanmu(String danmuId) async { await init(); try { final resp=await _dio.get('jgappapi.index/danmuReport', queryParameters:{'danmu_id':danmuId}); return resp.data['code']==1; } catch (_) { return false; } }

  Future<List<Map<String, dynamic>>> getCloudDanmaku(String videoUrl) async {
    final configApi=appConfig['danmaku_api']?.toString()??'';
    final cloudApis=<String>[];
    if (configApi.isNotEmpty) cloudApis.add(configApi);
    for(final api in cloudApis) {
      try {
        final resp=await _dio.get(api, queryParameters:{'id':videoUrl});
        if (resp.data is Map&&resp.data['data'] is List) {
          final rawList=resp.data['data'] as List;
          return rawList.map((item){
            if (item is List&&item.length>=5) return {'time':double.tryParse('${item[0]}')??0.0,'type':item[1],'color':'#${(int.tryParse('${item[2]}')??16777215).toRadixString(16).padLeft(6,'0')}','text':item[4].toString(),'source':'cloud'};
            return <String,dynamic>{};
          }).where((e)=>e.isNotEmpty).toList();
        }
      } catch (e) {}
    }
    return [];
  }
}