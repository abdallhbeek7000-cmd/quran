import 'package:flutter/material.dart';
import 'network_sync_indicator.dart';

class MyCustomScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final bool isDarkMode;
  final List<Widget>? actions;

  const MyCustomScaffold({
    super.key, 
    required this.title, 
    required this.body, 
    required this.isDarkMode,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          NetworkSyncIndicator(isDarkMode: isDarkMode), // 🚀 موجودة أوتوماتيكياً بكل الصفحات!
          ...?actions, // أي أزرار إضافية خاصة بالصفحة بتنضاف هون
        ],
      ),
      body: body,
    );
  }
}