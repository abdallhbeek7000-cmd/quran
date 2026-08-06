import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.html) 'package:path_provider/path_provider.dart';
import '../services/theme_provider.dart';
import '../widgets/offline_wrapper.dart';

class DailyStatsPage extends StatefulWidget {
  const DailyStatsPage({super.key});

  @override
  State<DailyStatsPage> createState() => _DailyStatsPageState();
}

class _DailyStatsPageState extends State<DailyStatsPage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  DateTime selectedDate = DateTime.now();

  String get formattedDate => "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

  String get arabicDayName {
    List<String> arabicDays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return arabicDays[selectedDate.weekday - 1];
  }

  Future<void> _pickDate(BuildContext context, bool isDarkMode) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: accentGold,
              onPrimary: Colors.white,
              onSurface: isDarkMode ? Colors.white : primaryColor,
            ),
            dialogBackgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: accentGold),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

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
          "الإحصائيات اليومية 📊",
          style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 18),
        ),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🎨 الخلفية الانسيابية مع الدوائر العائمة
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
              width: 260,
              height: 260,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🗓️ 1. كرت اختيار التاريخ الملكي الفاخر
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: isDarkMode ? accentGold : primaryColor),
                          tooltip: "اليوم السابق",
                          onPressed: () {
                            setState(() {
                              selectedDate = selectedDate.subtract(const Duration(days: 1));
                            });
                          },
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _pickDate(context, isDarkMode),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.calendar_month_rounded, color: accentGold, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        "يوم $arabicDayName",
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white : primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color: isDarkMode ? accentGold : primaryColor.withOpacity(0.8),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      fontFamily: 'Cairo',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: isDarkMode ? accentGold : primaryColor),
                          tooltip: "اليوم التالي",
                          onPressed: () {
                            setState(() {
                              selectedDate = selectedDate.add(const Duration(days: 1));
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 🟢 2. كرت الحضور المبدئي
                  _buildExpectedSessionsCard(formattedDate, isDarkMode),

                  const SizedBox(height: 14),

                  // 📝 3. كرت الجلسات المسجلة
                  InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyRecitationsPage(targetDate: formattedDate),
                        ),
                      );
                    },
                    child: _buildStreamCard(
                      title: "الجلسات المسجلة فعلياً اليوم 📝",
                      subtitle: "اضغط لعرض كافة تسميعات اليوم بالتفصيل",
                      icon: Icons.auto_stories_rounded,
                      color: Colors.greenAccent.shade700,
                      stream: FirebaseFirestore.instance
                          .collection('sessions')
                          .where('date', isEqualTo: formattedDate)
                          .where('absent', isEqualTo: false)
                          .snapshots(),
                      isDarkMode: isDarkMode,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ⚖️ 4. كرت ميزان الإنجاز السائل الزجاجي
                  InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PendingSessionsPage(targetDate: formattedDate),
                        ),
                      );
                    },
                    child: _buildAttendanceComparisonCard(formattedDate, isDarkMode),
                  ),

                  const SizedBox(height: 14),

                  // 🔴 5. كرت الغائبين اليوم
                  InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyAbsentStudentsPage(targetDate: formattedDate),
                        ),
                      );
                    },
                    child: _buildStreamCard(
                      title: "عدد الغائبين اليوم 🔴",
                      subtitle: "عرض القائمة وتصدير كرت الغياب لواتساب",
                      icon: Icons.person_off_rounded,
                      color: Colors.redAccent.shade200,
                      stream: FirebaseFirestore.instance
                          .collection('sessions')
                          .where('date', isEqualTo: formattedDate)
                          .where('absent', isEqualTo: true)
                          .snapshots(),
                      isDarkMode: isDarkMode,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 📈 6. كرت نسبة الحضور
                  _buildPercentageCard(formattedDate, isDarkMode),

                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpectedSessionsCard(String targetDate, bool isDarkMode) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('daily_attendance').doc(targetDate).snapshots(),
      builder: (context, snapshot) {
        int expectedCount = 0;
        if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
          var records = snapshot.data!['records'] as Map<String, dynamic>? ?? {};
          records.forEach((studentId, val) {
            if ((val is Map && val['status'] == 'present') || val == 'present') {
              expectedCount++;
            }
          });
        }
        return _statsUI(
          "المستهدفون للتسميع اليوم 🟢",
          "الحضور المبدئي الموثق بالصفحة",
          expectedCount.toString(),
          Icons.fact_check_rounded,
          isDarkMode ? Colors.lightBlueAccent : Colors.blue.shade600,
          snapshot.connectionState == ConnectionState.waiting,
          isDarkMode,
        );
      },
    );
  }

  Widget _buildAttendanceComparisonCard(String targetDate, bool isDarkMode) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('daily_attendance').doc(targetDate).snapshots(),
      builder: (context, attendanceSnap) {
        int expectedCount = 0;
        if (attendanceSnap.hasData && attendanceSnap.data!.exists && attendanceSnap.data!.data() != null) {
          var records = attendanceSnap.data!['records'] as Map<String, dynamic>? ?? {};
          records.forEach((studentId, val) {
            if ((val is Map && val['status'] == 'present') || val == 'present') {
              expectedCount++;
            }
          });
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sessions')
              .where('date', isEqualTo: targetDate)
              .where('absent', isEqualTo: false)
              .snapshots(),
          builder: (context, sessionSnap) {
            int actualCount = sessionSnap.hasData ? sessionSnap.data!.docs.length : 0;
            int diff = expectedCount - actualCount;
            bool isComplete = expectedCount > 0 && diff <= 0;

            final cardColor = isComplete ? Colors.green : Colors.orange;

            return _buildGlassContainer(
              isDarkMode: isDarkMode,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cardColor.withOpacity(0.3), cardColor.withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: cardColor.withOpacity(0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: cardColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Icon(
                      isComplete ? Icons.verified_rounded : Icons.warning_amber_rounded,
                      color: cardColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "متابعة إنجاز المشرفين اليوم ⚖️",
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDarkMode ? Colors.white : primaryColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: (isDarkMode ? Colors.white : primaryColor).withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDarkMode ? accentGold : primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (expectedCount == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "لم يتم تسجيل تفقد مبدئي لهذا اليوم بعد.",
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white70 : Colors.grey[700]),
                            ),
                          )
                        else if (isComplete)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.celebration_rounded, size: 14, color: Colors.green),
                                SizedBox(width: 6),
                                Text(
                                  "تم إنجاز وتسميع جميع جلسات الطلاب بنجاح! 🎉",
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.4), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_rounded, size: 14, color: Colors.orange),
                                const SizedBox(width: 6),
                                Text(
                                  "باقي ($diff) طلاب لم تُسجّل جلساتهم بعد! اضغط للمتابعة ⚠️",
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStreamCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Stream<QuerySnapshot> stream,
    required bool isDarkMode,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String value = snapshot.hasData ? snapshot.data!.docs.length.toString() : "0";
        return _statsUI(title, subtitle, value, icon, color, snapshot.connectionState == ConnectionState.waiting, isDarkMode);
      },
    );
  }

  Widget _buildPercentageCard(String targetDate, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('date', isEqualTo: targetDate)
          .snapshots(),
      builder: (context, snapshot) {
        String percentage = "0%";
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs;
          int presentCount = docs.where((doc) => doc['absent'] == false).length;
          percentage = "${((presentCount / docs.length) * 100).round()}%";
        }
        return _statsUI(
          "نسبة الحضور اليوم 📈",
          "نسبة التسميع بالنسبة لإجمالي السجلات اليومية",
          percentage,
          Icons.pie_chart_rounded,
          isDarkMode ? accentGold : Colors.blue.shade700,
          snapshot.connectionState == ConnectionState.waiting,
          isDarkMode,
        );
      },
    );
  }

  Widget _statsUI(String title, String subtitle, String value, IconData icon, Color color, bool isLoading, bool isDarkMode) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey[600], fontSize: 10, fontFamily: 'Cairo')),
                const SizedBox(height: 8),
                isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5, fontFamily: 'Cairo')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6),
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
// 🚀 1. واجهة الطلاب الحاضرين الذين لم تُسجل جلساتهم بعد (Liquid Glass ✨)
// =========================================================================
class PendingSessionsPage extends StatelessWidget {
  final String targetDate;
  const PendingSessionsPage({super.key, required this.targetDate});

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
            "الطلاب المتبقين للتسميع ($targetDate)",
            style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16),
          ),
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // 🎨 خلفية الجرادينت السائلة
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
              left: -40,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(isDarkMode ? 0.08 : 0.12),
                ),
              ),
            ),
            SafeArea(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('daily_attendance').doc(targetDate).snapshots(),
                builder: (context, attendanceSnap) {
                  if (attendanceSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!attendanceSnap.hasData || !attendanceSnap.data!.exists || attendanceSnap.data!.data() == null) {
                    return Center(
                      child: Text("لم يتم تسجيل تفقد مبدئي لليوم المختار بعد.", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : primaryColor, fontSize: 14)),
                    );
                  }

                  var records = attendanceSnap.data!['records'] as Map<String, dynamic>? ?? {};
                  List<String> presentStudentIds = [];

                  records.forEach((studentId, val) {
                    if ((val is Map && val['status'] == 'present') || val == 'present') {
                      presentStudentIds.add(studentId);
                    }
                  });

                  if (presentStudentIds.isEmpty) {
                    return Center(
                      child: Text("لا يوجد طلاب حاضرون مبدئياً بانتظار التسميع 🎉", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : primaryColor, fontSize: 14)),
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('sessions')
                        .where('date', isEqualTo: targetDate)
                        .snapshots(),
                    builder: (context, sessionsSnap) {
                      if (sessionsSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      Set<String> recordedStudentIds = sessionsSnap.hasData
                          ? sessionsSnap.data!.docs.map((doc) => doc['studentId'].toString()).toSet()
                          : {};

                      List<String> pendingStudentIds = presentStudentIds.where((id) => !recordedStudentIds.contains(id)).toList();

                      if (pendingStudentIds.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.verified_rounded, color: Colors.green, size: 65),
                              const SizedBox(height: 14),
                              Text("اكتمل الإنجاز! 🎉", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: isDarkMode ? Colors.white : primaryColor)),
                              const SizedBox(height: 6),
                              Text("تم تسجيل جلسات لجميع الطلاب الحاضرين بنجاح.", style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDarkMode ? Colors.white60 : Colors.black54)),
                            ],
                          ),
                        );
                      }

                      // 🚀 جلب تفاصيل جميع الطلاب دفعة واحدة وبدون Rebuilds عشوائية
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('students')
                            .where('archived', isEqualTo: false)
                            .snapshots(),
                        builder: (context, studentsSnap) {
                          if (studentsSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (!studentsSnap.hasData || studentsSnap.data!.docs.isEmpty) {
                            return const Center(child: Text("لا توجد بيانات للطلاب", style: TextStyle(fontFamily: 'Cairo')));
                          }

                          List<Map<String, dynamic>> pendingStudentsList = [];

                          for (var doc in studentsSnap.data!.docs) {
                            if (pendingStudentIds.contains(doc.id)) {
                              var data = doc.data() as Map<String, dynamic>;
                              dynamic rawSerial = data['serial'];
                              int serialNum = rawSerial is int ? rawSerial : (int.tryParse(rawSerial?.toString() ?? '0') ?? 0);

                              pendingStudentsList.add({
                                'id': doc.id,
                                'name': data['name'] ?? 'طالب',
                                'supervisorName': data['supervisorName'] ?? 'غير محدد',
                                'imageUrl': data['imageUrl'] ?? '',
                                'serial': serialNum,
                              });
                            }
                          }

                          // 🔢 الترتيب التسلسلي الفوري من الأصغر للأكبر
                          pendingStudentsList.sort((a, b) => (a['serial'] as int).compareTo(b['serial'] as int));

                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                            itemCount: pendingStudentsList.length,
                            itemBuilder: (context, index) {
                              var student = pendingStudentsList[index];
                              String studentName = student['name'];
                              String supervisorName = student['supervisorName'];
                              String imageUrl = student['imageUrl'];
                              String firstLetter = studentName.isNotEmpty ? studentName.trim().substring(0, 1) : "?";

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.55),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: Colors.orange.withOpacity(isDarkMode ? 0.35 : 0.5),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.03),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // ⏳ شارة بانتظار التسميع جهة اليمين
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: Colors.orange.withOpacity(0.6), width: 1),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 14),
                                                SizedBox(width: 5),
                                                Text(
                                                  "بانتظار التسميع",
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.orange),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // 📝 الاسم واسم المشرف بالمحاذاة التامة
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  studentName,
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'Cairo',
                                                    fontSize: 15,
                                                    color: isDarkMode ? Colors.white : primaryColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  "المشرف: $supervisorName",
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'Cairo',
                                                    color: isDarkMode ? Colors.white60 : Colors.black54,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // 🖼️ صورة الطالب زجاجية بإطار برتقالي
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.orange.withOpacity(0.6), width: 1.5),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(23),
                                              child: imageUrl.isNotEmpty
                                                  ? Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (c, e, s) => Center(child: Text(firstLetter, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor))),
                                                    )
                                                  : Center(child: Text(firstLetter, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor))),
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
// 🚀 2. واجهة الطلاب الغائبين مع التصدير
// =========================================================================
class DailyAbsentStudentsPage extends StatefulWidget {
  final String targetDate;
  const DailyAbsentStudentsPage({super.key, required this.targetDate});

