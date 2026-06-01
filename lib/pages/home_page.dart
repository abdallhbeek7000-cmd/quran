import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; // 🎯 استدعاء مكتبة الذاكرة المحلية
import 'package:quran_habal/services/cloudinary_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'dart:ui'; 

import 'login_page.dart';
import 'create_cycle_page.dart';
import 'cycles_page.dart';
import 'add_student_page.dart';
import 'students_page.dart';
import 'assign_students_page.dart';
import '../models/cycle_model.dart';
import '../services/cycle_service.dart';
import '../services/theme_provider.dart'; 
import 'statistics_page.dart';
import 'honor_board_page.dart';
import 'dashboard_page.dart';
import 'daily_stats_page.dart';
import 'supervisor_page.dart';
import 'inspirations_manage_page.dart'; 
import 'supervisor_inbox_page.dart'; 

class HomePage extends StatefulWidget {
  final String uid;
  final String role;

  const HomePage({
    super.key,
    required this.uid,
    required this.role,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final cycleService = CycleService();
  String currentCycle = "لا يوجد دورة";
  CycleModel? currentCycleModel;

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); 
  bool _isUploadingManagerImage = false; 

  @override
  void initState() {
    super.initState();
    loadCycle(); 
    _setupNotifications(); 
  }

  Future<void> _setupNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      await messaging.requestPermission(
        alert: true, 
        badge: true, 
        sound: true
      );

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, 
        badge: true, 
        sound: true, 
      );

      String? token = await messaging.getToken();
      
      if (token != null) {
        final String currentCollection = widget.role == "manager" ? "users" : "supervisors";
        await FirebaseFirestore.instance.collection(currentCollection).doc(widget.uid).set(
          {'fcmToken': token}, 
          SetOptions(merge: true) 
        );
        print("✅ تم حفظ توكن الإشعارات للمشرف بنجاح!");
      }
    } catch (e) {
      print("❌ خطأ في إعداد الإشعارات: $e");
    }
  }

  loadCycle() async {
    final cycle = await cycleService.getCurrentCycle();
    if (cycle != null) {
      setState(() {
        currentCycleModel = cycle;
        currentCycle = "${cycle.name} (${cycle.cycleNumber})";
      });
    }
  }

  // 🚀 دالة الخروج بعد التعديل لتنظيف الذاكرة
  logout() async {
    // 1. مسح الذاكرة المحلية (غسيل دماغ للتطبيق لينسى الرتبة السابقة)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 

    // 2. تسجيل الخروج من الفايربيز
    await FirebaseAuth.instance.signOut();
    
    // 3. التوجيه لصفحة الدخول
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _updateManagerImage() async {
    setState(() => _isUploadingManagerImage = true);
    try {
      String? url = await CloudinaryHelper.pickAndUploadProfileImage();
      if (url != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .set({'imageUrl': url}, SetOptions(merge: true));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث صورتك الشخصية بنجاح 🎉")),
        );
      }
    } catch (e) {
      print("خطأ في رفع صورة المدير: $e");
    } finally {
      setState(() => _isUploadingManagerImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String currentCollection = widget.role == "manager" ? "users" : "supervisors";
    final bool isDark = themeProvider.isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, 
        centerTitle: true,
        title: Text(
          widget.role == "manager" ? "لوحة المدير" : "لوحة المشرف",
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.orangeAccent : primaryColor,
            ),
            tooltip: "تغيير المظهر",
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            onPressed: logout,
            icon: Icon(Icons.logout, color: isDark ? Colors.redAccent : Colors.red),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] 
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)], 
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -50, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),
          Positioned(
            top: 200, right: -80,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? accentGold.withOpacity(0.1) : accentGold.withOpacity(0.15)),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    _buildGlassContainer(
                      isDark: isDark,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection(currentCollection).doc(widget.uid).snapshots(),
                            builder: (context, snapshot) {
                              String? imageUrl;
                              if (snapshot.hasData && snapshot.data!.exists) {
                                var userData = snapshot.data!.data() as Map<String, dynamic>?;
                                imageUrl = userData?['imageUrl'];
                              }

                              return GestureDetector(
                                onTap: widget.role == "manager" && !_isUploadingManagerImage ? _updateManagerImage : null,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 42,
                                      backgroundColor: isDark ? Colors.white12 : Colors.white54,
                                      backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                                      child: (imageUrl == null || imageUrl.isEmpty) && !_isUploadingManagerImage
                                          ? Icon(Icons.person, size: 45, color: isDark ? Colors.white : primaryColor)
                                          : null,
                                    ),
                                    if (_isUploadingManagerImage)
                                      const Positioned.fill(
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: CircularProgressIndicator(color: Colors.white),
                                        ),
                                      ),
                                    if (widget.role == "manager" && !_isUploadingManagerImage)
                                      Positioned(
                                        bottom: 0, right: 0,
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
                                          child: Icon(Icons.camera_alt, size: 16, color: primaryColor),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.role == "manager" ? "أهلاً مدير المعهد" : "أهلاً أيها المشرف",
                            style: TextStyle(color: isDark ? Colors.white : primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month, color: isDark ? accentGold : primaryColor),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("الدورة الحالية", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                                      Text(
                                        currentCycle,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : primaryColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.1,
                      children: [
                        if (widget.role == "manager") ...[
                          _buildGlassMenuCard(Icons.add_circle_outline, "إنشاء دورة", () => _nav(const CreateCyclePage()), isDark),
                          _buildGlassMenuCard(Icons.dashboard_customize, "لوحة التحكم", () => _nav(const DashboardPage()), isDark),
                          _buildGlassMenuCard(Icons.view_list, "عرض الدورات", () => _nav(const CyclesPage()), isDark),
                          _buildGlassMenuCard(Icons.wb_sunny_rounded, "إدارة الإشراقات", () => _nav(const InspirationsManagePage()), isDark),
                          
                          if (currentCycleModel != null)
                            _buildGlassMenuCard(Icons.person_add_alt_1, "إضافة طالب", () => _nav(AddStudentPage(cycle: currentCycleModel!)), isDark),
                          _buildGlassMenuCard(Icons.group_add, "إضافة مشرفين", () => _nav(const SupervisorPage()), isDark),
                          if (currentCycleModel != null)
                            _buildGlassMenuCard(Icons.shuffle, "توزيع الطلاب", () => _nav(AssignStudentsPage(cycle: currentCycleModel!)), isDark),
                        ],
                        if (currentCycleModel != null)
                          _buildGlassMenuCard(Icons.groups, "عرض الطلاب", () => _nav(StudentsPage(cycle: currentCycleModel!, role: widget.role, uid: widget.uid)), isDark),
                        
                        _buildGlassMenuCard(Icons.mark_chat_unread_rounded, "رسائل الأهالي", () => _nav(SupervisorInboxPage(supervisorId: widget.uid)), isDark),

                        _buildGlassMenuCard(Icons.bar_chart, "الإحصائيات", () => _nav(const StatisticsPage()), isDark),
                        _buildGlassMenuCard(Icons.query_stats, "الإحصائيات اليومية", () => _nav(const DailyStatsPage()), isDark),
                        _buildGlassMenuCard(Icons.workspace_premium, "لوحة الشرف", () => _nav(HonorBoardPage(role: widget.role)), isDark),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nav(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildGlassContainer({required Widget child, required bool isDark, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassMenuCard(IconData icon, String title, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: _buildGlassContainer(
        isDark: isDark,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 38,
              color: isDark ? accentGold : primaryColor,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white.withOpacity(0.9) : primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}