import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  // 🚀 أول ما يشتغل التطبيق، رح يستدعي دالة القراءة من الذاكرة
  ThemeProvider() {
    _loadTheme();
  }

  // 🚀 دالة تبديل الثيم
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveTheme(_isDarkMode); // حفظ الخيار الجديد فوراً
    notifyListeners();
  }

  // 🚀 دالة القراءة من الذاكرة الدائمة
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // إذا ما كان في قيمة محفوظة مسبقاً، رح يعتبرها false (فاتح)
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners(); // تحديث الواجهة بعد قراءة الذاكرة
  }

  // 🚀 دالة الحفظ في الذاكرة الدائمة
  Future<void> _saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }
}