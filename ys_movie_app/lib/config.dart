/**
 * 开发者：杰哥
 * 作用：App 全局配置文件
 * 小白解释：在这里修改你的服务器地址，App 就会连接到你的网站。
 */
class AppConfig {
  // =========================================================
  // 请在这里修改你的服务器地址
  // 注意：必须以 http:// 或 https:// 开头，不要以 / 结尾
  // 当前使用的后端地址为：http://pay.ddgg888.my/api.php
  // =========================================================
  static const String baseUrl = 'http://pay.ddgg888.my/api.php';

  static const String appName = '狐狸影视';
  static const bool overrideSourceName = false;
  static const bool useStaticCategories = true;
  static const List<Map<String, Object>> staticCategories = [
    {'type_id': 1, 'type_name': '电影'},
    {'type_id': 2, 'type_name': '电视剧'},
    {'type_id': 3, 'type_name': '综艺'},
    {'type_id': 4, 'type_name': '动漫'},
    {'type_id': 5, 'type_name': '短剧'},
  ];
}
