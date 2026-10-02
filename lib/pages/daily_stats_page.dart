import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:path_provider/path_provider.dart';
import '../services/theme_provider.dart';
import '../services/session_service.dart';
import '../widgets/offline_wrapper.dart';
import 'edit_session_page.dart';

// ⚙️ معرف الدورة الحالية لتحديد نطاق البيانات والتصفير للدورة الجديد
const String currentCycleId = 'cycle_2026_q4';

class DailyStatsPage extends StatefulWidget {
  final String role;

  const DailyStatsPage({super.key, this.role = 'supervisor'});

  @override
  State<DailyStatsPage> createState() => _DailyStatsPageState();
}

class _DailyStatsPageState extends State<DailyStatsPage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  DateTime selectedDate = DateTime.now();

  String get formattedDate =>
      "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

  String get arabicDayName {
    List<String> arabicDays = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
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
            dialogBackgroundColor:
                isDarkMode ? const Color(0xff1e293b) : Colors.white,
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
      backgroundColor:
          isDarkMode ? const Color(0xff0f172a) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "الإحصائيات اليومية 📊",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : primaryColor,
              fontFamily: 'Cairo',
              fontSize: 18),
        ),
        iconTheme:
            IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
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
                    ? [
                        const Color(0xff0f172a),
                        const Color(0xff1e293b),
                        const Color(0xff0f172a)
                      ]
                    : [
                        const Color(0xffe2e8f0),
                        const Color(0xffcfdef3),
                        const Color(0xffe0eafc)
                      ],
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
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode
                      ? accentGold.withOpacity(0.08)
                      : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode
                      ? primaryColor.withOpacity(0.15)
                      : primaryColor.withOpacity(0.2)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_rounded,
                              size: 18,
                              color: isDarkMode ? accentGold : primaryColor),
                          tooltip: "اليوم السابق",
                          onPressed: () {
                            setState(() {
                              selectedDate =
                                  selectedDate.subtract(const Duration(days: 1));
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
                                      Icon(Icons.calendar_month_rounded,
                                          color: accentGold, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        "يوم $arabicDayName",
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : primaryColor,
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
                                      color: isDarkMode
                                          ? accentGold
                                          : primaryColor.withOpacity(0.8),
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
                          icon: Icon(Icons.arrow_forward_ios_rounded,
                              size: 18,
                              color: isDarkMode ? accentGold : primaryColor),
                          tooltip: "اليوم التالي",
                          onPressed: () {
                            setState(() {
                              selectedDate =
                                  selectedDate.add(const Duration(days: 1));
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildExpectedSessionsCard(formattedDate, isDarkMode),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyRecitationsPage(
                              targetDate: formattedDate, role: widget.role),
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
                          .where('cycleId', isEqualTo: currentCycleId)
                          .where('date', isEqualTo: formattedDate)
                          .where('absent', isEqualTo: false)
                          .snapshots(),
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PendingSessionsPage(targetDate: formattedDate),
                        ),
                      );
                    },
                    child: _buildAttendanceComparisonCard(
                        formattedDate, isDarkMode),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyDidNotReciteStudentsPage(
                              targetDate: formattedDate),
                        ),
                      );
                    },
                    child: _buildStreamCard(
                      title: "حضر ولم يسمّع اليوم ⚠️",
                      subtitle: "عرض القائمة وتصدير الكرت لواتساب الأهالي",
                      icon: Icons.speaker_notes_off_outlined,
                      color: Colors.blueGrey,
                      stream: FirebaseFirestore.instance
                          .collection('sessions')
                          .where('cycleId', isEqualTo: currentCycleId)
                          .where('date', isEqualTo: formattedDate)
                          .where('didNotRecite', isEqualTo: true)
                          .snapshots(),
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyAbsentStudentsPage(
                              targetDate: formattedDate),
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
                          .where('cycleId', isEqualTo: currentCycleId)
                          .where('date', isEqualTo: formattedDate)
                          .where('absent', isEqualTo: true)
                          .snapshots(),
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  const SizedBox(height: 14),
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
      stream: FirebaseFirestore.instance
          .collection('daily_attendance')
          .doc('${currentCycleId}_$targetDate')
          .snapshots(),
      builder: (context, snapshot) {
        int expectedCount = 0;
        if (snapshot.hasData &&
            snapshot.data!.exists &&
            snapshot.data!.data() != null) {
          var records =
              snapshot.data!['records'] as Map<String, dynamic>? ?? {};
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
      stream: FirebaseFirestore.instance
          .collection('daily_attendance')
          .doc('${currentCycleId}_$targetDate')
          .snapshots(),
      builder: (context, attendanceSnap) {
        int expectedCount = 0;
        if (attendanceSnap.hasData &&
            attendanceSnap.data!.exists &&
            attendanceSnap.data!.data() != null) {
          var records =
              attendanceSnap.data!['records'] as Map<String, dynamic>? ?? {};
          records.forEach((studentId, val) {
            if ((val is Map && val['status'] == 'present') || val == 'present') {
              expectedCount++;
            }
          });
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sessions')
              .where('cycleId', isEqualTo: currentCycleId)
              .where('date', isEqualTo: targetDate)
              .where('absent', isEqualTo: false)
              .snapshots(),
          builder: (context, sessionSnap) {
            int actualCount =
                sessionSnap.hasData ? sessionSnap.data!.docs.length : 0;
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
                        colors: [
                          cardColor.withOpacity(0.3),
                          cardColor.withOpacity(0.1)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: cardColor.withOpacity(0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: cardColor.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Icon(
                      isComplete
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded,
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
                                color: (isDarkMode ? Colors.white : primaryColor)
                                    .withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color:
                                      isDarkMode ? accentGold : primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (expectedCount == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "لم يتم تسجيل تفقد مبدئي لهذا اليوم بعد.",
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey[700]),
                            ),
                          )
                        else if (isComplete)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.celebration_rounded,
                                    size: 14, color: Colors.green),
                                SizedBox(width: 6),
                                Text(
                                  "تم إنجاز وتسميع جميع جلسات الطلاب بنجاح! 🎉",
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.4),
                                  width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_rounded,
                                    size: 14, color: Colors.orange),
                                const SizedBox(width: 6),
                                Text(
                                  "باقي ($diff) طلاب لم تُسجّل جلساتهم بعد! اضغط للمتابعة ⚠",
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange),
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
        String value =
            snapshot.hasData ? snapshot.data!.docs.length.toString() : "0";
        return _statsUI(title, subtitle, value, icon, color,
            snapshot.connectionState == ConnectionState.waiting, isDarkMode);
      },
    );
  }

  Widget _buildPercentageCard(String targetDate, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('cycleId', isEqualTo: currentCycleId)
          .where('date', isEqualTo: targetDate)
          .snapshots(),
      builder: (context, snapshot) {
        String percentage = "0%";
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs;
          int presentCount =
              docs.where((doc) => doc['absent'] == false).length;
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

  Widget _statsUI(String title, String subtitle, String value, IconData icon,
      Color color, bool isLoading, bool isDarkMode) {
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
                Text(title,
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo')),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: isDarkMode ? Colors.white38 : Colors.grey[600],
                        fontSize: 10,
                        fontFamily: 'Cairo')),
                const SizedBox(height: 8),
                isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(value,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: 0.5,
                            fontFamily: 'Cairo')),
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

  Widget _buildGlassContainer(
      {required Widget child,
      required bool isDarkMode,
      EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.6),
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
// 🚀 1. واجهة الطلاب الحاضرين الذين لم تُسجل جلساتهم بعد
// =========================================================================
class PendingSessionsPage extends StatefulWidget {
  final String targetDate;
  const PendingSessionsPage({super.key, required this.targetDate});

  @override
  State<PendingSessionsPage> createState() => _PendingSessionsPageState();
}

class _PendingSessionsPageState extends State<PendingSessionsPage> {
  final WidgetsToImageController controller = WidgetsToImageController();
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);
  bool isExporting = false;

  Future<void> _sharePendingListAsImage(
      List<Map<String, dynamic>> pendingStudentsList) async {
    if (pendingStudentsList.isEmpty) return;
    setState(() => isExporting = true);
    try {
      final bytes = await controller.capture();
      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file =
            await File('${tempDir.path}/متبقين_تسميع_${widget.targetDate}.png')
                .create();
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              '⏳ تذكير بالطلاب المتبقين للتسميع اليوم (${widget.targetDate})\nنرجو من الإخوة المشرفين تسجيل التسميعات 🌸\nمعهد الشيخ سعيد العبدالله 🕌',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("حدث خطأ أثناء إنشاء الصورة: $e",
                style: const TextStyle(fontFamily: 'Cairo'))));
      }
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
        backgroundColor:
            isDarkMode ? const Color(0xff0f172a) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            "الطلاب المتبقين للتسميع (${widget.targetDate})",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : primaryColor,
                fontFamily: 'Cairo',
                fontSize: 16),
          ),
          iconTheme:
              IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
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
                      ? [
                          const Color(0xff0f172a),
                          const Color(0xff1e293b),
                          const Color(0xff0f172a)
                        ]
                      : [
                          const Color(0xffe2e8f0),
                          const Color(0xffcfdef3),
                          const Color(0xffe0eafc)
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('daily_attendance')
                    .doc('${currentCycleId}_${widget.targetDate}')
                    .snapshots(),
                builder: (context, attendanceSnap) {
                  if (attendanceSnap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!attendanceSnap.hasData ||
                      !attendanceSnap.data!.exists ||
                      attendanceSnap.data!.data() == null) {
                    return Center(
                      child: Text(
                          "لم يتم تسجيل تفقد مبدئي لليوم المختار بعد.",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white70 : primaryColor,
                              fontSize: 14)),
                    );
                  }

                  var records =
                      attendanceSnap.data!['records'] as Map<String, dynamic>? ??
                          {};
                  List<String> presentStudentIds = [];

                  records.forEach((studentId, val) {
                    if ((val is Map && val['status'] == 'present') ||
                        val == 'present') {
                      presentStudentIds.add(studentId);
                    }
                  });

                  if (presentStudentIds.isEmpty) {
                    return Center(
                      child: Text(
                          "لا يوجد طلاب حاضرون مبدئياً بانتظار التسميع 🎉",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white70 : primaryColor,
                              fontSize: 14)),
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('sessions')
                        .where('cycleId', isEqualTo: currentCycleId)
                        .where('date', isEqualTo: widget.targetDate)
                        .snapshots(),
                    builder: (context, sessionsSnap) {
                      if (sessionsSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      Set<String> recordedStudentIds = sessionsSnap.hasData
                          ? sessionsSnap.data!.docs
                              .map((doc) => doc['studentId'].toString())
                              .toSet()
                          : {};

                      List<String> pendingStudentIds = presentStudentIds
                          .where((id) => !recordedStudentIds.contains(id))
                          .toList();

                      if (pendingStudentIds.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  color: Colors.green, size: 65),
                              const SizedBox(height: 14),
                              Text("اكتمل الإنجاز! 🎉",
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isDarkMode
                                          ? Colors.white
                                          : primaryColor)),
                              const SizedBox(height: 6),
                              Text(
                                  "تم تسجيل جلسات لجميع الطلاب الحاضرين بنجاح.",
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      color: isDarkMode
                                          ? Colors.white60
                                          : Colors.black54)),
                            ],
                          ),
                        );
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('students')
                            .where('cycleId', isEqualTo: currentCycleId)
                            .where('archived', isEqualTo: false)
                            .snapshots(),
                        builder: (context, studentsSnap) {
                          if (studentsSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (!studentsSnap.hasData ||
                              studentsSnap.data!.docs.isEmpty) {
                            return const Center(
                                child: Text("لا توجد بيانات للطلاب",
                                    style: TextStyle(fontFamily: 'Cairo')));
                          }

                          List<Map<String, dynamic>> pendingStudentsList = [];

                          for (var doc in studentsSnap.data!.docs) {
                            if (pendingStudentIds.contains(doc.id)) {
                              var data = doc.data() as Map<String, dynamic>;
                              dynamic rawSerial = data['serial'];
                              int serialNum = rawSerial is int
                                  ? rawSerial
                                  : (int.tryParse(
                                          rawSerial?.toString() ?? '0') ??
                                      0);

                              pendingStudentsList.add({
                                'id': doc.id,
                                'name': data['name'] ?? 'طالب',
                                'supervisorName':
                                    data['supervisorName'] ?? 'غير محدد',
                                'imageUrl': data['imageUrl'] ?? '',
                                'serial': serialNum,
                              });
                            }
                          }

                          pendingStudentsList.sort((a, b) =>
                              (a['serial'] as int)
                                  .compareTo(b['serial'] as int));

                          return Stack(
                            children: [
                              Offstage(
                                offstage: true,
                                child: WidgetsToImage(
                                  controller: controller,
                                  child: SizedBox(
                                    width: 600,
                                    child: _buildExportablePoster(
                                        pendingStudentsList),
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 18, right: 18, top: 10),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.orange.shade800,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          elevation: 3,
                                        ),
                                        onPressed: isExporting
                                            ? null
                                            : () => _sharePendingListAsImage(
                                                pendingStudentsList),
                                        icon: isExporting
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2))
                                            : const Icon(Icons.share_rounded,
                                                color: Colors.white, size: 20),
                                        label: Text(
                                          isExporting
                                              ? "جاري الإنشاء..."
                                              : "مشاركة الصورة لتذكير المشرفين 📸",
                                          style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 15),
                                      itemCount: pendingStudentsList.length,
                                      itemBuilder: (context, index) {
                                        var student =
                                            pendingStudentsList[index];
                                        String studentName = student['name'];
                                        String supervisorName =
                                            student['supervisorName'];
                                        String imageUrl = student['imageUrl'];
                                        String firstLetter =
                                            studentName.isNotEmpty
                                                ? studentName
                                                    .trim()
                                                    .substring(0, 1)
                                                : "?";

                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 14),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                  sigmaX: 12, sigmaY: 12),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: isDarkMode
                                                      ? Colors.white
                                                          .withOpacity(0.06)
                                                      : Colors.white
                                                          .withOpacity(0.55),
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                  border: Border.all(
                                                    color: Colors.orange
                                                        .withOpacity(isDarkMode
                                                            ? 0.35
                                                            : 0.5),
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange
                                                            .withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                14),
                                                      ),
                                                      child: const Text(
                                                          "بانتظار التسميع",
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontFamily:
                                                                  'Cairo',
                                                              color: Colors
                                                                  .orange)),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: [
                                                          Text(studentName,
                                                              textAlign:
                                                                  TextAlign.right,
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontFamily:
                                                                      'Cairo',
                                                                  fontSize: 15,
                                                                  color: isDarkMode
                                                                      ? Colors
                                                                          .white
                                                                      : primaryColor)),
                                                          const SizedBox(
                                                              height: 3),
                                                          Text(
                                                              "المشرف: $supervisorName",
                                                              textAlign:
                                                                  TextAlign.right,
                                                              style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontFamily:
                                                                      'Cairo',
                                                                  color: isDarkMode
                                                                      ? Colors
                                                                          .white60
                                                                      : Colors
                                                                          .black54)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _buildExportablePoster(List<Map<String, dynamic>> students) {
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
          const Text("معهد الشيخ سعيد العبدالله",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo')),
          const SizedBox(height: 12),
          Text("⏳ الطلاب المتبقون للتسميع يوم: ${widget.targetDate}",
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo')),
          const SizedBox(height: 25),
          Table(
            children: [
              ...students.map((s) => TableRow(children: [
                    Text(s['name'] ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontFamily: 'Cairo')),
                    Text(s['supervisorName'] ?? '',
                        style: const TextStyle(
                            color: Colors.white70, fontFamily: 'Cairo')),
                  ]))
            ],
          )
        ],
      ),
    );
  }
}

