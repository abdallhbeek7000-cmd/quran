import 'dart:io';
import 'dart:typed_data';
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

  // 🔍 فحص حالة الحضور للتحقق من المسمى داخل records
  bool _isStudentPresent(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is String) {
      String s = val.trim().toLowerCase();
      return s == 'present' || s == 'حاضر' || s == 'true';
    }
    if (val is Map) {
      var status = val['status']?.toString().trim().toLowerCase();
      if (status == 'present' || status == 'حاضر' || status == 'true') return true;
      if (val['isPresent'] == true || val['attended'] == true) return true;
    }
    return false;
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
                          .where('date', isEqualTo: formattedDate)
                          .where('absent', isEqualTo: false)
                          .where('didNotRecite', isEqualTo: false)
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

  // 🔥 جلب مستند التفقد بالتاريخ (حتى لو كان معرّف المستند يبدأ بـ cycleId)
  Widget _buildExpectedSessionsCard(String targetDate, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_attendance')
          .where('date', isEqualTo: targetDate)
          .snapshots(),
      builder: (context, snapshot) {
        int expectedCount = 0;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            var records = data['records'] as Map<String, dynamic>? ?? {};
            records.forEach((studentId, val) {
              if (_isStudentPresent(val)) {
                expectedCount++;
              }
            });
          }
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_attendance')
          .where('date', isEqualTo: targetDate)
          .snapshots(),
      builder: (context, attendanceSnap) {
        int expectedCount = 0;
        if (attendanceSnap.hasData && attendanceSnap.data!.docs.isNotEmpty) {
          for (var doc in attendanceSnap.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            var records = data['records'] as Map<String, dynamic>? ?? {};
            records.forEach((studentId, val) {
              if (_isStudentPresent(val)) {
                expectedCount++;
              }
            });
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sessions')
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
          .where('date', isEqualTo: targetDate)
          .snapshots(),
      builder: (context, snapshot) {
        String percentage = "0%";
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs;
          int presentCount = docs.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            return (d['absent'] == false) && (d['didNotRecite'] != true);
          }).length;
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
// 🚀 1. واجهة المتبقين للتسميع (مع إصلاح جلب التفقد وحل التصدير)
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
  bool isExporting = false;

  bool _isStudentPresent(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is String) {
      String s = val.trim().toLowerCase();
      return s == 'present' || s == 'حاضر' || s == 'true';
    }
    if (val is Map) {
      var status = val['status']?.toString().trim().toLowerCase();
      if (status == 'present' || status == 'حاضر' || status == 'true') return true;
      if (val['isPresent'] == true || val['attended'] == true) return true;
    }
    return false;
  }

  Future<void> _sharePendingListAsImage(
      List<Map<String, dynamic>> pendingStudentsList) async {
    if (pendingStudentsList.isEmpty) return;
    setState(() => isExporting = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
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
      } else {
        throw "فشل التقاط البكسلات من الودجت";
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
            "المتبقين للتسميع (${widget.targetDate}) ⏳",
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
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('daily_attendance')
                    .where('date', isEqualTo: widget.targetDate)
                    .snapshots(),
                builder: (context, attendanceSnap) {
                  if (attendanceSnap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!attendanceSnap.hasData ||
                      attendanceSnap.data!.docs.isEmpty) {
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

                  List<String> presentStudentIds = [];
                  for (var doc in attendanceSnap.data!.docs) {
                    var attData = doc.data() as Map<String, dynamic>;
                    var records =
                        attData['records'] as Map<String, dynamic>? ?? {};
                    records.forEach((studentId, val) {
                      if (_isStudentPresent(val)) {
                        presentStudentIds.add(studentId);
                      }
                    });
                  }

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
                              // 🔥 نقل ودجت التصدير لـ Offscreen Rendering لضمان بنائها دون أخطاء
                              Positioned(
                                left: -9999,
                                child: WidgetsToImage(
                                  controller: controller,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      width: 600,
                                      child: _buildExportablePoster(
                                          pendingStudentsList),
                                    ),
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

                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
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
                                                          horizontal: 10,
                                                          vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange
                                                            .withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                12),
                                                      ),
                                                      child: const Text(
                                                          "بانتظار التسميع ⏳",
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
                                                                  fontSize: 14,
                                                                  color: isDarkMode
                                                                      ? Colors
                                                                          .white
                                                                      : primaryColor)),
                                                          const SizedBox(
                                                              height: 2),
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
          const Text("معهد الشيخ سعيد العبدالله 🕌",
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
          const SizedBox(height: 20),
          Table(
            children: [
              ...students.map((s) => TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(s['name'] ?? '',
                          style: const TextStyle(
                              color: Colors.white, fontFamily: 'Cairo')),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(s['supervisorName'] ?? '',
                          style: const TextStyle(
                              color: Colors.white70, fontFamily: 'Cairo')),
                    ),
                  ]))
            ],
          )
        ],
      ),
    );
  }
}

