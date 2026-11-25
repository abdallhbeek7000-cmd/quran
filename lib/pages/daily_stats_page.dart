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

  bool get _isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  String get arabicDayName {
    const List<String> arabicDays = [
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

  bool _isStudentPresent(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is String) {
      final s = val.trim().toLowerCase();
      return s == 'present' || s == 'حاضر' || s == 'true';
    }
    if (val is Map) {
      final status = val['status']?.toString().trim().toLowerCase();
      if (status == 'present' || status == 'حاضر' || status == 'true') {
        return true;
      }
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
    final dateStr = formattedDate;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDarkMode ? const Color(0xff0b1120) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "الإحصائيات اليومية",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDarkMode ? Colors.white : primaryColor,
                fontFamily: 'Cairo',
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.insights_rounded,
                color: isDarkMode ? accentGold : primaryColor, size: 20),
          ],
        ),
        iconTheme:
            IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // خلفية متدرجة ناعمة بدون فلاتر ثقيلة
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? const [
                        Color(0xff0b1120),
                        Color(0xff131c31),
                        Color(0xff0b1120),
                      ]
                    : const [
                        Color(0xfff8fafc),
                        Color(0xffe2e8f0),
                        Color(0xffdbeafe),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -50,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentGold.withOpacity(isDarkMode ? 0.08 : 0.14),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(isDarkMode ? 0.16 : 0.12),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('daily_attendance')
                    .where('date', isEqualTo: dateStr)
                    .snapshots(),
                builder: (context, attendanceSnap) {
                  int expectedCount = 0;
                  if (attendanceSnap.hasData) {
                    for (final doc in attendanceSnap.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final records =
                          data['records'] as Map<String, dynamic>? ?? {};
                      records.forEach((_, val) {
                        if (_isStudentPresent(val)) {
                          expectedCount++;
                        }
                      });
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('sessions')
                        .where('date', isEqualTo: dateStr)
                        .snapshots(),
                    builder: (context, sessionSnap) {
                      final isLoading = attendanceSnap.connectionState ==
                              ConnectionState.waiting &&
                          sessionSnap.connectionState ==
                              ConnectionState.waiting;

                      int recordedSessionsCount = 0;
                      int didNotReciteCount = 0;
                      int absentCount = 0;
                      int nonAbsentSessionsCount = 0;

                      if (sessionSnap.hasData) {
                        for (final doc in sessionSnap.data!.docs) {
                          final d = doc.data() as Map<String, dynamic>;
                          final isAbsent = d['absent'] == true;
                          final didNotRecite = d['didNotRecite'] == true;

                          if (isAbsent) {
                            absentCount++;
                          } else {
                            nonAbsentSessionsCount++;
                            if (didNotRecite) {
                              didNotReciteCount++;
                            } else {
                              recordedSessionsCount++;
                            }
                          }
                        }
                      }

                      final totalRecords = sessionSnap.hasData
                          ? sessionSnap.data!.docs.length
                          : 0;
                      final percentageText = totalRecords > 0
                          ? "${((recordedSessionsCount / totalRecords) * 100).round()}%"
                          : "0%";

                      final diff = expectedCount - nonAbsentSessionsCount;
                      final isComplete = expectedCount > 0 && diff <= 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🗓️ شريط اختيار التاريخ العصري
                          _buildDateSelectorCard(isDarkMode),

                          const SizedBox(height: 16),

                          // ⚖️ بطاقة متابعة إنجاز المشرفين (البارزة)
                          _buildComparisonBannerCard(
                            isDarkMode: isDarkMode,
                            expectedCount: expectedCount,
                            diff: diff,
                            isComplete: isComplete,
                            isLoading: isLoading,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PendingSessionsPage(targetDate: dateStr),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // 📊 شبكة الإحصائيات اليومية (بطاقتان في كل صف)
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatTile(
                                  title: "المستهدفون",
                                  subtitle: "الحضور المبدئي",
                                  value: expectedCount.toString(),
                                  icon: Icons.fact_check_rounded,
                                  accent: isDarkMode
                                      ? Colors.lightBlueAccent
                                      : const Color(0xff0284c7),
                                  isLoading: isLoading,
                                  isDarkMode: isDarkMode,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatTile(
                                  title: "نسبة التسميع",
                                  subtitle: "من إجمالي السجلات",
                                  value: percentageText,
                                  icon: Icons.pie_chart_rounded,
                                  accent: isDarkMode
                                      ? accentGold
                                      : const Color(0xffb45309),
                                  isLoading: isLoading,
                                  isDarkMode: isDarkMode,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // 📝 الجلسات المسجلة فعلياً
                          _buildActionStatCard(
                            title: "الجلسات المسجلة فعلياً اليوم",
                            subtitle: "اضغط لاستعراض كافة تسميعات اليوم بالتفصيل",
                            value: recordedSessionsCount.toString(),
                            icon: Icons.auto_stories_rounded,
                            accent: const Color(0xff16a34a),
                            isLoading: isLoading,
                            isDarkMode: isDarkMode,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DailyRecitationsPage(
                                    targetDate: dateStr,
                                    role: widget.role,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // ⚠️ حضر ولم يسمّع
                          _buildActionStatCard(
                            title: "حضر ولم يسمّع اليوم",
                            subtitle: "عرض القائمة وتصدير كرت للأهالي",
                            value: didNotReciteCount.toString(),
                            icon: Icons.speaker_notes_off_rounded,
                            accent: isDarkMode
                                ? Colors.amberAccent
                                : const Color(0xffd97706),
                            isLoading: isLoading,
                            isDarkMode: isDarkMode,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DailyDidNotReciteStudentsPage(
                                      targetDate: dateStr),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // 🔴 الغائبون
                          _buildActionStatCard(
                            title: "عدد الغائبين اليوم",
                            subtitle: "عرض القائمة وتصدير كرت الغياب",
                            value: absentCount.toString(),
                            icon: Icons.person_off_rounded,
                            accent: const Color(0xffef4444),
                            isLoading: isLoading,
                            isDarkMode: isDarkMode,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DailyAbsentStudentsPage(
                                      targetDate: dateStr),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectorCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ]
              : [
                  Colors.white.withOpacity(0.92),
                  Colors.white.withOpacity(0.75),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? accentGold.withOpacity(0.28)
              : Colors.white,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor:
                  (isDarkMode ? accentGold : primaryColor).withOpacity(0.1),
            ),
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: isDarkMode ? accentGold : primaryColor,
            ),
            tooltip: "اليوم السابق",
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _pickDate(context, isDarkMode),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          color: isDarkMode ? accentGold : primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "يوم $arabicDayName",
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        if (_isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentGold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: accentGold.withOpacity(0.5)),
                            ),
                            child: Text(
                              "اليوم",
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? const Color(0xfffde68a)
                                    : const Color(0xff92400e),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: isDarkMode
                            ? accentGold
                            : primaryColor.withOpacity(0.75),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor:
                  (isDarkMode ? accentGold : primaryColor).withOpacity(0.1),
            ),
            icon: Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: isDarkMode ? accentGold : primaryColor,
            ),
            tooltip: "اليوم التالي",
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBannerCard({
    required bool isDarkMode,
    required int expectedCount,
    required int diff,
    required bool isComplete,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    final statusColor = expectedCount == 0
        ? Colors.blueGrey
        : (isComplete ? const Color(0xff16a34a) : const Color(0xfff59e0b));

    String titleText = "متابعة إنجاز المشرفين";
    String badgeText = isLoading
        ? "..."
        : (expectedCount == 0
            ? "لا يوجد تفقد"
            : (isComplete ? "مكتمل" : "متبقٍ $diff"));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor.withOpacity(isDarkMode ? 0.2 : 0.14),
                isDarkMode
                    ? Colors.white.withOpacity(0.04)
                    : Colors.white.withOpacity(0.88),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: statusColor.withOpacity(0.45),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  expectedCount == 0
                      ? Icons.hourglass_empty_rounded
                      : (isComplete
                          ? Icons.verified_rounded
                          : Icons.pending_actions_rounded),
                  color: statusColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleText,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDarkMode ? Colors.white : primaryColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isDarkMode && statusColor == const Color(0xfff59e0b)
                                  ? Colors.amberAccent
                                  : statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      expectedCount == 0
                          ? "لم يتم تسجيل تفقد مبدئي لهذا اليوم بعد."
                          : (isComplete
                              ? "تم تسجيل جلسات جميع الطلاب الحاضرين بنجاح!"
                              : "يوجد ($diff) طلاب حاضرون بانتظار تسجيل التسميع — اضغط للعرض."),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDarkMode ? Colors.white54 : Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color accent,
    required bool isLoading,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.white,
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isDarkMode ? Colors.white : primaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          isLoading
              ? const SizedBox(
                  height: 34,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    color: accent,
                    height: 1.15,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              color: isDarkMode ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionStatCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color accent,
    required bool isLoading,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white,
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: isDarkMode ? Colors.white : primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: accent,
                        ),
                      ),
                    ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDarkMode ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 🚀 دالة المعاينة والمشاركة العامة المعززة بخيار (فاتح / غامق)
// =========================================================================
Future<void> _previewAndShareImage({
  required BuildContext context,
  required WidgetsToImageController controller,
  required String shareText,
  required String fileNamePrefix,
  required String targetDate,
  required Function(bool isPosterDark) onThemeChanged,
  required bool initialIsDark,
}) async {
  try {
    bool isPosterDark = initialIsDark;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xff0f172a),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.all(16),
            title: const Row(
              children: [
                Icon(Icons.remove_red_eye_rounded,
                    color: Color(0xffd4af37), size: 22),
                SizedBox(width: 8),
                Text(
                  "معاينة واختيار الثيم",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xff1e293b),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xff334155)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (isPosterDark) {
                              setStateDialog(() => isPosterDark = false);
                              onThemeChanged(false);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !isPosterDark
                                  ? const Color(0xffd4af37)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wb_sunny_rounded,
                                    size: 16,
                                    color: !isPosterDark
                                        ? Colors.black
                                        : Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  "ألوان فاتحة",
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: !isPosterDark
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!isPosterDark) {
                              setStateDialog(() => isPosterDark = true);
                              onThemeChanged(true);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isPosterDark
                                  ? const Color(0xffd4af37)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.nightlight_round,
                                    size: 16,
                                    color: isPosterDark
                                        ? Colors.black
                                        : Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  "ألوان غامقة",
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isPosterDark
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FutureBuilder<Uint8List?>(
                  key: ValueKey(isPosterDark),
                  future: Future.delayed(
                      const Duration(milliseconds: 80), () => controller.capture()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        height: 220,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                            color: Color(0xffd4af37)),
                      );
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return Container(
                        height: 150,
                        alignment: Alignment.center,
                        child: const Text("حدث خطأ أثناء التقاط المعاينة",
                            style: TextStyle(
                                color: Colors.white70, fontFamily: 'Cairo')),
                      );
                    }

                    final bytes = snapshot.data!;

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.45,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xff334155)),
                        ),
                        child: SingleChildScrollView(
                          child: Image.memory(bytes, fit: BoxFit.contain),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  "اختر النمط المناسب ثم اضغط تأكيد للمشاركة على الواتساب",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء",
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2563eb),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final capturedBytes = await controller.capture();
                  if (capturedBytes == null) return;

                  if (ctx.mounted) Navigator.pop(ctx);

                  final tempDir = await getTemporaryDirectory();
                  final safeDate = targetDate.replaceAll('/', '_');
                  final file = await File(
                          '${tempDir.path}/${fileNamePrefix}_$safeDate.png')
                      .create();
                  await file.writeAsBytes(capturedBytes);

                  await Share.shareXFiles(
                    [XFile(file.path)],
                    text: shareText,
                  );
                },
                icon: const Icon(Icons.share_rounded,
                    size: 18, color: Colors.white),
                label: const Text(
                  "تأكيد والمشاركة",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("حدث خطأ أثناء معاينة الصورة: $e",
              style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

// =========================================================================
// 🚀 1. واجهة المتبقين للتسميع
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
  bool isPosterDark = true;

  bool _isStudentPresent(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is String) {
      final s = val.trim().toLowerCase();
      return s == 'present' || s == 'حاضر' || s == 'true';
    }
    if (val is Map) {
      final status = val['status']?.toString().trim().toLowerCase();
      if (status == 'present' || status == 'حاضر' || status == 'true') {
        return true;
      }
      if (val['isPresent'] == true || val['attended'] == true) return true;
    }
    return false;
  }

  Future<void> _handleShareProcess(
      List<dynamic> pendingStudentsList) async {
    if (pendingStudentsList.isEmpty) return;

    await _previewAndShareImage(
      context: context,
      controller: controller,
      fileNamePrefix: "pending_recitations",
      targetDate: widget.targetDate,
      initialIsDark: isPosterDark,
      onThemeChanged: (bool isDark) {
        setState(() {
          isPosterDark = isDark;
        });
      },
      shareText:
          'تذكير بالطلاب المتبقين للتسميع اليوم (${widget.targetDate})\nنرجو من الإخوة المشرفين تسجيل التسميعات\nمعهد الشيخ سعيد العبدالله',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor:
            isDarkMode ? const Color(0xff0b1120) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            "المتبقين للتسميع (${widget.targetDate})",
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDarkMode ? Colors.white : primaryColor,
                fontFamily: 'Cairo',
                fontSize: 15.5),
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
                      ? const [
                          Color(0xff0b1120),
                          Color(0xff131c31),
                          Color(0xff0b1120),
                        ]
                      : const [
                          Color(0xfff8fafc),
                          Color(0xffe2e8f0),
                          Color(0xffdbeafe),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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

                  final List<String> presentStudentIds = [];
                  for (final doc in attendanceSnap.data!.docs) {
                    final attData = doc.data() as Map<String, dynamic>;
                    final records =
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
                          "لا يوجد طلاب حاضرون مبدئياً بانتظار التسميع",
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

                      final Set<String> recordedStudentIds = sessionsSnap.hasData
                          ? sessionsSnap.data!.docs
                              .map((doc) => doc['studentId'].toString())
                              .toSet()
                          : {};

                      final List<String> pendingStudentIds = presentStudentIds
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
                              Text("اكتمل الإنجاز!",
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

                            final List<Map<String, dynamic>>
                              pendingStudentsList = [];

                          for (final doc in studentsSnap.data!.docs) {
                            if (pendingStudentIds.contains(doc.id)) {
                              final data = doc.data() as Map<String, dynamic>;
                              final rawSerial = data['serial'];
                              final int serialNum = rawSerial is int
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
                              Positioned(
                                left: -9999,
                                child: WidgetsToImage(
                                  controller: controller,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      width: 600,
                                      child: _buildExportablePoster(
                                          pendingStudentsList, isPosterDark),
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
                                              const Color(0xffea580c),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          elevation: 3,
                                        ),
                                        onPressed: () => _handleShareProcess(
                                            pendingStudentsList),
                                        icon: const Icon(Icons.share_rounded,
                                            color: Colors.white, size: 20),
                                        label: const Text(
                                          "معاينة ومشاركة التذكير",
                                          style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                              color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 14),
                                      itemCount: pendingStudentsList.length,
                                      itemBuilder: (context, index) {
                                        final student =
                                            pendingStudentsList[index];
                                        final String studentName =
                                            student['name'];
                                        final String supervisorName =
                                            student['supervisorName'];

                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: isDarkMode
                                                ? Colors.white.withOpacity(0.06)
                                                : Colors.white
                                                    .withOpacity(0.9),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: const Color(0xfff59e0b)
                                                  .withOpacity(isDarkMode
                                                      ? 0.35
                                                      : 0.45),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xfff59e0b)
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12),
                                                ),
                                                child: const Text(
                                                  "بانتظار التسميع",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'Cairo',
                                                    color: Color(0xffd97706),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      studentName,
                                                      textAlign: TextAlign.right,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontFamily: 'Cairo',
                                                        fontSize: 14,
                                                        color: isDarkMode
                                                            ? Colors.white
                                                            : primaryColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "المشرف: $supervisorName",
                                                      textAlign: TextAlign.right,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontFamily: 'Cairo',
                                                        color: isDarkMode
                                                            ? Colors.white60
                                                            : Colors.black54,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
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

    Widget _buildExportablePoster(
      List<Map<String, dynamic>> students, bool isDark) {
    final bgColor = isDark ? const Color(0xff0f172a) : const Color(0xffffffff);
    final borderColor =
        isDark ? const Color(0xff334155) : const Color(0xffe2e8f0);
    final textColor = isDark ? Colors.white : const Color(0xff1e293b);
    final headerBg =
        isDark ? const Color(0xff1e293b) : const Color(0xfff1f5f9);
    final subTextColor =
        isDark ? const Color(0xff94a3b8) : const Color(0xff64748b);

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/logo500.png',
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xffd4af37).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mosque_rounded,
                        color: Color(0xffd4af37), size: 26),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text("معهد الشيخ سعيد العبدالله",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xfff59e0b).withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border:
                  Border.all(color: const Color(0xfff59e0b).withOpacity(0.5)),
            ),
            child: Text(
              "قائمة الطلاب المتبقين للتسميع - ${widget.targetDate}",
              style: TextStyle(
                  fontSize: 13,
                  color:
                      isDark ? const Color(0xfffde68a) : const Color(0xffb45309),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo'),
            ),
          ),
          const SizedBox(height: 20),
          Table(
            border: TableBorder.all(
                color: borderColor,
                width: 1,
                borderRadius: BorderRadius.circular(12)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: headerBg),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text("اسم الطالب",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: subTextColor,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text("المشرف المسؤول",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: subTextColor,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
              ...students.map((s) => TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(s['name'] ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: textColor,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(s['supervisorName'] ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: subTextColor,
                              fontFamily: 'Cairo',
                              fontSize: 12)),
                    ),
                  ]))
            ],
          ),
          const SizedBox(height: 18),
          Text(
            "نرجو من الإخوة المشرفين الكرام المتابعة وتسجيل التسميعات",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: subTextColor, fontSize: 11, fontFamily: 'Cairo'),
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

  String _getJuzName(int juzNum) {
    switch (juzNum) {
      case 30:
        return "جزء عمَّ";
      case 29:
        return "جزء تبارك";
      case 28:
        return "قد سمع";
      case 27:
        return "الذاريات";
      case 26:
        return "الأحقاف";
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
            isDarkMode ? const Color(0xff0b1120) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            "جلسات التسميع (${widget.targetDate})",
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDarkMode ? Colors.white : primaryColor,
                fontFamily: 'Cairo',
                fontSize: 15.5),
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
                      ? const [
                          Color(0xff0b1120),
                          Color(0xff131c31),
                          Color(0xff0b1120),
                        ]
                      : const [
                          Color(0xfff8fafc),
                          Color(0xffe2e8f0),
                          Color(0xffdbeafe),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
                      child: Text("لا توجد جلسات تسميع مسجلة في هذا اليوم",
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
                        left: 18, right: 18, top: 10, bottom: 30),
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
    final String studentName = data['studentName'] ?? 'طالب';
    final bool isAbsent = data['absent'] ?? false;
    final bool isExam = data['isExam'] ?? false;
    final bool didNotRecite = data['didNotRecite'] ?? false;
    final int selectedJuz =
        data['selectedJuz'] ?? (data['isJuzAmma'] == true ? 30 : 0);

    final String actualCreatedAt = data['actualCreatedAt']?.toString() ?? '';
    final String actualEditedAt = data['actualEditedAt']?.toString() ?? '';

    final String nMemo = data['newMemorization']?.toString().trim() ?? '';
    final String nRev = data['nearReview']?.toString().trim() ?? '';
    final String fRev = data['farReview']?.toString().trim() ??
        (data['review']?.toString().trim() ?? '');
    final String sight = data['readingBySight']?.toString().trim() ?? '';

    final String memRating = data['memorizationRating'] ?? data['rating'] ?? "";
    final String newRevRating = data['newReviewRating'] ??
        data['reviewRating'] ??
        data['rating'] ??
        "";
    final String oldRevRating = data['oldReviewRating'] ??
        data['reviewRating'] ??
        data['rating'] ??
        "";

    final String nHw = data['newHomework']?.toString().trim() ?? '';
    final String nRevHw = data['newReviewHomework']?.toString().trim() ?? '';
    final String oRevHw = data['oldReviewHomework']?.toString().trim() ?? '';
    final String oldHw = data['homework']?.toString().trim() ?? '';

    final List<dynamic>? memoSupList =
        data['newMemoSupervisorNames'] ?? data['supervisorNames'];
    final String memoSupervisors = (memoSupList != null && memoSupList.isNotEmpty)
        ? memoSupList.join(' ، ')
        : (data['supervisorName'] ?? 'غير محدد');

    final List<dynamic>? revSupList =
        data['reviewSupervisorNames'] ?? data['supervisorNames'];
    final String revSupervisors = (revSupList != null && revSupList.isNotEmpty)
        ? revSupList.join(' ، ')
        : (data['supervisorName'] ?? 'غير محدد');

    final List<Widget> activeBoxes = [];
    if (!didNotRecite && !isAbsent && !isExam) {
      if (nMemo.isNotEmpty) {
        activeBoxes.add(_buildGridInfoBox(Icons.star_rounded, "الحفظ الجديد",
            nMemo, Colors.amber, isDarkMode));
      }
      if (nRev.isNotEmpty) {
        activeBoxes.add(_buildGridInfoBox(
            Icons.menu_book_rounded,
            "مراجعة جديد",
            nRev,
            isDarkMode ? Colors.tealAccent : Colors.teal,
            isDarkMode));
      }
      if (fRev.isNotEmpty) {
        activeBoxes.add(_buildGridInfoBox(
            Icons.history_toggle_off_rounded,
            "مراجعة قديم",
            fRev,
            Colors.blueGrey,
            isDarkMode));
      }
      if (sight.isNotEmpty) {
        activeBoxes.add(_buildGridInfoBox(
            Icons.chrome_reader_mode_rounded,
            "قراءة نظراً",
            sight,
            Colors.indigoAccent,
            isDarkMode));
      }
    }

    final String juzChipTitle = _getJuzName(selectedJuz);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white,
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.22 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
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
                          radius: 15,
                          backgroundColor: accentGold.withOpacity(0.2),
                          child: Icon(Icons.person_rounded,
                              color: accentGold, size: 17),
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
                  const SizedBox(height: 8),
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
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.role == 'manager' &&
                    (actualCreatedAt.isNotEmpty ||
                        actualEditedAt.isNotEmpty)) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(isDarkMode ? 0.12 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.amber.withOpacity(0.4), width: 1),
                    ),
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
                    color: isDarkMode ? Colors.white12 : Colors.black12,
                    height: 18),
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
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                ],
                if (nHw.isNotEmpty ||
                    nRevHw.isNotEmpty ||
                    oRevHw.isNotEmpty ||
                    oldHw.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentGold.withOpacity(isDarkMode ? 0.08 : 0.06),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: accentGold.withOpacity(0.3)),
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
                        const SizedBox(height: 6),
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
                ],
                if (data['religiousActivities'] != null &&
                    data['religiousActivities']
                        .toString()
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildMinimalistDetailRow(Icons.mosque_outlined,
                      "الأنشطة الدينية", data['religiousActivities'], isDarkMode),
                ],
                if (selectedJuz == 0) ...[
                  const SizedBox(height: 10),
                  _buildMinimalistDetailRow(
                      Icons.analytics_outlined,
                      "إجمالي الحفظ للختمة",
                      data['total_memorized_pages'] != null
                          ? "${data['total_memorized_pages']} صفحة"
                          : "---",
                      isDarkMode),
                ],
                if (data['studentStatus'] != null &&
                    data['studentStatus'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildMinimalistDetailRow(Icons.mood, "حالة الطالب",
                      data['studentStatus'], isDarkMode),
                ],
                if (data['notes'] != null &&
                    data['notes'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildNotesBox(data['notes'], isDarkMode),
                ],
                const SizedBox(height: 10),
                _buildActionButtons(context, sessionId, data, isDarkMode),
              ],
            ),
          ),
        ],
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
            : const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDarkMode ? Colors.white12 : const Color(0xffe2e8f0),
            width: 0.9),
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
              color: isDarkMode ? accentGold : primaryColor.withOpacity(0.7)),
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
            : const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: isDarkMode ? Colors.white12 : const Color(0xffe2e8f0)),
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
              final bool? confirm = await showDialog<bool>(
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
                            "هل أنت متأكد من رغبتك في حذف هذه الجلسة بشكل نهائي؟",
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo')),
    );
  }
}

