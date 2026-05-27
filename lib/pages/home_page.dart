import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // مكتبة الـ Provider
import 'package:cloud_firestore/cloud_firestore.dart'; // مكتبة الفايرستور
import 'package:quran_habal/services/cloudinary_helper.dart';

import 'login_page.dart';
import 'create_cycle_page.dart';
import 'cycles_page.dart';
import 'add_student_page.dart';
import 'students_page.dart';
import 'assign_students_page.dart';
import '../models/cycle_model.dart';
import '../services/cycle_service.dart';
import '../services/theme_provider.dart'; // استدعاء الـ ThemeProvider
import 'statistics_page.dart';
import 'honor_board_page.dart';
import 'dashboard_page.dart';
import 'daily_stats_page.dart';
import 'supervisor_page.dart';
import 'update_checker.dart'; // 🎯 استدعاء ملف الفحص لضمان طيران التحديثات لايف


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
  bool _isUploadingManagerImage = false; // لمؤشر تحميل رفع صورة المدير

  @override
  void initState() {
    super.initState();
    loadCycle();

    // 🎯 تشغيل فحص التحديث أوتوماتيكياً بأمان للمشرفين والمدير بعد بناء الواجهة فوراً
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates(context);
    });
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
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // دالة مخصصة للمدير لرفع وتحديث صورته الشخصية
  Future<void> _updateManagerImage() async {
    setState(() => _isUploadingManagerImage = true);
    try {
      String? url = await CloudinaryHelper.pickAndUploadProfileImage();
      if (url != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .set({'imageUrl': url}, SetOptions(merge: true)); // حفظ أو دمج الحقل في مستند المدير

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

    // تحديد الـ Collection والمسار بناءً على دور المستخدم الحالي بشكل ديناميكي
    final String currentCollection = widget.role == "manager" ? "users" : "supervisors";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
        title: Text(
          widget.role == "manager" ? "لوحة المدير" : "لوحة المشرف",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            tooltip: "تغيير المظهر",
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section المعدل بالكامل لدعم الـ Streams والصور الشخصية
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // استخدام StreamBuilder لسحب وعرض الصورة فوراً وبشكل لحظي
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(currentCollection)
                        .doc(widget.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      String? imageUrl;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        var userData = snapshot.data!.data() as Map<String, dynamic>?;
                        imageUrl = userData?['imageUrl'];
                      }

                      return GestureDetector(
                        // التفعيل للمدير فقط، وتعطيله للمشرف
                        onTap: widget.role == "manager" && !_isUploadingManagerImage
                            ? _updateManagerImage
                            : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white24,
                              backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                                  ? NetworkImage(imageUrl)
                                  : null,
                              child: (imageUrl == null || imageUrl.isEmpty) && !_isUploadingManagerImage
                                  ? const Icon(Icons.person, size: 45, color: Colors.white)
                                  : null,
                            ),
                            if (_isUploadingManagerImage)
                              const Positioned.fill(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                              ),
                            // أيقونة الكاميرا الصغيرة لإعلام المدير بإمكانية التعديل
                            if (widget.role == "manager" && !_isUploadingManagerImage)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                  child: Icon(Icons.camera_alt, size: 14, color: primaryColor),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.role == "manager" ? "أهلاً مدير المعهد" : "أهلاً أيها المشرف",
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  
                  // Current Cycle Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: themeProvider.isDarkMode ? Colors.orange : primaryColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("الدورة الحالية", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                currentCycle, 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  color: themeProvider.isDarkMode ? Colors.white : primaryColor,
                                ),
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

            Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.1,
                children: [
                  // Manager Only Actions
                  if (widget.role == "manager") ...[
                    _buildMenuCard(Icons.add_circle_outline, "إنشاء دورة", () => _nav(const CreateCyclePage()), themeProvider.isDarkMode),
                    _buildMenuCard(Icons.dashboard_customize, "لوحة التحكم", () => _nav(const DashboardPage()), themeProvider.isDarkMode),
                    _buildMenuCard(Icons.view_list, "عرض الدورات", () => _nav(const CyclesPage()), themeProvider.isDarkMode),
                    if (currentCycleModel != null)
                      _buildMenuCard(Icons.person_add_alt_1, "إضافة طالب", () => _nav(AddStudentPage(cycle: currentCycleModel!)), themeProvider.isDarkMode),
                    _buildMenuCard(Icons.group_add, "إضافة مشرفين", () => _nav(const SupervisorPage()), themeProvider.isDarkMode),
                    if (currentCycleModel != null)
                      _buildMenuCard(Icons.shuffle, "توزيع الطلاب", () => _nav(AssignStudentsPage(cycle: currentCycleModel!)), themeProvider.isDarkMode),
                  ],

                  // Common Actions
                  if (currentCycleModel != null)
                    _buildMenuCard(Icons.groups, "عرض الطلاب", () => _nav(StudentsPage(cycle: currentCycleModel!, role: widget.role, uid: widget.uid)), themeProvider.isDarkMode),
                  
                  _buildMenuCard(Icons.bar_chart, "الإحصائيات", () => _nav(const StatisticsPage()), themeProvider.isDarkMode),
                  _buildMenuCard(Icons.query_stats, "الإحصائيات اليومية", () => _nav(const DailyStatsPage()), themeProvider.isDarkMode),
                  _buildMenuCard(Icons.workspace_premium, "لوحة الشرف", () => _nav(HonorBoardPage(role: widget.role)), themeProvider.isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nav(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildMenuCard(IconData icon, String title, VoidCallback onTap, bool isDarkMode) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05), 
              blurRadius: 10, 
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              size: 35, 
              color: isDarkMode ? Colors.orange : primaryColor,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.bold, 
                color: isDarkMode ? Colors.white : primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}