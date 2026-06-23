import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quran_habal/pages/leave_requests_page.dart'; 
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
import 'honor_board_page.dart';
import 'dashboard_page.dart';
import 'daily_stats_page.dart';
import 'supervisor_page.dart';
import 'inspirations_manage_page.dart'; 
import 'supervisor_inbox_page.dart'; 
import 'statistics_page.dart'; 
import 'broadcast_page.dart'; 
import '../services/notification_queue_manager.dart'; 
import '../widgets/offline_wrapper.dart'; 

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

  bool isAlsoManager = false;

  @override
  void initState() {
    super.initState();
    loadCycle(); 
    _setupNotifications(); 
    _checkIfManager(); 
    _checkPendingNotifications(); 
  }

  void _checkPendingNotifications() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      await NotificationQueueManager.processPendingNotifications(context);
    }
  }

  void _checkIfManager() {
    String realUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (widget.role == "manager") {
      if (mounted) setState(() => isAlsoManager = true);
    } else if (realUid.isNotEmpty && realUid != widget.uid) {
      if (mounted) setState(() => isAlsoManager = true);
    } else {
      if (mounted) setState(() => isAlsoManager = false);
    }
  }

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
              Text("إدارة الحسابات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
              if (isAlsoManager && widget.role == 'supervisor') ...[
                const SizedBox(height: 15),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _returnToManager();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, color: Colors.orange.shade800),
                        const SizedBox(width: 10),
                        Text("العودة للوحة الإدارة الأساسية", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.orange.shade800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Divider(color: isDark ? Colors.white24 : Colors.black12),
              ],
              const SizedBox(height: 10),
              Text("الدخول كـ مشرف:", style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo')),
              const SizedBox(height: 10),
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
                              backgroundImage: sup['imageUrl'] != null && sup['imageUrl'].isNotEmpty ? NetworkImage(sup['imageUrl']) : null,
                              child: (sup['imageUrl'] == null || sup['imageUrl'].isEmpty) ? Icon(Icons.person, color: primaryColor) : null,
                            ),
                            title: Text(sup['name'] ?? 'مشرف', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87)),
                            subtitle: Text(sup['phone'] ?? '', style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
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

  void _impersonateSupervisor(String supId) async {
    Navigator.pop(context); 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'supervisor');
    await prefs.setString('userId', supId); 
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(uid: supId, role: 'supervisor')));
  }

  void _returnToManager() async {
    String realUid = FirebaseAuth.instance.currentUser?.uid ?? widget.uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'manager');
    await prefs.setString('userId', realUid);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(uid: realUid, role: 'manager')));
  }

  Future<void> _setupNotifications() async {
    try {
      String realUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (widget.uid != realUid && widget.role == 'supervisor') return;
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      String? token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection(widget.role == "manager" ? "users" : "supervisors").doc(widget.uid).set(
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

    return OfflineWrapper(
      child: Scaffold(
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
            if (isAlsoManager)
              IconButton(
                icon: Icon(Icons.people_alt_rounded, color: isDark ? accentGold : primaryColor),
                onPressed: () => _showSupervisorsList(isDark),
              ),
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? Colors.orangeAccent : primaryColor),
              onPressed: () => themeProvider.toggleTheme(),
            ),
            IconButton(onPressed: logout, icon: Icon(Icons.logout, color: isDark ? Colors.redAccent : Colors.red)),
          ],
        ),
        body: Stack(
          children: [
            // خلفية التدرج
            Container(
              width: double.infinity, height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)], 
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
            
            // الدوائر الخلفية (ثابتة وواضحة جداً الحين دون تغبيش يخفيها)
            Stack(
              children: [
                Positioned(
                  top: -50, left: -50,
                  child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2))),
                ),
                Positioned(
                  top: 200, right: -80,
                  child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? accentGold.withOpacity(0.1) : accentGold.withOpacity(0.15))),
                ),
              ],
            ),

            // 🚀 استخدام CustomScrollView المحترف لمنع الـ Lag نهائياً وثبات السكرول
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // جزء البروفايل العلوي (هاد بس المسموح نخليه زجاجي ثقيل لأنه ثابت وما بيأثر ع السكرول)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    sliver: SliverToBoxAdapter(
                      child: _buildRealGlassHeader(isDark, currentCollection),
                    ),
                  ),
                  
                  // شبكة الأزرار الـ 12 الموزعة بخفة وسلاسة مطلقة
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 1.1,
                      ),
                      delegate: SliverChildListDelegate([
                        if (widget.role == "manager") ...[
                          _buildPerformanceMenuCard(Icons.campaign_rounded, "إرسال إعلان للجميع", () => _nav(const BroadcastPage()), isDark),
                          _buildPerformanceMenuCard(Icons.add_circle_outline, "إنشاء دورة", () => _nav(const CreateCyclePage()), isDark),
                          _buildPerformanceMenuCard(Icons.dashboard_customize, "لوحة التحكم", () => _nav(const DashboardPage()), isDark),
                          _buildPerformanceMenuCard(Icons.view_list, "عرض الدورات", () => _nav(const CyclesPage()), isDark),
                          _buildPerformanceMenuCard(Icons.wb_sunny_rounded, "إدارة الإشراقات", () => _nav(const InspirationsManagePage()), isDark),
                          if (currentCycleModel != null)
                            _buildPerformanceMenuCard(Icons.person_add_alt_1, "إضافة طالب", () => _nav(AddStudentPage(cycle: currentCycleModel!)), isDark),
                          _buildPerformanceMenuCard(Icons.group_add, "إضافة مشرفين", () => _nav(const SupervisorPage()), isDark),
                          if (currentCycleModel != null)
                            _buildPerformanceMenuCard(Icons.shuffle, "توزيع الطلاب", () => _nav(AssignStudentsPage(cycle: currentCycleModel!)), isDark),
                        ],
                        if (currentCycleModel != null) ...[
                          _buildPerformanceMenuCard(Icons.groups, "عرض الطلاب", () => _nav(StudentsPage(cycle: currentCycleModel!, role: widget.role, uid: widget.uid)), isDark),
                          _buildPerformanceMenuCard(Icons.archive_rounded, "الطلاب المتوقفين", () => _nav(ArchivedStudentsPage(cycle: currentCycleModel!, role: widget.role, uid: widget.uid)), isDark),
                        ],
                        _buildPerformanceMenuCard(Icons.mark_chat_unread_rounded, "رسائل الأهالي", () => _nav(SupervisorInboxPage(supervisorId: widget.uid)), isDark),
                        _buildPerformanceMenuCard(Icons.pie_chart_rounded, "الإحصائيات", () => _nav(const StatisticsPage()), isDark),
                        _buildPerformanceMenuCard(Icons.query_stats, "الإحصائيات اليومية", () => _nav(const DailyStatsPage()), isDark),
                        _buildPerformanceMenuCard(Icons.workspace_premium, "لوحة الشرف", () => _nav(HonorBoardPage(role: widget.role)), isDark),
                        _buildPerformanceMenuCard(Icons.event_busy_rounded, "طلبات الاستئذان", () => _nav(LeaveRequestsPage(supervisorId: widget.uid, role: widget.role)), isDark),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 كرت البروفايل العلوي يحتفظ بالزجاج والغبش الحقيقي الفخم لأنه ثابت بالأعلى
  Widget _buildRealGlassHeader(bool isDark, String currentCollection) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
          ),
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
                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
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
      ),
    );
  }

  // 🚀 كروت الأزرار الـ 12 أصبحت خفيفة جداً بشفافية ذكية وظلال ممتازة لتبدو زجاجية تماماً وواضحة فوق الدوائر وبسرعة صاروخية!
  Widget _buildPerformanceMenuCard(IconData icon, String title, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.75), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
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

  void _nav(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250), 
      ),
    );
  }
}