// =========================================================================
// 🚀 3. واجهة سجل الغائبين
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
  bool isPosterDark = true;

  Future<void> _handleShareProcess(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;

    await _previewAndShareImage(
      context: context,
      controller: controller,
      fileNamePrefix: "absent_students",
      targetDate: widget.targetDate,
      initialIsDark: isPosterDark,
      onThemeChanged: (bool isDark) {
        setState(() {
          isPosterDark = isDark;
        });
      },
      shareText:
          'كرت الغياب اليومي (${widget.targetDate})\nمعهد الشيخ سعيد العبدالله',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor:
            isDarkMode ? const Color(0xff0b1120) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text("سجل الغائبين (${widget.targetDate})",
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDarkMode ? Colors.white : primaryColor,
                  fontFamily: 'Cairo',
                  fontSize: 15.5)),
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
                      ? const [
                          Color(0xff0b1120),
                          Color(0xff131c31),
                          Color(0xff0b1120),
                        ]
                      : const [
                          Color(0xfff8fafc),
                          Color(0xffe2e8f0),
                          Color(0xffdbeafe),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
                      child: Text("لا يوجد غياب مسجل في هذا اليوم",
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white70 : primaryColor,
                              fontSize: 14)),
                    );
                  }

                  return Stack(
                    children: [
                      Positioned(
                        left: -9999,
                        child: WidgetsToImage(
                          controller: controller,
                          child: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: 600,
                              child: _buildExportablePoster(
                                  absentDocs, isPosterDark),
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
                                  backgroundColor: const Color(0xffdc2626),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 3,
                                ),
                                onPressed: () => _handleShareProcess(absentDocs),
                                icon: const Icon(Icons.share_rounded,
                                    color: Colors.white, size: 20),
                                label: const Text(
                                  "معاينة ومشاركة كرت الغياب",
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
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
                                final String studentName =
                                    data['studentName'] ?? 'طالب';
                                final String reason =
                                    data['absenceReason'] ?? 'بدون سبب مُسجّل';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.redAccent
                                            .withOpacity(0.35),
                                        width: 1.2),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(14),
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
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14.5,
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : primaryColor)),
                                            const SizedBox(height: 2),
                                            Text("سبب الغياب: $reason",
                                                style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 11.5,
                                                    color: isDarkMode
                                                        ? Colors.white60
                                                        : Colors.black54)),
                                          ],
                                        ),
                                      ),
                                    ],
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

  Widget _buildExportablePoster(List<QueryDocumentSnapshot> docs, bool isDark) {
    final bgColor = isDark ? const Color(0xff0f172a) : const Color(0xffffffff);
    final borderColor =
        isDark ? const Color(0xff334155) : const Color(0xffe2e8f0);
    final textColor = isDark ? Colors.white : const Color(0xff1e293b);
    final headerBg =
        isDark ? const Color(0xff1e293b) : const Color(0xfff1f5f9);
    final subTextColor =
        isDark ? const Color(0xff94a3b8) : const Color(0xff64748b);

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/logo500.png',
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xffd4af37).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mosque_rounded,
                        color: Color(0xffd4af37), size: 26),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text("معهد الشيخ سعيد العبدالله",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xffef4444).withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border:
                  Border.all(color: const Color(0xffef4444).withOpacity(0.5)),
            ),
            child: Text(
              "جدول الطلاب الغائبين - ${widget.targetDate}",
              style: TextStyle(
                  fontSize: 13,
                  color:
                      isDark ? const Color(0xfffca5a5) : const Color(0xff991b1b),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo'),
            ),
          ),
          const SizedBox(height: 20),
          Table(
            border: TableBorder.all(
                color: borderColor,
                width: 1,
                borderRadius: BorderRadius.circular(12)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: headerBg),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text("اسم الطالب",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: subTextColor,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text("حالة الغياب / العذر",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: subTextColor,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
              ...docs.map((doc) {
                final s = doc.data() as Map<String, dynamic>;
                final String reason = s['absenceReason'] ?? 'بدون عذر';
                final bool hasExcused = reason.contains("بعذر") ||
                    reason.contains("استئذان") ||
                    reason.contains("مريض");

                return TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(s['studentName'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: textColor,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: hasExcused
                              ? const Color(0xff059669)
                              : const Color(0xffdc2626),
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5),
                    ),
                  ),
                ]);
              })
            ],
          ),
          const SizedBox(height: 18),
          Text(
            "يرجى من أولياء الأمور الكرام الحرص والمتابعة لعدم التكرار",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: subTextColor, fontSize: 11, fontFamily: 'Cairo'),
          )
        ],
      ),
    );
  }
}

