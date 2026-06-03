import 'package:dio/dio.dart';
import 'dart:convert'; // Import dart:convert

void main() async {
  print('Starting API Test...');
  
  // 模拟 App 中的逻辑
  String baseUrl = 'https://ys.ddgg888.my/api.php';
  if (!baseUrl.endsWith('/')) {
    baseUrl += '/';
  }
  
  print('Base URL: $baseUrl');

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: { 'Content-Type': 'application/json' },
    // Force response type to plain text to handle all cases manually or let Dio handle it
    // responseType: ResponseType.plain, 
  ));

  try {
    print('Requesting: ${baseUrl}provide/vod/?ac=list&at=json&pg=1&pagesize=20&by=hits_week');
    
    final resp = await dio.get('provide/vod/', queryParameters: {
      'ac': 'list',
      'pg': 1,
      'pagesize': 20,
      'by': 'hits_week',
      'at': 'json',
    });

    print('Response Status: ${resp.statusCode}');
    print('Response Data Type: ${resp.data.runtimeType}');
    
    if (resp.statusCode == 200) {
      dynamic data = resp.data;
      
      // Manual parsing fix
      if (data is String) {
        print('⚠️ Response is String, attempting to parse JSON...');
        try {
          data = jsonDecode(data);
          print('✅ JSON Parse Success!');
        } catch (e) {
          print('❌ JSON Parse Error: $e');
        }
      }

      if (data is Map) {
        if (data.containsKey('list')) {
           final list = data['list'];
           if (list is List) {
             print('✅ Success! Found ${list.length} videos.');
             if (list.isNotEmpty) {
               print('First video example: ${list[0]['vod_name']}');
             }
           } else {
             print('❌ Error: "list" is not a List. It is ${list.runtimeType}');
           }
        } else {
          print('❌ Error: Response does not contain "list" key.');
          print('Keys found: ${data.keys}');
        }
      } else {
        print('❌ Error: Response data is not a Map (JSON). It is ${data.runtimeType}');
        print('Content preview: ${data.toString().substring(0, 100)}...');
      }
    } else {
      print('❌ Error: HTTP Status ${resp.statusCode}');
    }

  } catch (e) {
    print('❌ Exception Occurred: $e');
    if (e is DioException) {
      print('Dio Message: ${e.message}');
      if (e.response != null) {
        print('Server Response: ${e.response?.data}');
      }
    }
  }
}
