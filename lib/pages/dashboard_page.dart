import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/theme_provider.dart';
import '../widgets/offline_wrapper.dart';
import 'edit_student_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDarkMode ? const Color(0xff0f172a) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "إحصائيات المعهد 📊",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : primaryColor,
            fontFamily: 'Cairo',
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -30,
            left: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.14),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode ? primaryColor.withOpacity(0.18) : primaryColor.withOpacity(0.22),
              ),
            ),
          ),

          SafeArea(
            child: FutureBuilder<List<dynamic>>(
              future: Future.wait([
                FirebaseFirestore.instance.collection('students').where('archived', isEqualTo: false).get(),
                FirebaseFirestore.instance.collection('supervisors').get(),
                FirebaseFirestore.instance.collection('sessions').get(),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = (snapshot.data![0] as QuerySnapshot).docs;
                final supervisors = (snapshot.data![1] as QuerySnapshot).docs;
                final sessions = (snapshot.data![2] as QuerySnapshot).docs;

                int absentCount = 0;
                int noSupervisor = 0;

                for (var s in sessions) {
                  final data = s.data() as Map<String, dynamic>;
                  if (data['absent'] == true) absentCount++;
                }

                for (var s in students) {
                  final data = s.data() as Map<String, dynamic>;
                  if (data['supervisorId'] == null || data['supervisorId'].toString().trim().isEmpty) noSupervisor++;
                }

                int totalStudents = students.length;
                int assignedStudents = totalStudents - noSupervisor;
                double assignedPercentage = totalStudents > 0 ? (assignedStudents / totalStudents) : 0.0;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(isDarkMode),

                      const SizedBox(height: 15),

                      _buildProgressSummaryCard(
                        totalStudents: totalStudents,
                        assignedStudents: assignedStudents,
                        percentage: assignedPercentage,
                        isDarkMode: isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 1.05,
                        children: [
                          _buildGlassStatCard(
                            title: "إجمالي الطلاب",
                            value: totalStudents.toString(),
                            subtitle: "نشطون في الدورة",
                            icon: Icons.people_alt_rounded,
                            color: isDarkMode ? Colors.lightBlueAccent : Colors.blue.shade600,
                            isDarkMode: isDarkMode,
                          ),
                          
                          InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SupervisorsStudentsCountPage()),
                              );
                            },
                            child: _buildGlassStatCard(
                              title: "المشرفين",
                              value: supervisors.length.toString(),
                              subtitle: "اضغط للتوزيع 👥",
                              icon: Icons.admin_panel_settings_rounded,
                              color: isDarkMode ? accentGold : Colors.amber.shade700,
                              isDarkMode: isDarkMode,
                            ),
                          ),

                          _buildGlassStatCard(
                            title: "إجمالي الجلسات",
                            value: sessions.length.toString(),
                            subtitle: "جلسة موثقة 📖",
                            icon: Icons.auto_stories_rounded,
                            color: Colors.greenAccent.shade700,
                            isDarkMode: isDarkMode,
                          ),
                          
                          InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AllAbsentStudentsSummaryPage()),
                              );
                            },
                            child: _buildGlassStatCard(
                              title: "طلاب غائبون",
                              value: absentCount.toString(),
                              subtitle: "عرض السجل 🚨",
                              icon: Icons.person_off_rounded,
                              color: Colors.redAccent.shade200,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),

                      // 🏅 زر الانتقال لإحصائية أكثر المشرفين تسجيلاً للجلسات
                      InkWell(
                        borderRadius: BorderRadius.circular(25),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TopSessionSupervisorsPage()),
                          );
                        },
                        child: _buildGlassContainer(
                          isDarkMode: isDarkMode,
                          padding: const EdgeInsets.all(18),
                          customColor: isDarkMode ? Colors.amber.withOpacity(0.12) : Colors.amber.withOpacity(0.18),
                          customBorderColor: accentGold.withOpacity(0.6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: accentGold.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.workspace_premium_rounded, color: isDarkMode ? accentGold : Colors.amber.shade900, size: 30),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "أكثر المشرفين تسميعاً 🏆",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isDarkMode ? Colors.white : primaryColor,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "ترتيب المشرفين بحسب إجمالي الجلسات المسجلة",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode ? Colors.white70 : Colors.black54,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, color: isDarkMode ? accentGold : primaryColor, size: 16),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      InkWell(
                        borderRadius: BorderRadius.circular(25),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UnassignedStudentsPage()),
                          );
                        },
                        child: _buildGlassContainer(
                          isDarkMode: isDarkMode,
                          padding: const EdgeInsets.all(18),
                          customColor: isDarkMode ? Colors.orange.withOpacity(0.12) : Colors.orange.withOpacity(0.18),
                          customBorderColor: Colors.orange.withOpacity(0.5),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "طلاب يحتاجون مشرف",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isDarkMode ? Colors.white : primaryColor,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      noSupervisor > 0 
                                          ? "هناك $noSupervisor طالباً ينتظرون التوزيع"
                                          : "تم توزيع جميع الطلاب بنجاح 🎉",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode ? Colors.white70 : Colors.black54,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8)
                                  ],
                                ),
                                child: Text(
                                  noSupervisor.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      _buildNotesSection(isDarkMode),

                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "نظرة عامة 👑", 
          style: TextStyle(
            color: isDarkMode ? Colors.white : primaryColor,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        Text(
          "إليك أحدث الإحصائيات والأداء العام للمعهد لهذه الدورة", 
          style: TextStyle(
            color: isDarkMode ? Colors.white60 : Colors.grey[700],
            fontSize: 13,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSummaryCard({
    required int totalStudents,
    required int assignedStudents,
    required double percentage,
    required bool isDarkMode,
  }) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart_rounded, color: isDarkMode ? accentGold : primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "مؤشر توزيع الطلاب",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : primaryColor,
                    ),
                  ),
                ],
              ),
              Text(
                "${(percentage * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDarkMode ? accentGold : primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 10,
              backgroundColor: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage == 1.0 ? Colors.greenAccent.shade700 : accentGold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "تم توزيع $assignedStudents طالب من أصل $totalStudents على المشرفين.",
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: isDarkMode ? Colors.white60 : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
  }) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : primaryColor,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.white38 : Colors.grey[600],
              fontSize: 10,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(bool isDarkMode) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_rounded, color: isDarkMode ? accentGold : primaryColor, size: 22),
              const SizedBox(width: 8),
              Text(
                "توصيات الإدارة اليومية",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : primaryColor,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          Divider(height: 24, color: isDarkMode ? Colors.white12 : Colors.black12),
          _noteItem("تأكد من توزيع الطلاب الجدد فور تسجيلهم بالدورة.", Icons.person_add_alt_1_rounded, Colors.blueAccent, isDarkMode),
          _noteItem("متابعة تقارير غياب الطلاب وتفعيل الاتصال بأولياء الأمور.", Icons.phone_callback_rounded, Colors.greenAccent.shade700, isDarkMode),
          _noteItem("تكريم المشرفين والطلاب المتميزين نهاية كل أسبوع.", Icons.military_tech_rounded, accentGold, isDarkMode),
        ],
      ),
    );
  }

  Widget _noteItem(String text, IconData icon, Color color, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    required bool isDarkMode,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    Color? customColor,
    Color? customBorderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ?? (isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.45)),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: customBorderColor ?? (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.03),
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
}

