import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PubicConfig {
  // 建立一個監聽器，讓全 App 都能接收到主題變化的通知
  static final ValueNotifier<Brightness> appBrightness = ValueNotifier(Brightness.light);

  // 儲存設定到手機本地
  static Future<void> setTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);

    // 更新監聽器的值
    appBrightness.value = isDark ? Brightness.dark : Brightness.light;
  }

  // 初始化（在 App 啟動時呼叫）
  static Future<void> initTheme() async {
    final prefs = await SharedPreferences.getInstance();
    bool isDark = prefs.getBool('isDarkMode') ?? false; // 預設淺色
    appBrightness.value = isDark ? Brightness.dark : Brightness.light;
  }
}