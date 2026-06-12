import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart'; // تأكد من مسار خدمة الإشعارات عندك

class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  
  bool _isLoading = false;
  double _progress = 0.0;
  int _totalStudents = 0;
  int _sentCount = 0;

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: -10, end: 20).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  // 🚀 دالة الإرسال للجميع
  Future<void> _sendBroadcast() async {
    final String title = _titleController.text.trim();
    final String body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text("يرجى كتابة عنوان وتفاصيل الإعلان", style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _sentCount = 0;
    });

    try {
      // 1. جلب جميع الطلاب من قاعدة البيانات
      final QuerySnapshot studentsSnapshot = await FirebaseFirestore.instance.collection('students').get();
      _totalStudents = studentsSnapshot.docs.length;

      if (_totalStudents == 0) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. حلقة إرسال الإشعارات لجميع الطلاب
      for (var doc in studentsSnapshot.docs) {
        await NotificationService.sendAndSaveNotification(
          studentId: doc.id,
          title: title,
          body: body,
          type: 'broadcast', // نوع مخصص للإعلانات العامة
          // لم نمرر الـ context هنا حتى لا تظهر 100 رسالة نجاح في الشاشة
        );

        // تحديث شريط التقدم
        _sentCount++;
        setState(() {
          _progress = _sentCount / _totalStudents;
        });
      }

      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green, 
            content: Text("✅ تم إرسال الإعلان لجميع الطلاب بنجاح!", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("❌ حدث خطأ: $e", style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text("الإعلانات العامة", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
        centerTitle: true,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
      ),
      body: Stack(
        children: [
          // الخلفية
          Container(
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // الدوائر العائمة
          AnimatedBuilder(
            animation: _bgAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: 50 + _bgAnimation.value,
                    left: -50 - (_bgAnimation.value / 2),
                    child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12))),
                  ),
                  Positioned(
                    bottom: 100 - _bgAnimation.value,
                    right: -60 + _bgAnimation.value,
                    child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2))),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildGlassContainer(
                  isDarkMode: isDarkMode,
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_rounded, size: 60, color: isDarkMode ? accentGold : primaryColor),
                      const SizedBox(height: 15),
                      Text("إرسال إعلان للجميع", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                      const SizedBox(height: 5),
                      Text("سيصل هذا الإشعار كرسالة منبثقة ويوثق في سجلات جميع أولياء الأمور.", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white60 : Colors.black54, fontFamily: 'Cairo')),
                      const SizedBox(height: 30),

                      // حقل العنوان
                      TextField(
                        controller: _titleController,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        decoration: _glassInputDecoration("عنوان الإعلان (مثال: عطلة رسمية)", Icons.title, isDarkMode),
                      ),
                      const SizedBox(height: 15),

                      // حقل التفاصيل
                      TextField(
                        controller: _bodyController,
                        maxLines: 4,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        decoration: _glassInputDecoration("تفاصيل الإعلان أو التذكير...", Icons.message_rounded, isDarkMode),
                      ),
                      const SizedBox(height: 30),

                      // شريط التقدم أثناء الإرسال
                      if (_isLoading) ...[
                        Column(
                          children: [
                            LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: isDarkMode ? Colors.white12 : Colors.black12,
                              color: accentGold,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            const SizedBox(height: 10),
                            Text("جاري الإرسال: $_sentCount / $_totalStudents", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.black87)),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ],

                      // زر الإرسال
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _sendBroadcast,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9),
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          icon: _isLoading ? const SizedBox() : const Icon(Icons.send_rounded),
                          label: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("إرسال الإعلان للجميع", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _glassInputDecoration(String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600, fontFamily: 'Cairo', fontSize: 13),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.6), 
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDarkMode ? accentGold : primaryColor, width: 1.5)),
    );
  }
}