// =========================================================================
// 🏆 1. صفحة ترتيب المشرفين الأكثر تسجيلاً للجلسات
// =========================================================================
class TopSessionSupervisorsPage extends StatelessWidget {
  const TopSessionSupervisorsPage({super.key});

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDarkMode ? const Color(0xff0f172a) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            "أكثر المشرفين تسجيلاً للجلسات 🏆", 
            style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16)
          ),
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            Container(
              width: double.infinity, height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('supervisors').snapshots(),
                builder: (context, supSnap) {
                  if (!supSnap.hasData) return const Center(child: CircularProgressIndicator());

                  final supervisors = supSnap.data!.docs;

                  if (supervisors.isEmpty) {
                    return Center(
                      child: Text("لا يوجد مشرفون مسجلون بالنظام 📭", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : primaryColor, fontSize: 15)),
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('sessions').where('absent', isEqualTo: false).snapshots(),
                    builder: (context, sessionSnap) {
                      if (!sessionSnap.hasData) return const Center(child: CircularProgressIndicator());

                      final sessions = sessionSnap.data!.docs;

                      Map<String, int> supervisorSessionCounts = {};

                      for (var s in sessions) {
                        var data = s.data() as Map<String, dynamic>;
                        
                        // فحص قائمة المشرفين للجلسة (إذا كان أكثر من مشرف)
                        List<dynamic>? supNamesList = data['supervisorNames'];
                        if (supNamesList != null && supNamesList.isNotEmpty) {
                          for (var supName in supNamesList) {
                            String nameStr = supName.toString().trim();
                            if (nameStr.isNotEmpty) {
                              supervisorSessionCounts[nameStr] = (supervisorSessionCounts[nameStr] ?? 0) + 1;
                            }
                          }
                        } else {
                          // المشرف المفرد للجلسة
                          String singleSup = data['supervisorName']?.toString().trim() ?? '';
                          if (singleSup.isNotEmpty) {
                            supervisorSessionCounts[singleSup] = (supervisorSessionCounts[singleSup] ?? 0) + 1;
                          }
                        }
                      }

                      List<Map<String, dynamic>> supervisorsList = supervisors.map((sup) {
                        var supData = sup.data() as Map<String, dynamic>;
                        String supName = supData['name']?.toString().trim() ?? 'مشرف';
                        String imageUrl = supData['imageUrl'] ?? '';
                        
                        return {
                          'id': sup.id,
                          'name': supName,
                          'imageUrl': imageUrl,
                          'count': supervisorSessionCounts[supName] ?? 0,
                        };
                      }).toList();

                      // الترتيب من الأكبر إلى الأصغر
                      supervisorsList.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        itemCount: supervisorsList.length,
                        itemBuilder: (context, index) {
                          final item = supervisorsList[index];
                          final String supName = item['name'];
                          final String imageUrl = item['imageUrl'];
                          final int sessionCount = item['count'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: index == 0
                                          ? accentGold.withOpacity(0.8)
                                          : (isDarkMode ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.7)),
                                      width: index == 0 ? 1.8 : 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: index == 0 ? accentGold : primaryColor.withOpacity(0.3), width: 2),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(25),
                                              child: imageUrl.isNotEmpty
                                                  ? Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (c, e, s) => _buildAvatarFallback(supName, isDarkMode, primaryColor),
                                                    )
                                                  : _buildAvatarFallback(supName, isDarkMode, primaryColor),
                                            ),
                                          ),
                                          if (index == 0)
                                            const CircleAvatar(radius: 10, backgroundColor: Colors.amber, child: Icon(Icons.star_rounded, size: 12, color: Colors.white))
                                          else if (index == 1)
                                            const CircleAvatar(radius: 10, backgroundColor: Colors.grey, child: Icon(Icons.star_rounded, size: 12, color: Colors.white))
                                          else if (index == 2)
                                            const CircleAvatar(radius: 10, backgroundColor: Colors.brown, child: Icon(Icons.star_rounded, size: 12, color: Colors.white)),
                                        ],
                                      ),
                                      const SizedBox(width: 14),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              supName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                fontFamily: 'Cairo',
                                                color: isDarkMode ? Colors.white : primaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "الترتيب: #${index + 1}",
                                              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDarkMode ? Colors.white54 : Colors.black54),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: sessionCount > 0 
                                              ? (isDarkMode ? accentGold.withOpacity(0.2) : Colors.green.withOpacity(0.12)) 
                                              : Colors.grey.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: sessionCount > 0 ? (isDarkMode ? accentGold : Colors.green) : Colors.grey, 
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          "$sessionCount جلسة",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Cairo',
                                            color: sessionCount > 0 ? (isDarkMode ? accentGold : Colors.green.shade800) : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name, bool isDarkMode, Color primaryColor) {
    return Container(
      color: isDarkMode ? primaryColor.withOpacity(0.5) : primaryColor.withOpacity(0.12),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1) : 'م',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontSize: 18),
        ),
      ),
    );
  }
}