// =========================================================================
// 🚀 2. واجهة الطلاب الغائبين
// =========================================================================
class DailyAbsentStudentsPage extends StatefulWidget {
  final String targetDate;
  const DailyAbsentStudentsPage({super.key, required this.targetDate});

  @override
  State<DailyAbsentStudentsPage> createState() =>
      _DailyAbsentStudentsPageState();
}

class _DailyAbsentStudentsPageState extends State<DailyAbsentStudentsPage> {
  final WidgetsToImageController controller = WidgetsToImageController();
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);
  bool isExporting = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor:
            isDarkMode ? const Color(0xff0f172a) : const Color(0xfff1f5f9),
        appBar: AppBar(
          title: Text("الطلاب الغائبين (${widget.targetDate}) 🔴",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : primaryColor,
                  fontFamily: 'Cairo',
                  fontSize: 16)),
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sessions')
              .where('cycleId', isEqualTo: currentCycleId)
              .where('date', isEqualTo: widget.targetDate)
              .where('absent', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final absentDocs = snapshot.data!.docs;

            if (absentDocs.isEmpty) {
              return Center(
                child: Text("لا يوجد غياب مسجل في هذا اليوم 🎉",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white70 : primaryColor,
                        fontSize: 15)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: absentDocs.length,
              itemBuilder: (context, index) {
                final data = absentDocs[index].data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(data['studentName'] ?? 'طالب',
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : primaryColor)),
                  subtitle: Text(data['absenceReason'] ?? 'بدون سبب',
                      style: TextStyle(
                          color: isDarkMode ? Colors.white60 : Colors.black54)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// =========================================================================
// 🚀 3. واجهة الطلاب الحاضرين الذين لم يسمّعوا
// =========================================================================
class DailyDidNotReciteStudentsPage extends StatefulWidget {
  final String targetDate;
  const DailyDidNotReciteStudentsPage({super.key, required this.targetDate});

  @override
  State<DailyDidNotReciteStudentsPage> createState() =>
      _DailyDidNotReciteStudentsPageState();
}

class _DailyDidNotReciteStudentsPageState
    extends State<DailyDidNotReciteStudentsPage> {
  final Color primaryColor = const Color(0xff425c75);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text("حضر ولم يسمّع (${widget.targetDate}) ⚠️",
            style: const TextStyle(fontFamily: 'Cairo')),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .where('cycleId', isEqualTo: currentCycleId)
            .where('date', isEqualTo: widget.targetDate)
            .where('didNotRecite', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("لا يوجد طلاب بحالة حضر ولم يسمّع اليوم 🎉",
                  style: TextStyle(fontFamily: 'Cairo')),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['studentName'] ?? 'طالب',
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : primaryColor)),
              );
            },
          );
        },
      ),
    );
  }
}

