/// 鏂囦欢鍚嶏細api.dart
/// 浣滆€咃細鏉板摜锛坆y锛氭澃鍝?/ qq锛?711793818锛?/// 鍒涘缓鏃ユ湡锛?025-12-16
/// 浣滅敤锛歁acCMS10 鎺ュ彛灏佽锛堥椤靛垵濮嬪寲銆佸垎绫荤瓫閫夈€佽鎯呫€佽瘎璁恒€佸脊骞曘€佺櫥褰曠瓑锛?/// 瑙ｉ噴锛氭墍鏈夌綉缁滆姹傞兘浠庤繖閲岃蛋锛岄椤靛垎绫?璇︽儏/鎼滅储閮介潬瀹冦€?import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'dart:collection';
// by锛氭澃鍝?
// qq锛?2711793818
// 淇鐧诲綍鐘舵€佹牎楠岄棶棰?
import 'dart:convert'; // 寮曞叆 jsonDecode
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
    if (DateTime.now().isAfter(entry.expiresAt)) {
      return null;
    }
    _map[key] = entry;
    return entry.value;
  }

  void set(String key, V value) {
    _map.remove(key);
    _map[key] = _LruEntry(value: value, expiresAt: DateTime.now().add(ttl));
    while (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
  }

  void clear() {
    _map.clear();
  }
}

class MacApi {
  // 鍗曚緥妯″紡
  static final MacApi _instance = MacApi._internal();
  factory MacApi() => _instance;
  MacApi._internal() {
    setup(); // 纭繚鍗曚緥鍒涘缓鏃剁珛鍗冲垵濮嬪寲 Dio
  }

  late Dio _dio;
  late CookieJar _cookieJar;
  bool _initialized = false;
  String? _appUserToken;
  
  // 缂撳瓨妫€娴嬬粨鏋?  DateTime? _lastDetect;
  bool? _pluginFilterOk;
  bool? _customApiOk;
  bool? _standardApiOk;
  
  String _appOs = 'android';
  int _appVersionCode = 1;
  String _appVersionName = '1.0.0';

  void setup() {
    _dio = Dio(BaseOptions(
      baseUrl: rootUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.json,
      validateStatus: (status) {
        return status != null && status < 500;
      },
    ));

    // 鎷︽埅鍣細澶勭悊 JSON 瀹归敊
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 寮€鍙戣€咃細鏉板摜
        // 淇锛氭櫤鑳借拷鍔?api.php 鍓嶇紑
        // 浣滅敤锛氬鏋?AppConfig 閰嶇疆浜?api.php锛屼絾璇锋眰璺緞鏄?jgappapi 鎴?provide 寮€澶达紝
        // 鑷姩鎶?api.php 鍔犱笂锛岄槻姝?404銆?        // 鍚屾椂淇濈暀 index.php/user/login 绛夎矾寰勬甯歌闂紙涓嶅姞 api.php锛夈€?        if (AppConfig.baseUrl.contains('/api.php')) {
           final path = options.path;
           if (!path.startsWith('http') && 
               !path.startsWith('/') && 
               (path.startsWith('jgappapi') || path.startsWith('provide'))) {
              options.path = 'api.php/$path';
           }
        }

