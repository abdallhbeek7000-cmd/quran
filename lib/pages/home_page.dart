import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_page.dart';
import 'create_cycle_page.dart';
import 'cycles_page.dart';
import 'add_student_page.dart';
import 'students_page.dart';
import 'assign_students_page.dart';
import '../models/cycle_model.dart';
import '../services/cycle_service.dart';
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: Text(
          widget.role == "manager" ? "لوحة المدير" : "لوحة المشرف",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout, color: Colors.white),
          )
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
                color: primaryColor,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: primaryColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("الدورة الحالية", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(currentCycle, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
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
                    _buildMenuCard(Icons.add_circle_outline, "إنشاء دورة", () => _nav(const CreateCyclePage())),
                    _buildMenuCard(Icons.dashboard_customize, "لوحة التحكم", () => _nav(const DashboardPage())),
                    _buildMenuCard(Icons.view_list, "عرض الدورات", () => _nav(const CyclesPage())),
                    if (currentCycleModel != null)
                      _buildMenuCard(Icons.person_add_alt_1, "إضافة طالب", () => _nav(AddStudentPage(cycle: currentCycleModel!))),
                    _buildMenuCard(Icons.group_add, "إضافة مشرفين", () => _nav(const SupervisorPage())),
                    if (currentCycleModel != null)
                      _buildMenuCard(Icons.shuffle, "توزيع الطلاب", () => _nav(AssignStudentsPage(cycle: currentCycleModel!))),
                  ],

                  // Common Actions
                  if (currentCycleModel != null)
                    _buildMenuCard(Icons.groups, "عرض الطلاب", () => _nav(StudentsPage(cycle: currentCycleModel!, role: widget.role, uid: widget.uid))),
                  
                  _buildMenuCard(Icons.bar_chart, "الإحصائيات", () => _nav(const StatisticsPage())),
                  _buildMenuCard(Icons.query_stats, "الإحصائيات اليومية", () => _nav(const DailyStatsPage())),
                  _buildMenuCard(Icons.workspace_premium, "لوحة الشرف", () => _nav(const HonorBoardPage())),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function for Navigation
  void _nav(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // Modern Card Builder
  Widget _buildMenuCard(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 35, color: primaryColor),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}