// =========================================================================
// 🚀 2. صفحة تعداد طلاب كل مشرف
// =========================================================================
class SupervisorsStudentsCountPage extends StatelessWidget {
  const SupervisorsStudentsCountPage({super.key});

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDarkMode ? const Color(0xff0f172a) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            "توزيع الطلاب على المشرفين 👥", 
            style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16)
          ),
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            Container(
              width: double.infinity, height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('supervisors').snapshots(),
                builder: (context, supSnap) {
                  if (!supSnap.hasData) return const Center(child: CircularProgressIndicator());

                  final supervisors = supSnap.data!.docs;

                  if (supervisors.isEmpty) {
                    return Center(
                      child: Text("لا يوجد مشرفون مسجلون بالنظام حالياً 📭", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : primaryColor, fontSize: 15)),
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('students').where('archived', isEqualTo: false).snapshots(),
                    builder: (context, stdSnap) {
                      if (!stdSnap.hasData) return const Center(child: CircularProgressIndicator());

                      final students = stdSnap.data!.docs;

                      Map<String, int> supervisorCounts = {};
                      for (var std in students) {
                        var data = std.data() as Map<String, dynamic>;
                        String sId = data['supervisorId']?.toString() ?? '';
                        if (sId.isNotEmpty) {
                          supervisorCounts[sId] = (supervisorCounts[sId] ?? 0) + 1;
                        }
                      }

                      List<Map<String, dynamic>> supervisorsList = supervisors.map((sup) {
                        var supData = sup.data() as Map<String, dynamic>;
                        String supId = sup.id;
                        return {
                          'id': supId,
                          'name': supData['name'] ?? 'مشرف',
                          'imageUrl': supData['imageUrl'] ?? '',
                          'count': supervisorCounts[supId] ?? 0,
                        };
                      }).toList();

                      supervisorsList.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        itemCount: supervisorsList.length,
                        itemBuilder: (context, index) {
                          final item = supervisorsList[index];
                          final String supName = item['name'];
                          final String imageUrl = item['imageUrl'];
                          final int studentCount = item['count'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: index == 0
                                          ? accentGold.withOpacity(0.8)
                                          : (isDarkMode ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.7)),
                                      width: index == 0 ? 1.8 : 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: index == 0 ? accentGold : primaryColor.withOpacity(0.3), width: 2),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(25),
                                              child: imageUrl.isNotEmpty
                                                  ? Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (c, e, s) => _buildAvatarFallback(supName, isDarkMode, primaryColor),
                                                    )
                                                  : _buildAvatarFallback(supName, isDarkMode, primaryColor),
                                            ),
                                          ),
                                          if (index == 0)
                                            const CircleAvatar(radius: 10, backgroundColor: Colors.amber, child: Icon(Icons.star_rounded, size: 12, color: Colors.white))
                                          else if (index == 1)
                                            const CircleAvatar(radius: 10, backgroundColor: Colors.grey, child: Icon(Icons.star_rounded, size: 12, color: Colors.white))
                                          else if (index == 2)
                                            const CircleAvatar(radius: 10, backgroundColor: Colors.brown, child: Icon(Icons.star_rounded, size: 12, color: Colors.white)),
                                        ],
                                      ),
                                      const SizedBox(width: 14),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              supName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                fontFamily: 'Cairo',
                                                color: isDarkMode ? Colors.white : primaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "الترتيب: #${index + 1}",
                                              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDarkMode ? Colors.white54 : Colors.black54),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: studentCount > 0 
                                              ? (isDarkMode ? accentGold.withOpacity(0.2) : primaryColor.withOpacity(0.12)) 
                                              : Colors.grey.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: studentCount > 0 ? (isDarkMode ? accentGold : primaryColor) : Colors.grey, 
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          "$studentCount طلاب",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Cairo',
                                            color: studentCount > 0 ? (isDarkMode ? accentGold : primaryColor) : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name, bool isDarkMode, Color primaryColor) {
    return Container(
      color: isDarkMode ? primaryColor.withOpacity(0.5) : primaryColor.withOpacity(0.12),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1) : 'م',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontSize: 18),
        ),
      ),
    );
  }
}

