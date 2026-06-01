import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
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

  // 🚀 متغير للتحقق إذا كان المشرف الحالي هو بالأساس مدير (God Mode)
  bool isAlsoManager = false;

  @override
  void initState() {
    super.initState();
    loadCycle(); 
    _setupNotifications(); 
    _checkIfManager(); // التحقق الصامت بالخلفية
  }

  // 🚀 دالة الفحص: تتأكد هل الحساب الأساسي هو حساب مدير؟
  Future<void> _checkIfManager() async {
    String realUid = FirebaseAuth.instance.currentUser?.uid ?? widget.uid;
    
    if (widget.role == "manager") {
      if (mounted) setState(() => isAlsoManager = true);
    } else {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(realUid).get();
        if (doc.exists && mounted) {
          setState(() => isAlsoManager = true);
        }
      } catch (e) {
        print("خطأ في التحقق من الإدارة: $e");
      }
    }
  }

  // 🚀 نافذة اختيار المشرفين للمدير
  void _showSupervisorsList(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff1e293b) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Text("الدخول كـ مشرف", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
              const SizedBox(height: 10),
              Text("اختر المشرف الذي تود إدارة حسابه:", style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo')),
              const SizedBox(height: 15),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('supervisors').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text("لا يوجد مشرفين", style: TextStyle(fontFamily: 'Cairo')));
                    
                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var sup = docs[index].data() as Map<String, dynamic>;
                        String supId = docs[index].id;
                        String name = sup['name'] ?? 'مشرف';
                        String phone = sup['phone'] ?? '';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.2),
                              child: Icon(Icons.person, color: primaryColor),
                            ),
                            title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87)),
                            subtitle: Text(phone, style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                            trailing: Icon(Icons.login_rounded, color: accentGold),
                            onTap: () => _impersonateSupervisor(supId),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // 🚀 تنفيذ الدخول لحساب المشرف
  void _impersonateSupervisor(String supId) async {
    Navigator.pop(context); // إغلاق القائمة
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'supervisor');
    await prefs.setString('userId', supId); // نوهم التطبيق أن الـ ID الحالي هو للمشرف

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage(uid: supId, role: 'supervisor')),
    );
  }

  // 🚀 العودة للوحة الإدارة
  void _returnToManager() async {
    String realUid = FirebaseAuth.instance.currentUser?.uid ?? widget.uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'manager');
    await prefs.setString('userId', realUid);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage(uid: realUid, role: 'manager')),
    );
  }

  Future<void> _setupNotifications() async {
    try {
      String realUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      // 🛡️ حماية أمنية: لا تقم بتحديث توكن الإشعارات إذا كان المدير متخفياً كحساب مشرف
      if (widget.uid != realUid && widget.role == 'supervisor') return;

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      String? token = await messaging.getToken();
      if (token != null) {
        final String currentCollection = widget.role == "manager" ? "users" : "supervisors";
        await FirebaseFirestore.instance.collection(currentCollection).doc(widget.uid).set(
          {'fcmToken': token}, SetOptions(merge: true) 
        );
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

  logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _updateManagerImage() async {
    setState(() => _isUploadingManagerImage = true);
    try {
      String? url = await CloudinaryHelper.pickAndUploadProfileImage();
      if (url != null) {
        await FirebaseFirestore.instance.collection(widget.role == "manager" ? "users" : "supervisors").doc(widget.uid).set({'imageUrl': url}, SetOptions(merge: true));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث الصورة بنجاح 🎉", style: TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      print("خطأ في رفع الصورة: $e");
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
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo'),
        ),
        actions: [
          // 🚀 زر الدخول لحسابات المشرفين (يظهر للمدير فقط في وضع الإدارة)
          if (widget.role == "manager")
            IconButton(
              icon: Icon(Icons.people_alt_rounded, color: isDark ? accentGold : primaryColor),
              tooltip: "الدخول كـ مشرف",
              onPressed: () => _showSupervisorsList(isDark),
            ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? Colors.orangeAccent : primaryColor),
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
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)], 
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(top: -50, left: -50, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)))),
          Positioned(top: 200, right: -80, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? accentGold.withOpacity(0.1) : accentGold.withOpacity(0.15)))),

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
                              String? currentName;
                              if (snapshot.hasData && snapshot.data!.exists) {
                                var userData = snapshot.data!.data() as Map<String, dynamic>?;
                                imageUrl = userData?['imageUrl'];
                                currentName = userData?['name'];
                              }

                              return Column(
                                children: [
                                  GestureDetector(
                                    onTap: !_isUploadingManagerImage ? _updateManagerImage : null,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 42,
                                          backgroundColor: isDark ? Colors.white12 : Colors.white54,
                                          backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                                          child: (imageUrl == null || imageUrl.isEmpty) && !_isUploadingManagerImage ? Icon(Icons.person, size: 45, color: isDark ? Colors.white : primaryColor) : null,
                                        ),
                                        if (_isUploadingManagerImage) const Positioned.fill(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.white))),
                                        if (!_isUploadingManagerImage)
                                          Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 14, backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white, child: Icon(Icons.camera_alt, size: 16, color: primaryColor))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.role == "manager" ? "أهلاً مدير المعهد" : (currentName != null ? "المشرف: $currentName" : "أهلاً أيها المشرف"),
                                    style: TextStyle(color: isDark ? Colors.white : primaryColor, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                  ),
                                ],
                              );
                            },
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
                                      Text("الدورة الحالية", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700], fontFamily: 'Cairo')),
                                      Text(currentCycle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),

                    // 🚀 زر العودة للمدير (يظهر فقط إذا كان المدير داخل حساب مشرف)
                    if (isAlsoManager && widget.role == 'supervisor') ...[
                      InkWell(
                        onTap: _returnToManager,
                        borderRadius: BorderRadius.circular(20),
                        child: _buildGlassContainer(
                          isDark: isDark,
                          customColor: Colors.orangeAccent.withOpacity(isDark ? 0.2 : 0.1),
                          customBorderColor: Colors.orangeAccent.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.admin_panel_settings_rounded, color: isDark ? Colors.orangeAccent : Colors.orange.shade800, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                "العودة للوحة الإدارة",
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold, 
                                  fontFamily: 'Cairo', 
                                  color: isDark ? Colors.orangeAccent : Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

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

  Widget _buildGlassContainer({required Widget child, required bool isDark, EdgeInsetsGeometry padding = EdgeInsets.zero, Color? customColor, Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ?? (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: customBorderColor ?? (isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6)), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 15, offset: const Offset(0, 8))],
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
            Icon(icon, size: 38, color: isDark ? accentGold : primaryColor),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDark ? Colors.white.withOpacity(0.9) : primaryColor)),
          ],
        ),
      ),
    );
  }
}