  @override
  State<DailyAbsentStudentsPage> createState() => _DailyAbsentStudentsPageState();
}

class _DailyAbsentStudentsPageState extends State<DailyAbsentStudentsPage> {
  final WidgetsToImageController controller = WidgetsToImageController();
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);
  bool isExporting = false;

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    try {
      await Share.share("رقم هاتف ولي الأمر للمتابعة: $phoneNumber");
    } catch (e) {
      print("Error sharing phone number: $e");
    }
  }

  Future<void> _shareAbsentListAsImage() async {
    setState(() => isExporting = true);
    try {
      final bytes = await controller.capture();
      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/غياب_${widget.targetDate}.png').create();
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: '📊 قائمة الطلاب الغائبين في حلقة يوم (${widget.targetDate})\nمعهد الشيخ سعيد العبدالله 🕌',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ أثناء إنشاء الصورة: $e")));
    } finally {
      if (mounted) setState(() => isExporting = false);
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
          title: Text("الطلاب الغائبين (${widget.targetDate}) 🔴", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16)),
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
          centerTitle: true,
          actions: [
            IconButton(
              icon: isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.share_rounded, color: isDarkMode ? accentGold : primaryColor),
              tooltip: "تصدير صورة لواتساب الأهالي",
              onPressed: isExporting ? null : _shareAbsentListAsImage,
            ),
          ],
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
                stream: FirebaseFirestore.instance.collection('sessions')
                    .where('date', isEqualTo: widget.targetDate)
                    .where('absent', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final absentDocs = snapshot.data!.docs;

                  if (absentDocs.isEmpty) {
                    return Center(
                      child: Text("لا يوجد غياب مسجل في هذا اليوم 🎉", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : primaryColor, fontSize: 15)),
                    );
                  }

                  return Stack(
                    children: [
                      Positioned(
                        left: -9999,
                        top: -9999,
                        child: WidgetsToImage(
                          controller: controller,
                          child: SizedBox(
                            width: 600,
                            child: _buildExportablePoster(absentDocs),
                          ),
                        ),
                      ),
                      ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        itemCount: absentDocs.length,
                        itemBuilder: (context, index) {
                          final data = absentDocs[index].data() as Map<String, dynamic>;
                          final String studentId = data['studentId'] ?? '';
                          final String studentName = data['studentName'] ?? 'طالب';
                          final String absenceType = data['absenceType'] ?? 'بدون عذر';
                          final String absenceReason = data['absenceReason'] ?? '';

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('students').doc(studentId).get(),
                            builder: (context, studentSnap) {
                              String parentPhone = '';
                              if (studentSnap.hasData && studentSnap.data!.exists) {
                                parentPhone = (studentSnap.data!.data() as Map<String, dynamic>)['parentPhone'] ?? '';
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
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
                                            const Icon(Icons.person_off_rounded, color: Colors.redAccent, size: 20),
                                            const SizedBox(width: 8),
                                            Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (absenceType == 'بعذر' ? Colors.green : Colors.redAccent).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: absenceType == 'بعذر' ? Colors.green : Colors.redAccent, width: 0.8),
                                          ),
                                          child: Text(absenceType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: absenceType == 'بعذر' ? Colors.green : Colors.redAccent)),
                                        ),
                                      ],
                                    ),
                                    if (absenceReason.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text("السبب: $absenceReason", style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: isDarkMode ? Colors.white70 : Colors.black87)),
                                    ],
                                    if (parentPhone.isNotEmpty) ...[
                                      const SizedBox(height: 10),
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
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportablePoster(List<QueryDocumentSnapshot> docs) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff0f172a), Color(0xff1e293b), Color(0xff0f172a)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mosque, color: accentGold, size: 32),
              const SizedBox(width: 12),
              const Text("معهد الشيخ سعيد العبدالله", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: accentGold.withOpacity(0.15), borderRadius: BorderRadius.circular(25), border: Border.all(color: accentGold, width: 1)),
            child: Text("📊 جدول غياب الطلاب يوم: ${widget.targetDate}", style: TextStyle(fontSize: 14, color: accentGold, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
          const SizedBox(height: 25),
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white24, width: 1.2)),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(1.2), 2: FlexColumnWidth(2)},
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12)),
                  children: [
                    _tableHeader("اسم الطالب"),
                    _tableHeader("الحالة"),
                    _tableHeader("ملاحظات / السبب"),
                  ],
                ),
                ...docs.map((d) {
                  var data = d.data() as Map<String, dynamic>;
                  String name = data['studentName'] ?? 'طالب';
                  String type = data['absenceType'] ?? 'بدون عذر';
                  String reason = data['absenceReason'] ?? '---';
                  return TableRow(
                    children: [
                      _tableCell(name, isBold: true),
                      _tableCell(type, color: type == 'بعذر' ? Colors.greenAccent : Colors.redAccent),
                      _tableCell(reason.isEmpty ? '---' : reason),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text("يرجى من أولياء الأمور الكرام المتابعة والحرص على حضور الطلاب 🌸", style: TextStyle(fontSize: 13, color: Colors.white60, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _tableHeader(String txt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Text(txt, textAlign: TextAlign.center, style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
    );
  }

  Widget _tableCell(String txt, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        txt,
        textAlign: TextAlign.center,
        style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontFamily: 'Cairo'),
      ),
    );
  }
}

// =========================================================================
// 🚀 3. واجهة التسميعات والجلسات اليومية
// =========================================================================
class DailyRecitationsPage extends StatefulWidget {
  final String targetDate;
  const DailyRecitationsPage({super.key, required this.targetDate});

  @override
  State<DailyRecitationsPage> createState() => _DailyRecitationsPageState();
}

class _DailyRecitationsPageState extends State<DailyRecitationsPage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  String _getArabicDayName(String dateString) {
    try {
      List<String> parts = dateString.split('-');
      if (parts.length == 3) {
        int year = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int day = int.parse(parts[2]);
        DateTime date = DateTime(year, month, day);
        List<String> arabicDays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
        return arabicDays[date.weekday - 1];
      }
    } catch (e) {
      return "";
    }
    return "";
  }

  Color _getRatingColor(String? rating) {
    switch (rating) {
      case "ممتاز": return Colors.green;
      case "جيد جداً": return Colors.teal;
      case "جيد": return Colors.orange;
      case "مقبول": return Colors.blueGrey;
      case "ضعيف": return Colors.red;
      default: return Colors.blue;
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
          title: Text("جلسات التسميع (${widget.targetDate}) 📝", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16)),
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
                stream: FirebaseFirestore.instance.collection('sessions')
                    .where('date', isEqualTo: widget.targetDate)
                    .where('absent', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final sessions = snapshot.data!.docs;

                  if (sessions.isEmpty) {
                    return Center(
                      child: Text("لا توجد تسميعات مسجلة في هذا اليوم", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : primaryColor, fontSize: 15)),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final data = session.data() as Map<String, dynamic>;
                      return _buildSessionTimelineItem(context, session.id, data, isDarkMode, index + 1);
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

  Widget _buildSessionTimelineItem(BuildContext context, String sessionId, Map<String, dynamic> data, bool isDarkMode, int sessionNumber) {
    bool isExam = data['isExam'] ?? false;
    bool didNotRecite = data['didNotRecite'] ?? false;

    String studentName = data['studentName'] ?? 'طالب';
    String sessionDateRaw = data['date'] ?? '';
    String dayName = _getArabicDayName(sessionDateRaw);
    String displayDate = dayName.isNotEmpty ? "$dayName، $sessionDateRaw" : sessionDateRaw;

    String nMemo = data['newMemorization']?.toString().trim() ?? '';
    String nRev = data['nearReview']?.toString().trim() ?? '';
    String fRev = data['farReview']?.toString().trim() ?? '';
    String sight = data['readingBySight']?.toString().trim() ?? '';

    String memRating = data['memorizationRating'] ?? data['rating'] ?? "";
    String newRevRating = data['newReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? "";
    String oldRevRating = data['oldReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? "";

    String nHw = data['newHomework']?.toString().trim() ?? '';
    String nRevHw = data['newReviewHomework']?.toString().trim() ?? '';
    String oRevHw = data['oldReviewHomework']?.toString().trim() ?? '';

    List<dynamic>? supNamesList = data['supervisorNames'];
    String supervisorsDisplay = (supNamesList != null && supNamesList.isNotEmpty) ? supNamesList.join(' ، ') : (data['supervisorName'] ?? 'غير محدد');

    List<Widget> activeBoxes = [];
    if (!didNotRecite && !isExam) {
      if (nMemo.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.star_rounded, "الحفظ الجديد", nMemo, Colors.amber, isDarkMode));
      if (nRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.menu_book_rounded, "مراجعة جديد", nRev, Colors.teal, isDarkMode));
      if (fRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.history_toggle_off_rounded, "مراجعة قديم", fRev, Colors.blueGrey, isDarkMode));
      if (sight.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.chrome_reader_mode_rounded, "قراءة نظراً", sight, Colors.indigoAccent, isDarkMode));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.45),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isExam ? Colors.teal.withOpacity(0.4) : (didNotRecite ? Colors.blueGrey.withOpacity(0.4) : (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6))), width: 1.5),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                    color: isExam ? Colors.teal.withOpacity(isDarkMode ? 0.2 : 0.15) : (didNotRecite ? Colors.blueGrey.withOpacity(isDarkMode ? 0.2 : 0.15) : (isDarkMode ? Colors.white.withOpacity(0.05) : primaryColor.withOpacity(0.05))),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(isExam ? Icons.workspace_premium : (didNotRecite ? Icons.speaker_notes_off_outlined : Icons.person), size: 18, color: isDarkMode ? accentGold : primaryColor),
                              const SizedBox(width: 8),
                              Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 14)),
                            ],
                          ),
                          if (isExam) _buildBadge("جلسة اختبار 📝", Colors.teal) else if (didNotRecite) _buildBadge("بدون تسميع ℹ️", Colors.blueGrey),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("جلسة #$sessionNumber | $displayDate", style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: isDarkMode ? Colors.white60 : Colors.black54)),
                      if (!isExam && !didNotRecite) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: [
                            if (nMemo.isNotEmpty && memRating.isNotEmpty) _buildBadge("حفظ: $memRating", _getRatingColor(memRating)),
                            if (nRev.isNotEmpty && newRevRating.isNotEmpty) _buildBadge("م.جديد: $newRevRating", _getRatingColor(newRevRating)),
                            if (fRev.isNotEmpty && oldRevRating.isNotEmpty) _buildBadge("م.قديم: $oldRevRating", _getRatingColor(oldRevRating)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMinimalistDetailRow(Icons.person_outline, "المشرف", supervisorsDisplay, isDarkMode, isBold: true),
                      Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 18),
                      if (!isExam && !didNotRecite && activeBoxes.isNotEmpty) ...[
                        for (int i = 0; i < activeBoxes.length; i += 2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(child: activeBoxes[i]),
                                const SizedBox(width: 8),
                                if (i + 1 < activeBoxes.length) Expanded(child: activeBoxes[i + 1]) else const Expanded(child: SizedBox()),
                              ],
                            ),
                          ),
                        Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 18),
                      ],
                      if (nHw.isNotEmpty || nRevHw.isNotEmpty || oRevHw.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: accentGold.withOpacity(0.08), borderRadius: BorderRadius.circular(15), border: Border.all(color: accentGold.withOpacity(0.25))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.menu_book, size: 15, color: accentGold),
                                  const SizedBox(width: 6),
                                  Text("الواجب القادم:", style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (nHw.isNotEmpty) _buildHomeworkRow("حفظ جديد", nHw, isDarkMode),
                              if (nRevHw.isNotEmpty) _buildHomeworkRow("مراجعة جديد", nRevHw, isDarkMode),
                              if (oRevHw.isNotEmpty) _buildHomeworkRow("مراجعة قديم", oRevHw, isDarkMode),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeworkRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3, right: 8),
      child: Row(
        children: [
          Text("• $label: ", style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white60 : Colors.black54, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildGridInfoBox(IconData icon, String title, String val, Color iconColor, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(fontSize: 10, color: isDarkMode ? Colors.white60 : Colors.grey[700], fontWeight: FontWeight.bold, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 3),
          Text(val.trim().isEmpty ? '---' : val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildMinimalistDetailRow(IconData icon, String label, String value, bool isDarkMode, {bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDarkMode ? accentGold : primaryColor.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey[700], fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        Expanded(child: Text(value.trim().isEmpty ? '---' : value, style: TextStyle(fontSize: 12, color: isBold ? (isDarkMode ? Colors.white : primaryColor) : (isDarkMode ? Colors.white70 : Colors.black87), fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontFamily: 'Cairo'))),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }
}