// =========================================================================
// 🚀 2. واجهة التسميعات والجلسات اليومية
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
  final Color accentGold = const Color(0xffd4af37);

  String _getArabicDayName(String dateString) {
    try {
      List<String> parts = dateString.split('-');
      if (parts.length == 3) {
        int year = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int day = int.parse(parts[2]);
        DateTime date = DateTime(year, month, day);
        List<String> arabicDays = [
          'الإثنين',
          'الثلاثاء',
          'الأربعاء',
          'الخميس',
          'الجمعة',
          'السبت',
          'الأحد'
        ];
        return arabicDays[date.weekday - 1];
      }
    } catch (e) {
      return "";
    }
    return "";
  }

  String _getJuzName(int juzNum) {
    switch (juzNum) {
      case 30:
        return "جزء عمَّ 👶";
      case 29:
        return "جزء تبارك 📖";
      case 28:
        return "قد سمع 📜";
      case 27:
        return "الذاريات 🌟";
      case 26:
        return "الأحقاف ✨";
      default:
        return "";
    }
  }

  Color _getRatingColor(String? rating) {
    switch (rating) {
      case "ممتاز":
        return Colors.green;
      case "جيد جداً":
        return Colors.teal;
      case "جيد":
        return Colors.orange;
      case "مقبول":
        return Colors.blueGrey;
      case "ضعيف":
        return Colors.red;
      default:
        return Colors.blue;
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
            "جلسات التسميع (${widget.targetDate}) 📝",
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
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sessions')
                    .where('date', isEqualTo: widget.targetDate)
                    .where('absent', isEqualTo: false)
                    .where('didNotRecite', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text("لا توجد جلسات تسميع مسجلة في هذا اليوم 🍃",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white70 : primaryColor,
                              fontSize: 14)),
                    );
                  }

                  final sessions = snapshot.data!.docs;

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, top: 10, bottom: 30),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final sessionDoc = sessions[index];
                      final data = sessionDoc.data() as Map<String, dynamic>;

                      return _buildSessionCardItem(
                          context, sessionDoc.id, data, isDarkMode);
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

  Widget _buildSessionCardItem(BuildContext context, String sessionId,
      Map<String, dynamic> data, bool isDarkMode) {
    String studentName = data['studentName'] ?? 'طالب';
    bool isAbsent = data['absent'] ?? false;
    bool isExam = data['isExam'] ?? false;
    bool didNotRecite = data['didNotRecite'] ?? false;
    int selectedJuz =
        data['selectedJuz'] ?? (data['isJuzAmma'] == true ? 30 : 0);

    String sessionDateRaw = data['date'] ?? '';

    String actualCreatedAt = data['actualCreatedAt']?.toString() ?? '';
    String actualEditedAt = data['actualEditedAt']?.toString() ?? '';

    String nMemo = data['newMemorization']?.toString().trim() ?? '';
    String nRev = data['nearReview']?.toString().trim() ?? '';
    String fRev = data['farReview']?.toString().trim() ??
        (data['review']?.toString().trim() ?? '');
    String sight = data['readingBySight']?.toString().trim() ?? '';

    String memRating = data['memorizationRating'] ?? data['rating'] ?? "";
    String newRevRating =
        data['newReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? "";
    String oldRevRating =
        data['oldReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? "";

    String nHw = data['newHomework']?.toString().trim() ?? '';
    String nRevHw = data['newReviewHomework']?.toString().trim() ?? '';
    String oRevHw = data['oldReviewHomework']?.toString().trim() ?? '';
    String oldHw = data['homework']?.toString().trim() ?? '';

    List<dynamic>? memoSupList =
        data['newMemoSupervisorNames'] ?? data['supervisorNames'];
    String memoSupervisors = (memoSupList != null && memoSupList.isNotEmpty)
        ? memoSupList.join(' ، ')
        : (data['supervisorName'] ?? 'غير محدد');

    List<dynamic>? revSupList =
        data['reviewSupervisorNames'] ?? data['supervisorNames'];
    String revSupervisors = (revSupList != null && revSupList.isNotEmpty)
        ? revSupList.join(' ، ')
        : (data['supervisorName'] ?? 'غير محدد');

    List<Widget> activeBoxes = [];
    if (!didNotRecite && !isAbsent && !isExam) {
      if (nMemo.isNotEmpty)
        activeBoxes.add(_buildGridInfoBox(
            Icons.star_rounded, "الحفظ الجديد", nMemo, Colors.amber, isDarkMode));
      if (nRev.isNotEmpty)
        activeBoxes.add(_buildGridInfoBox(
            Icons.menu_book_rounded,
            "مراجعة جديد",
            nRev,
            isDarkMode ? Colors.tealAccent : Colors.teal,
            isDarkMode));
      if (fRev.isNotEmpty)
        activeBoxes.add(_buildGridInfoBox(
            Icons.history_toggle_off_rounded,
            "مراجعة قديم",
            fRev,
            Colors.blueGrey,
            isDarkMode));
      if (sight.isNotEmpty)
        activeBoxes.add(_buildGridInfoBox(
            Icons.chrome_reader_mode_rounded,
            "قراءة نظراً",
            sight,
            Colors.indigoAccent,
            isDarkMode));
    }

    String juzChipTitle = _getJuzName(selectedJuz);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : primaryColor.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: accentGold.withOpacity(0.2),
                            child: Icon(Icons.person_rounded,
                                color: accentGold, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            studentName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : primaryColor,
                              fontFamily: 'Cairo',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (juzChipTitle.isNotEmpty)
                        _buildBadge(juzChipTitle, Colors.purple),
                    ],
                  ),
                  if (!isAbsent && !isExam && !didNotRecite) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (nMemo.isNotEmpty && memRating.isNotEmpty)
                          _buildBadge(
                              "حفظ: $memRating", _getRatingColor(memRating)),
                        if (nRev.isNotEmpty && newRevRating.isNotEmpty)
                          _buildBadge("م.جديد: $newRevRating",
                              _getRatingColor(newRevRating)),
                        if (fRev.isNotEmpty && oldRevRating.isNotEmpty)
                          _buildBadge("م.قديم: $oldRevRating",
                              _getRatingColor(oldRevRating)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.role == 'manager' &&
                      (actualCreatedAt.isNotEmpty ||
                          actualEditedAt.isNotEmpty)) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber
                            .withOpacity(isDarkMode ? 0.12 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.amber.withOpacity(0.4), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (actualCreatedAt.isNotEmpty)
                                  Text(
                                    "تاريخ ووقت الإدخال الفعلي: $actualCreatedAt",
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo',
                                        color: isDarkMode
                                            ? Colors.amberAccent
                                            : Colors.orange.shade900),
                                  ),
                                if (actualEditedAt.isNotEmpty)
                                  Text(
                                    "تاريخ آخر تعديل: $actualEditedAt",
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo',
                                        color: isDarkMode
                                            ? Colors.orangeAccent
                                            : Colors.deepOrange.shade800),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (nMemo.isNotEmpty && memoSupervisors == revSupervisors) ...[
                    _buildMinimalistDetailRow(Icons.person_outline,
                        "المشرف المسجِّل", memoSupervisors, isDarkMode,
                        isBold: true),
                  ] else ...[
                    if (nMemo.isNotEmpty)
                      _buildMinimalistDetailRow(Icons.person_pin_rounded,
                          "مشرف الحفظ الجديد", memoSupervisors, isDarkMode,
                          isBold: true),
                    if (fRev.isNotEmpty || nRev.isNotEmpty) ...[
                      if (nMemo.isNotEmpty) const SizedBox(height: 6),
                      _buildMinimalistDetailRow(
                          Icons.supervisor_account_rounded,
                          "مشرف المراجعة",
                          revSupervisors,
                          isDarkMode,
                          isBold: true),
                    ],
                  ],

                  Divider(
                      color: isDarkMode ? Colors.white24 : Colors.black12,
                      height: 20),

                  if (activeBoxes.isNotEmpty) ...[
                    for (int i = 0; i < activeBoxes.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(child: activeBoxes[i]),
                            const SizedBox(width: 10),
                            if (i + 1 < activeBoxes.length)
                              Expanded(child: activeBoxes[i + 1])
                            else
                              Expanded(child: const SizedBox()),
                          ],
                        ),
                      ),
                    Divider(
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                        height: 20),
                  ],

                  if (nHw.isNotEmpty ||
                      nRevHw.isNotEmpty ||
                      oRevHw.isNotEmpty ||
                      oldHw.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentGold
                            .withOpacity(isDarkMode ? 0.08 : 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color: accentGold.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.assignment_outlined,
                                  size: 16, color: accentGold),
                              const SizedBox(width: 6),
                              Text("الواجب القادم:",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (nHw.isNotEmpty)
                            _buildHomeworkRow("حفظ جديد", nHw, isDarkMode),
                          if (nRevHw.isNotEmpty)
                            _buildHomeworkRow("مراجعة جديد", nRevHw, isDarkMode),
                          if (oRevHw.isNotEmpty)
                            _buildHomeworkRow("مراجعة قديم", oRevHw, isDarkMode),
                          if (oldHw.isNotEmpty &&
                              nHw.isEmpty &&
                              nRevHw.isEmpty &&
                              oRevHw.isEmpty)
                            _buildHomeworkRow("الواجب", oldHw, isDarkMode),
                        ],
                      ),
                    ),
                    Divider(
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                        height: 20),
                  ],

                  if (data['religiousActivities'] != null &&
                      data['religiousActivities']
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                    _buildMinimalistDetailRow(Icons.mosque_outlined,
                        "الأنشطة الدينية", data['religiousActivities'], isDarkMode),
                    Divider(
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                        height: 20),
                  ],

                  if (selectedJuz == 0) ...[
                    _buildMinimalistDetailRow(
                        Icons.analytics_outlined,
                        "إجمالي الحفظ للختمة",
                        data['total_memorized_pages'] != null
                            ? "${data['total_memorized_pages']} صفحة"
                            : "---",
                        isDarkMode),
                    Divider(
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                        height: 20),
                  ],

                  if (data['studentStatus'] != null &&
                      data['studentStatus'].toString().trim().isNotEmpty) ...[
                    _buildMinimalistDetailRow(Icons.mood, "حالة الطالب",
                        data['studentStatus'], isDarkMode),
                    Divider(
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                        height: 20),
                  ],

                  if (data['notes'] != null &&
                      data['notes'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildNotesBox(data['notes'], isDarkMode),
                  ],

                  const SizedBox(height: 12),
                  _buildActionButtons(context, sessionId, data, isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeworkRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, right: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• $label: ",
              style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildGridInfoBox(IconData icon, String title, String val,
      Color iconColor, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withOpacity(0.2)
            : const Color(0xfff8fafc).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDarkMode ? Colors.white12 : const Color(0xffe2e8f0),
            width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode ? Colors.white60 : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo'),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            val.trim().isEmpty ? '---' : val,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : primaryColor,
                fontFamily: 'Cairo',
                height: 1.4),
          )
        ],
      ),
    );
  }

  Widget _buildMinimalistDetailRow(
      IconData icon, String label, String value, bool isDarkMode,
      {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon,
              size: 17,
              color: isDarkMode ? accentGold : primaryColor.withOpacity(0.6)),
        ),
        const SizedBox(width: 8),
        Text("$label: ",
            style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white60 : Colors.grey[700],
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '---' : value,
            style: TextStyle(
                fontSize: 13,
                color: isBold
                    ? (isDarkMode ? Colors.white : primaryColor)
                    : (isDarkMode ? Colors.white70 : Colors.black87),
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontFamily: 'Cairo'),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesBox(String notes, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withOpacity(0.2)
            : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: isDarkMode ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.comment,
              size: 16, color: isDarkMode ? accentGold : primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text("ملاحظات: $notes",
                style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String id,
      Map<String, dynamic> data, bool isDarkMode) {
    if (widget.role == "readonly") {
      return const SizedBox();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
              backgroundColor: isDarkMode
                  ? Colors.orange.withOpacity(0.12)
                  : Colors.orange.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EditSessionPage(sessionId: id, data: data))),
          icon: Icon(Icons.edit_rounded,
              size: 16,
              color: isDarkMode ? Colors.orangeAccent : Colors.orange.shade800),
          label: Text("تعديل الجلسة",
              style: TextStyle(
                  color: isDarkMode
                      ? Colors.orangeAccent
                      : Colors.orange.shade800,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
        if (widget.role == "manager") ...[
          const SizedBox(width: 10),
          TextButton.icon(
            style: TextButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                        backgroundColor: isDarkMode
                            ? const Color(0xff1e293b)
                            : Colors.white,
                        title: Text("حذف الجلسة",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black)),
                        content: Text(
                            "هل أنت تأكد من رغبتك في حذف هذه الجلسة بشكل نهائي؟",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black87)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text("إلغاء",
                                  style: TextStyle(fontFamily: 'Cairo'))),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text("حذف",
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold))),
                        ],
                      ));

              if (confirm == true) {
                await SessionService().deleteSession(id);
                SessionService()
                    .recalculateConsecutiveAbsences(data['studentId']);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("تم حذف الجلسة بنجاح",
                        style: TextStyle(fontFamily: 'Cairo'))));
              }
            },
            icon: const Icon(Icons.delete_outline,
                size: 16, color: Colors.redAccent),
            label: const Text("حذف",
                style: TextStyle(
                    color: Colors.redAccent,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ]
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 4)
          ]),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo')),
    );
  }

  Widget _buildGlassContainer(
      {required Widget child,
      required bool isDarkMode,
      EdgeInsetsGeometry padding = EdgeInsets.zero,
      Color? customColor,
      Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ??
                (isDarkMode
                    ? Colors.white.withOpacity(0.06)
                    : Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: customBorderColor ??
                  (isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.6)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.02),
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
// 🚀 3. واجهة سجل الغائبين (مع التصدير بنجاح ودون أخطاء)
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
  bool isExporting = false;

  Future<void> _shareAbsentListAsImage(
      List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    setState(() => isExporting = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final bytes = await controller.capture();
      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file =
            await File('${tempDir.path}/قائمة_الغياب_${widget.targetDate}.png')
                .create();
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              '🚨 كرت الغياب اليومي (${widget.targetDate})\nمعهد الشيخ سعيد العبدالله 🕌',
        );
      } else {
        throw "فشل التقاط بكسلات الصورة";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("حدث خطأ أثناء تصدير الصورة: $e",
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
          title: Text("سجل الغائبين (${widget.targetDate}) 🔴",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : primaryColor,
                  fontFamily: 'Cairo',
                  fontSize: 16)),
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
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sessions')
                    .where('date', isEqualTo: widget.targetDate)
                    .where('absent', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final absentDocs = snapshot.data?.docs ?? [];

                  if (absentDocs.isEmpty) {
                    return Center(
                      child: Text("لا يوجد غياب مسجل في هذا اليوم 🎉",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white70 : primaryColor,
                              fontSize: 14)),
                    );
                  }

                  return Stack(
                    children: [
                      // 🔥 الرسم خارج الشاشة لضمان أداء لالتقاط بدون مشاكل
                      Positioned(
                        left: -9999,
                        child: WidgetsToImage(
                          controller: controller,
                          child: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: 600,
                              child: _buildExportablePoster(absentDocs),
                            ),
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
                                  backgroundColor: Colors.redAccent.shade700,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 3,
                                ),
                                onPressed: isExporting
                                    ? null
                                    : () => _shareAbsentListAsImage(absentDocs),
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
                                      : "مشاركة كرت الغياب اليومي لـ لواتساب 📸",
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
                              padding: const EdgeInsets.all(18),
                              itemCount: absentDocs.length,
                              itemBuilder: (context, index) {
                                final data = absentDocs[index].data()
                                    as Map<String, dynamic>;
                                String studentName =
                                    data['studentName'] ?? 'طالب';
                                String reason =
                                    data['absenceReason'] ?? 'بدون سبَب مُسجّل';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 12, sigmaY: 12),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? Colors.white.withOpacity(0.06)
                                              : Colors.white.withOpacity(0.55),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: Colors.redAccent
                                                  .withOpacity(0.3),
                                              width: 1.2),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent
                                                    .withOpacity(0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                  Icons.person_off_rounded,
                                                  color: Colors.redAccent,
                                                  size: 22),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(studentName,
                                                      style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                          color: isDarkMode
                                                              ? Colors.white
                                                              : primaryColor)),
                                                  const SizedBox(height: 2),
                                                  Text("سبب الغياب: $reason",
                                                      style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          fontSize: 11,
                                                          color: isDarkMode
                                                              ? Colors.white60
                                                              : Colors.black54)),
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
          const Text("معهد الشيخ سعيد العبدالله 🕌",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo')),
          const SizedBox(height: 12),
          Text("🔴 قائمة الطلاب الغائبين يوم: ${widget.targetDate}",
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo')),
          const SizedBox(height: 20),
          Table(
            children: [
              ...docs.map((doc) {
                var s = doc.data() as Map<String, dynamic>;
                return TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(s['studentName'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(s['absenceReason'] ?? 'بدون سبب',
                        style: const TextStyle(
                            color: Colors.white70, fontFamily: 'Cairo')),
                  ),
                ]);
              })
            ],
          )
        ],
      ),
    );
  }
}