        if (_appUserToken != null && _appUserToken!.isNotEmpty) {
           options.headers['app-user-token'] = _appUserToken;
        }
        // 鑷姩娣诲姞閫氱敤 Headers
        options.headers.addAll(_headers);
        handler.next(options);
      },
      onResponse: (response, handler) {
        // 鑷姩澶勭悊锛氬鏋滃悗绔繑鍥炵殑鏄?String 绫诲瀷鐨?JSON锛岃嚜鍔ㄨ浆鎴?Map
        if (response.data is String) {
          try {
            // 鏈変簺鏈嶅姟鍣ㄨ繑鍥炵殑 JSON 鍓嶅悗鍙兘鏈夌┖鐧藉瓧绗?            final str = (response.data as String).trim();
            if (str.startsWith('{') || str.startsWith('[')) {
               response.data = jsonDecode(str);
            } else if (str == 'closed') {
               // 鐗规畩澶勭悊 MacCMS 鍏抽棴鐘舵€?               throw DioException(
                 requestOptions: response.requestOptions,
                 error: '鏈嶅姟鍣ㄥ姛鑳藉凡鍏抽棴鎴栬矾寰勯敊璇?(closed)',
                 type: DioExceptionType.badResponse,
               );
            }
          } catch (e) {
            print('JSON鑷姩瑙ｆ瀽澶辫触: $e');
          }
        }
        handler.next(response);
      },
      onError: (e, handler) {
        print('API Error: ${e.message}');
        handler.next(e);
      },
    ));
  }

  /// 鑾峰彇缃戠珯鏍硅矾寰勶紙鐢ㄤ簬闈濧PI鎺ュ彛锛屽鐢ㄦ埛涓績锛?  String get rootUrl {
    String root;
    final base = AppConfig.baseUrl;
    if (base.contains('/api.php')) {
      root = base.split('/api.php').first;
    } else {
      root = base;
    }
    return root.endsWith('/') ? root : '$root/';
  }

  /// 鍒濆鍖?Cookie锛堢敤浜庝繚鎸佺櫥褰曠姸鎬侊級
  Future<void> init() async {
    if (_initialized) return;
    if (!kIsWeb) {
      // 绉诲姩绔娇鐢ㄥ唴瀛?Cookie锛岄伩鍏?dart:io 渚濊禆瀵艰嚧 Web 缂栬瘧澶辫触
      _cookieJar = CookieJar();
      _dio.interceptors.add(CookieManager(_cookieJar));
    }
    // 璇诲彇鏈湴缂撳瓨鐨?JgApp token锛堝鏋滄湁鐨勮瘽锛?    final prefs = await SharedPreferences.getInstance();
    _appUserToken = prefs.getString('app_user_token');
    // 寮€鍙戣€咃細鏉板摜
    // 浣滅敤锛氬綋鍩熷悕鍙樻洿鏃讹紝鑷姩娓呯┖鏃х殑鍒濆鍖栫紦瀛橈紝閬垮厤鍒嗙被璇诲彇鍒版棫鏁版嵁
    // 瑙ｉ噴锛氫綘鎹簡鍚庡彴鍦板潃锛岃€佺殑缂撳瓨浼氳娓呮帀锛岄噸鏂版媺鏈€鏂板垎绫汇€?    try {
      final baseRoot = rootUrl; // 渚嬪 http://pay.ddgg888.my/
      final lastBase = prefs.getString('app_init_base') ?? '';
      if (lastBase.trim() != baseRoot.trim()) {
        await prefs.remove('app_init_json');
        await prefs.remove('app_init_ts');
        await prefs.setString('app_init_base', baseRoot);
        _categoryCache.clear();
      }
    } catch (_) {}

    _appOs = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'android',
    };

    try {
      final info = await PackageInfo.fromPlatform();
      _appVersionName = info.version;
      _appVersionCode = _parseJgAppVersionCode(_appVersionName);
      if (_appVersionCode <= 0) {
        _appVersionCode = int.tryParse(info.buildNumber) ?? 0;
      }
      if (_appVersionCode <= 0) {
        _appVersionCode = 1;
      }
    } catch (_) {
      if (_appVersionCode <= 0) _appVersionCode = 1;
    }

    _initialized = true;
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氭娴嬪悗绔帴鍙ｅ彲鐢ㄦ€э紙鎻掍欢绛涢€夈€乤pp_api.php銆佹爣鍑咥PI锛夊苟缂撳瓨缁撴灉
  /// 瑙ｉ噴锛氬厛鐪嬬湅鍝簺鍚庣鎺ュ彛鑳界敤锛屽悗闈㈠氨浼樺厛鐢ㄨ兘鐢ㄧ殑锛岀渷鏃堕棿銆?  Future<Map<String, bool>> detectInterfaces({bool force = false}) async {
    // 5鍒嗛挓鍐呭凡鏈夋娴嬬粨鏋滃垯澶嶇敤
    if (!force && _lastDetect != null && DateTime.now().difference(_lastDetect!) < const Duration(minutes: 5)) {
      return {
        'plugin': _pluginFilterOk ?? false,
        'custom': _customApiOk ?? false,
        'standard': _standardApiOk ?? false,
      };
    }

    await init();
    _lastDetect = DateTime.now();

    // 1) 鎻掍欢绛涢€夋帴鍙?    try {
      final resp = await _dio.get('jgappapi.index/typeFilterVodList', queryParameters: {
        'page': 1,
        'limit': 1,
        'sort': '鏈€鏂?,
      });
      _pluginFilterOk = resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1);
    } catch (_) { _pluginFilterOk = false; }

    // 2) 鑷畾涔?app_api.php
    try {
      final resp = await _dio.get('${rootUrl}app_api.php', queryParameters: {
        'ac': 'list',
        'pg': 1,
        'pagesize': 1,
      });
      _customApiOk = resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1);
    } catch (_) { _customApiOk = false; }

    // 3) 鏍囧噯鎺ュ彛 provide/vod/
    try {
      final resp = await _dio.get('provide/vod/', queryParameters: {
        'ac': 'list',
        'pg': 1,
        'pagesize': 1,
        'at': 'json',
      });
      _standardApiOk = resp.statusCode == 200 && resp.data is Map;
    } catch (_) { _standardApiOk = false; }

    return {
      'plugin': _pluginFilterOk ?? false,
      'custom': _customApiOk ?? false,
      'standard': _standardApiOk ?? false,
    };
  }

  // ================= 鐢ㄦ埛鐩稿叧 =================

  /// 娉ㄥ唽
  /// 寮€鍙戣€咃細鏉板摜缃戠粶绉戞妧 (qq: 2711793818)
  /// 淇锛氭敮鎸侀獙璇佺爜鍜岄個璇风爜浼犲叆
  Future<Map<String, dynamic>> register(String username, String password, {String verifyCode = '', String inviteCode = ''}) async {
    await init();
    try {
      // 0. 浼樺厛灏濊瘯 JgApp 鎻掍欢娉ㄥ唽鎺ュ彛
      try {
        final data = {
          'user_name': username,
          'password': password,
          'invite_code': inviteCode,
        };
        if (verifyCode.isNotEmpty) {
          data['verify'] = verifyCode;
        }
        final resp = await _dio.post(
          'jgappapi.index/appRegister',
          data: data,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: _headers,
          ),
        );
        if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
          return {'success': true, 'info': resp.data['msg'] ?? '娉ㄥ唽鎴愬姛'};
        } else if (resp.data is Map && resp.data['msg'] != null) {
          return {'success': false, 'msg': resp.data['msg']};
        }
      } catch (_) {}

      // 1. 鍏舵灏濊瘯 app_api.php (鐢ㄦ埛鑷畾涔夋彃浠舵帴鍙?
      final customApiUrl = '${rootUrl}app_api.php';
      try {
        final data = {
          'user_name': username,
          'user_pwd': password,
          'user_pwd2': password,
        };
        if (verifyCode.isNotEmpty) {
          data['verify'] = verifyCode;
        }
        if (inviteCode.isNotEmpty) {
          data['invite_code'] = inviteCode;
        }
        final resp = await _dio.post(customApiUrl, queryParameters: {'ac': 'register'}, data: data);
        if (resp.statusCode == 200 && resp.data is Map) {
           if (resp.data['code'] == 1) {
             return {'success': true, 'info': resp.data['msg'] ?? '娉ㄥ唽鎴愬姛'};
           } else {
             return {'success': false, 'msg': resp.data['msg']};
           }
        }
      } catch (_) {}

      // 2. 闄嶇骇锛氬皾璇曟爣鍑?MacCMS 璺緞: /index.php/user/reg
      final url = '${rootUrl}/index.php/user/reg';
      final data = {
        'user_name': username,
        'user_pwd': password,
        'user_pwd2': password,
        'verify': verifyCode,
      };
      if (inviteCode.isNotEmpty) {
        data['invite_code'] = inviteCode;
      }
      final resp = await _dio.post(url, data: data, options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
        }
      ));
      
      final respData = resp.data;
      if (respData is Map && respData['code'] == 1) {
        return {'success': true, 'info': respData['msg'] ?? '娉ㄥ唽鎴愬姛'};
      } else if (respData is Map) {
        return {'success': false, 'msg': respData['msg'] ?? '娉ㄥ唽澶辫触'};
      } else {
        return {'success': false, 'msg': '鏈嶅姟鍣ㄨ繑鍥為潪JSON鏍煎紡锛屽彲鑳芥湭寮€鍚疉PI娉ㄥ唽'};
      }
    } catch (e) {
      return {'success': false, 'msg': '璇锋眰澶辫触: $e'};
    }
  }

  /// 妫€鏌ユ槸鍚︾櫥褰?  /// 寮€鍙戣€咃細鏉板摜缃戠粶绉戞妧 (qq: 2711793818)
  /// 淇锛氱畝鍖栭€昏緫锛屾槑纭牎楠屼紭鍏堢骇锛岄伩鍏嶈繃鏈焧oken璇垽
  Future<bool> checkLogin({bool force = false}) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final hasToken = _appUserToken != null && _appUserToken!.isNotEmpty;

    // 1. 寮哄埗妯″紡锛氬繀椤昏蛋缃戠粶鏍￠獙
    if (force) {
      try {
        final resp = await _dio.get('jgappapi.index/userInfo');
        final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
        if (resp.statusCode == 200 && resp.data is Map && code == 1) {
          // 鏇存柊鏈湴鐢ㄦ埛淇℃伅
          try {
            final data = resp.data['data'];
            if (data is Map && data['user_info'] is Map) {
              final user = data['user_info'] as Map;
              if (user['user_name'] != null) {
                await prefs.setString('user_name', user['user_name'].toString());
              }
            }
          } catch (_) {}
          return true;
        }
        // 鏍￠獙澶辫触锛屾竻鐞嗘湰鍦皌oken
        await logout();
        return false;
      } catch (_) {
        await logout();
        return false;
      }
    }

    // 2. 闈炲己鍒舵ā寮忥細鏈塼oken鍒欎紭鍏堢綉缁滄牎楠岋紝鏃爐oken鐩存帴杩斿洖false
    if (!hasToken) return false;

    try {
      final resp = await _dio.get('jgappapi.index/userInfo');
      final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
      if (resp.statusCode == 200 && resp.data is Map && code == 1) {
        return true;
      }
      // token澶辨晥锛屾竻鐞嗘湰鍦?      await logout();
      return false;
    } catch (_) {
      // 缃戠粶寮傚父鏃讹紝鏈塼oken鍒欎箰瑙傝涓哄凡鐧诲綍锛堥伩鍏嶅急缃戠幆澧冮绻佹帀绾匡級
      return true;
    }
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氫繚瀛?JgApp 鎻掍欢杩斿洖鐨?auth_token
  /// 瑙ｉ噴锛氭妸鍚庣缁欑殑鈥滅櫥褰曠エ鎹€濊浣忥紝鍚庨潰鑷姩甯﹀湪璇锋眰閲屻€?  Future<void> _saveAppUserToken(String? token) async {
    // 鍗充娇 token 涓虹┖锛屼篃瑕佸皾璇曚繚瀛橈紙濡傛灉涔嬪墠鏈夌殑璇濓級锛屼絾杩欓噷鍙鐞嗛潪绌?    if (token == null || token.isEmpty) return;
    _appUserToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_user_token', token);
  }

  /// 鐧诲綍
  Future<Map<String, dynamic>> login(String username, String password) async {
    await init();
    
    // 0. 浼樺厛灏濊瘯 JgApp 鎻掍欢 appLogin锛堣繑鍥?auth_token锛岀敤浜?app-user-token 澶达級
    try {
      final resp = await _dio.post(
        'jgappapi.index/appLogin',
        data: {
          'user_name': username,
          'password': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: _headers,
        ),
      );
      final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
      if (resp.statusCode == 200 && resp.data is Map && code == 1) {
        final data = resp.data['data'];
        String? token;
        if (data is Map) {
             // 灏濊瘯澶氱璺緞鑾峰彇 token
             if (data['user'] is Map) {
                token = data['user']['auth_token']?.toString();
             }
             if (token == null || token.isEmpty) {
                token = data['auth_token']?.toString();
             }
             if (token == null || token.isEmpty) {
                token = data['token']?.toString();
             }
        }
        
        await _saveAppUserToken(token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', username);
        return {'success': true, 'info': resp.data['msg'] ?? '鐧诲綍鎴愬姛'};
      }
    } catch (_) {
      // 蹇界暐鎻掍欢閿欒锛岀户缁皾璇曞叾浠栫櫥褰曟柟寮?    }
    
    // 1. 灏濊瘯 app_api.php锛堝吋瀹规棫鐗堣嚜瀹氫箟鎺ュ彛锛?    final customApiUrl = '${rootUrl}app_api.php';
    try {
      final resp = await _dio.post(customApiUrl, queryParameters: {'ac': 'login'}, data: {
        'user_name': username,
        'user_pwd': password,
      });
      if (resp.statusCode == 200 && resp.data is Map) {
         final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
         if (code == 1) {
           final prefs = await SharedPreferences.getInstance();
           await prefs.setString('user_name', username);
           return {'success': true, 'info': resp.data['msg'] ?? '鐧诲綍鎴愬姛'};
         } else {
           return {'success': false, 'msg': resp.data['msg']};
         }
      }
    } catch (_) {}

    // 2. 闄嶇骇锛氬皾璇曟爣鍑嗚矾寰?    final url = '${rootUrl}index.php/user/login';
    try {
      final resp = await _dio.post(url, data: {
        'user_name': username,
        'user_pwd': password,
      }, options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
        validateStatus: (status) => status! < 500, // 鍏佽 302/400 绛?      ));
      
      // 濡傛灉杩斿洖 HTML锛屾鏌ユ槸鍚﹀寘鍚壒瀹氶敊璇?      if (resp.data is String) {
         if (resp.data.toString().contains('鍘熺敓鎺ュ彛')) {
            return {'success': false, 'msg': '鏈嶅姟鍣ㄩ檺鍒讹細璇疯仈绯荤鐞嗗憳寮€鍚?APP API 鎺ュ彛鏉冮檺'};
         }
      }
      
      final data = resp.data;
      // 鍏煎 code 鍙兘鏄瓧绗︿覆鐨勬儏鍐?      final code = int.tryParse('${data['code'] ?? 0}') ?? 0;
      if (data is Map && code == 1) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', username);
        return {'success': true, 'info': data['msg'] ?? '鐧诲綍鎴愬姛'};
      } else {
        return {'success': false, 'msg': data is Map ? data['msg'] : '鐧诲綍澶辫触'};
      }
    } catch (e) {
      // 濡傛灉鏍囧噯璺緞澶辫触锛屽皾璇?API 璺緞锛堟湁浜涙彃浠舵敮鎸侊級
      try {
         final resp = await _dio.post('user/login', data: {
            'user_name': username,
            'user_pwd': password,
         });
         final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
         if (code == 1) {
            return {'success': true, 'info': resp.data['info']};
         }
      } catch (_) {}
      return {'success': false, 'msg': '鐧诲綍璇锋眰澶辫触: $e'};
    }
  }

  /// 閫€鍑虹櫥褰曪紙娓呯悊鏈湴 Cookie锛?  Future<void> logout() async {
    await init();
    if (!kIsWeb) {
      await _cookieJar.deleteAll();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
     await prefs.remove('app_user_token');
     _appUserToken = null;
  }

  /// 鑾峰彇缂撳瓨鐨勭敤鎴蜂俊鎭?  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? '鐢ㄦ埛';
  }

  /// 娣诲姞鏀惰棌
  Future<Map<String, dynamic>> addFav(String vodId) async {
    await init();
    // 浼樺厛浣跨敤鎻掍欢鎺ュ彛锛歫gappapi.index/collect锛堟敮鎸?app-user-token锛屾棤闇€ Cookie锛?    try {
      final resp = await _dio.get(
        'jgappapi.index/collect',
        queryParameters: {'vod_id': vodId},
        options: Options(headers: _headers),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final code = int.tryParse('${resp.data['code'] ?? 1}') ?? 1;
        final msg = (resp.data['data'] is Map)
            ? (resp.data['data']['msg']?.toString() ?? '')
            : (resp.data['msg']?.toString() ?? '');
        return {'success': code == 1, 'msg': msg.isNotEmpty ? msg : (code == 1 ? '鏀惰棌鎴愬姛' : '鏀惰棌澶辫触')};
      }
    } catch (_) {
      // 蹇界暐鎻掍欢閿欒锛岄檷绾у埌鏍囧噯鎺ュ彛
    }
    // 鍏煎鏍囧噯鎺ュ彛锛氶渶瑕?Cookie 浼氳瘽
    try {
      final resp = await _dio.post('user/ulog_add', data: {
        'ulog_mid': 1,
        'ulog_rid': vodId,
        'ulog_type': 2,
      });
      final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
      return {
        'success': code == 1,
        'msg': resp.data['msg'] ?? (code == 1 ? '鏀惰棌鎴愬姛' : '鏀惰棌澶辫触'),
      };
    } catch (e) {
      return {'success': false, 'msg': '璇锋眰澶辫触: $e'};
    }
  }

  /// 娣诲姞鎾斁璁板綍
  Future<bool> addHistory(String vodId) async {
    await init();
    // ulog_type: 4=鎾斁璁板綍
    final resp = await _dio.post('user/ulog_add', data: {
      'ulog_mid': 1,
      'ulog_rid': vodId,
      'ulog_type': 4,
    });
    return resp.data['code'] == 1;
  }

  /// 鑾峰彇鏀惰棌鍒楄〃
  Future<List<Map<String, dynamic>>> getFavs({int page = 1}) async {
    await init();
    // 浼樺厛浣跨敤鎻掍欢鎺ュ彛锛歫gappapi.index/collectList
    try {
      final resp = await _dio.get(
        'jgappapi.index/collectList',
        queryParameters: {'page': page},
        options: Options(headers: _headers),
      );
      if (resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        final rows = (data?['collect_list'] as List?) ?? const [];
        return rows.whereType<Map>().map((v) {
          final vod = (v['vod'] as Map?) ?? const {};
          return {
            'log_id': '${v['id']}', // 鎻掍欢杩斿洖鐨勬敹钘忚褰旾D
            'id': '${v['vod_id']}',
            'title': vod['vod_name']?.toString() ?? '',
            'poster': _fixUrl(vod['vod_pic']?.toString()),
          };
        }).toList();
      }
    } catch (_) {}
    // 鍏煎鏍囧噯鎺ュ彛
    try {
      final resp = await _dio.get('user/ulog_list', queryParameters: {
        'ulog_mid': 1,
        'ulog_type': 2,
        'limit': 100,
      });
      final rows = (resp.data?['info']?['rows'] as List?) ?? [];
      return rows.map((v) => {
        'log_id': '${v['ulog_id']}', // 鏀惰棌璁板綍ID锛岀敤浜庡垹闄?        'id': '${v['ulog_rid']}',
        'title': (v['data'] is Map ? v['data']['name'] : '') ?? '',
        'poster': _fixUrl((v['data'] is Map ? v['data']['pic'] : '')?.toString()),
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 鍒犻櫎鏀惰棌
  Future<Map<String, dynamic>> deleteFav(String logId, {String? vodId, String? ids}) async {
    await init();
    // 浼樺厛浣跨敤鎻掍欢鎺ュ彛锛歫gappapi.index/deleteCollect锛堟敮鎸佹寜 vod_id 鎴?ids 鎵归噺鍒犻櫎锛?    try {
      // 鍙浼犲叆浜?vodId 鎴?ids锛屾垨鑰?logId 鐪嬭捣鏉ュ儚涓?ID锛岄兘灏濊瘯璋冪敤鎻掍欢鎺ュ彛
      final effectiveIds = ids ?? (RegExp(r'^\d+$').hasMatch(logId) ? logId : null);
      
      if ((vodId != null && vodId.isNotEmpty) || (effectiveIds != null && effectiveIds.isNotEmpty)) {
        final params = <String, dynamic>{};
        if (effectiveIds != null && effectiveIds.isNotEmpty) {
           params['ids'] = effectiveIds;
        } else {
           params['vod_id'] = vodId;
        }
        
        final resp = await _dio.get(
          'jgappapi.index/deleteCollect',
          queryParameters: params,
          options: Options(headers: _headers),
        );
        if (resp.statusCode == 200 && resp.data is Map) {
          final code = int.tryParse('${resp.data['code'] ?? 1}') ?? 1;
          final msg = resp.data['msg']?.toString() ?? '';
          // 鍙鎺ュ彛杩斿洖锛屽氨璁や负鎴愬姛锛坈ode=1锛夛紝闄ら潪鏄庣‘鎶ラ敊
          return {'success': code == 1, 'msg': msg.isNotEmpty ? msg : (code == 1 ? '鍒犻櫎鎴愬姛' : '鍒犻櫎澶辫触')};
        }
      }
    } catch (_) {}
    // 鍏煎鏍囧噯鎺ュ彛锛氭寜 logId 鍒犻櫎

    try {
      final resp = await _dio.post('user/ulog_del', data: {
        'ids': logId,
        'type': 2,
      });
      final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
      return {
        'success': code == 1,
        'msg': resp.data['msg'] ?? (code == 1 ? '鍒犻櫎鎴愬姛' : '鍒犻櫎澶辫触'),
      };
    } catch (e) {
      return {'success': false, 'msg': '璇锋眰澶辫触: $e'};
    }
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氶€氳繃 vodId 鍒犻櫎鏀惰棌
  Future<Map<String, dynamic>> deleteFavByVodId(String vodId) async {
    await init();
    // 1. 灏濊瘯閫氳繃鎻掍欢鎺ュ彛鍒犻櫎 (鏀寔 vod_id)
    try {
      final resp = await _dio.get(
        'jgappapi.index/deleteCollect',
        queryParameters: {'vod_id': vodId},
        options: Options(headers: _headers),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
         final code = int.tryParse('${resp.data['code'] ?? 1}') ?? 1;
         return {'success': code == 1, 'msg': resp.data['msg'] ?? '鍒犻櫎鎴愬姛'};
      }
    } catch (_) {}

    // 2. 濡傛灉鎻掍欢澶辫触锛屽厛鑾峰彇鍒楄〃鎵惧埌 logId锛屽啀鍒犻櫎
    try {
      final favs = await getFavs(page: 1);
      final item = favs.firstWhere((e) => '${e['id']}' == vodId, orElse: () => {});
      if (item.isNotEmpty && item['log_id'] != null) {
        return await deleteFav(item['log_id']!);
      }
    } catch (_) {}
    
    return {'success': false, 'msg': '鏈壘鍒版敹钘忚褰?};
  }

  /// 妫€鏌ュ崟涓奖鐗囨槸鍚﹀凡鏀惰棌锛堟彃浠舵帴鍙ｏ級
  Future<bool> isCollected(String vodId) async {
    await init();
    try {
      final resp = await _dio.get(
        'jgappapi.index/isCollect',
        queryParameters: {'vod_id': vodId},
        options: Options(headers: _headers),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        // 鎻掍欢閫氬父杩斿洖 {code:1, data:{is_collect:true/false}} 鎴栬€?{data:true/false}
        final data = resp.data['data'];
        if (data is Map && data['is_collect'] is bool) {
          return data['is_collect'] as bool;
        }
        if (data is bool) return data;
        // 濡傛灉鍙繑鍥?msg锛屼笉鍙潬锛岄檷绾у埌鍒楄〃鍒ゆ柇
      }
    } catch (_) {}
    // 鍏滃簳锛氶€氳繃鏀惰棌鍒楄〃鍒ゆ柇
    try {
      final favs = await getFavs(page: 1);
      return favs.any((e) => '${e['id']}' == vodId);
    } catch (_) {
      return false;
    }
  }

  /// 鑾峰彇鎾斁璁板綍
  Future<List<Map<String, dynamic>>> getHistory() async {
    await init();
    final resp = await _dio.get('user/ulog_list', queryParameters: {
      'ulog_mid': 1,
      'ulog_type': 4,
      'limit': 100,
    });
    final rows = (resp.data?['info']?['rows'] as List?) ?? [];
    return rows.map((v) => {
      'id': '${v['ulog_rid']}',
      'title': v['data']['name'] ?? '',
      'poster': v['data']['pic'] ?? '',
    }).toList();
  }

  // ================= 瑙嗛鐩稿叧 =================

  /// 杈呭姪鍑芥暟锛氬鐞嗗浘鐗囬摼鎺ワ紙澶勭悊鐩稿璺緞锛?  String fixUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // 濡傛灉鏄?mac_turl 杩欐牱鐨勯潪娉曢摼鎺ワ紝灏濊瘯淇鎴栧拷鐣?    if (url.contains('mac_turl')) return '';

    String finalUrl = url;
    
    // 濡傛灉鏄浉瀵硅矾寰勶紝鎷兼帴鍒板煙鍚嶆牴鐩綍
    if (!url.startsWith('http')) {
      final base = AppConfig.baseUrl;
      // 绉婚櫎 api.php 鍙婂叾鍚庨潰鐨勫唴瀹癸紝鑾峰彇鐪熸鐨勬牴鍩熷悕
      // 渚嬪 https://ys.ddgg888.my/api.php/provide/vod/ -> https://ys.ddgg888.my/
      final root = base.split('/api.php').first;
      
      if (url.startsWith('/')) {
         finalUrl = '$root$url';
      } else {
         finalUrl = '$root/$url';
      }
    }
    
    // 寮哄埗灏?http 杞负 https锛堝鏋滈厤缃槸 https锛?    if (AppConfig.baseUrl.startsWith('https://') && finalUrl.startsWith('http://')) {
      finalUrl = finalUrl.replaceFirst('http://', 'https://');
    }
    
    return finalUrl;
  }

  /// 鍐呴儴璋冪敤淇濈暀鍏煎
  String _fixUrl(String? url) => fixUrl(url);

  /// 鑾峰彇鎺ㄨ崘瑙嗛锛堢敤浜庤疆鎾浘锛孡evel=9锛?  Future<List<Map<String, dynamic>>> getBanner() async {
    // 浼樺厛灏濊瘯浠?app_api.php init 鎺ュ彛鑾峰彇
    final data = await getAppInit();
    if (data.isNotEmpty && data['banner_list'] != null) {
      try {
        final list = (data['banner_list'] as List);
        return list.map((item) {
          final v = item as Map<String, dynamic>;
          return {
            'id': '${v['vod_id']}',
            'title': v['vod_name'] ?? '',
            'poster': _fixUrl(v['vod_pic']),
            'type': v['type_name'] ?? '',
          };
        }).toList();
      } catch (e) {
        print('Banner Parse Error: $e');
      }
    }

    // 鎻掍欢/鑷畾涔夋帴鍙ｄ笉鍙敤鏃讹紝浣跨敤绛涢€夋帴鍙ｈ繎浼尖€滆疆鎾€濓細鍙栧懆鐑鎴栨渶鐑?    // 鏉板摜锛氭牴鎹敤鎴疯姹傦紝绉婚櫎鎵€鏈夎嚜鍔ㄥ厹搴曟暟鎹€傚鏋滄病鏈夐厤缃?Banner锛屽氨涓嶆樉绀恒€?    /*
    try {
      final hotWeek = await getFiltered(orderby: 'hits_week', limit: 5);
      if (hotWeek.isNotEmpty) {
        return hotWeek.map((e) => {
          'id': e['id'],
          'title': e['title'],
          'poster': e['poster'],
          'type': e['type'] ?? '',
        }).toList();
      }
      final hot = await getFiltered(orderby: 'hits', limit: 5);
      if (hot.isNotEmpty) {
        return hot.map((e) => {
          'id': e['id'],
          'title': e['title'],
          'poster': e['poster'],
          'type': e['type'] ?? '',
        }).toList();
      }
    } catch (_) {}
    */
    return [];
  }

  /// 鑾峰彇鐑挱鍒楄〃
  Future<List<Map<String, dynamic>>> getHot({int page = 1}) async {
    // 寮€鍙戣€咃細鏉板摜
    // 浣滅敤锛氳幏鍙栤€滃綋鍓嶇儹鎾€濓紝浼樺厛浣跨敤鎻掍欢绛涢€夋帴鍙ｏ紙sort=hits_week锛夛紝閬垮厤鏍囧噯鎺ュ彛鍏抽棴瀵艰嚧绌烘暟鎹?    // 瑙ｉ噴锛氬鏋滃悗绔爣鍑嗘帴鍙ｅ叧浜嗭紝鎴戠敤鎻掍欢鐨勬帴鍙ｆ嬁鈥滃懆鐑挱鈥濆垪琛ㄣ€?    const limit = 20;
    try {
      final list = await getFiltered(page: page, limit: limit, orderby: 'hits_week');
      if (list.isNotEmpty) return list;
    } catch (_) {}

    await init();
    try {
      final resp = await _dio.get('provide/vod/', queryParameters: {
        'ac': 'detail',
        'pg': page,
        'pagesize': limit,
        'by': 'hits_week',
        'at': 'json',
      });
      // 淇锛氬鐞?closed 鐘舵€?      if (resp.data is String && resp.data.toString().trim() == 'closed') {
        return [];
      }
      final rows = (resp.data?['list'] as List?) ?? [];
      return rows.map((v) => {
        'id': '${v['vod_id']}',
        'title': v['vod_name'] ?? '',
        'poster': _fixUrl(v['vod_pic']),
        'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
        'year': '${v['vod_year'] ?? ''}',
        'overview': v['vod_remarks'] ?? v['vod_blurb'] ?? '',
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // 绠€鍗曠殑鍐呭瓨缂撳瓨锛屼紭鍖栨悳绱㈤€熷害
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  // APP 鍒濆鍖栨暟鎹紦瀛?  Map<String, dynamic>? _initData;
  DateTime? _initDataAt;
  
  List<String> get filterWords {
    if (_initData != null && _initData!['filter_words'] is List) {
      return (_initData!['filter_words'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  // 寮€鍙戣€咃細鏉板摜缃戠粶绉戞妧 (qq: 2711793818)
  // 浣滅敤锛氳幏鍙栧叏灞€閰嶇疆锛堣仈绯绘柟寮忋€佸垎浜枃妗堛€佸脊骞曞紑鍏崇瓑锛?  // 瑙ｉ噴锛氫粠鎻掍欢 init 鎺ュ彛鐨?config 瀛楁璇诲彇鍚庡彴鎵€鏈夎缃?  Map<String, dynamic> get appConfig {
    if (_initData != null && _initData!['config'] is Map) {
      return _initData!['config'] as Map<String, dynamic>;
    }
    return {};
  }

  // 寮€鍙戣€咃細鏉板摜缃戠粶绉戞妧 (qq: 2711793818)
  // 浣滅敤锛氳幏鍙栭〉闈㈢骇璁剧疆锛堥殣钘忓皝闈€侀殣钘忕増鏈彿绛夛級
  // 瑙ｉ噴锛氫粠鎻掍欢 init 鎺ュ彛鐨?app_page_setting.app_page_setting 瀛楁璇诲彇
  Map<String, dynamic> get appPageSetting {
    if (_initData != null &&
        _initData!['app_page_setting'] is Map &&
        _initData!['app_page_setting']['app_page_setting'] is Map) {
      return _initData!['app_page_setting']['app_page_setting'] as Map<String, dynamic>;
    }
    return {};
  }

  // ================= 鍩虹閰嶇疆 =================
  String get contactUrl => appConfig['app_contact_url']?.toString() ?? appConfig['kefu_url']?.toString() ?? '';
  String get contactText => appConfig['app_contact_text']?.toString() ?? '鑱旂郴瀹㈡湇';
  String get shareText => appConfig['app_share_text']?.toString() ?? '鎺ㄨ崘涓€娆惧緢濂界敤鐨勮拷鍓PP锛屽揩鏉ヤ笅杞藉惂锛?;
  String get extraFindUrl => appConfig['app_extra_find_url']?.toString() ?? '';
  int get cacheTime => int.tryParse('${appConfig['init_cache_time'] ?? 60}') ?? 60;

  // ================= 璇勮寮€鍏?=================
  bool get isCommentOpen => (int.tryParse('${appConfig['system_comment_status'] ?? 1}') ?? 1) == 1;
  bool get isCommentAudit => (int.tryParse('${appConfig['system_comment_audit'] ?? 0}') ?? 0) == 1;

  // ================= 娉ㄥ唽寮€鍏?=================
  bool get isRegOpen => (int.tryParse('${appConfig['system_register_user_status'] ?? 1}') ?? 1) == 1;
  bool get isRegVerify => (int.tryParse('${appConfig['system_reg_verify'] ?? 0}') ?? 0) == 1;
  bool get isRegWarter => (int.tryParse('${appConfig['system_reg_warter'] ?? 0}') ?? 0) == 1;
  int get regNum => int.tryParse('${appConfig['system_reg_num'] ?? 0}') ?? 0;

  // ================= VPN/璇曠敤 =================
  bool get isVpnDetect => appConfig['system_vpn_check_status'] == true;
  int get trySee => int.tryParse('${appConfig['system_trysee'] ?? 0}') ?? 0;

  // ================= 寮瑰箷寮€鍏?=================
  bool get isDanmuEnabled => (int.tryParse('${appConfig['system_danmu_status'] ?? 1}') ?? 1) == 1;
  bool get isThirdDanmuEnabled => appConfig['system_third_danmu_status'] == true;

  // ================= 璇勮/鐢ㄦ埛 =================
  bool get isUserAvatarOpen => (int.tryParse('${appConfig['system_user_avatar_status'] ?? 1}') ?? 1) == 1;
  String get hotSearch => appConfig['system_hot_search']?.toString() ?? '';
  int get searchListType => int.tryParse('${appConfig['system_config_search_list_type'] ?? 1}') ?? 1;

  // ================= 鍏充簬鎴戜滑 =================
  String get aboutUsAvatar => appConfig['system_config_about_us_avatar_url']?.toString() ?? '';
  String get aboutUsContent => appConfig['system_config_about_us_content']?.toString() ?? '';

  // ================= 鎺ㄨ崘绾у埆 =================
  int get bannerLevel => int.tryParse('${appConfig['system_banner_level'] ?? 9}') ?? 9;
  int get hotLevel => int.tryParse('${appConfig['system_hot_level'] ?? 8}') ?? 8;

  // ================= 椤甸潰璁剧疆锛堥殣钘忓皝闈㈢瓑锛?================
  bool get isHideVersion => appPageSetting['app_page_version_hide'] == true;
  bool get isHideDetailPic => appPageSetting['app_page_vod_detail_pic_hide'] == true;
  bool get isHideMineBg => appPageSetting['app_page_mine_bg_hide'] == true;
  int get homepageTypeSize => int.tryParse('${appPageSetting['app_page_homepage_type_size'] ?? 14}') ?? 14;
  int get homepageBannerInterval => int.tryParse('${appPageSetting['app_page_homepage_banner_interval'] ?? 5}') ?? 5;
  String get rankListType => appPageSetting['app_page_rank_list_type']?.toString() ?? '2';
  int get vodSourceType => int.tryParse('${appPageSetting['app_vod_source_type'] ?? 0}') ?? 0;

  // ================= 骞垮憡寮€鍏?=================
  bool get isSplashAdOpen => appConfig['ad_splash_status'] == true;
  bool get isHomeInsertAdOpen => appConfig['ad_home_page_insert_status'] == true;
  bool get isMineBannerAdOpen => appConfig['ad_mine_page_banner_status'] == true;
  bool get isDetailBannerAdOpen => appConfig['ad_detail_page_banner_status'] == true;
  bool get isSearchBannerAdOpen => appConfig['ad_search_page_banner_status'] == true;

  // ================= 鎼滅储瑙勫垯 =================
  String get searchVodRule {
    if (_initData != null &&
        _initData!['app_page_setting'] is Map) {
      return (_initData!['app_page_setting'] as Map)['search_vod_rule']?.toString() ?? '鎼滅储鍚嶇О 绠€浠?;
    }
    return '鎼滅储鍚嶇О 绠€浠?;
  }

  bool containsFilterWord(String text) {
    if (text.isEmpty) return false;
    for (final word in filterWords) {
      if (word.isNotEmpty && text.contains(word)) return true;
    }
    return false;
  }
  
  // 閫氱敤 Headers
  Map<String, dynamic> get _headers => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'X-Requested-With': 'XMLHttpRequest',
    'app-os': _appOs,
    'app-version-code': '$_appVersionCode',
  };

  /// 寮€鍙戣€咃細鏉板摜缃戠粶绉戞妧 (qq: 2711793818)
  /// 浣滅敤锛氭妸 app 鐗堟湰鍙疯浆鎴?JgApp 鎻掍欢闇€瑕佺殑 version_code
  /// 瑙ｉ噴锛氬悗绔敤 1.0.0 -> 10000 杩欑瑙勫垯鍒ゆ柇鏈夋病鏈夋柊鐗堟湰銆?  /// 淇锛氭敮鎸佷换鎰忕増鏈彿锛屽 1.10.0 -> 11000
  int _parseJgAppVersionCode(String versionName) {
    final parts = versionName.split('.');
    if (parts.length < 3) return 0;
    final major = int.tryParse(parts[0]) ?? 0;
    final minor = int.tryParse(parts[1]) ?? 0;
    final patch = int.tryParse(parts[2]) ?? 0;
    // 鏀寔浠绘剰鐗堟湰鍙凤紝濡?1.10.0 -> 11000
    return major * 10000 + minor * 100 + patch;
  }

  /// 鑾峰彇 APP 鍒濆鍖栨暟鎹?(鐑悳銆丅anner銆佹帹鑽?
  Future<Map<String, dynamic>> getAppInit({bool force = false}) async {
    // 0) 鍏堣繑鍥炩€滃唴瀛樼紦瀛樷€濓紝閬垮厤閲嶅璇锋眰
    if (!force &&
        _initData != null &&
        _initDataAt != null &&
        DateTime.now().difference(_initDataAt!) < const Duration(minutes: 30)) {
      return _initData!;
    }
    await init();
    // 1) 濡傛灉鈥滅鐩樼紦瀛樷€濆瓨鍦紝鍒欎紭鍏堢珛鍗宠繑鍥烇紝鍚庡彴鍒锋柊
    try {
      final disk = await _loadInitDataFromDisk();
      if (!force && disk != null && disk.isNotEmpty) {
        _initData = disk['data'] as Map<String, dynamic>;
        _initDataAt = DateTime.fromMillisecondsSinceEpoch(disk['ts'] as int);
        // 寮傛鍒锋柊鏈€鏂版暟鎹紝涓嶉樆濉為灞?        _refreshAppInitInBackground();
        return _initData!;
      }
    } catch (_) {}
    // 娓呯┖鍐呭瓨缂撳瓨锛屽噯澶囬噸鏂板姞杞?    _initData = null;
    _initDataAt = null;
    
    // 1. 灏濊瘯 JgApp 鎻掍欢鎺ュ彛
    try {
      final resp = await _dio.get('jgappapi.index/init', options: Options(headers: _headers));
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
        final respMap = resp.data as Map;
        dynamic data = respMap['data'];
        if (data is String) {
          final raw = data.trim();
          try {
            data = jsonDecode(utf8.decode(base64Decode(raw)));
          } catch (_) {
            try {
              data = jsonDecode(raw);
            } catch (_) {
              data = <String, dynamic>{};
            }
          }
        }
        final Map dataMap = (data is Map) ? data : <String, dynamic>{};

        // 澶勭悊 type_list
        dynamic rawTypeList = dataMap['type_list'];
        
        // 寮€鍙戣€咃細鏉板摜
        // 淇锛氬吋瀹?type_list 浣嶄簬 dataMap['data'] 缁撴瀯涓嬬殑鎯呭喌
        if (rawTypeList == null && dataMap['data'] is Map) {
             rawTypeList = dataMap['data']['type_list'];
        }
        
        // 淇锛氬吋瀹?curl 缁撴灉鏄剧ず鐨勬墎骞崇粨鏋勶紙type_list 灏卞湪鏍硅妭鐐逛笅锛屼絾 dataMap 鍙兘鏄暣涓?response锛?        // 瀹為檯涓?jgappapi.index/init 杩斿洖鐨勭粨鏋勬槸 {code:1, msg:.., type_list:[...], ...}
        // 鎵€浠ュ綋 respMap 灏辨槸 dataMap 鏃讹紝type_list 搴旇鑳界洿鎺ュ彇鍒般€?        // 浣嗘槸锛屽鏋?dataMap 鏄?respMap['data']锛岃€?type_list 杩樺湪澶栧眰锛屽氨浼氬彇涓嶅埌銆?        // 鎴戜滑杩欓噷鍋氫釜澧炲己鏌ユ壘锛?        if (rawTypeList == null && respMap['type_list'] != null) {
           rawTypeList = respMap['type_list'];
        }

        if (rawTypeList is String) {
          final raw = rawTypeList.trim();
          try {
            rawTypeList = jsonDecode(utf8.decode(base64Decode(raw)));
          } catch (_) {
            try {
              rawTypeList = jsonDecode(raw);
            } catch (_) {
              rawTypeList = const [];
            }
          }
        }
        // 鍏煎锛氶儴鍒嗗悗绔繑鍥炵殑 type_list 鏄?Map 鏄犲皠锛坕d -> name 鎴栧璞★級
        if (rawTypeList is Map) {
          final List<Map<String, dynamic>> mapped = [];
          (rawTypeList as Map).forEach((k, v) {
            final id = int.tryParse('$k') ?? (int.tryParse('${(v as Map?)?['type_id'] ?? 0}') ?? 0);
            if (v is Map) {
              final name = (v['type_name'] ?? v['name'] ?? '').toString().trim();
              if (id > 0 && name.isNotEmpty) {
                mapped.add({'type_id': id, 'type_name': name, 'enabled': (v['enabled'] ?? v['is_enabled'] ?? v['status'] ?? v['type_status'] ?? v['is_open'] ?? 1)});
              }
            } else {
              final name = '$v'.toString().trim();
              if (id > 0 && name.isNotEmpty) {
                mapped.add({'type_id': id, 'type_name': name, 'enabled': 1});
              }
            }
          });
          rawTypeList = mapped;
        }
        
        // 鍏抽敭淇锛氫紭鍏堜娇鐢ㄦ彃浠惰繑鍥炵殑 type_list锛屽鏋滀负绌烘墠灏濊瘯鏍囧噯鎺ュ彛鍏滃簳
        var typeList = (rawTypeList is List) ? rawTypeList : const [];
        // 浠呬娇鐢ㄦ彃浠惰繑鍥炵殑鍒嗙被锛屼笉鍐嶄娇鐢ㄦ爣鍑嗘帴鍙ｅ厹搴?
        _initData = {
          'type_list': typeList.whereType<Map>().map((m) {
            final dynamic enabledRaw = m['enabled'] ?? m['is_enabled'] ?? m['status'] ?? m['type_status'] ?? m['is_open'];
            final bool enabled = enabledRaw == null
                ? true
                : (enabledRaw is bool
                    ? enabledRaw
                    : (int.tryParse('$enabledRaw') ?? 0) == 1);
            return {
              'type_id': m['type_id'],
              'type_name': (m['type_name'] ?? '').toString().trim(),
              'enabled': enabled,
            };
          }).toList(),
          'app_page_setting': dataMap['app_page_setting'],
          'notice': (dataMap['notice'] is Map)
              ? {
                  'id': (dataMap['notice'] as Map)['id'],
                  'title': (dataMap['notice'] as Map)['title'] ?? '',
                  'sub_title': (dataMap['notice'] as Map)['sub_title'] ?? '',
                  'create_time': (dataMap['notice'] as Map)['create_time'] ?? '',
                  'content': (dataMap['notice'] as Map)['content'] ?? '',
                  'is_force': ((dataMap['notice'] as Map)['is_force'] == true || (dataMap['notice'] as Map)['is_force'] == 1 || '${(dataMap['notice'] as Map)['is_force']}' == '1'),
                }
              : null,
          // 鐗堟湰鏇存柊淇℃伅锛堟潵鑷彃浠?init 杩斿洖鐨?update 瀛楁锛?          'update': (dataMap['update'] is Map)
              ? {
                  'version_name': (dataMap['update'] as Map)['version_name']?.toString() ?? '',
                  'version_code': (dataMap['update'] as Map)['version_code']?.toString() ?? '',
                  'download_url': (dataMap['update'] as Map)['download_url']?.toString() ?? '',
                  'browser_download_url': (dataMap['update'] as Map)['browser_download_url']?.toString() ?? '',
                  'app_size': (dataMap['update'] as Map)['app_size']?.toString() ?? '',
                  'description': (dataMap['update'] as Map)['description']?.toString() ?? '',
                  'is_force': ((dataMap['update'] as Map)['is_force'] == true || (dataMap['update'] as Map)['is_force'] == 1),
                }
              : null,
          'banner_list': ((dataMap['banner_list'] as List?) ?? const []).whereType<Map>().map((v) {
                // 澧炲己瑙ｆ瀽锛氬吋瀹?slide_id/slide_pic 绛夊瓧娈?                final id = '${v['vod_id'] ?? v['slide_id'] ?? v['id'] ?? ''}';
                final title = (v['vod_name'] ?? v['slide_name'] ?? v['title'] ?? '').toString();
                final pic = (v['vod_pic'] ?? v['slide_pic'] ?? v['poster'] ?? v['img'] ?? '').toString();
                final url = (v['vod_link'] ?? v['slide_url'] ?? v['url'] ?? '').toString();
                
                return {
                  'id': id,
                  'title': title,
                  'poster': _fixUrl(pic),
                  'type': v['type_name'] ?? '',
                  'url': url,
                };
              }).toList(),
          'recommend_list': ((dataMap['recommend_list'] as List?) ?? const []).whereType<Map>().map((v) => {
                'id': '${v['vod_id']}',
                'title': v['vod_name'] ?? '',
                'poster': _fixUrl(v['vod_pic']),
                'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
                'year': '${v['vod_year'] ?? ''}',
                'overview': v['vod_remarks'] ?? '',
              }).toList(),
          'type_recommend_list': typeList.whereType<Map>().where((t) {
            final id = int.tryParse('${t['type_id'] ?? 0}') ?? 0;
            return id != 0 && t['recommend_list'] is List;
          }).map((t) {
            final typeId = t['type_id'];
            final typeName = (t['type_name'] ?? '').toString().trim();
            final recList = (t['recommend_list'] as List?) ?? const [];
            return {
              'type_id': typeId,
              'type_name': typeName,
              'list': recList.whereType<Map>().map((v) => {
                    'id': '${v['vod_id']}',
                    'title': v['vod_name'] ?? '',
                    'poster': _fixUrl(v['vod_pic']),
                    'overview': v['vod_remarks'] ?? '',
                    'year': '${v['vod_year'] ?? ''}',
                  }).toList(),
            };
          }).toList(),
          'home_advert': (dataMap['home_advert'] is Map)
              ? {
                  'id': '${dataMap['home_advert']['vod_id']}',
                  'title': dataMap['home_advert']['vod_name'] ?? '',
                  'poster': _fixUrl(dataMap['home_advert']['vod_pic']),
                  'url': dataMap['home_advert']['vod_link'] ?? '',
                }
              : null,
          'icon_advert': ((dataMap['icon_advert'] as List?) ?? const [])
              .whereType<Map>()
              .map((v) => {
                    'id': '${v['vod_id']}',
                    'title': v['vod_name'] ?? '',
                    'poster': _fixUrl(v['vod_pic']),
                    'url': v['vod_link'] ?? '',
                  })
              .toList(),
          'hot_search_list': _parseHotSearch(dataMap),
          'notice_count': int.tryParse('${dataMap['notice_count'] ?? 0}') ?? 0,
          'filter_words': (dataMap['filter_words'] is String)
              ? (dataMap['filter_words'] as String).split(',').where((e) => e.isNotEmpty).toList()
              : [],
          'config': dataMap['config'] is Map ? dataMap['config'] : {},
          // 鏉板摜锛氶€忎紶鑷畾涔夊箍鍛婂瓧娈碉紝渚涢椤?Banner 鍏滃簳浣跨敤
          'advert_list': dataMap['advert_list'] ?? respMap['advert_list'],
          'custom_ads': dataMap['custom_ads'] ?? respMap['custom_ads'],
          'ads': dataMap['ads'] ?? respMap['ads'],
          'home_banner': dataMap['home_banner'] ?? respMap['home_banner'],
          'slide_list': dataMap['slide_list'] ?? respMap['slide_list'], // 澧炲姞 slide_list 閫忎紶
          'focus_list': dataMap['focus_list'] ?? respMap['focus_list'], // 澧炲姞 focus_list 閫忎紶
          
          // 寮€鍙戣€咃細鏉板摜
          // 淇锛氶€忎紶缃《璇勮閰嶇疆锛堣В鍐宠鎯呴〉鏃犳硶鏄剧ず缃《璇勮鐨勯棶棰橈級
          // 浼樺厛椤哄簭锛歞ataMap > respMap > config > system
          'app_comment_top_status': dataMap['app_comment_top_status'] ?? respMap['app_comment_top_status'] ?? (dataMap['config'] is Map ? dataMap['config']['app_comment_top_status'] : null) ?? (dataMap['system'] is Map ? dataMap['system']['app_comment_top_status'] : null),
          'app_comment_top_name': dataMap['app_comment_top_name'] ?? respMap['app_comment_top_name'] ?? (dataMap['config'] is Map ? dataMap['config']['app_comment_top_name'] : null) ?? (dataMap['system'] is Map ? dataMap['system']['app_comment_top_name'] : null),
          'app_comment_top_avatar': dataMap['app_comment_top_avatar'] ?? respMap['app_comment_top_avatar'] ?? (dataMap['config'] is Map ? dataMap['config']['app_comment_top_avatar'] : null) ?? (dataMap['system'] is Map ? dataMap['system']['app_comment_top_avatar'] : null),
          'app_comment_top_content': dataMap['app_comment_top_content'] ?? respMap['app_comment_top_content'] ?? (dataMap['config'] is Map ? dataMap['config']['app_comment_top_content'] : null) ?? (dataMap['system'] is Map ? dataMap['system']['app_comment_top_content'] : null),
        };
        _initDataAt = DateTime.now();
        // 鎸佷箙鍖栫紦瀛橈紝鎻愬崌涓嬫鍚姩閫熷害
        _saveInitDataToDisk(_initData!);
        return _initData!;
      }
    } catch (_) {}

    // 1.1 鑻?init 涓嶅彲鐢紝灏濊瘯鎻掍欢鎻愪緵鐨勭簿绠€鍒嗙被鎺ュ彛 jgappapi.index/typeList
    try {
      final resp = await _dio.get('jgappapi.index/typeList', options: Options(headers: _headers));
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
        final data = (resp.data['data'] as Map?) ?? const {};
        final typeList = (data['type_list'] as List?) ?? const [];
        if (typeList.isNotEmpty) {
          _initData = {
            'type_list': typeList.map((m) {
              final dynamic enabledRaw = m['enabled'] ?? m['is_enabled'] ?? m['status'] ?? m['type_status'] ?? m['is_open'];
              final bool enabled = enabledRaw == null
                  ? true
                  : (enabledRaw is bool ? enabledRaw : (int.tryParse('$enabledRaw') ?? 0) == 1);
              return {
                'type_id': m['type_id'],
                'type_name': (m['type_name'] ?? '').toString().trim(),
                'enabled': enabled,
              };
            }).toList(),
          };
          _initDataAt = DateTime.now();
          _saveInitDataToDisk(_initData!);
          return _initData!;
        }
      }
    } catch (_) {}

    // 2. 灏濊瘯 app_api.php (鏃х増鎻掍欢)
    final customApiUrl = '${rootUrl}app_api.php';
    try {
      final resp = await _dio.get(customApiUrl, queryParameters: {'ac': 'init'}, options: Options(headers: _headers));
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
        final raw = resp.data as Map;
        final rawTypeList = (raw['type_list'] as List?) ?? const [];
        final normalizedTypeList = rawTypeList.whereType<Map>().map((m) {
          final dynamic enabledRaw = m['enabled'] ?? m['is_enabled'] ?? m['status'] ?? m['type_status'] ?? m['is_open'];
          final bool enabled = enabledRaw == null
              ? true
              : (enabledRaw is bool
                  ? enabledRaw
                  : (int.tryParse('$enabledRaw') ?? 0) == 1);
          return {
            'type_id': m['type_id'],
            'type_name': (m['type_name'] ?? '').toString().trim(),
            'enabled': enabled,
          };
        }).toList();
        _initData = {
          ...raw,
          if (raw['notice'] is Map)
            'notice': {
              'id': (raw['notice'] as Map)['id'],
              'title': (raw['notice'] as Map)['title'] ?? '',
              'sub_title': (raw['notice'] as Map)['sub_title'] ?? '',
              'create_time': (raw['notice'] as Map)['create_time'] ?? '',
              'content': (raw['notice'] as Map)['content'] ?? '',
              'is_force': ((raw['notice'] as Map)['is_force'] == true || (raw['notice'] as Map)['is_force'] == 1 || '${(raw['notice'] as Map)['is_force']}' == '1'),
            },
          if (normalizedTypeList.isNotEmpty) 'type_list': normalizedTypeList,
        };
        _initDataAt = DateTime.now();
        // 鎸佷箙鍖栫紦瀛?        _saveInitDataToDisk(_initData!);
        return _initData!;
      }
    } catch (e) {
      print('Init API Error: $e');
    }

    // 鎻掍欢涓庤嚜瀹氫箟鎺ュ彛鍧囦笉鍙敤鏃讹紝杩斿洖绌虹粨鏋勶紝閬垮厤宕╂簝
    _initData = {
      'type_list': const <Map<String, dynamic>>[],
    };
    _initDataAt = DateTime.now();
    _saveInitDataToDisk(_initData!);
    return _initData!;
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氫粎鑾峰彇鎻掍欢鍚庡彴鍒嗙被鍒楄〃锛堢敤浜庨椤甸《閮ㄥ垎绫诲厹搴曟媺鍙栵級
  /// 瑙ｉ噴锛氬鏋滃垵濮嬪寲鎺ュ彛娌″甫鍒嗙被锛屾垨鑰呰В鏋愬け璐ワ紝灏辩敤杩欎釜鎺ュ彛鍗曠嫭鎷垮垎绫汇€?  Future<List<Map<String, dynamic>>> getPluginTypeList() async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/typeList', options: Options(headers: _headers));
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
        final data = (resp.data['data'] as Map?) ?? const {};
        dynamic raw = data['type_list'] ?? data['list'] ?? data['class']; // 澧炲姞鍏煎瀛楁
        
        if (raw is String) {
          final s = raw.trim();
          try {
            raw = jsonDecode(utf8.decode(base64Decode(s)));
          } catch (_) {
            try {
              raw = jsonDecode(s);
            } catch (_) {
              raw = const [];
            }
          }
        }
        
        // 鍏煎锛氶儴鍒嗗悗绔繑鍥炵殑 type_list 鏄?Map 鏄犲皠
        if (raw is Map) {
          final List<Map<String, dynamic>> mapped = [];
          (raw as Map).forEach((k, v) {
            final id = int.tryParse('$k') ?? (int.tryParse('${(v as Map?)?['type_id'] ?? 0}') ?? 0);
            if (v is Map) {
              final name = (v['type_name'] ?? v['name'] ?? '').toString().trim();
              if (id > 0 && name.isNotEmpty) {
                mapped.add({
                  'type_id': id,
                  'type_name': name,
                  'enabled': (v['enabled'] ?? v['is_enabled'] ?? v['status'] ?? v['type_status'] ?? v['is_open'] ?? 1),
                });
              }
            } else {
              final name = '$v'.toString().trim();
              if (id > 0 && name.isNotEmpty) {
                mapped.add({'type_id': id, 'type_name': name, 'enabled': 1});
              }
            }
          });
          raw = mapped;
        }
        
        if (raw is List) {
          return raw.whereType<Map>().map((m) {
            final dynamic enabledRaw = m['enabled'] ?? m['is_enabled'] ?? m['status'] ?? m['type_status'] ?? m['is_open'];
            final bool enabled = enabledRaw == null
                ? true
                : (enabledRaw is bool ? enabledRaw : (int.tryParse('$enabledRaw') ?? 0) == 1);
            return {
              'type_id': m['type_id'],
              'type_name': (m['type_name'] ?? '').toString().trim(),
              'enabled': enabled,
            };
          }).toList();
        }
      }
    } catch (_) {}
    return const [];
  }

  /// 灏?APP 鍒濆鍖栨暟鎹繚瀛樺埌纾佺洏锛圫haredPreferences锛?  /// 璇存槑锛氶伩鍏嶆瘡娆¤繘鍏?App 閮界櫧灞忓姞杞斤紝鎻愬崌棣栧睆閫熷害
  Future<void> _saveInitDataToDisk(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_init_json', jsonEncode(data));
      await prefs.setInt('app_init_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// 浠庣鐩樿鍙?APP 鍒濆鍖栨暟鎹?  /// 杩斿洖锛歿 'data': Map<String,dynamic>, 'ts': int } 鎴?null
  Future<Map<String, dynamic>?> _loadInitDataFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('app_init_json');
      final ts = prefs.getInt('app_init_ts') ?? 0;
      if (raw == null || raw.isEmpty) return null;
      final Map<String, dynamic> data = jsonDecode(raw);
      if (data.isEmpty) return null;
      // 濡傛灉缂撳瓨鏃堕棿瓒呰繃 12 灏忔椂锛屼粛鐒跺彲浠ョ敤锛屼絾浼氳Е鍙戝悗鍙板埛鏂?      return {'data': data, 'ts': ts};
    } catch (_) {
      return null;
    }
  }

  /// 鍚庡彴鍒锋柊 APP 鍒濆鍖栨暟鎹紙鏃犳劅鐭ワ級锛岀敤浜庢洿鏂扮鐩樼紦瀛?  Future<void> _refreshAppInitInBackground() async {
    try {
      final latest = await getAppInit(force: true);
      await _saveInitDataToDisk(latest);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getVodWeekList({required int week, int page = 1}) async {
    await init();
    try {
      final resp = await _dio.get(
        'jgappapi.index/vodWeekList',
        queryParameters: {
          'week': week,
          'page': page,
        },
      );
      if (resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        final list = (data?['week_list'] as List?) ?? const [];
        return list.whereType<Map>().map((v) {
          final dynamic rawTypeId = v['type_id'] ?? v['type_id_1'] ?? v['type'];
          final int parsedTypeId = int.tryParse('$rawTypeId') ?? 0;
          return {
            'id': '${v['vod_id']}',
            'title': v['vod_name'] ?? '',
            'poster': _fixUrl(v['vod_pic']),
            'type_id': parsedTypeId,
            'type': v['type_name'] ?? '',
            'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
            'year': '${v['vod_year'] ?? ''}',
            'overview': v['vod_remarks'] ?? '',
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getTopicList({int page = 1}) async {
    await init();
    try {
      final resp = await _dio.get(
        'jgappapi.index/topicList',
        queryParameters: {'page': page},
      );
      if (resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        final list = (data?['topic_list'] as List?) ?? const [];
        return list.whereType<Map>().map((t) {
          return {
            'id': int.tryParse('${t['topic_id'] ?? 0}') ?? 0,
            'title': (t['topic_name'] ?? '').toString(),
            'poster': _fixUrl(t['topic_pic']),
            'overview': (t['topic_blurb'] ?? '').toString(),
            'vod_names': (t['topic_vod_names'] ?? '').toString(),
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getTopicVodList({required int topicId, int page = 1}) async {
    await init();
    try {
      final resp = await _dio.get(
        'jgappapi.index/topicVodList',
        queryParameters: {
          'topic_id': topicId,
          'page': page,
        },
      );
      if (resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        final list = (data?['topic_vod_list'] as List?) ?? const [];
        return list.whereType<Map>().map((v) {
          final dynamic rawTypeId = v['type_id'] ?? v['type_id_1'] ?? v['type'];
          final int parsedTypeId = int.tryParse('$rawTypeId') ?? 0;
          return {
            'id': '${v['vod_id']}',
            'title': v['vod_name'] ?? '',
            'poster': _fixUrl(v['vod_pic']),
            'type_id': parsedTypeId,
            'type': v['type_name'] ?? '',
            'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
            'year': '${v['vod_year'] ?? ''}',
            'overview': v['vod_remarks'] ?? '',
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getStandardTypeList() async {
    return _fetchStandardTypeList();
  }

  Future<List<Map<String, dynamic>>> _fetchStandardTypeList() async {
    final list = <Map<String, dynamic>>[];
    // 1) 鏍囧噯 provide/vod/ 鎺ュ彛
    try {
      final resp = await _dio.get('provide/vod/', queryParameters: {
        'ac': 'list',
        'pg': 1,
        'pagesize': 1,
        'at': 'json',
      });
      final raw = resp.data;
      final cls = (raw is Map) ? raw['class'] : null;
      if (cls is List) {
        for (final it in cls) {
          if (it is! Map) continue;
          final id = int.tryParse('${it['type_id'] ?? it['typeid'] ?? it['id'] ?? it['type']}') ?? 0;
          final pid = int.tryParse('${it['type_pid'] ?? it['parent_id'] ?? 0}') ?? 0;
          final name = (it['type_name'] ?? it['typename'] ?? it['name'] ?? '').toString().trim();
          if (id > 0 && name.isNotEmpty) {
            list.add({'type_id': id, 'type_name': name, 'type_pid': pid});
          }
        }
      }
    } catch (_) {}
    if (list.isNotEmpty) return list;
    // 2) MacCMS API: type/get_list (杩斿洖 rows 鍒楄〃)
    try {
      final resp = await _dio.get('type/get_list', queryParameters: {'type_pid': 0});
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
        final info = (resp.data['info'] as Map?) ?? const {};
        final rows = (info['rows'] as List?) ?? const [];
        for (final it in rows) {
          if (it is! Map) continue;
          final id = int.tryParse('${it['type_id'] ?? it['id'] ?? it['type']}') ?? 0;
          final name = (it['type_name'] ?? it['name'] ?? '').toString().trim();
          if (id > 0 && name.isNotEmpty) {
            list.add({'type_id': id, 'type_name': name, 'type_pid': 0});
          }
        }
      }
    } catch (_) {}
    if (list.isNotEmpty) return list;
    // 3) MacCMS API: type/get_all_list (杩斿洖 rows 鍙兘涓哄垪琛ㄦ垨鏄犲皠)
    try {
      final resp = await _dio.get('type/get_all_list');
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
        final info = (resp.data['info'] as Map?) ?? const {};
        final rows = info['rows'];
        if (rows is List) {
          for (final it in rows) {
            if (it is! Map) continue;
            final id = int.tryParse('${it['type_id'] ?? it['id'] ?? it['type']}') ?? 0;
            final name = (it['type_name'] ?? it['name'] ?? '').toString().trim();
            if (id > 0 && name.isNotEmpty) {
              list.add({'type_id': id, 'type_name': name, 'type_pid': 0});
            }
          }
        } else if (rows is Map) {
          rows.forEach((k, v) {
            final id = int.tryParse('$k') ?? 0;
            String name = '';
            if (v is Map) {
              name = (v['type_name'] ?? v['name'] ?? '').toString().trim();
            } else {
              name = '$v'.toString().trim();
            }
            if (id > 0 && name.isNotEmpty) {
              list.add({'type_id': id, 'type_name': name, 'type_pid': 0});
            }
          });
        }
      }
    } catch (_) {}
    return list;
  }

  /// 鍐呴儴杈呭姪锛氫娇鐢ㄦ爣鍑嗘帴鍙ｈ幏鍙栧垪琛?  Future<List<Map<String, dynamic>>> _fetchStandardList({int? typeId, int page = 1, int limit = 20, String by = 'time'}) async {
    try {
      final params = <String, dynamic>{
        'ac': 'detail', // 浣跨敤 detail 鑾峰彇鏇村叏淇℃伅
        'pg': page,
        'pagesize': limit,
        'at': 'json',
        'by': by,
      };
      if (typeId != null) params['t'] = typeId;
      
      final resp = await _dio.get('provide/vod/', queryParameters: params);
      final list = (resp.data?['list'] as List?) ?? [];
      return list.map((v) {
        final dynamic rawTypeId = v['type_id'] ?? v['type_id_1'] ?? v['type'];
        final int parsedTypeId = int.tryParse('$rawTypeId') ?? 0;
        return {
          'id': '${v['vod_id']}',
          'title': v['vod_name'] ?? '',
          'poster': _fixUrl(v['vod_pic']),
          'type': v['type_name'] ?? '',
          'type_id': parsedTypeId,
          'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
          'year': '${v['vod_year'] ?? ''}',
          'overview': v['vod_remarks'] ?? '',
          'remarks': v['vod_remarks'] ?? '', // 鏂板瀛楁
          'blurb': v['vod_blurb'] ?? v['vod_content'] ?? '', // 鏂板瀛楁
          'area': v['vod_area'] ?? '',
          'lang': v['vod_lang'] ?? '',
          'class': v['type_name'] ?? v['vod_class'] ?? '',
          'actor': v['vod_actor'] ?? '',
          'play_url': v['vod_play_url'] ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 鑾峰彇鎸囧畾鎺ㄨ崘绛夌骇鐨勮棰?(level=1~9)
  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳幏鍙栧悗鍙拌缃簡鎺ㄨ崘绛夌骇鐨勮棰?  Future<List<Map<String, dynamic>>> getRecommended({required int level, int limit = 6}) async {
    await init();
    try {
      // 0. 浼樺厛灏濊瘯 JgApp 鎻掍欢鐨?vodLevel 鎺ュ彛 (閮ㄥ垎鎻掍欢鏀寔)
      try {
        final resp = await _dio.get('jgappapi.index/vodLevel', queryParameters: {
          'level': level,
          'page': 1,
          'limit': limit,
        });
        if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
           final list = (resp.data['data']['list'] as List?) ?? [];
           if (list.isNotEmpty) {
             return list.map((v) => {
               'id': '${v['vod_id']}',
               'title': v['vod_name'] ?? '',
               'poster': _fixUrl(v['vod_pic']),
               'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
               'year': '${v['vod_year'] ?? ''}',
               'overview': v['vod_remarks'] ?? '',
             }).toList();
           }
        }
      } catch (_) {}

      // 1. 灏濊瘯 app_api.php (鑷畾涔夋帴鍙ｉ€氬父鏀寔鏇村ソ)
      final customApiUrl = '${rootUrl}app_api.php';
      try {
        final resp = await _dio.get(customApiUrl, queryParameters: {
          'ac': 'list',
          'level': level,
          'pagesize': limit,
          'at': 'json',
        });
        if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
           final list = (resp.data['list'] as List?) ?? [];
           return list.map((v) => {
             'id': '${v['vod_id']}',
             'title': v['vod_name'] ?? '',
             'poster': _fixUrl(v['vod_pic']),
             'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
             'year': '${v['vod_year'] ?? ''}',
             'overview': v['vod_remarks'] ?? '',
           }).toList();
        }
      } catch (_) {}

      // 2. 鎻掍欢鍏滃簳锛氱Щ闄よ嚜鍔ㄥ厹搴曢€昏緫
      // 寮€鍙戣€咃細鏉板摜
      // 鍘熷洜锛氶椤垫湁涓撻棬鐨勫厹搴曢€昏緫锛堥檺鍒舵暟閲忥級锛岃繖閲屽鏋滆嚜鍔ㄥ～鍏呬細瀵艰嚧棣栭〉璇垽涓衡€滃凡閰嶇疆鎺ㄨ崘鈥濊€屾樉绀鸿繃澶氭暟鎹€?      // 濡傛灉鍚庡彴娌￠厤缃?level 鎺ㄨ崘锛屽氨搴旇杩斿洖绌恒€?      /*
      try {
        final hot = await getFiltered(orderby: 'hits', limit: limit);
        if (hot.isNotEmpty) return hot;
        final good = await getFiltered(orderby: 'score', limit: limit);
        if (good.isNotEmpty) return good;
      } catch (_) {}
      */

      // 3. 灏濊瘯鏍囧噯鎺ュ彛 (provide/vod/) - 宸茬Щ闄?      // 寮€鍙戣€咃細鏉板摜
      // 鍘熷洜锛氱敤鎴锋槑纭姹備粎閫氳繃鎻掍欢鍚庡彴鑾峰彇鏁版嵁锛屼笉闇€瑕佸紑鍚?CMS 寮€鏀?API銆?      // 濡傛灉鎻掍欢閰嶇疆姝ｇ‘锛屾暟鎹簲鍖呭惈鍦?init 鎺ュ彛鐨?recommend_list 涓紝鎴栭€氳繃 jgappapi 鑾峰彇銆?      /*
      try {
        final resp = await _dio.get('provide/vod/', queryParameters: {
          'ac': 'detail', // 浣跨敤 detail 鑾峰彇鍥剧墖鍜?vod_level
          'level': level,
          'pagesize': limit,
          'at': 'json',
        });
        // ...
      } catch (_) {}
      */

      return [];
    } catch (_) {
      return [];
    }
  }


  /// 瑙ｆ瀽鐑悳璇嶏紙鏀寔鏁扮粍鎴栭€楀彿鍒嗛殧瀛楃涓诧級
  List<String> _parseHotSearch(Map data) {
    dynamic raw = data['hot_search_list'] ?? data['search_hot'];
    if (raw == null) return [];
    
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    
    if (raw is String) {
      return raw.split(',').where((e) => e.trim().isNotEmpty).toList();
    }
    
    return [];
  }

  /// 鑾峰彇鐑悳鍏抽敭璇?  Future<List<String>> getHotKeywords() async {
    // 1. 灏濊瘯浠?AppInit 鑾峰彇 (鍚庡彴閰嶇疆鐨勬悳绱㈢儹璇?
    final data = await getAppInit();
    if (data.isNotEmpty && data['hot_search_list'] != null) {
       final list = (data['hot_search_list'] as List);
       if (list.isNotEmpty) {
         return list.map((e) => e.toString()).toList();
       }
    }

    // 2. 濡傛灉鍚庡彴娌￠厤缃儹璇嶏紝鍒欒嚜鍔ㄨ幏鍙栤€滃懆鐑挱鈥濆墠10鍚嶇殑鏍囬浣滀负鐑悳
    try {
      final hotVideos = await getHot(page: 1);
      if (hotVideos.isNotEmpty) {
        return hotVideos.take(10).map((v) => v['title'].toString()).toList();
      }
    } catch (_) {}

    // 3. 鏈€鍚庣殑鍏滃簳
    return ['绻佽姳', '搴嗕綑骞?, '鏂楃牬鑻嶇┕', '闆腑鎮嶅垁琛?, '瀹岀編涓栫晫', '鍚炲櫖鏄熺┖'];
  }

  /// 鎼滅储瑙嗛锛氬皬鐧界悊瑙ｄ负鈥滄寜鍚嶅瓧鎼溾€?  Future<List<Map<String, dynamic>>> searchByName(String keyword) async {
    // 浼樺厛鏌ョ紦瀛橈紝鎻愬崌閫熷害
    if (_searchCache.containsKey(keyword)) {
      return _searchCache[keyword]!;
    }

    await init();

    // 0. 浼樺厛灏濊瘯 JgApp 鎻掍欢鎼滅储鎺ュ彛 (jgappapi.index/searchList)
    try {
      final resp = await _dio.get('jgappapi.index/searchList', queryParameters: {
        'keywords': keyword,
        'page': 1,
      });
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
         final list = (resp.data['data']['search_list'] as List?) ?? [];
         final results = list.map((v) {
            return {
              'id': '${v['vod_id']}',
              'title': v['vod_name'] ?? '',
              'poster': _fixUrl(v['vod_pic']),
              'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
              'year': '${v['vod_year'] ?? ''}',
              'overview': v['vod_remarks'] ?? v['vod_blurb'] ?? '',
              'area': v['vod_area'] ?? '',
              'lang': v['vod_lang'] ?? '',
              'class': v['type_name'] ?? v['vod_class'] ?? '',
              'actor': v['vod_actor'] ?? '',
            };
         }).toList();
         
         if (results.isNotEmpty) {
           _searchCache[keyword] = results;
           return results;
         }
      }
    } catch (_) {}

    // 1. 降级：使用 MacCMS 标准搜索接口 (ac=videolist)
    try {
      final resp = await _dio.get('provide/vod/', queryParameters: {
        'ac': 'videolist',
        'wd': keyword,
        'pagesize': 20,
        'at': 'json',
      });
      if (resp.statusCode == 200 && resp.data is Map) {
        final rows = (resp.data['list'] as List?) ?? [];
        if (rows.isNotEmpty) {
          final results = rows.map((v) => {
            'id': '${v['vod_id'] ?? v['id'] ?? 0}',
            'title': v['vod_name'] ?? v['title'] ?? '',
            'poster': _fixUrl(v['vod_pic'] ?? v['poster'] ?? v['pic']),
            'score': double.tryParse('${v['vod_score'] ?? v['score'] ?? 0}') ?? 0.0,
            'year': '${v['vod_year'] ?? v['year'] ?? ''}',
            'overview': v['vod_content'] ?? v['vod_blurb'] ?? v['vod_remarks'] ?? v['overview'] ?? v['blurb'] ?? '',
            'area': v['vod_area'] ?? v['area'] ?? '',
            'lang': v['vod_lang'] ?? v['lang'] ?? '',
            'class': v['type_name'] ?? v['vod_class'] ?? v['class'] ?? '',
            'actor': v['vod_actor'] ?? v['actor'] ?? '',
          }).toList();
          _searchCache[keyword] = results;
          return results;
        }
      }
    } catch (_) {
      // 忽略错误
    }

    // 2. 最终降级：返回空列表
    return [];
  }

  /// 鑾峰彇璇︽儏涓庢挱鏀惧垪琛?  Future<Map<String, dynamic>?> getDetail(String id) async {
    await init();
    
    // 1. 灏濊瘯 JgApp 鎻掍欢鎺ュ彛 (jgappapi.index/vodDetail)
    try {
      final resp = await _dio.get('jgappapi.index/vodDetail', queryParameters: {'vod_id': id});
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
         dynamic data = resp.data['data'];
         
         // 灏濊瘯瑙ｅ瘑
         if (data is String) {
            try {
              final raw = data.trim();
              // 灏濊瘯 Base64 瑙ｇ爜
              try {
                data = jsonDecode(utf8.decode(base64Decode(raw)));
              } catch (_) {
                // 濡傛灉涓嶆槸 Base64锛屽彲鑳芥槸鏅€?JSON 瀛楃涓?                data = jsonDecode(raw);
              }
            } catch (_) {}
         }

         // 濡傛灉 data 鏄?Map锛岃鏄庢槸鏄庢枃鎴栬В瀵嗘垚鍔燂紝鐩存帴浣跨敤
         if (data is Map) {
           final info = data['vod'];
           final playList = (data['vod_play_list'] as List).map((p) {
              final pi = (p['player_info'] as Map?) ?? const {};
              final show = (pi['app_name'] ?? pi['app_show'] ?? pi['appName'] ?? pi['show'] ?? '鎾斁婧?).toString();
              return {
                'show': show,
                'urls': (p['urls'] as List).map((u) => {
                  'name': u['name'] ?? '姝ｇ墖',
                  'url': u['url'] ?? '',
                  'parse_api': u['parse_api_url'] ?? '',
                }).toList(),
              };
           }).toList();
           
           List<Map<String, dynamic>> finalPlayList = [];
           for(var source in playList) {
              List<Map<String, dynamic>> eps = [];
              final srcUrls = (source['urls'] as List?) ?? const [];
              for(var ep in srcUrls) {
                 eps.add({
                    'name': ep['name'], 
                    'url': _fixUrl(ep['url']),
                    'parse_api': ep['parse_api'] // 淇锛氫繚鐣欒В鏋愭帴鍙ｅ瓧娈?                 });
              }
              finalPlayList.add({'show': source['show'], 'urls': eps});
           }

           return {
             'id': '${info['vod_id']}',
             'title': info['vod_name'] ?? '',
             'poster': _fixUrl(info['vod_pic']),
             'score': double.tryParse('${info['vod_score'] ?? 0}') ?? 0.0,
             'year': '${info['vod_year'] ?? ''}',
             'type_id': int.tryParse('${info['type_id'] ?? 0}') ?? 0,
             'area': info['vod_area'] ?? '',
             'class': info['vod_class'] ?? info['type_name'] ?? '',
             'director': info['vod_director'] ?? '',
             'actor': info['vod_actor'] ?? '',
             'overview': info['vod_blurb'] ?? info['vod_remarks'] ?? info['vod_content'] ?? '',
             'play_list': finalPlayList,
             'official_comment': data['official_comment'],
             // 鍏煎鏃у瓧娈碉紙淇濇寔鍘熻鎯呴〉UI锛?             'vod_name': info['vod_name'] ?? '',
             'vod_pic': _fixUrl(info['vod_pic']),
             'vod_year': '${info['vod_year'] ?? ''}',
             'vod_area': info['vod_area'] ?? '',
             'type_name': info['type_name'] ?? (info['vod_class'] ?? ''),
             'vod_actor': info['vod_actor'] ?? '',
             'vod_content': info['vod_content'] ?? (info['vod_blurb'] ?? info['vod_remarks'] ?? ''),
             'vod_play_list': finalPlayList,
             // ... 骞垮憡瀛楁鐪佺暐锛岄槻姝㈣В鏋愰敊璇?...
           };
         }
      }
    } catch (_) {}

    // 2. 灏濊瘯 app_api.php (鏄庢枃鎺ュ彛锛屽彲鑳藉寘鍚挱鏀炬簮鍚嶇О)
    final customApiUrl = '${rootUrl}app_api.php';
    try {
      final resp = await _dio.get(customApiUrl, queryParameters: {
        'ac': 'detail',
        'ids': id,
      });
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
         final info = resp.data['list'][0];
         // 瑙ｆ瀽 app_api.php 杩斿洖鐨勬挱鏀惧垪琛?         // 缁撴瀯鍙兘涓庢爣鍑?API 绫讳技锛屼篃鍙兘涓嶅悓锛岃繖閲屽皾璇曢€氱敤瑙ｆ瀽
         final playList = <Map<String, dynamic>>[];
         // ... (瑙ｆ瀽閫昏緫鍚屾爣鍑咥PI锛屼絾鍙兘鍖呭惈 'player_info'?)
         // 鏆傛椂璺宠繃锛岀洿鎺ョ敤鏍囧噯API瑙ｆ瀽锛屼絾鍔犱笂鏄犲皠
      }
    } catch (_) {}

    // 鎻掍欢涓庤嚜瀹氫箟鎺ュ彛鍧囦笉鍙敤
    return null;
  }

  /// 瑙ｆ瀽鎾斁閾炬帴锛堟敮鎸?JgApp 鎻掍欢杩斿洖鐨勮В鏋愭帴鍙ｏ級
  /// by锛氭澃鍝?qq锛?2711793818
  /// - 鍙傛暟锛?  ///   - url: 鍘熷鎾斁鍦板潃锛堝彲鑳戒负鐩撮摼鎴栭渶瑕佽В鏋愶級
  ///   - parseApi: 瑙ｆ瀽鎺ュ彛瀹屾暣鍦板潃锛堝鎻掍欢杩斿洖鐨?`parse_api_url`锛?  /// - 杩斿洖锛氭渶缁堝彲鎾斁鐨勭洿閾撅紙m3u8/mp4/http锛?  Future<String> resolvePlayUrl(String url, {String? parseApi}) async {
    await init();
    // 濡傛灉娌℃湁瑙ｆ瀽鎺ュ彛锛岀洿鎺ヨ繑鍥炰慨姝ｅ悗鐨勭洿閾?    if (parseApi == null || parseApi.isEmpty) {
      return _fixUrl(url);
    }

    try {
      // 缁熶竴瑙ｆ瀽鎺ュ彛浼犲弬瑙勫垯锛?      // 1) 濡傛灉鍖呭惈鍗犱綅绗?{url}锛屾浛鎹负缂栫爜鍚庣殑鍘熷鍦板潃
      // 2) 濡傛灉涓嶅惈鍗犱綅绗︼紝鑷姩琛ュ厖 ?url=encoded 鎴?&url=encoded
      // 3) 鑻ヤ负 jgappapi.index/vodParse 褰㈠紡锛屽己鍒朵娇鐢?queryParameters 浼犲弬
      String requestUrl = parseApi;
      final encoded = Uri.encodeComponent(url);
      if (requestUrl.contains('{url}')) {
        requestUrl = requestUrl.replaceAll('{url}', encoded);
      } else if (requestUrl.contains('jgappapi.index/vodParse')) {
        // 浣跨敤 queryParameters 浼犻€?url
        final resp = await _dio.get(requestUrl, queryParameters: {'url': url}, options: Options(responseType: ResponseType.json));
        return _extractFinalUrl(resp.data) ?? _fixUrl(url);
      } else {
        if (requestUrl.contains('?')) {
          if (!RegExp('(?:^|[?&])url=').hasMatch(requestUrl)) {
            requestUrl = '$requestUrl&url=$encoded';
          }
        } else {
          requestUrl = '$requestUrl?url=$encoded';
        }
      }

      final resp = await _dio.get(requestUrl, options: Options(responseType: ResponseType.json));

      dynamic data = resp.data;
      // 鏈変簺瑙ｆ瀽杩斿洖瀛楃涓诧紝闇€瑕佸皾璇?JSON 瑙ｆ瀽
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          // 灏濊瘯浠庡瓧绗︿覆涓彁鍙?URL
          final match = RegExp("https?://[^\\s'\\\"<>]+").firstMatch(data);
          if (match != null) {
            return _fixUrl(match.group(0)!);
          }
        }
      }

      final finalUrl = _extractFinalUrl(data);
      if (finalUrl != null && finalUrl.isNotEmpty) {
        return _fixUrl(finalUrl);
      }
    } catch (e) {
      debugPrint('瑙ｆ瀽鎾斁閾炬帴澶辫触: $e');
    }
    // 鍏滃簳杩斿洖鍘熼摼鎺?    return _fixUrl(url);
  }

  /// 浠庤В鏋愬搷搴斾腑绋冲仴鎻愬彇鏈€缁堢洿閾?  /// by锛氭澃鍝?qq锛?2711793818
  /// - 鏀寔缁撴瀯锛?  ///   1) { url: '...' }
  ///   2) { play_url: '...' } / { real: '...' } / { m3u8: '...' } / { link: '...' }
  ///   3) { json: '{ \"url\": \"...\" }' }
  ///   4) 绾瓧绗︿覆涓彁鍙?http(s) 閾炬帴
  String? _extractFinalUrl(dynamic data) {
    if (data is Map) {
      for (final key in ['url', 'play_url', 'real', 'm3u8', 'link']) {
        final v = data[key];
        if (v is String && v.isNotEmpty) return v;
      }
      if (data['json'] is String) {
        try {
          final inner = jsonDecode(data['json']);
          if (inner is Map) {
            for (final key in ['url', 'play_url', 'real', 'm3u8', 'link']) {
              final v = inner[key];
              if (v is String && v.isNotEmpty) return v;
            }
          }
        } catch (_) {}
      }
    } else if (data is String) {
      final match = RegExp("https?://[^\\s'\\\"<>]+").firstMatch(data);
      if (match != null) return match.group(0);
    }
    return null;
  }

  String _mapSourceCodeToName(String code) {
    final c = code.toLowerCase().trim();
    // 绮剧‘鏄犲皠
    const exact = {
      'kkm3u8': '澶稿厠璧勬簮',
      'kkyun': '澶稿厠浜?,
      'quark': '澶稿厠璧勬簮',
      'lzm3u8': '閲忓瓙璧勬簮',
      'lzyun': '閲忓瓙浜?,
      'liangzi': '閲忓瓙璧勬簮',
      'ffm3u8': '闈炲嚒璧勬簮',
      'ffyun': '闈炲嚒浜?,
      'feifan': '闈炲嚒璧勬簮',
      'xgm3u8': '瑗跨摐璧勬簮',
      'xigua': '瑗跨摐璧勬簮',
      'wjm3u8': '鏃犲敖璧勬簮',
      'wuji': '鏃犲敖璧勬簮',
      'tkm3u8': '澶╃┖璧勬簮',
      'tiankong': '澶╃┖璧勬簮',
      'dbm3u8': '鐧惧害璧勬簮',
      'baidu': '鐧惧害璧勬簮',
      'bjm3u8': '鍏垝璧勬簮',
      'bajie': '鍏垝璧勬簮',
      'xlm3u8': '鏂版氮璧勬簮',
      'xinlang': '鏂版氮璧勬簮',
      'hhm3u8': '璞崕璧勬簮',
      'snm3u8': '绱㈠凹璧勬簮',
      'hnm3u8': '绾㈢墰璧勬簮',
    };
    if (exact.containsKey(c)) return exact[c]!;
    // 妯＄硦鍖归厤
    if (c.contains('liang') || c.contains('lz')) return '閲忓瓙璧勬簮';
    if (c.contains('feifan') || c.contains('ff')) return '闈炲嚒璧勬簮';
    if (c.contains('xigua') || c.contains('xg')) return '瑗跨摐璧勬簮';
    if (c.contains('quark') || c.contains('kk')) return '澶稿厠璧勬簮';
    if (c.contains('tiankong') || c.contains('tk')) return '澶╃┖璧勬簮';
    if (c.contains('wuji') || c.contains('wj')) return '鏃犲敖璧勬簮';
    if (c.contains('baidu') || c.contains('db')) return '鐧惧害璧勬簮';
    if (c.contains('bajie') || c.contains('bj')) return '鍏垝璧勬簮';
    if (c.contains('xinlang') || c.contains('xl')) return '鏂版氮璧勬簮';
    if (c.contains('m3u8')) return '楂樻竻璧勬簮';
    if (c.contains('yun')) return '浜戞挱璧勬簮';
    return code;
  }

  /**
   * 鑾峰彇绛涢€夐」锛氬勾浠?鍦板尯/绫诲瀷锛堜緷璧栧悗绔?get_year/get_area/get_class锛?   */
  Future<Map<String, List<String>>> getFacets({int typeId1 = 1}) async {
    // 鏆傛椂杩斿洖甯哥敤骞翠唤鍜屽湴鍖?    return {
      'years': ['2025','2024','2023','2022','2021','2020','2019','2018','2017'],
      'areas': ['澶ч檰','棣欐腐','鍙版咕','缇庡浗','闊╁浗','鏃ユ湰','娉板浗','鑻卞浗','娉曞浗'],
      'classes': ['鍔ㄤ綔','鍠滃墽','鐖辨儏','绉戝够','鎭愭€?,'鍓ф儏','鎴樹簤','绾綍'],
    };
  }

  final _LruCache<List<Map<String, dynamic>>> _categoryCache = _LruCache(
    capacity: 200,
    ttl: const Duration(minutes: 30),
  );

  /// 鏍规嵁绛涢€夐」鑾峰彇鍒楄〃锛堟敮鎸?app_api.php 楂樼骇绛涢€夛級
  Future<List<Map<String, dynamic>>> getFiltered({
    int? typeId,
    String? year,
    String? area,
    String? lang,
    String? clazz,
    String orderby = 'time', // 榛樿鎸夋椂闂?    int page = 1,
    int limit = 20,
  }) async {
    await init();
    // 鏋勫缓缂撳瓨閿?    final cacheKey = '$typeId-$year-$area-$lang-$clazz-$orderby-$page';
    final cached = _categoryCache.get(cacheKey);
    if (cached != null) return cached;

    await detectInterfaces();

    // 1. 灏濊瘯 JgApp 鎻掍欢鎺ュ彛 (jgappapi.index/typeFilterVodList)
    // 鏀寔楂樼骇绛涢€夛細class, area, lang, year, sort
    try {
       // 濡傛灉鏍囧噯鎺ュ彛宸插叧闂紙closed锛夛紝鍒欏繀椤讳緷璧栨彃浠?       // if (_pluginFilterOk == false) { throw Exception('plugin disabled'); }
       
       // 杞崲鎺掑簭鍙傛暟涓轰腑鏂囨爣璇嗭紝鍖归厤 JgApp 鎻掍欢鐨?switch case
       String sortParam = '鏈€鏂?; // 榛樿鏈€鏂?       if (orderby == 'hits' || orderby == '鏈€鐑?) sortParam = '鏈€鐑?;
       else if (orderby == 'score' || orderby == '鏈€璧?) sortParam = '鏈€璧?;
       else if (orderby.contains('hits_day')) sortParam = '鏃ユ';
       else if (orderby.contains('hits_week')) sortParam = '鍛ㄦ';
       else if (orderby.contains('hits_month')) sortParam = '鏈堟';
       
       final params = {
         'page': page,
         'limit': limit,
         'pagesize': limit,
         'sort': sortParam,
       };
       
       if (typeId != null) params['type_id'] = typeId;
       if (year != null && year != '鍏ㄩ儴') params['year'] = year;
       if (area != null && area != '鍏ㄩ儴') params['area'] = area;
       if (lang != null && lang != '鍏ㄩ儴') params['lang'] = lang;
       if (clazz != null && clazz != '鍏ㄩ儴') params['class'] = clazz;
       
       // print('Filter Request: jgappapi.index/typeFilterVodList params=$params');
       
       final resp = await _dio.get('jgappapi.index/typeFilterVodList', queryParameters: params);
       if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
          dynamic data = resp.data['data'];
          // 鍏煎锛氬鏋?data 鏄?Base64 瀛楃涓诧紝鍏堣В鐮佸緱鍒?JSON
          if (data is String) {
            try {
              final decodedStr = utf8.decode(base64Decode(data));
              data = jsonDecode(decodedStr);
            } catch (_) {
              data = {};
            }
          }
          if (data is Map) {
            final rawList = (data['recommend_list'] as List?)
                ?? (data['vod_list'] as List?)
                ?? (data['list'] as List?)
                ?? [];
            final results = rawList.map((v) {
              final dynamic rawTypeId = v['type_id'] ?? v['type_id_1'] ?? v['type'];
              final int parsedTypeId = int.tryParse('$rawTypeId') ?? 0;
              return {
                'id': '${v['vod_id']}',
                'title': v['vod_name'] ?? '',
                'poster': _fixUrl(v['vod_pic']),
                'type_id': parsedTypeId,
                'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
                'year': '${v['vod_year'] ?? ''}',
                'overview': v['vod_remarks'] ?? '',
                'remarks': v['vod_remarks'] ?? '', // 鏂板瀛楁
                'blurb': v['vod_blurb'] ?? v['vod_content'] ?? '', // 鏂板瀛楁
                'area': v['vod_area'] ?? '',
                'lang': v['vod_lang'] ?? '',
                'class': v['type_name'] ?? v['vod_class'] ?? '',
                'actor': v['vod_actor'] ?? '',
                'play_url': v['vod_play_url'] ?? '',
              };
            }).toList();
            
            if (results.isNotEmpty) {
              _categoryCache.set(cacheKey, results);
              return results;
            }
          }
       }
    } catch (_) {}

    // 2. 浼樺厛浣跨敤 app_api.php 鐨勯珮绾х瓫閫夋帴鍙?    final customApiUrl = '${rootUrl}app_api.php';
    try {
       if (_customApiOk == false) { throw Exception('custom disabled'); }
       final params = {
         'ac': 'list',
         'pg': page,
         'pagesize': limit,
         'by': orderby,
       };
       if (typeId != null) params['t'] = typeId;
       if (year != null && year != '鍏ㄩ儴') params['year'] = year;
       if (area != null && area != '鍏ㄩ儴') params['area'] = area;
       if (lang != null && lang != '鍏ㄩ儴') params['lang'] = lang;
       if (clazz != null && clazz != '鍏ㄩ儴') params['class'] = clazz;
       
       final resp = await _dio.get(customApiUrl, queryParameters: params);
       if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
          final list = (resp.data['list'] as List?) ?? [];
          final results = list.map((item) {
            final v = item as Map<String, dynamic>;
            final dynamic rawTypeId = v['type_id'] ?? v['type_id_1'] ?? v['type'];
            final int parsedTypeId = int.tryParse('$rawTypeId') ?? 0;
            return {
              'id': '${v['vod_id']}',
              'title': v['vod_name'] ?? '',
              'poster': _fixUrl(v['vod_pic']),
              'type_id': parsedTypeId,
              'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
              'year': '${v['vod_year'] ?? ''}',
              'overview': v['vod_remarks'] ?? '',
              'area': v['vod_area'] ?? '',
              'lang': v['vod_lang'] ?? '',
              'class': v['type_name'] ?? v['vod_class'] ?? '',
              'actor': v['vod_actor'] ?? '',
              'play_url': v['vod_play_url'] ?? '',
            };
          }).toList();
          
          if (results.isNotEmpty) {
            // 瀹㈡埛绔簩娆℃牎楠屽垎绫籌D
            final validated = _filterByTypeId(typeId, results);
            _categoryCache.set(cacheKey, validated);
            return validated;
          }
       }
    } catch (_) {
      // 蹇界暐閿欒锛岄檷绾у鐞?    }

    // 鍏滃簳锛氭棤璁烘槸鍚﹀甫鏈夐珮绾х瓫閫夊弬鏁帮紝鑻ュ墠涓や釜鎺ュ彛澶辫触鎴栨棤鏁版嵁锛?    // 浣跨敤鏍囧噯API杩斿洖鈥滃垎绫?鎺掑簭鈥濈殑鍒楄〃锛岄伩鍏嶅嚭鐜扮櫧鏉?    // 淇锛氬鏋滄爣鍑嗘帴鍙?closed锛屽垯涓嶅皾璇?    if (_standardApiOk != false) {
      final list = await _fetchStandardList(typeId: typeId, page: page, limit: limit, by: orderby);
      final validated = _filterByTypeId(typeId, list);
      if (validated.isNotEmpty) {
        _categoryCache.set(cacheKey, validated);
        return validated;
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _filterByTypeId(int? typeId, List<Map<String, dynamic>> items) {
    if (typeId == null) return items;
    final filtered = items.where((e) {
      final raw = e['type_id'];
      final tid = int.tryParse('$raw') ?? 0;
      if (tid == 0) return true;
      return tid == typeId;
    }).toList();
    return filtered.isNotEmpty ? filtered : items;
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氬澶栨毚闇叉帴鍙ｅ仴搴风姸鎬侊紙缁欒皟璇曞叆鍙ｆ垨椤甸潰璇婃柇鐢級
  /// 瑙ｉ噴锛氬憡璇変綘鐜板湪鍚庣鍝嚑涓帴鍙ｈ兘鐢ㄣ€?  Future<Map<String, bool>> getInterfaceStatus() async {
    return await detectInterfaces(force: true);
  }

  /// 杩愯鐜鏍囪瘑锛氱敤浜庢挱鏀惧櫒閫夋嫨
  bool get isWeb => kIsWeb;

  // ================= 璇勮涓庡脊骞曠浉鍏?=================
  
  Future<List<Map<String, dynamic>>> getComments(String vodId) async {
    await init();
    
    // 1. 灏濊瘯 JgApp 鎻掍欢鎺ュ彛
    try {
       final resp = await _dio.get('jgappapi.index/commentList', queryParameters: {'vod_id': vodId});
       if (resp.data['code'] == 1) {
          final list = (resp.data['data']['comment_list'] as List);
          return list.map((c) => {
             'id': c['comment_id'],
             'name': c['user_name'] ?? '鍖垮悕',
             'content': c['comment_content'] ?? '',
             'time': c['time_str'] ?? '',
             'avatar': _fixUrl(c['user_avatar']),
             'is_top': (c['comment_top']?.toString() == '1' || c['is_top']?.toString() == '1'),
          }).toList();
       }
    } catch (_) {}

    final customApiUrl = '${rootUrl}app_api.php';
    try {
      final resp = await _dio.get(customApiUrl, queryParameters: {
        'ac': 'get_comments',
        'rid': vodId,
      });
      if (resp.data['code'] == 1) {
        final list = (resp.data['list'] as List);
        return list.map((c) {
           final m = c as Map<String, dynamic>;
           return {
             'id': m['id'] ?? m['comment_id'],
             'name': m['name'] ?? m['user_name'] ?? '鍖垮悕',
             'content': m['content'] ?? m['comment_content'] ?? '',
             'time': m['time'] ?? m['time_str'] ?? '',
             'avatar': _fixUrl(m['avatar'] ?? m['user_avatar']),
             'is_top': (m['is_top']?.toString() == '1' || m['top']?.toString() == '1'),
           };
        }).toList();
      }
    } catch (_) {}
    return [];
  }
  
  Future<List<Map<String, dynamic>>> getDanmakus(String vodId) async {
    await init();
    try {
       final resp = await _dio.get('jgappapi.index/danmuList', queryParameters: {'vod_id': vodId});
       if (resp.data['code'] == 1) {
          final list = (resp.data['data']['danmu_list'] as List);
          return list.map((d) => {
             'id': d['danmu_id'] ?? d['id'] ?? 0,
             'text': d['content'] ?? '',
             'color': d['color'] ?? '#FFFFFF',
             'time': d['time'] ?? 0,
          }).toList();
       }
    } catch (_) {}
    return [];
  }

  /// 寮€鍙戣€咃細鏉板摜缃戠粶绉戞妧 (qq: 2711793818)
  /// 浣滅敤锛氬彂閫佽瘎璁?  /// 杩斿洖锛歿'success': true, 'needAudit': false, 'msg': ''}
  Future<Map<String, dynamic>> sendComment(String vodId, String content, String nickname) async {
    await init();
    
    // 1. 灏濊瘯 JgApp 鎻掍欢鎺ュ彛
    try {
      final resp = await _dio.post('jgappapi.index/sendComment', data: {
        'vod_id': vodId,
        'comment': content,
      });
      if (resp.data['code'] == 1) {
         return {'success': true, 'needAudit': false, 'msg': '璇勮鍙戦€佹垚鍔?};
      }
      if (resp.data['code'] == 2) {
         return {'success': true, 'needAudit': true, 'msg': '璇勮宸叉彁浜わ紝瀹℃牳閫氳繃鍚庢樉绀?};
      }
      return {'success': false, 'needAudit': false, 'msg': resp.data['msg']?.toString() ?? '鍙戦€佸け璐?};
    } catch (_) {}

    // 2. 闄嶇骇锛歛pp_api.php
    final customApiUrl = '${rootUrl}app_api.php';
    try {
      final resp = await _dio.post(customApiUrl, queryParameters: {'ac': 'add_comment'}, data: {
        'rid': vodId,
        'content': content,
        'name': nickname,
      });
      if (resp.data['code'] == 1) {
         return {'success': true, 'needAudit': false, 'msg': '璇勮鍙戦€佹垚鍔?};
      }
      return {'success': false, 'needAudit': false, 'msg': resp.data['msg']?.toString() ?? '鍙戦€佸け璐?};
    } catch (_) {
      return {'success': false, 'needAudit': false, 'msg': '缃戠粶閿欒'};
    }
  }

  /// 寮€鍙戣€咃細鏉板摜缃戠粶绉戞妧 (qq: 2711793818)
  /// 浣滅敤锛氬彂閫佸脊骞?  /// 杩斿洖锛歿'success': true, 'needAudit': false, 'msg': ''}
  Future<Map<String, dynamic>> sendDanmaku(String vodId, String content, {String color = '#FFFFFF', int time = 0}) async {
    await init();
    try {
      final resp = await _dio.post('jgappapi.index/sendDanmu', data: {
        'vod_id': vodId,
        'danmu': content,
        'color': color,
        'time': time,
        'url_position': 0, // 榛樿绗竴涓挱鏀炬簮
      });
      if (resp.data['code'] == 1) {
         return {'success': true, 'needAudit': false, 'msg': '寮瑰箷鍙戦€佹垚鍔?};
      }
      if (resp.data['code'] == 2) {
         return {'success': true, 'needAudit': true, 'msg': '寮瑰箷宸叉彁浜わ紝瀹℃牳閫氳繃鍚庢樉绀?};
      }
      return {'success': false, 'needAudit': false, 'msg': resp.data['msg']?.toString() ?? '鍙戦€佸け璐?};
    } catch (_) {
      return {'success': false, 'needAudit': false, 'msg': '缃戠粶閿欒'};
    }
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氭彁浜ょ敤鎴峰弽棣堬紙jgapp 鎻掍欢 suggest 鎺ュ彛锛?  /// 瑙ｉ噴锛氭妸浣犻亣鍒扮殑闂鎴栧缓璁彂缁欏悗鍙般€?  Future<bool> sendSuggest(String content) async {
    await init();
    try {
      final resp = await _dio.post(
        'jgappapi.index/suggest',
        data: {
          'content': content,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: _headers,
        ),
      );
      return resp.statusCode == 200 &&
          resp.data is Map &&
          (resp.data['code'] == 1);
    } catch (_) {
      return false;
    }
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氭彁浜ゆ眰鐗囷紙jgapp 鎻掍欢 find 鎺ュ彛锛?  /// 瑙ｉ噴锛氭壘涓嶅埌鐨勭墖瀛愬湪杩欓噷鍛婅瘔鍚庡彴銆?  Future<bool> sendFind({required String name, String remark = ''}) async {
    await init();
    try {
      final resp = await _dio.post(
        'jgappapi.index/find',
        data: {
          'name': name,
          'remark': remark,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: _headers,
        ),
      );
      return resp.statusCode == 200 &&
          resp.data is Map &&
          (resp.data['code'] == 1);
    } catch (_) {
      return false;
    }
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氬崟涓奖鐗囧偓鏇达紙jgapp 鎻掍欢 requestUpdate 鎺ュ彛锛?  /// 瑙ｉ噴锛氬湪璇︽儏椤电偣鍑烩€滃偓鏇粹€濓紝鍛婅瘔鍚庡彴蹇偣鏇存柊杩欎竴閮ㄣ€?  Future<Map<String, dynamic>> requestUpdate(String vodId) async {
    await init();
    try {
      final resp = await _dio.get(
        'jgappapi.index/requestUpdate',
        queryParameters: {
          'vod_id': vodId,
        },
      );
      if (resp.statusCode == 200 && resp.data is Map) {
         final code = resp.data['code'];
         return {
           'success': code == 1 || code == '1',
           'msg': resp.data['msg']?.toString() ?? '鏈煡閿欒',
         };
      }
      return {'success': false, 'msg': '缃戠粶璇锋眰澶辫触: ${resp.statusCode}'};
    } catch (e) {
      return {'success': false, 'msg': '璇锋眰寮傚父: $e'};
    }
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳幏鍙栫郴缁熷叕鍛婂垪琛紙jgapp 鎻掍欢 noticeList 鎺ュ彛锛?  /// 瑙ｉ噴锛氭媺鍙栧悗鍙伴厤缃殑鍏憡锛岀敤浜庘€滄秷鎭腑蹇?鍏憡鈥濄€?  Future<List<Map<String, dynamic>>> getNoticeList({int page = 1}) async {
    await init();
    try {
      final resp = await _dio.get(
        'jgappapi.index/noticeList',
        queryParameters: {
          'page': page,
        },
      );
      if (resp.statusCode == 200 &&
          resp.data is Map &&
          (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        final list = (data?['notice_list'] as List?) ?? [];
        return list.map((e) {
          final m = e as Map<String, dynamic>;
          return {
            'id': m['id'],
            'title': m['title'] ?? '',
            'sub_title': m['sub_title'] ?? '',
            'create_time': m['create_time'] ?? '',
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳幏鍙栧崟鏉＄郴缁熷叕鍛婅鎯?  /// 瑙ｉ噴锛氱偣鍏憡鍒楄〃鐨勪竴鏉★紝灞曠ず瀹屾暣鍐呭銆?  Future<Map<String, dynamic>?> getNoticeDetail(int noticeId) async {
    await init();
    try {
      final resp = await _dio.get(
        'jgappapi.index/noticeDetail',
        queryParameters: {
          'notice_id': noticeId,
        },
      );
      if (resp.statusCode == 200 &&
          resp.data is Map &&
          (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        final notice = (data?['notice'] as Map?) ?? {};
        return {
          'id': notice['id'],
          'title': notice['title'] ?? '',
          'sub_title': notice['sub_title'] ?? '',
          'create_time': notice['create_time'] ?? '',
          'content': notice['content'] ?? '',
        };
      }
    } catch (_) {}
    return null;
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳幏鍙栦釜浜烘秷鎭粺璁★紙jgapp 鎻掍欢 userNoticeType锛?  /// 瑙ｉ噴锛氬悗鍙拌繑鍥炩€滃弽棣堟湭璇绘暟/姹傜墖鏈鏁扳€濓紝鐢ㄤ簬娑堟伅涓績绾㈢偣銆?  Future<Map<String, int>> getUserNoticeTypes() async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/userNoticeType');
      if (resp.statusCode == 200 &&
          resp.data is Map &&
          (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        return {
          'suggest_count': (data?['suggest_count'] ?? 0) as int,
          'find_count': (data?['find_count'] ?? 0) as int,
        };
      }
    } catch (_) {}
    return {
      'suggest_count': 0,
      'find_count': 0,
    };
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳幏鍙栦釜浜烘秷鎭垪琛紙jgapp 鎻掍欢 userNoticeList锛?  /// 瑙ｉ噴锛氭樉绀哄悗鍙伴拡瀵逛綘鐨勫弽棣?姹傜墖鐨勫洖澶嶈褰曘€?  Future<List<Map<String, dynamic>>> getUserNoticeList({
    required int type,
    int page = 1,
  }) async {
    await init();
    try {
      final resp = await _dio.get(
        'jgappapi.index/userNoticeList',
        queryParameters: {
          'page': page,
          'type': type,
        },
      );
      if (resp.statusCode == 200 &&
          resp.data is Map &&
          (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        final list = (data?['user_notice_list'] as List?) ?? [];
        return list.whereType<Map>().map((m) {
          return {
            'id': m['id'],
            'title': (m['title'] ?? '').toString(),
            'content': (m['content'] ?? '').toString(),
            'reply_content': (m['reply_content'] ?? '').toString(),
            'create_time': (m['create_time'] ?? '').toString(),
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳幏鍙栭個璇疯褰曟暟鎹紙jgapp 鎻掍欢 inviteLogs锛?  /// 瑙ｉ噴锛氭煡鐪嬩綘閫氳繃閭€璇风爜閭€璇蜂簡澶氬皯浜猴紝浠ュ強绉垎瑙勫垯璇存槑銆?  Future<Map<String, dynamic>> getInviteLogs({int page = 1}) async {
    await init();
    try {
      final resp = await _dio.get(
        'jgappapi.index/inviteLogs',
        queryParameters: {
          'page': page,
        },
      );
      if (resp.statusCode == 200 &&
          resp.data is Map &&
          (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        return {
          'invite_logs': (data?['invite_logs'] as List? ?? [])
              .cast<Map<String, dynamic>>(),
          'invite_count': data?['invite_count'] ?? 0,
          'intro': data?['intro'] ?? '',
        };
      }
    } catch (_) {}
    return {
      'invite_logs': <Map<String, dynamic>>[],
      'invite_count': 0,
      'intro': '',
    };
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳幏鍙栫Н鍒嗚褰曪紙jgapp 鎻掍欢 userPointsLogs锛?  /// 瑙ｉ噴锛氱湅鍒扮Н鍒嗙殑鑾峰緱涓庢秷璐硅褰曘€?  Future<Map<String, dynamic>> getUserPointsLogs({int page = 1}) async {
    await init();
    try {
      final resp = await _dio.get(
        'jgappapi.index/userPointsLogs',
        queryParameters: {
          'page': page,
        },
      );
      if (resp.statusCode == 200 &&
          resp.data is Map &&
          (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        return {
          'plogs':
              (data?['plogs'] as List? ?? []).cast<Map<String, dynamic>>(),
          'user_points': data?['user_points'] ?? 0,
          'intro': data?['intro'] ?? '',
          'remain_watch_times': data?['remain_watch_times'] ?? 0,
        };
      }
    } catch (_) {}
    return {
      'plogs': <Map<String, dynamic>>[],
      'user_points': 0,
      'intro': '',
      'remain_watch_times': 0,
    };
  }

  Future<Map<String, dynamic>?> getUserInfoSummary() async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/userInfo');
      if (resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        final user = (data?['user_info'] as Map?) ?? <String, dynamic>{};
        return {
          'user_name': user['user_nick_name'] ?? user['user_name'] ?? '鐢ㄦ埛',
          'group_name': user['group_name'] ?? '鏅€氫細鍛?,
          'user_points': int.tryParse('${user['user_points'] ?? 0}') ?? 0,
          'user_id': user['user_id'],
          'user_portrait': _fixUrl(user['user_portrait']),
        };
      }
    } catch (_) {}
    return null;
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳幏鍙栨垜鐨勯〉闈俊鎭紙jgapp 鎻掍欢 mineInfo锛?  /// 瑙ｉ噴锛氳幏鍙栫敤鎴峰熀鏈俊鎭拰鏈娑堟伅鏁伴噺锛岀敤浜庢垜鐨勯〉闈㈠睍绀恒€?  Future<Map<String, dynamic>?> getMineInfo() async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/mineInfo');
      if (resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        final user = (data?['user'] as Map?) ?? <String, dynamic>{};
        return {
          'user_info': user,
          'user_notice_unread_count': data?['user_notice_unread_count'] ?? 0,
          'user_name': user['user_nick_name'] ?? user['user_name'] ?? '鐢ㄦ埛',
          'user_points': int.tryParse('${user['user_points'] ?? 0}') ?? 0,
          'group_name': user['group_name'] ?? '鏅€氫細鍛?,
          'user_portrait': _fixUrl(user['user_portrait']),
          'is_vip': user['group_id'] != null && int.tryParse('${user['group_id']}') != 3, // 闈炴櫘閫氫細鍛樼粍鍗充负VIP
        };
      }
    } catch (_) {}
    return null;
  }


  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳幏鍙栫敤鎴锋秷鎭垪琛紙jgapp 鎻掍欢 userNoticeList锛?  /// 瑙ｉ噴锛氳幏鍙栫敤鎴风殑绯荤粺娑堟伅鍜岄€氱煡銆?  Future<List<Map<String, dynamic>>> getUserNotices({int page = 1, int limit = 20}) async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/userNoticeList', queryParameters: {
        'page': page,
        'limit': limit,
      });
      if (resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        final list = (data?['list'] as List? ?? []);
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳幏鍙栦細鍛樹腑蹇冩暟鎹紙jgapp 鎻掍欢 userVipCenter锛?  /// 瑙ｉ噴锛氬睍绀哄綋鍓嶄細鍛樼姸鎬佸拰鍙喘涔扮殑浼氬憳濂楅銆?  Future<Map<String, dynamic>?> getUserVipCenter() async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/userVipCenter');
      if (resp.statusCode == 200 &&
          resp.data is Map &&
          (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        return {
          'user': (data?['user'] as Map?) ?? <String, dynamic>{},
          'vip_group_list':
              (data?['vip_group_list'] as List? ?? []).cast<Map<String, dynamic>>(),
        };
      }
    } catch (_) {}
    return null;
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氭鏌ョ増鏈洿鏂帮紙jgapp 鎻掍欢 appUpdate/appUpdateV2锛?  /// 瑙ｉ噴锛氱偣鈥滄鏌ュ崌绾р€濇椂鍚戝悗鍙伴棶涓€涓嬫湁娌℃湁鏂扮増鏈€?  Future<Map<String, dynamic>?> getAppUpdate() async {
    await init();

    Map<String, dynamic>? normalize(Map raw) {
      return {
        'version_name': raw['version_name']?.toString() ?? '',
        'version_code': raw['version_code']?.toString() ?? '',
        'download_url': raw['download_url']?.toString() ?? '',
        'browser_download_url': raw['browser_download_url']?.toString() ?? '',
        'app_size': raw['app_size']?.toString() ?? '',
        'description': raw['description']?.toString() ?? '',
        'is_force': raw['is_force'] == true || raw['is_force'] == 1,
      };
    }

    try {
      final resp = await _dio.get(
        'jgappapi.index/appUpdateV2',
        options: Options(headers: _headers),
      );
      if (resp.statusCode == 200 &&
          resp.data is Map &&
          (resp.data['code'] == 1) &&
          resp.data['data'] is Map) {
        return normalize(resp.data['data'] as Map);
      }
    } catch (_) {}

    try {
      final resp = await _dio.get(
        'jgappapi.index/appUpdate',
        options: Options(headers: _headers),
      );
      if (resp.statusCode == 200 &&
          resp.data is Map &&
          (resp.data['code'] == 1)) {
        final data = resp.data['data'];
        if (data is Map && data['update'] is Map) {
          return normalize(data['update'] as Map);
        }
      }
    } catch (_) {}

    return null;
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳喘涔颁細鍛橈紙jgapp 鎻掍欢 userBuyVip锛?  /// 瑙ｉ噴锛氭牴鎹悗鍙伴厤缃殑濂楅鎵ｇН鍒嗗紑閫?VIP銆?  Future<Map<String, dynamic>> buyVip({required int index}) async {
    await init();
    try {
      final resp = await _dio.post(
        'jgappapi.index/userBuyVip',
        data: {
          'index': index,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: _headers,
        ),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return {
          'success': resp.data['code'] == 1,
          'msg': resp.data['msg'] ?? '',
          'user': (resp.data['data']?['user'] as Map?) ??
              <String, dynamic>{},
        };
      }
    } catch (_) {}
    return {
      'success': false,
      'msg': '璐拱澶辫触锛岃绋嶅悗閲嶈瘯',
      'user': <String, dynamic>{},
    };
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氫慨鏀瑰瘑鐮侊紙jgapp 鎻掍欢 modifyPassword锛?  Future<Map<String, dynamic>> modifyPassword(String oldPwd, String newPwd) async {
    await init();
    try {
      final resp = await _dio.post(
        'jgappapi.index/modifyPassword',
        data: {'password': oldPwd, 'new_password': newPwd},
        options: Options(contentType: Headers.formUrlEncodedContentType, headers: _headers),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
         return {'success': resp.data['code'] == 1, 'msg': resp.data['msg']};
      }
      return {'success': false, 'msg': '璇锋眰澶辫触'};
    } catch (e) {
      return {'success': false, 'msg': '$e'};
    }
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氫慨鏀规樀绉帮紙jgapp 鎻掍欢 modifyUserNickName锛?  Future<bool> modifyUserNickName(String nickname) async {
    await init();
    try {
      final resp = await _dio.post(
        'jgappapi.index/modifyUserNickName',
        data: {'user_nick_name': nickname},
        options: Options(contentType: Headers.formUrlEncodedContentType, headers: _headers),
      );
      if (resp.data['code'] == 1) {
        // 鏇存柊鏈湴缂撳瓨
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', nickname);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氫笂浼犲ご鍍忥紙jgapp 鎻掍欢 appAvatarUpload锛?  Future<Map<String, dynamic>> uploadAvatar(FormData formData) async {
    await init();
    try {
      final resp = await _dio.post(
        'jgappapi.index/appAvatarUpload',
        data: formData,
        options: Options(headers: _headers),
      );
      if (resp.data['code'] == 1) {
        return {'success': true, 'url': _fixUrl(resp.data['data']['user']['user_avatar'])};
      } else {
        return {'success': false, 'msg': resp.data['msg']};
      }
    } catch (e) {
      return {'success': false, 'msg': '$e'};
    }
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氳鐪嬫縺鍔辫棰戣幏鍙栧鍔憋紙jgapp 鎻掍欢 watchRewardAd锛?  Future<Map<String, dynamic>> watchRewardAd() async {
    await init();
    try {
      // 涓存椂鏂规锛氱洿鎺ヨ姹傦紝鏈熸湜鍚庣鏈夊瀹瑰鐞?      final resp = await _dio.post(
        'jgappapi.index/watchRewardAd',
        data: {'data': ''}, // 浼犵┖data
        options: Options(contentType: Headers.formUrlEncodedContentType, headers: _headers),
      );
      if (resp.data is Map && resp.data['code'] == 1) {
         return {'success': true, 'points': resp.data['data']['points'] ?? 0};
      }
      return {'success': false, 'msg': resp.data['msg'] ?? '闇€瑕佸鎴风閰嶇疆AES鍔犲瘑瀵嗛挜'};
    } catch (_) {
      return {'success': false, 'msg': '璇锋眰澶辫触'};
    }
  }
  
  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氫妇鎶ヨ瘎璁?  Future<bool> reportComment(String commentId) async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/commentTipOff', queryParameters: {'comment_id': commentId});
      return resp.data['code'] == 1;
    } catch (_) {
      return false;
    }
  }

  /// 寮€鍙戣€咃細鏉板摜
  /// 浣滅敤锛氫妇鎶ュ脊骞?  Future<bool> reportDanmu(String danmuId) async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/danmuReport', queryParameters: {'danmu_id': danmuId});
      return resp.data['code'] == 1;
    } catch (_) {
      return false;
    }
  }

  /// 鑾峰彇浜戠寮瑰箷 (鏀寔 DPlayer/Danmaku 鍗忚)
  /// 浼樺厛浣跨敤鍚庡彴閰嶇疆鐨勬帴鍙ｏ紝鍏舵灏濊瘯纭紪鐮佺殑婧?  Future<List<Map<String, dynamic>>> getCloudDanmaku(String videoUrl) async {
    // 1. 鑾峰彇鍚庡彴閰嶇疆鐨勫脊骞曟帴鍙?(寤鸿鍦ㄥ悗鍙?APP閰嶇疆 -> 鑷畾涔夊弬鏁?涓坊鍔?danmaku_api)
    final configApi = appConfig['danmaku_api']?.toString() ?? '';
    
    final cloudApis = <String>[];
    if (configApi.isNotEmpty) {
      cloudApis.add(configApi);
    }
    
    // 2. 娣诲姞榛樿婧?(浣滀负鍏滃簳)
    // cloudApis.add('https://api.danmu.icu/api.php');
    
    for (final api in cloudApis) {
      try {
        final resp = await _dio.get(api, queryParameters: {'id': videoUrl});
        
        // 瑙ｆ瀽 DPlayer 鏍煎紡
        if (resp.data is Map && resp.data['data'] is List) {
           final rawList = resp.data['data'] as List;
           return rawList.map((item) {
             // DPlayer format: [time, type, color, author, text]
             if (item is List && item.length >= 5) {
               return {
                 'time': double.tryParse('${item[0]}') ?? 0.0,
                 'type': item[1],
                 'color': '#${(int.tryParse('${item[2]}') ?? 16777215).toRadixString(16).padLeft(6, '0')}',
                 'text': item[4].toString(),
                 'source': 'cloud',
               };
             }
             return <String, dynamic>{};
           }).where((e) => e.isNotEmpty).toList();
        }
        // 瑙ｆ瀽 XML 鏍煎紡 (Bilibili 椋庢牸) - 鏆傜暐锛岄渶瑕?xml parser
      } catch (e) {
        // print('Cloud Danmaku Error ($api): $e');
      }
    }
    return [];
  }
}
