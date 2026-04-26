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
// by：杰哥 
// qq： 2711793818
// 修复登录状态校验问题

import 'dart:convert'; // 引入 jsonDecode
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
  // 单例模式
  static final MacApi _instance = MacApi._internal();
  factory MacApi() => _instance;
  MacApi._internal() {
    setup(); // 确保单例创建时立即初始化 Dio
  }

  late Dio _dio;
  late CookieJar _cookieJar;
  bool _initialized = false;
  String? _appUserToken;
  
  // 缓存检测结果
  DateTime? _lastDetect;
  bool? _pluginFilterOk;
  bool? _customApiOk;
  bool? _standardApiOk;
  
  String _appOs = 'android';
  int _appVersionCode = 1;
  String _appVersionName = '1.0.0';

  void setup() {
    _dio = Dio(BaseOptions(
      baseUrl: _rootUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
      validateStatus: (status) {
        return status != null && status < 500;
      },
    ));

    // 拦截器：处理 JSON 容错
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 开发者：杰哥
        // 修复：智能追加 api.php 前缀
        // 作用：如果 AppConfig 配置了 api.php，但请求路径是 jgappapi 或 provide 开头，
        // 自动把 api.php 加上，防止 404。
        // 同时保留 index.php/user/login 等路径正常访问（不加 api.php）。
        if (AppConfig.baseUrl.contains('/api.php')) {
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
        // 自动添加通用 Headers
        options.headers.addAll(_headers);
        handler.next(options);
      },
      onResponse: (response, handler) {
        // 自动处理：如果后端返回的是 String 类型的 JSON，自动转成 Map
        if (response.data is String) {
          try {
            // 有些服务器返回的 JSON 前后可能有空白字符
            final str = (response.data as String).trim();
            if (str.startsWith('{') || str.startsWith('[')) {
               response.data = jsonDecode(str);
            } else if (str == 'closed') {
               // 特殊处理 MacCMS 关闭状态
               throw DioException(
                 requestOptions: response.requestOptions,
                 error: '服务器功能已关闭或路径错误 (closed)',
                 type: DioExceptionType.badResponse,
               );
            }
          } catch (e) {
            print('JSON自动解析失败: $e');
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

  /// 获取网站根路径（用于非API接口，如用户中心）
  String get _rootUrl {
    String root;
    final base = AppConfig.baseUrl;
    if (base.contains('/api.php')) {
      root = base.split('/api.php').first;
    } else {
      root = base;
    }
    return root.endsWith('/') ? root : '$root/';
  }

  /// 初始化 Cookie（用于保持登录状态）
  Future<void> init() async {
    if (_initialized) return;
    if (!kIsWeb) {
      // 移动端使用内存 Cookie，避免 dart:io 依赖导致 Web 编译失败
      _cookieJar = CookieJar();
      _dio.interceptors.add(CookieManager(_cookieJar));
    }
    // 读取本地缓存的 JgApp token（如果有的话）
    final prefs = await SharedPreferences.getInstance();
    _appUserToken = prefs.getString('app_user_token');
    // 开发者：杰哥
    // 作用：当域名变更时，自动清空旧的初始化缓存，避免分类读取到旧数据
    // 解释：你换了后台地址，老的缓存会被清掉，重新拉最新分类。
    try {
      final baseRoot = _rootUrl; // 例如 http://pay.ddgg888.my/
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

  /// 开发者：杰哥
  /// 作用：检测后端接口可用性（插件筛选、app_api.php、标准API）并缓存结果
  /// 解释：先看看哪些后端接口能用，后面就优先用能用的，省时间。
  Future<Map<String, bool>> detectInterfaces({bool force = false}) async {
    // 5分钟内已有检测结果则复用
    if (!force && _lastDetect != null && DateTime.now().difference(_lastDetect!) < const Duration(minutes: 5)) {
      return {
        'plugin': _pluginFilterOk ?? false,
        'custom': _customApiOk ?? false,
        'standard': _standardApiOk ?? false,
      };
    }

    await init();
    _lastDetect = DateTime.now();

    // 1) 插件筛选接口
    try {
      final resp = await _dio.get('jgappapi.index/typeFilterVodList', queryParameters: {
        'page': 1,
        'limit': 1,
        'sort': '最新',
      });
      _pluginFilterOk = resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1);
    } catch (_) { _pluginFilterOk = false; }

    // 2) 自定义 app_api.php
    try {
      final resp = await _dio.get('${_rootUrl}app_api.php', queryParameters: {
        'ac': 'list',
        'pg': 1,
        'pagesize': 1,
      });
      _customApiOk = resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1);
    } catch (_) { _customApiOk = false; }

    // 3) 标准接口 provide/vod/
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

  // ================= 用户相关 =================

  /// 注册
  Future<Map<String, dynamic>> register(String username, String password) async {
    await init();
    try {
      // 0. 优先尝试 JgApp 插件注册接口
      try {
        final resp = await _dio.post(
          'jgappapi.index/appRegister',
          data: {
            'user_name': username,
            'password': password,
            'invite_code': '', // 暂留空
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: _headers,
          ),
        );
        if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
          return {'success': true, 'info': resp.data['msg'] ?? '注册成功'};
        } else if (resp.data is Map && resp.data['msg'] != null) {
          return {'success': false, 'msg': resp.data['msg']};
        }
      } catch (_) {}

      // 1. 其次尝试 app_api.php (用户自定义插件接口)
      // 这个文件需要用户上传到网站根目录
      final customApiUrl = '${_rootUrl}app_api.php';
      try {
        final resp = await _dio.post(customApiUrl, queryParameters: {'ac': 'register'}, data: {
          'user_name': username,
          'user_pwd': password,
          'user_pwd2': password,
        });
        if (resp.statusCode == 200 && resp.data is Map) {
           if (resp.data['code'] == 1) {
             return {'success': true, 'info': resp.data['msg'] ?? '注册成功'};
           } else {
             return {'success': false, 'msg': resp.data['msg']};
           }
        }
      } catch (_) {
        // app_api.php 不存在或请求失败，降级到默认逻辑
      }

      // 2. 降级：尝试标准 MacCMS 路径: /index.php/user/reg
      // ... (保留原有逻辑)
      final url = '${_rootUrl}/index.php/user/reg';
      final resp = await _dio.post(url, data: {
        'user_name': username,
        'user_pwd': password,
        'user_pwd2': password,
        'verify': '', // 可能需要验证码
      }, options: Options(
        contentType: Headers.formUrlEncodedContentType, // 表单提交
        headers: {
          'X-Requested-With': 'XMLHttpRequest', // 伪装 AJAX
        }
      ));
      
      final data = resp.data;
      if (data is Map && data['code'] == 1) {
        return {'success': true, 'info': data['msg'] ?? '注册成功'};
      } else if (data is Map) {
        return {'success': false, 'msg': data['msg'] ?? '注册失败'};
      } else {
        // 如果返回 HTML，可能是 200 OK 但内容是页面
        return {'success': false, 'msg': '服务器返回非JSON格式，可能未开启API注册'};
      }
    } catch (e) {
      return {'success': false, 'msg': '请求失败: $e'};
    }
  }

  /// 检查是否登录
  Future<bool> checkLogin({bool force = false}) async {
    await init();
    
    // 0. 优先信任最近一次成功登录的 Token（如果有）
    final prefs = await SharedPreferences.getInstance();
    final localUser = prefs.getString('user_name');
    final hasToken = _appUserToken != null && _appUserToken!.isNotEmpty;

    // 如果强制刷新，则忽略本地快速判断
    if (!force && (hasToken || (localUser != null && localUser.isNotEmpty))) {
       // 这是一个快速返回，但也可能导致 token 失效了还认为已登录
       // 只有当 force=true 时，我们才强制走网络校验
    } else if (!force) {
       // 如果不是强制刷新，且本地有痕迹，先乐观返回 true，但也可能导致状态不同步
       // 为了稳健，我们这里调整逻辑：
       // 1. 如果 force=true，必须走网络
       // 2. 如果 force=false，且本地有 Token，优先尝试走网络校验（不阻塞 UI 可以吗？不行，这里是 Future<bool>）
       // 所以保持原逻辑：force=false 时，优先信任本地，除非 explicit logout
    }

    // 1. 优先通过 JgApp 插件 userInfo 接口校验 app-user-token
    try {
      if (hasToken) {
        final resp = await _dio.get('jgappapi.index/userInfo');
        // 如果返回 code=1，即使 data 是加密串无法解析，我们也认为是登录成功的
        // 因为未登录通常返回 code=0 或 1001
        final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
        if (resp.statusCode == 200 && resp.data is Map && code == 1) {
          // 尝试解析用户信息，如果失败则忽略，但认为登录有效
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
        } else if (force) {
           // 强制刷新且校验失败，说明 token 过期
           return false;
        }
      }
    } catch (_) {
       if (force) return false; 
    }

    // 2. 兼容旧逻辑：通过收藏列表来验证 session（依赖 Cookie）
    try {
      final resp = await _dio.get('user/ulog_list', queryParameters: {
        'ulog_mid': 1, 
        'ulog_type': 2,
        'limit': 1,
      });
      final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
      if (code == 1) {
         return true;
      }
    } catch (_) {}
    
    // 3. 如果以上都失败，但本地存有 user_name，我们最后尝试一次 user/index 
    if (localUser != null && localUser.isNotEmpty) {
       try {
         final resp = await _dio.get('user/index');
         final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
         if (resp.data is Map && code == 1) return true;
         // 有些模版返回 HTML，包含“退出”字样通常意味着已登录
         if (resp.data is String && resp.data.toString().contains('退出')) return true;
       } catch (_) {}
    }

    // 4. 终极兜底：如果本地有 Token 或 用户名，且不是强制刷新
    // 修复：用户反馈登录成功后页面不刷新，可能是因为接口校验失败但其实本地已有凭证
    if (!force && (hasToken || (localUser != null && localUser.isNotEmpty))) {
      return true; 
    }

    return false;
  }

  /// 开发者：杰哥
  /// 作用：保存 JgApp 插件返回的 auth_token
  /// 解释：把后端给的“登录票据”记住，后面自动带在请求里。
  Future<void> _saveAppUserToken(String? token) async {
    // 即使 token 为空，也要尝试保存（如果之前有的话），但这里只处理非空
    if (token == null || token.isEmpty) return;
    _appUserToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_user_token', token);
  }

  /// 登录
  Future<Map<String, dynamic>> login(String username, String password) async {
    await init();
    
    // 0. 优先尝试 JgApp 插件 appLogin（返回 auth_token，用于 app-user-token 头）
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
             // 尝试多种路径获取 token
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
        return {'success': true, 'info': resp.data['msg'] ?? '登录成功'};
      }
    } catch (_) {
      // 忽略插件错误，继续尝试其他登录方式
    }
    
    // 1. 尝试 app_api.php（兼容旧版自定义接口）
    final customApiUrl = '${_rootUrl}app_api.php';
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
           return {'success': true, 'info': resp.data['msg'] ?? '登录成功'};
         } else {
           return {'success': false, 'msg': resp.data['msg']};
         }
      }
    } catch (_) {}

    // 2. 降级：尝试标准路径
    final url = '${_rootUrl}index.php/user/login';
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
        validateStatus: (status) => status! < 500, // 允许 302/400 等
      ));
      
      // 如果返回 HTML，检查是否包含特定错误
      if (resp.data is String) {
         if (resp.data.toString().contains('原生接口')) {
            return {'success': false, 'msg': '服务器限制：请联系管理员开启 APP API 接口权限'};
         }
      }
      
      final data = resp.data;
      // 兼容 code 可能是字符串的情况
      final code = int.tryParse('${data['code'] ?? 0}') ?? 0;
      if (data is Map && code == 1) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', username);
        return {'success': true, 'info': data['msg'] ?? '登录成功'};
      } else {
        return {'success': false, 'msg': data is Map ? data['msg'] : '登录失败'};
      }
    } catch (e) {
      // 如果标准路径失败，尝试 API 路径（有些插件支持）
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
      return {'success': false, 'msg': '登录请求失败: $e'};
    }
  }

  /// 退出登录（清理本地 Cookie）
  Future<void> logout() async {
    await init();
    if (!kIsWeb) {
      await _cookieJar.deleteAll();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
     await prefs.remove('app_user_token');
     _appUserToken = null;
  }

  /// 获取缓存的用户信息
  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? '用户';
  }

  /// 添加收藏
  Future<Map<String, dynamic>> addFav(String vodId) async {
    await init();
    // 优先使用插件接口：jgappapi.index/collect（支持 app-user-token，无需 Cookie）
    try {
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
        return {'success': code == 1, 'msg': msg.isNotEmpty ? msg : (code == 1 ? '收藏成功' : '收藏失败')};
      }
    } catch (_) {
      // 忽略插件错误，降级到标准接口
    }
    // 兼容标准接口：需要 Cookie 会话
    try {
      final resp = await _dio.post('user/ulog_add', data: {
        'ulog_mid': 1,
        'ulog_rid': vodId,
        'ulog_type': 2,
      });
      final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
      return {
        'success': code == 1,
        'msg': resp.data['msg'] ?? (code == 1 ? '收藏成功' : '收藏失败'),
      };
    } catch (e) {
      return {'success': false, 'msg': '请求失败: $e'};
    }
  }

  /// 添加播放记录
  Future<bool> addHistory(String vodId) async {
    await init();
    // ulog_type: 4=播放记录
    final resp = await _dio.post('user/ulog_add', data: {
      'ulog_mid': 1,
      'ulog_rid': vodId,
      'ulog_type': 4,
    });
    return resp.data['code'] == 1;
  }

  /// 获取收藏列表
  Future<List<Map<String, dynamic>>> getFavs({int page = 1}) async {
    await init();
    // 优先使用插件接口：jgappapi.index/collectList
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
            'log_id': '${v['id']}', // 插件返回的收藏记录ID
            'id': '${v['vod_id']}',
            'title': vod['vod_name']?.toString() ?? '',
            'poster': _fixUrl(vod['vod_pic']?.toString()),
          };
        }).toList();
      }
    } catch (_) {}
    // 兼容标准接口
    try {
      final resp = await _dio.get('user/ulog_list', queryParameters: {
        'ulog_mid': 1,
        'ulog_type': 2,
        'limit': 100,
      });
      final rows = (resp.data?['info']?['rows'] as List?) ?? [];
      return rows.map((v) => {
        'log_id': '${v['ulog_id']}', // 收藏记录ID，用于删除
        'id': '${v['ulog_rid']}',
        'title': (v['data'] is Map ? v['data']['name'] : '') ?? '',
        'poster': _fixUrl((v['data'] is Map ? v['data']['pic'] : '')?.toString()),
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 删除收藏
  Future<Map<String, dynamic>> deleteFav(String logId, {String? vodId, String? ids}) async {
    await init();
    // 优先使用插件接口：jgappapi.index/deleteCollect（支持按 vod_id 或 ids 批量删除）
    try {
      // 只要传入了 vodId 或 ids，或者 logId 看起来像个 ID，都尝试调用插件接口
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
          // 只要接口返回，就认为成功（code=1），除非明确报错
          return {'success': code == 1, 'msg': msg.isNotEmpty ? msg : (code == 1 ? '删除成功' : '删除失败')};
        }
      }
    } catch (_) {}
    // 兼容标准接口：按 logId 删除

    try {
      final resp = await _dio.post('user/ulog_del', data: {
        'ids': logId,
        'type': 2,
      });
      final code = int.tryParse('${resp.data['code'] ?? 0}') ?? 0;
      return {
        'success': code == 1,
        'msg': resp.data['msg'] ?? (code == 1 ? '删除成功' : '删除失败'),
      };
    } catch (e) {
      return {'success': false, 'msg': '请求失败: $e'};
    }
  }

  /// 开发者：杰哥
  /// 作用：通过 vodId 删除收藏
  Future<Map<String, dynamic>> deleteFavByVodId(String vodId) async {
    await init();
    // 1. 尝试通过插件接口删除 (支持 vod_id)
    try {
      final resp = await _dio.get(
        'jgappapi.index/deleteCollect',
        queryParameters: {'vod_id': vodId},
        options: Options(headers: _headers),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
         final code = int.tryParse('${resp.data['code'] ?? 1}') ?? 1;
         return {'success': code == 1, 'msg': resp.data['msg'] ?? '删除成功'};
      }
    } catch (_) {}

    // 2. 如果插件失败，先获取列表找到 logId，再删除
    try {
      final favs = await getFavs(page: 1);
      final item = favs.firstWhere((e) => '${e['id']}' == vodId, orElse: () => {});
      if (item.isNotEmpty && item['log_id'] != null) {
        return await deleteFav(item['log_id']!);
      }
    } catch (_) {}
    
    return {'success': false, 'msg': '未找到收藏记录'};
  }

  /// 检查单个影片是否已收藏（插件接口）
  Future<bool> isCollected(String vodId) async {
    await init();
    try {
      final resp = await _dio.get(
        'jgappapi.index/isCollect',
        queryParameters: {'vod_id': vodId},
        options: Options(headers: _headers),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        // 插件通常返回 {code:1, data:{is_collect:true/false}} 或者 {data:true/false}
        final data = resp.data['data'];
        if (data is Map && data['is_collect'] is bool) {
          return data['is_collect'] as bool;
        }
        if (data is bool) return data;
        // 如果只返回 msg，不可靠，降级到列表判断
      }
    } catch (_) {}
    // 兜底：通过收藏列表判断
    try {
      final favs = await getFavs(page: 1);
      return favs.any((e) => '${e['id']}' == vodId);
    } catch (_) {
      return false;
    }
  }

  /// 获取播放记录
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

  // ================= 视频相关 =================

  /// 辅助函数：处理图片链接（处理相对路径）
  String fixUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // 如果是 mac_turl 这样的非法链接，尝试修复或忽略
    if (url.contains('mac_turl')) return '';

    String finalUrl = url;
    
    // 如果是相对路径，拼接到域名根目录
    if (!url.startsWith('http')) {
      final base = AppConfig.baseUrl;
      // 移除 api.php 及其后面的内容，获取真正的根域名
      // 例如 https://ys.ddgg888.my/api.php/provide/vod/ -> https://ys.ddgg888.my/
      final root = base.split('/api.php').first;
      
      if (url.startsWith('/')) {
         finalUrl = '$root$url';
      } else {
         finalUrl = '$root/$url';
      }
    }
    
    // 强制将 http 转为 https（如果配置是 https）
    if (AppConfig.baseUrl.startsWith('https://') && finalUrl.startsWith('http://')) {
      finalUrl = finalUrl.replaceFirst('http://', 'https://');
    }
    
    return finalUrl;
  }

  /// 内部调用保留兼容
  String _fixUrl(String? url) => fixUrl(url);

  /// 获取推荐视频（用于轮播图，Level=9）
  Future<List<Map<String, dynamic>>> getBanner() async {
    // 优先尝试从 app_api.php init 接口获取
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

    // 插件/自定义接口不可用时，使用筛选接口近似“轮播”：取周热榜或最热
    // 杰哥：根据用户要求，移除所有自动兜底数据。如果没有配置 Banner，就不显示。
    /*
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

  /// 获取热播列表
  Future<List<Map<String, dynamic>>> getHot({int page = 1}) async {
    // 开发者：杰哥
    // 作用：获取“当前热播”，优先使用插件筛选接口（sort=hits_week），避免标准接口关闭导致空数据
    // 解释：如果后端标准接口关了，我用插件的接口拿“周热播”列表。
    const limit = 20;
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
      // 修复：处理 closed 状态
      if (resp.data is String && resp.data.toString().trim() == 'closed') {
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

  // 简单的内存缓存，优化搜索速度
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  // APP 初始化数据缓存
  Map<String, dynamic>? _initData;
  DateTime? _initDataAt;
  
  List<String> get filterWords {
    if (_initData != null && _initData!['filter_words'] is List) {
      return (_initData!['filter_words'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  // 开发者：杰哥
  // 作用：获取全局配置（联系方式、分享文案、弹幕开关等）
  Map<String, dynamic> get appConfig {
    if (_initData != null && _initData!['config'] is Map) {
      return _initData!['config'] as Map<String, dynamic>;
    }
    return {};
  }

  String get contactUrl => appConfig['app_contact_url']?.toString() ?? appConfig['kefu_url']?.toString() ?? '';
  String get contactText => appConfig['app_contact_text']?.toString() ?? '联系客服';
  String get shareText => appConfig['app_share_text']?.toString() ?? '推荐一款很好用的追剧APP，快来下载吧！';
  bool get isDanmuEnabled => (int.tryParse('${appConfig['system_danmu_status'] ?? 1}') ?? 1) == 1;

  // 关于我们
  String get aboutUsAvatar => appConfig['system_config_about_us_avatar_url']?.toString() ?? '';
  String get aboutUsContent => appConfig['system_config_about_us_content']?.toString() ?? '';

  bool containsFilterWord(String text) {
    if (text.isEmpty) return false;
    for (final word in filterWords) {
      if (word.isNotEmpty && text.contains(word)) return true;
    }
    return false;
  }
  
  // 通用 Headers
  Map<String, dynamic> get _headers => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'X-Requested-With': 'XMLHttpRequest',
    'app-os': _appOs,
    'app-version-code': '$_appVersionCode',
  };

  /// 开发者：杰哥
  /// 作用：把 app 版本号转成 JgApp 插件需要的 version_code
  /// 解释：后端用 1.0.0 -> 100 这种规则判断有没有新版本。
  int _parseJgAppVersionCode(String versionName) {
    final parts = versionName.split('.');
    if (parts.length < 3) return 0;
    final major = int.tryParse(parts[0]) ?? -1;
    final minor = int.tryParse(parts[1]) ?? -1;
    final patch = int.tryParse(parts[2]) ?? -1;
    if (major < 0 || minor < 0 || patch < 0) return 0;
    if (minor > 9 || patch > 9) return 0;
    final merged = int.tryParse('$major$minor$patch') ?? 0;
    return merged;
  }

  /// 获取 APP 初始化数据 (热搜、Banner、推荐)
  Future<Map<String, dynamic>> getAppInit({bool force = false}) async {
    // 0) 先返回“内存缓存”，避免重复请求
    if (!force &&
        _initData != null &&
        _initDataAt != null &&
        DateTime.now().difference(_initDataAt!) < const Duration(minutes: 30)) {
      return _initData!;
    }
    await init();
    // 1) 如果“磁盘缓存”存在，则优先立即返回，后台刷新
    try {
      final disk = await _loadInitDataFromDisk();
      if (!force && disk != null && disk.isNotEmpty) {
        _initData = disk['data'] as Map<String, dynamic>;
        _initDataAt = DateTime.fromMillisecondsSinceEpoch(disk['ts'] as int);
        // 异步刷新最新数据，不阻塞首屏
        _refreshAppInitInBackground();
        return _initData!;
      }
    } catch (_) {}
    // 清空内存缓存，准备重新加载
    _initData = null;
    _initDataAt = null;
    
    // 1. 尝试 JgApp 插件接口
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

        // 处理 type_list
        dynamic rawTypeList = dataMap['type_list'];
        
        // 开发者：杰哥
        // 修复：兼容 type_list 位于 dataMap['data'] 结构下的情况
        if (rawTypeList == null && dataMap['data'] is Map) {
             rawTypeList = dataMap['data']['type_list'];
        }
        
        // 修复：兼容 curl 结果显示的扁平结构（type_list 就在根节点下，但 dataMap 可能是整个 response）
        // 实际上 jgappapi.index/init 返回的结构是 {code:1, msg:.., type_list:[...], ...}
        // 所以当 respMap 就是 dataMap 时，type_list 应该能直接取到。
        // 但是，如果 dataMap 是 respMap['data']，而 type_list 还在外层，就会取不到。
        // 我们这里做个增强查找：
        if (rawTypeList == null && respMap['type_list'] != null) {
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
        // 兼容：部分后端返回的 type_list 是 Map 映射（id -> name 或对象）
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
        
        // 关键修复：优先使用插件返回的 type_list，如果为空才尝试标准接口兜底
        var typeList = (rawTypeList is List) ? rawTypeList : const [];
        // 仅使用插件返回的分类，不再使用标准接口兜底

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
          // 版本更新信息（来自插件 init 返回的 update 字段）
          'update': (dataMap['update'] is Map)
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
                // 增强解析：兼容 slide_id/slide_pic 等字段
                final id = '${v['vod_id'] ?? v['slide_id'] ?? v['id'] ?? ''}';
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
          // 杰哥：透传自定义广告字段，供首页 Banner 兜底使用
          'advert_list': dataMap['advert_list'] ?? respMap['advert_list'],
          'custom_ads': dataMap['custom_ads'] ?? respMap['custom_ads'],
          'ads': dataMap['ads'] ?? respMap['ads'],
          'home_banner': dataMap['home_banner'] ?? respMap['home_banner'],
          'slide_list': dataMap['slide_list'] ?? respMap['slide_list'], // 增加 slide_list 透传
          'focus_list': dataMap['focus_list'] ?? respMap['focus_list'], // 增加 focus_list 透传
          
          // 开发者：杰哥
          // 修复：透传置顶评论配置（解决详情页无法显示置顶评论的问题）
          // 优先顺序：dataMap > respMap > config > system
          'app_comment_top_status': dataMap['app_comment_top_status'] ?? respMap['app_comment_top_status'] ?? (dataMap['config'] is Map ? dataMap['config']['app_comment_top_status'] : null) ?? (dataMap['system'] is Map ? dataMap['system']['app_comment_top_status'] : null),
          'app_comment_top_name': dataMap['app_comment_top_name'] ?? respMap['app_comment_top_name'] ?? (dataMap['config'] is Map ? dataMap['config']['app_comment_top_name'] : null) ?? (dataMap['system'] is Map ? dataMap['system']['app_comment_top_name'] : null),
          'app_comment_top_avatar': dataMap['app_comment_top_avatar'] ?? respMap['app_comment_top_avatar'] ?? (dataMap['config'] is Map ? dataMap['config']['app_comment_top_avatar'] : null) ?? (dataMap['system'] is Map ? dataMap['system']['app_comment_top_avatar'] : null),
          'app_comment_top_content': dataMap['app_comment_top_content'] ?? respMap['app_comment_top_content'] ?? (dataMap['config'] is Map ? dataMap['config']['app_comment_top_content'] : null) ?? (dataMap['system'] is Map ? dataMap['system']['app_comment_top_content'] : null),
        };
        _initDataAt = DateTime.now();
        // 持久化缓存，提升下次启动速度
        _saveInitDataToDisk(_initData!);
        return _initData!;
      }
    } catch (_) {}

    // 1.1 若 init 不可用，尝试插件提供的精简分类接口 jgappapi.index/typeList
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

    // 2. 尝试 app_api.php (旧版插件)
    final customApiUrl = '${_rootUrl}app_api.php';
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
        // 持久化缓存
        _saveInitDataToDisk(_initData!);
        return _initData!;
      }
    } catch (e) {
      print('Init API Error: $e');
    }

    // 插件与自定义接口均不可用时，返回空结构，避免崩溃
    _initData = {
      'type_list': const <Map<String, dynamic>>[],
    };
    _initDataAt = DateTime.now();
    _saveInitDataToDisk(_initData!);
    return _initData!;
  }

  /// 开发者：杰哥
  /// 作用：仅获取插件后台分类列表（用于首页顶部分类兜底拉取）
  /// 解释：如果初始化接口没带分类，或者解析失败，就用这个接口单独拿分类。
  Future<List<Map<String, dynamic>>> getPluginTypeList() async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/typeList', options: Options(headers: _headers));
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
        final data = (resp.data['data'] as Map?) ?? const {};
        dynamic raw = data['type_list'] ?? data['list'] ?? data['class']; // 增加兼容字段
        
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
        
        // 兼容：部分后端返回的 type_list 是 Map 映射
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

  /// 将 APP 初始化数据保存到磁盘（SharedPreferences）
  /// 说明：避免每次进入 App 都白屏加载，提升首屏速度
  Future<void> _saveInitDataToDisk(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_init_json', jsonEncode(data));
      await prefs.setInt('app_init_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// 从磁盘读取 APP 初始化数据
  /// 返回：{ 'data': Map<String,dynamic>, 'ts': int } 或 null
  Future<Map<String, dynamic>?> _loadInitDataFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('app_init_json');
      final ts = prefs.getInt('app_init_ts') ?? 0;
      if (raw == null || raw.isEmpty) return null;
      final Map<String, dynamic> data = jsonDecode(raw);
      if (data.isEmpty) return null;
      // 如果缓存时间超过 12 小时，仍然可以用，但会触发后台刷新
      return {'data': data, 'ts': ts};
    } catch (_) {
      return null;
    }
  }

  /// 后台刷新 APP 初始化数据（无感知），用于更新磁盘缓存
  Future<void> _refreshAppInitInBackground() async {
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
    // 1) 标准 provide/vod/ 接口
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
    // 2) MacCMS API: type/get_list (返回 rows 列表)
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
    // 3) MacCMS API: type/get_all_list (返回 rows 可能为列表或映射)
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

  /// 内部辅助：使用标准接口获取列表
  Future<List<Map<String, dynamic>>> _fetchStandardList({int? typeId, int page = 1, int limit = 20, String by = 'time'}) async {
    try {
      final params = <String, dynamic>{
        'ac': 'detail', // 使用 detail 获取更全信息
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
          'remarks': v['vod_remarks'] ?? '', // 新增字段
          'blurb': v['vod_blurb'] ?? v['vod_content'] ?? '', // 新增字段
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

  /// 获取指定推荐等级的视频 (level=1~9)
  /// 开发者：杰哥
  /// 作用：获取后台设置了推荐等级的视频
  Future<List<Map<String, dynamic>>> getRecommended({required int level, int limit = 6}) async {
    await init();
    try {
      // 0. 优先尝试 JgApp 插件的 vodLevel 接口 (部分插件支持)
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

      // 1. 尝试 app_api.php (自定义接口通常支持更好)
      final customApiUrl = '${_rootUrl}app_api.php';
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

      // 2. 插件兜底：移除自动兜底逻辑
      // 开发者：杰哥
      // 原因：首页有专门的兜底逻辑（限制数量），这里如果自动填充会导致首页误判为“已配置推荐”而显示过多数据。
      // 如果后台没配置 level 推荐，就应该返回空。
      /*
      try {
        final hot = await getFiltered(orderby: 'hits', limit: limit);
        if (hot.isNotEmpty) return hot;
        final good = await getFiltered(orderby: 'score', limit: limit);
        if (good.isNotEmpty) return good;
      } catch (_) {}
      */

      // 3. 尝试标准接口 (provide/vod/) - 已移除
      // 开发者：杰哥
      // 原因：用户明确要求仅通过插件后台获取数据，不需要开启 CMS 开放 API。
      // 如果插件配置正确，数据应包含在 init 接口的 recommend_list 中，或通过 jgappapi 获取。
      /*
      try {
        final resp = await _dio.get('provide/vod/', queryParameters: {
          'ac': 'detail', // 使用 detail 获取图片和 vod_level
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


  /// 解析热搜词（支持数组或逗号分隔字符串）
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

  /// 获取热搜关键词
  Future<List<String>> getHotKeywords() async {
    // 1. 尝试从 AppInit 获取 (后台配置的搜索热词)
    final data = await getAppInit();
    if (data.isNotEmpty && data['hot_search_list'] != null) {
       final list = (data['hot_search_list'] as List);
       if (list.isNotEmpty) {
         return list.map((e) => e.toString()).toList();
       }
    }

    // 2. 如果后台没配置热词，则自动获取“周热播”前10名的标题作为热搜
    try {
      final hotVideos = await getHot(page: 1);
      if (hotVideos.isNotEmpty) {
        return hotVideos.take(10).map((v) => v['title'].toString()).toList();
      }
    } catch (_) {}

    // 3. 最后的兜底
    return ['繁花', '庆余年', '斗破苍穹', '雪中悍刀行', '完美世界', '吞噬星空'];
  }

  /// 搜索视频：小白理解为“按名字搜”
  Future<List<Map<String, dynamic>>> searchByName(String keyword) async {
    // 优先查缓存，提升速度
    if (_searchCache.containsKey(keyword)) {
      return _searchCache[keyword]!;
    }

    await init();

    // 0. 优先尝试 JgApp 插件搜索接口 (jgappapi.index/searchList)
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

    // 1. 尝试 app_api.php (支持 Xunsearch)
    final customApiUrl = '${_rootUrl}app_api.php';
    try {
       final resp = await _dio.get(customApiUrl, queryParameters: {
         'ac': 'search',
         'wd': keyword,
         'pagesize': 20,
       });
       if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
          final list = (resp.data['list'] as List?) ?? [];
          // 类型转换 List<dynamic> -> List<Map<String, dynamic>>
          final results = list.map((item) {
             final v = item as Map<String, dynamic>;
             return {
               'id': '${v['vod_id']}',
               'title': v['vod_name'] ?? '',
               'poster': _fixUrl(v['vod_pic']),
               'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
               'year': '${v['vod_year'] ?? ''}',
               'overview': v['vod_remarks'] ?? '',
               'area': v['vod_area'] ?? '',
               'lang': v['vod_lang'] ?? '',
               'class': v['type_name'] ?? v['vod_class'] ?? '',
               'actor': v['vod_actor'] ?? '',
             };
          }).toList();
          
          _searchCache[keyword] = results;
          return results;
       }
    } catch (_) {
      // 忽略错误，降级处理
    }

    // 2. 降级：使用 ac=detail 以获取图片
    final resp = await _dio.get('provide/vod/', queryParameters: {
      'ac': 'detail',
      'wd': keyword,
      'pagesize': 20,
      'at': 'json',
    });
    final rows = (resp.data?['list'] as List?) ?? [];
    final results = rows.map((v) => {
      'id': '${v['vod_id']}',
      'title': v['vod_name'] ?? '',
      'poster': _fixUrl(v['vod_pic']),
      'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
      'year': '${v['vod_year'] ?? ''}',
      // 修复：优先使用内容简介
      'overview': v['vod_content'] ?? v['vod_blurb'] ?? v['vod_remarks'] ?? '',
      'area': v['vod_area'] ?? '',
      'lang': v['vod_lang'] ?? '',
      'class': v['type_name'] ?? v['vod_class'] ?? '',
      'actor': v['vod_actor'] ?? '',
    }).toList();
    
    // 存入缓存
    _searchCache[keyword] = results;
    return results;
  }

  /// 获取详情与播放列表
  Future<Map<String, dynamic>?> getDetail(String id) async {
    await init();
    
    // 1. 尝试 JgApp 插件接口 (jgappapi.index/vodDetail)
    try {
      final resp = await _dio.get('jgappapi.index/vodDetail', queryParameters: {'vod_id': id});
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
         dynamic data = resp.data['data'];
         
         // 尝试解密
         if (data is String) {
            try {
              final raw = data.trim();
              // 尝试 Base64 解码
              try {
                data = jsonDecode(utf8.decode(base64Decode(raw)));
              } catch (_) {
                // 如果不是 Base64，可能是普通 JSON 字符串
                data = jsonDecode(raw);
              }
            } catch (_) {}
         }

         // 如果 data 是 Map，说明是明文或解密成功，直接使用
         if (data is Map) {
           final info = data['vod'];
           final playList = (data['vod_play_list'] as List).map((p) {
              final pi = (p['player_info'] as Map?) ?? const {};
              final show = (pi['app_name'] ?? pi['app_show'] ?? pi['appName'] ?? pi['show'] ?? '播放源').toString();
              return {
                'show': show,
                'urls': (p['urls'] as List).map((u) => {
                  'name': u['name'] ?? '正片',
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
                    'parse_api': ep['parse_api'] // 修复：保留解析接口字段
                 });
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
             // 兼容旧字段（保持原详情页UI）
             'vod_name': info['vod_name'] ?? '',
             'vod_pic': _fixUrl(info['vod_pic']),
             'vod_year': '${info['vod_year'] ?? ''}',
             'vod_area': info['vod_area'] ?? '',
             'type_name': info['type_name'] ?? (info['vod_class'] ?? ''),
             'vod_actor': info['vod_actor'] ?? '',
             'vod_content': info['vod_content'] ?? (info['vod_blurb'] ?? info['vod_remarks'] ?? ''),
             'vod_play_list': finalPlayList,
             // ... 广告字段省略，防止解析错误 ...
           };
         }
      }
    } catch (_) {}

    // 2. 尝试 app_api.php (明文接口，可能包含播放源名称)
    final customApiUrl = '${_rootUrl}app_api.php';
    try {
      final resp = await _dio.get(customApiUrl, queryParameters: {
        'ac': 'detail',
        'ids': id,
      });
      if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
         final info = resp.data['list'][0];
         // 解析 app_api.php 返回的播放列表
         // 结构可能与标准 API 类似，也可能不同，这里尝试通用解析
         final playList = <Map<String, dynamic>>[];
         // ... (解析逻辑同标准API，但可能包含 'player_info'?)
         // 暂时跳过，直接用标准API解析，但加上映射
      }
    } catch (_) {}

    // 插件与自定义接口均不可用
    return null;
  }

  /// 解析播放链接（支持 JgApp 插件返回的解析接口）
  /// by：杰哥 qq： 2711793818
  /// - 参数：
  ///   - url: 原始播放地址（可能为直链或需要解析）
  ///   - parseApi: 解析接口完整地址（如插件返回的 `parse_api_url`）
  /// - 返回：最终可播放的直链（m3u8/mp4/http）
  Future<String> resolvePlayUrl(String url, {String? parseApi}) async {
    await init();
    // 如果没有解析接口，直接返回修正后的直链
    if (parseApi == null || parseApi.isEmpty) {
      return _fixUrl(url);
    }

    try {
      // 统一解析接口传参规则：
      // 1) 如果包含占位符 {url}，替换为编码后的原始地址
      // 2) 如果不含占位符，自动补充 ?url=encoded 或 &url=encoded
      // 3) 若为 jgappapi.index/vodParse 形式，强制使用 queryParameters 传参
      String requestUrl = parseApi;
      final encoded = Uri.encodeComponent(url);
      if (requestUrl.contains('{url}')) {
        requestUrl = requestUrl.replaceAll('{url}', encoded);
      } else if (requestUrl.contains('jgappapi.index/vodParse')) {
        // 使用 queryParameters 传递 url
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
      // 有些解析返回字符串，需要尝试 JSON 解析
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          // 尝试从字符串中提取 URL
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
      debugPrint('解析播放链接失败: $e');
    }
    // 兜底返回原链接
    return _fixUrl(url);
  }

  /// 从解析响应中稳健提取最终直链
  /// by：杰哥 qq： 2711793818
  /// - 支持结构：
  ///   1) { url: '...' }
  ///   2) { play_url: '...' } / { real: '...' } / { m3u8: '...' } / { link: '...' }
  ///   3) { json: '{ \"url\": \"...\" }' }
  ///   4) 纯字符串中提取 http(s) 链接
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
    // 精确映射
    const exact = {
      'kkm3u8': '夸克资源',
      'kkyun': '夸克云',
      'quark': '夸克资源',
      'lzm3u8': '量子资源',
      'lzyun': '量子云',
      'liangzi': '量子资源',
      'ffm3u8': '非凡资源',
      'ffyun': '非凡云',
      'feifan': '非凡资源',
      'xgm3u8': '西瓜资源',
      'xigua': '西瓜资源',
      'wjm3u8': '无尽资源',
      'wuji': '无尽资源',
      'tkm3u8': '天空资源',
      'tiankong': '天空资源',
      'dbm3u8': '百度资源',
      'baidu': '百度资源',
      'bjm3u8': '八戒资源',
      'bajie': '八戒资源',
      'xlm3u8': '新浪资源',
      'xinlang': '新浪资源',
      'hhm3u8': '豪华资源',
      'snm3u8': '索尼资源',
      'hnm3u8': '红牛资源',
    };
    if (exact.containsKey(c)) return exact[c]!;
    // 模糊匹配
    if (c.contains('liang') || c.contains('lz')) return '量子资源';
    if (c.contains('feifan') || c.contains('ff')) return '非凡资源';
    if (c.contains('xigua') || c.contains('xg')) return '西瓜资源';
    if (c.contains('quark') || c.contains('kk')) return '夸克资源';
    if (c.contains('tiankong') || c.contains('tk')) return '天空资源';
    if (c.contains('wuji') || c.contains('wj')) return '无尽资源';
    if (c.contains('baidu') || c.contains('db')) return '百度资源';
    if (c.contains('bajie') || c.contains('bj')) return '八戒资源';
    if (c.contains('xinlang') || c.contains('xl')) return '新浪资源';
    if (c.contains('m3u8')) return '高清资源';
    if (c.contains('yun')) return '云播资源';
    return code;
  }

  /**
   * 获取筛选项：年份/地区/类型（依赖后端 get_year/get_area/get_class）
   */
  Future<Map<String, List<String>>> getFacets({int typeId1 = 1}) async {
    // 暂时返回常用年份和地区
    return {
      'years': ['2025','2024','2023','2022','2021','2020','2019','2018','2017'],
      'areas': ['大陆','香港','台湾','美国','韩国','日本','泰国','英国','法国'],
      'classes': ['动作','喜剧','爱情','科幻','恐怖','剧情','战争','纪录'],
    };
  }

  final _LruCache<List<Map<String, dynamic>>> _categoryCache = _LruCache(
    capacity: 200,
    ttl: const Duration(minutes: 30),
  );

  /// 根据筛选项获取列表（支持 app_api.php 高级筛选）
  Future<List<Map<String, dynamic>>> getFiltered({
    int? typeId,
    String? year,
    String? area,
    String? lang,
    String? clazz,
    String orderby = 'time', // 默认按时间
    int page = 1,
    int limit = 20,
  }) async {
    await init();
    // 优先检测一次接口状态（缓存5分钟），提升响应速度
    await detectInterfaces();
    // 构建缓存键
    final cacheKey = '$typeId-$year-$area-$lang-$clazz-$orderby-$page';
    final cached = _categoryCache.get(cacheKey);
    if (cached != null) return cached;

    // 1. 尝试 JgApp 插件接口 (jgappapi.index/typeFilterVodList)
    // 支持高级筛选：class, area, lang, year, sort
    try {
       // 如果标准接口已关闭（closed），则必须依赖插件
       // if (_pluginFilterOk == false) { throw Exception('plugin disabled'); }
       
       // 转换排序参数为中文标识，匹配 JgApp 插件的 switch case
       String sortParam = '最新'; // 默认最新
       if (orderby == 'hits' || orderby == '最热') sortParam = '最热';
       else if (orderby == 'score' || orderby == '最赞') sortParam = '最赞';
       else if (orderby.contains('hits_day')) sortParam = '日榜';
       else if (orderby.contains('hits_week')) sortParam = '周榜';
       else if (orderby.contains('hits_month')) sortParam = '月榜';
       
       final params = {
         'page': page,
         'limit': limit,
         'pagesize': limit,
         'sort': sortParam,
       };
       
       if (typeId != null) params['type_id'] = typeId;
       if (year != null && year != '全部') params['year'] = year;
       if (area != null && area != '全部') params['area'] = area;
       if (lang != null && lang != '全部') params['lang'] = lang;
       if (clazz != null && clazz != '全部') params['class'] = clazz;
       
       // print('Filter Request: jgappapi.index/typeFilterVodList params=$params');
       
       final resp = await _dio.get('jgappapi.index/typeFilterVodList', queryParameters: params);
       if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
          dynamic data = resp.data['data'];
          // 兼容：如果 data 是 Base64 字符串，先解码得到 JSON
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
                'remarks': v['vod_remarks'] ?? '', // 新增字段
                'blurb': v['vod_blurb'] ?? v['vod_content'] ?? '', // 新增字段
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

    // 2. 优先使用 app_api.php 的高级筛选接口
    final customApiUrl = '${_rootUrl}app_api.php';
    try {
       if (_customApiOk == false) { throw Exception('custom disabled'); }
       final params = {
         'ac': 'list',
         'pg': page,
         'pagesize': limit,
         'by': orderby,
       };
       if (typeId != null) params['t'] = typeId;
       if (year != null && year != '全部') params['year'] = year;
       if (area != null && area != '全部') params['area'] = area;
       if (lang != null && lang != '全部') params['lang'] = lang;
       if (clazz != null && clazz != '全部') params['class'] = clazz;
       
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
            // 客户端二次校验分类ID
            final validated = _filterByTypeId(typeId, results);
            _categoryCache.set(cacheKey, validated);
            return validated;
          }
       }
    } catch (_) {
      // 忽略错误，降级处理
    }

    // 兜底：无论是否带有高级筛选参数，若前两个接口失败或无数据，
    // 使用标准API返回“分类+排序”的列表，避免出现白板
    // 修复：如果标准接口 closed，则不尝试
    if (_standardApiOk != false) {
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

  /// 开发者：杰哥
  /// 作用：对外暴露接口健康状态（给调试入口或页面诊断用）
  /// 解释：告诉你现在后端哪几个接口能用。
  Future<Map<String, bool>> getInterfaceStatus() async {
    return await detectInterfaces(force: true);
  }

  /// 运行环境标识：用于播放器选择
  bool get isWeb => kIsWeb;

  // ================= 评论与弹幕相关 =================
  
  Future<List<Map<String, dynamic>>> getComments(String vodId) async {
    await init();
    
    // 1. 尝试 JgApp 插件接口
    try {
       final resp = await _dio.get('jgappapi.index/commentList', queryParameters: {'vod_id': vodId});
       if (resp.data['code'] == 1) {
          final list = (resp.data['data']['comment_list'] as List);
          return list.map((c) => {
             'id': c['comment_id'],
             'name': c['user_name'] ?? '匿名',
             'content': c['comment_content'] ?? '',
             'time': c['time_str'] ?? '',
             'avatar': _fixUrl(c['user_avatar']),
             'is_top': (c['comment_top']?.toString() == '1' || c['is_top']?.toString() == '1'),
          }).toList();
       }
    } catch (_) {}

    final customApiUrl = '${_rootUrl}app_api.php';
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
             'name': m['name'] ?? m['user_name'] ?? '匿名',
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

  Future<bool> sendComment(String vodId, String content, String nickname) async {
    await init();
    
    // 1. 尝试 JgApp 插件接口
    try {
      final resp = await _dio.post('jgappapi.index/sendComment', data: {
        'vod_id': vodId,
        'comment': content,
      });
      if (resp.data['code'] == 1) {
         return true;
      }
    } catch (_) {}

    // 2. 降级：app_api.php
    final customApiUrl = '${_rootUrl}app_api.php';
    try {
      final resp = await _dio.post(customApiUrl, queryParameters: {'ac': 'add_comment'}, data: {
        'rid': vodId,
        'content': content,
        'name': nickname,
      });
      return resp.data['code'] == 1;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendDanmaku(String vodId, String content, {String color = '#FFFFFF', int time = 0}) async {
    await init();
    try {
      final resp = await _dio.post('jgappapi.index/sendDanmu', data: {
        'vod_id': vodId,
        'danmu': content,
        'color': color,
        'time': time,
        'url_position': 0, // 默认第一个播放源
      });
      return resp.data['code'] == 1;
    } catch (_) {
      return false;
    }
  }

  /// 开发者：杰哥
  /// 作用：提交用户反馈（jgapp 插件 suggest 接口）
  /// 解释：把你遇到的问题或建议发给后台。
  Future<bool> sendSuggest(String content) async {
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

  /// 开发者：杰哥
  /// 作用：提交求片（jgapp 插件 find 接口）
  /// 解释：找不到的片子在这里告诉后台。
  Future<bool> sendFind({required String name, String remark = ''}) async {
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

  /// 开发者：杰哥
  /// 作用：单个影片催更（jgapp 插件 requestUpdate 接口）
  /// 解释：在详情页点击“催更”，告诉后台快点更新这一部。
  Future<Map<String, dynamic>> requestUpdate(String vodId) async {
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
           'msg': resp.data['msg']?.toString() ?? '未知错误',
         };
      }
      return {'success': false, 'msg': '网络请求失败: ${resp.statusCode}'};
    } catch (e) {
      return {'success': false, 'msg': '请求异常: $e'};
    }
  }

  /// 开发者：杰哥
  /// 作用：获取系统公告列表（jgapp 插件 noticeList 接口）
  /// 解释：拉取后台配置的公告，用于“消息中心-公告”。
  Future<List<Map<String, dynamic>>> getNoticeList({int page = 1}) async {
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

  /// 开发者：杰哥
  /// 作用：获取单条系统公告详情
  /// 解释：点公告列表的一条，展示完整内容。
  Future<Map<String, dynamic>?> getNoticeDetail(int noticeId) async {
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

  /// 开发者：杰哥
  /// 作用：获取个人消息统计（jgapp 插件 userNoticeType）
  /// 解释：后台返回“反馈未读数/求片未读数”，用于消息中心红点。
  Future<Map<String, int>> getUserNoticeTypes() async {
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

  /// 开发者：杰哥
  /// 作用：获取个人消息列表（jgapp 插件 userNoticeList）
  /// 解释：显示后台针对你的反馈/求片的回复记录。
  Future<List<Map<String, dynamic>>> getUserNoticeList({
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

  /// 开发者：杰哥
  /// 作用：获取邀请记录数据（jgapp 插件 inviteLogs）
  /// 解释：查看你通过邀请码邀请了多少人，以及积分规则说明。
  Future<Map<String, dynamic>> getInviteLogs({int page = 1}) async {
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

  /// 开发者：杰哥
  /// 作用：获取积分记录（jgapp 插件 userPointsLogs）
  /// 解释：看到积分的获得与消费记录。
  Future<Map<String, dynamic>> getUserPointsLogs({int page = 1}) async {
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
          'user_name': user['user_nick_name'] ?? user['user_name'] ?? '用户',
          'group_name': user['group_name'] ?? '普通会员',
          'user_points': int.tryParse('${user['user_points'] ?? 0}') ?? 0,
          'user_id': user['user_id'],
          'user_portrait': _fixUrl(user['user_portrait']),
        };
      }
    } catch (_) {}
    return null;
  }

  /// 开发者：杰哥
  /// 作用：获取我的页面信息（jgapp 插件 mineInfo）
  /// 解释：获取用户基本信息和未读消息数量，用于我的页面展示。
  Future<Map<String, dynamic>?> getMineInfo() async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/mineInfo');
      if (resp.statusCode == 200 && resp.data is Map && (resp.data['code'] == 1)) {
        final data = resp.data['data'] as Map?;
        final user = (data?['user'] as Map?) ?? <String, dynamic>{};
        return {
          'user_info': user,
          'user_notice_unread_count': data?['user_notice_unread_count'] ?? 0,
          'user_name': user['user_nick_name'] ?? user['user_name'] ?? '用户',
          'user_points': int.tryParse('${user['user_points'] ?? 0}') ?? 0,
          'group_name': user['group_name'] ?? '普通会员',
          'user_portrait': _fixUrl(user['user_portrait']),
          'is_vip': user['group_id'] != null && int.tryParse('${user['group_id']}') != 3, // 非普通会员组即为VIP
        };
      }
    } catch (_) {}
    return null;
  }


  /// 开发者：杰哥
  /// 作用：获取用户消息列表（jgapp 插件 userNoticeList）
  /// 解释：获取用户的系统消息和通知。
  Future<List<Map<String, dynamic>>> getUserNotices({int page = 1, int limit = 20}) async {
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

  /// 开发者：杰哥
  /// 作用：获取会员中心数据（jgapp 插件 userVipCenter）
  /// 解释：展示当前会员状态和可购买的会员套餐。
  Future<Map<String, dynamic>?> getUserVipCenter() async {
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

  /// 开发者：杰哥
  /// 作用：检查版本更新（jgapp 插件 appUpdate/appUpdateV2）
  /// 解释：点“检查升级”时向后台问一下有没有新版本。
  Future<Map<String, dynamic>?> getAppUpdate() async {
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

  /// 开发者：杰哥
  /// 作用：购买会员（jgapp 插件 userBuyVip）
  /// 解释：根据后台配置的套餐扣积分开通 VIP。
  Future<Map<String, dynamic>> buyVip({required int index}) async {
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
      'msg': '购买失败，请稍后重试',
      'user': <String, dynamic>{},
    };
  }

  /// 开发者：杰哥
  /// 作用：修改密码（jgapp 插件 modifyPassword）
  Future<Map<String, dynamic>> modifyPassword(String oldPwd, String newPwd) async {
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
      return {'success': false, 'msg': '请求失败'};
    } catch (e) {
      return {'success': false, 'msg': '$e'};
    }
  }

  /// 开发者：杰哥
  /// 作用：修改昵称（jgapp 插件 modifyUserNickName）
  Future<bool> modifyUserNickName(String nickname) async {
    await init();
    try {
      final resp = await _dio.post(
        'jgappapi.index/modifyUserNickName',
        data: {'user_nick_name': nickname},
        options: Options(contentType: Headers.formUrlEncodedContentType, headers: _headers),
      );
      if (resp.data['code'] == 1) {
        // 更新本地缓存
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', nickname);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 开发者：杰哥
  /// 作用：上传头像（jgapp 插件 appAvatarUpload）
  Future<Map<String, dynamic>> uploadAvatar(FormData formData) async {
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

  /// 开发者：杰哥
  /// 作用：观看激励视频获取奖励（jgapp 插件 watchRewardAd）
  Future<Map<String, dynamic>> watchRewardAd() async {
    await init();
    try {
      // 临时方案：直接请求，期望后端有宽容处理
      final resp = await _dio.post(
        'jgappapi.index/watchRewardAd',
        data: {'data': ''}, // 传空data
        options: Options(contentType: Headers.formUrlEncodedContentType, headers: _headers),
      );
      if (resp.data is Map && resp.data['code'] == 1) {
         return {'success': true, 'points': resp.data['data']['points'] ?? 0};
      }
      return {'success': false, 'msg': resp.data['msg'] ?? '需要客户端配置AES加密密钥'};
    } catch (_) {
      return {'success': false, 'msg': '请求失败'};
    }
  }
  
  /// 开发者：杰哥
  /// 作用：举报评论
  Future<bool> reportComment(String commentId) async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/commentTipOff', queryParameters: {'comment_id': commentId});
      return resp.data['code'] == 1;
    } catch (_) {
      return false;
    }
  }

  /// 开发者：杰哥
  /// 作用：举报弹幕
  Future<bool> reportDanmu(String danmuId) async {
    await init();
    try {
      final resp = await _dio.get('jgappapi.index/danmuReport', queryParameters: {'danmu_id': danmuId});
      return resp.data['code'] == 1;
    } catch (_) {
      return false;
    }
  }

  /// 获取云端弹幕 (支持 DPlayer/Danmaku 协议)
  /// 优先使用后台配置的接口，其次尝试硬编码的源
  Future<List<Map<String, dynamic>>> getCloudDanmaku(String videoUrl) async {
    // 1. 获取后台配置的弹幕接口 (建议在后台 APP配置 -> 自定义参数 中添加 danmaku_api)
    final configApi = appConfig['danmaku_api']?.toString() ?? '';
    
    final cloudApis = <String>[];
    if (configApi.isNotEmpty) {
      cloudApis.add(configApi);
    }
    
    // 2. 添加默认源 (作为兜底)
    // cloudApis.add('https://api.danmu.icu/api.php');
    
    for (final api in cloudApis) {
      try {
        // ... (rest of the logic)
        final resp = await _dio.get(api, queryParameters: {'id': videoUrl});
        
        // 解析 DPlayer 格式
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
        // 解析 XML 格式 (Bilibili 风格) - 暂略，需要 xml parser
      } catch (e) {
        // print('Cloud Danmaku Error ($api): $e');
      }
    }
    return [];
  }
}
