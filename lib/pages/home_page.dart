import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // مكتبة الـ Provider

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

  @override
  void initState() {
    super.initState();
    loadCycle();
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

  @override
  Widget build(BuildContext context) {
    // مراقبة حالة الوضع الليلي من الـ Provider لتغيير أيقونة الزر
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      // جعل الخلفية تتبع ثيم النظام الحالي تلقائياً
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
        title: Text(
          widget.role == "manager" ? "لوحة المدير" : "لوحة المشرف",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          // زر قلب الوضع الليلي / الفاتح بشكل اختياري
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
            // Header Section
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
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
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

  // تعديل الـ Card Builder ليستقبل حالة الـ Dark Mode ويغير ألوانه تلقائياً
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