// =========================================================================
// 🚀 4. واجهة الطلاب (حضر ولم يسمّع مع التصدير HD)
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
  final WidgetsToImageController controller = WidgetsToImageController();
  final Color primaryColor = const Color(0xff425c75);
  bool isExporting = false;

  Future<void> _shareDidNotReciteListAsImage(
      List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    setState(() => isExporting = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final bytes = await controller.capture();
      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = await File(
                '${tempDir.path}/حضر_ولم_يسمع_${widget.targetDate}.png')
            .create();
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              '⚠️️ إشعار الطلاب (حضر ولم يسمّع) اليوم (${widget.targetDate})\nمعهد الشيخ سعيد العبدالله 🕌',
        );
      } else {
        throw "فشل التقاط بكسلات الصورة";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("حدث خطأ أثناء تصدير الصورة: $e",
                style: const TextStyle(fontFamily: 'Cairo'))));
      }
    } finally {
      if (mounted) setState(() => isExporting = false);
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
        title: Text("حضر ولم يسمّع (${widget.targetDate}) ⚠️",
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : primaryColor,
                fontSize: 16)),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .where('date', isEqualTo: widget.targetDate)
                  .where('didNotRecite', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Text("لا يوجد طلاب بحالة حضر ولم يسمّع اليوم 🎉",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white70 : primaryColor,
                            fontSize: 14)),
                  );
                }

                return Stack(
                  children: [
                    // 🔥 الرسم خارج الشاشة لضمان التصدير
                    Positioned(
                      left: -9999,
                      child: WidgetsToImage(
                        controller: controller,
                        child: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 600,
                            child: _buildExportablePoster(docs),
                          ),
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
                                backgroundColor: Colors.blueGrey.shade800,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                              ),
                              onPressed: isExporting
                                  ? null
                                  : () => _shareDidNotReciteListAsImage(docs),
                              icon: isExporting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.share_rounded,
                                      color: Colors.white, size: 20),
                              label: Text(
                                isExporting
                                    ? "جاري الإنشاء..."
                                    : "مشاركة القائمة كصورة لجروب الأهالي 📸",
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
                            padding: const EdgeInsets.all(18),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              String studentName =
                                  data['studentName'] ?? 'طالب';
                              String supervisorName =
                                  data['supervisorName'] ?? 'غير محدد';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 12, sigmaY: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? Colors.white.withOpacity(0.06)
                                            : Colors.white.withOpacity(0.55),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.blueGrey
                                                .withOpacity(0.4),
                                            width: 1.2),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey
                                                  .withOpacity(0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                                Icons.speaker_notes_off_outlined,
                                                color: Colors.blueGrey,
                                                size: 22),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(studentName,
                                                    style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                        color: isDarkMode
                                                            ? Colors.white
                                                            : primaryColor)),
                                                const SizedBox(height: 2),
                                                Text("المشرف: $supervisorName",
                                                    style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontSize: 11,
                                                        color: isDarkMode
                                                            ? Colors.white60
                                                            : Colors.black54)),
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
            ),
          ),
        ],
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
          const Text("معهد الشيخ سعيد العبدالله 🕌",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo')),
          const SizedBox(height: 12),
          Text("⚠️ قائمة الطلاب الذين حضروا ولم يسمّعوا يوم: ${widget.targetDate}",
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo')),
          const SizedBox(height: 20),
          Table(
            children: [
              ...docs.map((doc) {
                var s = doc.data() as Map<String, dynamic>;
                return TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(s['studentName'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(s['supervisorName'] ?? 'غير محدد',
                        style: const TextStyle(
                            color: Colors.white70, fontFamily: 'Cairo')),
                  ),
                ]);
              })
            ],
          )
        ],
      ),
    );
  }
}