// =========================================================================
// 🚀 4. واجهة حضر ولم يسمّع
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
  bool isPosterDark = true;

  Future<void> _handleShareProcess(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;

    await _previewAndShareImage(
      context: context,
      controller: controller,
      fileNamePrefix: "not_recited_students",
      targetDate: widget.targetDate,
      initialIsDark: isPosterDark,
      onThemeChanged: (bool isDark) {
        setState(() {
          isPosterDark = isDark;
        });
      },
      shareText:
          'إشعار الطلاب (حضر ولم يسمّع) اليوم (${widget.targetDate})\nمعهد الشيخ سعيد العبدالله',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDarkMode ? const Color(0xff0b1120) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text("حضر ولم يسمّع (${widget.targetDate})",
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: isDarkMode ? Colors.white : primaryColor,
                fontSize: 15.5)),
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
                    ? const [
                        Color(0xff0b1120),
                        Color(0xff131c31),
                        Color(0xff0b1120),
                      ]
                    : const [
                        Color(0xfff8fafc),
                        Color(0xffe2e8f0),
                        Color(0xffdbeafe),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
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
                    child: Text("لا يوجد طلاب بحالة حضر ولم يسمّع اليوم",
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white70 : primaryColor,
                            fontSize: 14)),
                  );
                }

                return Stack(
                  children: [
                    Positioned(
                      left: -9999,
                      child: WidgetsToImage(
                        controller: controller,
                        child: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 600,
                            child: _buildExportablePoster(docs, isPosterDark),
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
                                backgroundColor: const Color(0xff334155),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                              ),
                              onPressed: () => _handleShareProcess(docs),
                              icon: const Icon(Icons.share_rounded,
                                  color: Colors.white, size: 20),
                              label: const Text(
                                "معاينة ومشاركة القائمة للأهالي",
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
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
                              final String studentName =
                                  data['studentName'] ?? 'طالب';
                              final String supervisorName =
                                  data['supervisorName'] ?? 'غير محدد';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.blueGrey.withOpacity(0.4),
                                      width: 1.2),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(14),
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
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14.5,
                                                  color: isDarkMode
                                                      ? Colors.white
                                                      : primaryColor)),
                                          const SizedBox(height: 2),
                                          Text("المشرف: $supervisorName",
                                              style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 11.5,
                                                  color: isDarkMode
                                                      ? Colors.white60
                                                      : Colors.black54)),
                                        ],
                                      ),
                                    ),
                                  ],
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

  Widget _buildExportablePoster(List<QueryDocumentSnapshot> docs, bool isDark) {
    final bgColor = isDark ? const Color(0xff0f172a) : const Color(0xffffffff);
    final borderColor =
        isDark ? const Color(0xff334155) : const Color(0xffe2e8f0);
    final textColor = isDark ? Colors.white : const Color(0xff1e293b);
    final headerBg =
        isDark ? const Color(0xff1e293b) : const Color(0xfff1f5f9);
    final subTextColor =
        isDark ? const Color(0xff94a3b8) : const Color(0xff64748b);

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/logo500.png',
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xffd4af37).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mosque_rounded,
                        color: Color(0xffd4af37), size: 26),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text("معهد الشيخ سعيد العبدالله",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xfff59e0b).withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border:
                  Border.all(color: const Color(0xfff59e0b).withOpacity(0.5)),
            ),
            child: Text(
              "قائمة الطلاب الذين حضروا ولم يسْمَعوا - ${widget.targetDate}",
              style: TextStyle(
                  fontSize: 13,
                  color:
                      isDark ? const Color(0xfffde68a) : const Color(0xffb45309),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo'),
            ),
          ),
          const SizedBox(height: 20),
          Table(
            border: TableBorder.all(
                color: borderColor,
                width: 1,
                borderRadius: BorderRadius.circular(12)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: headerBg),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text("اسم الطالب",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: subTextColor,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text("المشرف المسؤول",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: subTextColor,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
              ...docs.map((doc) {
                final s = doc.data() as Map<String, dynamic>;
                return TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(s['studentName'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: textColor,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(s['supervisorName'] ?? 'غير محدد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: subTextColor,
                            fontFamily: 'Cairo',
                            fontSize: 12)),
                  ),
                ]);
              })
            ],
          ),
          const SizedBox(height: 18),
          Text(
            "يرجى من أولياء الأمور الكرام الحرص على إعداد وتسميع المقرر بالبيت",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: subTextColor, fontSize: 11, fontFamily: 'Cairo'),
          )
        ],
      ),
    );
  }
}