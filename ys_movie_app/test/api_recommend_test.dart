import 'package:dio/dio.dart';
import 'dart:convert';

void main() async {
  print('=== API 推荐数据测试 ===');

  String baseUrl = 'https://ys.ddgg888.my/api.php';
  if (!baseUrl.endsWith('/')) {
    baseUrl += '/';
  }

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  // 测试 1: jgappapi.index/init
  print('\n--- 测试 1: jgappapi.index/init ---');
  try {
    final resp = await dio.get('jgappapi.index/init');
    print('Status: ${resp.statusCode}');
    if (resp.data is Map && resp.data['code'] == 1) {
      final data = resp.data['data'] as Map? ?? {};
      final recommendList = data['recommend_list'] as List? ?? [];
      final bannerList = data['banner_list'] as List? ?? [];
      print('recommend_list: ${recommendList.length} 条');
      print('banner_list: ${bannerList.length} 条');
    } else {
      print('返回异常: ${resp.data}');
    }
  } catch (e) {
    print('错误: $e');
  }

  // 测试 2: jgappapi.index/typeFilterVodList (最新)
  print('\n--- 测试 2: jgappapi.index/typeFilterVodList (sort=最新) ---');
  try {
    final resp = await dio.get('jgappapi.index/typeFilterVodList', queryParameters: {
      'sort': '最新',
      'limit': 12,
      'page': 1,
    });
    print('Status: ${resp.statusCode}');
    if (resp.data is Map && resp.data['code'] == 1) {
      final data = resp.data['data'] as Map? ?? {};
      final list = data['recommend_list'] as List? ?? [];
      print('recommend_list: ${list.length} 条');
      if (list.isNotEmpty) {
        print('第一条: ${list[0]['vod_name']}');
      }
    } else {
      print('返回异常: ${resp.data}');
    }
  } catch (e) {
    print('错误: $e');
  }

  // 测试 3: jgappapi.index/vodLevel
  print('\n--- 测试 3: jgappapi.index/vodLevel (level=8) ---');
  try {
    final resp = await dio.get('jgappapi.index/vodLevel', queryParameters: {
      'level': 8,
      'limit': 12,
      'page': 1,
    });
    print('Status: ${resp.statusCode}');
    if (resp.data is Map && resp.data['code'] == 1) {
      final data = resp.data['data'] as Map? ?? {};
      final list = data['list'] as List? ?? [];
      print('list: ${list.length} 条');
    } else {
      print('返回异常: ${resp.data}');
    }
  } catch (e) {
    print('错误: $e');
  }

  // 测试 4: app_api.php
  print('\n--- 测试 4: app_api.php?ac=init ---');
  try {
    final resp = await dio.get('https://ys.ddgg888.my/app_api.php', queryParameters: {
      'ac': 'init',
    });
    print('Status: ${resp.statusCode}');
    print('Data: ${resp.data}');
  } catch (e) {
    print('错误: $e');
  }

  print('\n=== 测试完成 ===');
}