// =========================================================================
// 🚀 4. واجهة التسميعات والجلسات اليومية
// =========================================================================
class DailyRecitationsPage extends StatefulWidget {
  final String targetDate;
  final String role;

  const DailyRecitationsPage({
    super.key,
    required this.targetDate,
    this.role = 'supervisor',
  });

  @override
  State<DailyRecitationsPage> createState() => _DailyRecitationsPageState();
}

class _DailyRecitationsPageState extends State<DailyRecitationsPage> {
  final Color primaryColor = const Color(0xff425c75);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text("جلسات التسميع (${widget.targetDate}) 📝",
              style: const TextStyle(fontFamily: 'Cairo')),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sessions')
              .where('cycleId', isEqualTo: currentCycleId)
              .where('date', isEqualTo: widget.targetDate)
              .where('absent', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final sessions = snapshot.data!.docs;

            if (sessions.isEmpty) {
              return const Center(
                child: Text("لا توجد تسميعات مسجلة في هذا اليوم",
                    style: TextStyle(fontFamily: 'Cairo')),
              );
            }

            return ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final data = session.data() as Map<String, dynamic>;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(data['studentName'] ?? 'طالب',
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        "الحفظ: ${data['newMemorization'] ?? 'لا يوجد'}",
                        style: const TextStyle(fontFamily: 'Cairo')),
                    trailing: widget.role == 'manager'
                        ? IconButton(
                            icon:
                                const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () async {
                              await SessionService()
                                  .deleteSession(session.id);
                              SessionService().recalculateConsecutiveAbsences(
                                  data['studentId']);
                            },
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}