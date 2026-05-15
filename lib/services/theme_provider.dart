import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  // الوضع الافتراضي هو الفاتح (false)
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  // دالة لقلب الوضع عند ضغط الزر
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners(); // هذا السطر يقوم بتحديث كل صفحات التطبيق فوراً
  }
}