// =========================================================================
// 🚀 3. صفحة تقرير الغيابات التراكمية الشاملة لجميع الطلاب
// =========================================================================
class AllAbsentStudentsSummaryPage extends StatelessWidget {
  const AllAbsentStudentsSummaryPage({super.key});

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    try {
      await Share.share("رقم هاتف ولي الأمر للمتابعة: $phoneNumber");
    } catch (e) {
      print("Error sharing phone number: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDarkMode ? const Color(0xff0f172a) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text("سجل غيابات الطلاب 🚨", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16)),
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            Container(
              width: double.infinity, height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sessions')
                    .where('absent', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final absentSessions = snapshot.data!.docs;

                  if (absentSessions.isEmpty) {
                    return Center(
                      child: Text("لا توجد أي غيابات مسجلة حتى الآن 🎉", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : primaryColor, fontSize: 15)),
                    );
                  }

                  Map<String, Map<String, dynamic>> studentAbsenceMap = {};

                  for (var doc in absentSessions) {
                    var data = doc.data() as Map<String, dynamic>;
                    String studentId = data['studentId'] ?? '';
                    String studentName = data['studentName'] ?? 'طالب';

                    if (studentId.isEmpty) continue;

                    if (!studentAbsenceMap.containsKey(studentId)) {
                      studentAbsenceMap[studentId] = {
                        'studentId': studentId,
                        'studentName': studentName,
                        'count': 1,
                        'supervisorName': data['supervisorName'] ?? 'غير محدد',
                      };
                    } else {
                      studentAbsenceMap[studentId]!['count'] = (studentAbsenceMap[studentId]!['count'] as int) + 1;
                    }
                  }

                  List<Map<String, dynamic>> sortedAbsenceList = studentAbsenceMap.values.toList();
                  sortedAbsenceList.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: sortedAbsenceList.length,
                    itemBuilder: (context, index) {
                      final item = sortedAbsenceList[index];
                      final String studentId = item['studentId'];
                      final String studentName = item['studentName'];
                      final int totalAbsences = item['count'];
                      final String supervisorName = item['supervisorName'];

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('students').doc(studentId).get(),
                        builder: (context, studentSnap) {
                          String parentPhone = '';
                          if (studentSnap.hasData && studentSnap.data!.exists) {
                            parentPhone = (studentSnap.data!.data() as Map<String, dynamic>)['parentPhone'] ?? '';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.35), width: 1.2),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person_off_rounded, color: Colors.redAccent, size: 22),
                                        const SizedBox(width: 8),
                                        Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 6)],
                                      ),
                                      child: Text(
                                        "$totalAbsences غيابات",
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text("المشرف: $supervisorName", style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: isDarkMode ? Colors.white60 : Colors.black54)),
                                if (parentPhone.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      style: TextButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      onPressed: () => _makePhoneCall(parentPhone),
                                      icon: const Icon(Icons.phone, size: 15, color: Colors.green),
                                      label: const Text("اتصال بولي الأمر", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 11)),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 🚀 4. صفحة عرض الطلاب غير الموزعين على مشرفين
// =========================================================================
class UnassignedStudentsPage extends StatelessWidget {
  const UnassignedStudentsPage({super.key});

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    try {
      await Share.share("رقم هاتف ولي الأمر للمتابعة: $phoneNumber");
    } catch (e) {
      print("Error sharing phone number: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDarkMode ? const Color(0xff0f172a) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text("الطلاب غير الموزعين ⚠️", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16)),
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            Container(
              width: double.infinity, height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('students')
                    .where('archived', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final unassignedDocs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final supId = data['supervisorId'];
                    return supId == null || supId.toString().trim().isEmpty;
                  }).toList();

                  if (unassignedDocs.isEmpty) {
                    return Center(
                      child: Text("جميع الطلاب موزعين على مشرفين بنجاح 🎉", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : primaryColor, fontSize: 15)),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: unassignedDocs.length,
                    itemBuilder: (context, index) {
                      final doc = unassignedDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String studentName = data['name'] ?? 'طالب بدون اسم';
                      final String serialNumber = data['serial']?.toString() ?? '---';
                      final String parentPhone = data['parentPhone'] ?? data['phone'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withOpacity(0.4), width: 1.2),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_search_rounded, color: Colors.orange, size: 22),
                                    const SizedBox(width: 8),
                                    Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange, width: 0.8),
                                  ),
                                  child: Text("رقم: $serialNumber", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.orange)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (parentPhone.isNotEmpty)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    onPressed: () => _makePhoneCall(parentPhone),
                                    icon: const Icon(Icons.phone, size: 15, color: Colors.green),
                                    label: const Text("اتصال بولي الأمر", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 11)),
                                  ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(backgroundColor: (isDarkMode ? accentGold : primaryColor).withOpacity(0.15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => EditStudentPage(student: doc)));
                                  },
                                  icon: Icon(Icons.edit_note_rounded, size: 16, color: isDarkMode ? accentGold : primaryColor),
                                  label: Text("تعيين مشرف", style: TextStyle(color: isDarkMode ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}