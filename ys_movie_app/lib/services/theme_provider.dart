import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  String _themeStyle = 'dark'; // 默认暗夜蓝（天空蓝暗色模式）

  String get themeStyle => _themeStyle;

  bool get isDark => _themeStyle == 'dark' || _themeStyle == 'blue_black' || (_themeStyle == 'system' &&  WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _themeStyle = prefs.getString('theme_style') ?? 'blue_black';
    notifyListeners();
  }

  Future<void> setThemeStyle(String style) async {
    _themeStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_style', style);
  }
  
  // 获取当前对应的 ThemeMode，用于传给 MaterialApp
  ThemeMode get themeMode {
    if (_themeStyle == 'light') return ThemeMode.light;
    if (_themeStyle == 'dark' || _themeStyle == 'blue_black') return ThemeMode.dark;
    return ThemeMode.dark; // 不再使用 system
  }
  
  // 获取特定主题的 Seed Color 或配色方案
  // 蓝色渐变黑色主题：主色调可能是蓝色，背景是黑
}
