import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:path_provider/path_provider.dart';
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

  String get formattedDate => "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}";

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
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "الإحصائيات اليومية",
          style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor),
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
              width: 260,
              height: 260,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.07) : accentGold.withOpacity(0.12)),
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
                  InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () => _pickDate(context, isDarkMode),
                    child: _buildGlassContainer(
                      isDarkMode: isDarkMode,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event, color: isDarkMode ? accentGold : primaryColor, size: 22),
                              const SizedBox(width: 12),
                              Text("إحصائيات اليوم: ", style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(formattedDate, style: TextStyle(color: isDarkMode ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          Icon(Icons.edit_calendar_rounded, color: isDarkMode ? accentGold : primaryColor, size: 20),
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
                        MaterialPageRoute(
                          builder: (_) => DailyAbsentStudentsPage(targetDate: formattedDate),
                        ),
                      );
                    },
                    child: _buildStreamCard(
                      title: "عدد الغائبين اليوم",
                      icon: Icons.person_off_rounded,
                      color: Colors.redAccent,
                      stream: FirebaseFirestore.instance
                          .collection('sessions')
                          .where('date', isEqualTo: formattedDate)
                          .where('absent', isEqualTo: true)
                          .snapshots(),
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      title: "عدد التسميعات اليوم",
                      icon: Icons.menu_book_rounded,
                      color: Colors.green,
                      stream: FirebaseFirestore.instance
                          .collection('sessions')
                          .where('date', isEqualTo: formattedDate)
                          .where('absent', isEqualTo: false)
                          .snapshots(),
                      isDarkMode: isDarkMode,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPercentageCard(formattedDate, isDarkMode),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamCard({
    required String title,
    required IconData icon,
    required Color color,
    required Stream<QuerySnapshot> stream,
    required bool isDarkMode,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String value = "0";
        if (snapshot.hasData) {
          value = snapshot.data!.docs.length.toString();
        }
        return _statsUI(title, value, icon, color, snapshot.connectionState == ConnectionState.waiting, isDarkMode);
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
          "نسبة الحضور اليوم",
          percentage,
          Icons.pie_chart_rounded,
          isDarkMode ? accentGold : Colors.blue,
          snapshot.connectionState == ConnectionState.waiting,
          isDarkMode,
        );
      },
    );
  }

  Widget _statsUI(String title, String value, IconData icon, Color color, bool isLoading, bool isDarkMode) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[700], fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(value, style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(isDarkMode ? 0.15 : 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Icon(icon, color: color, size: 32),
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
            color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6),
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
// 🚀 1. واجهة الطلاب الغائبين (البوستر مخفي تماماً بالخلفية ويرتفع بدقة عالية عند المشاركة)
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

  // 📸 دالة الالتقاط والمشاركة
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
        backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text("الطلاب الغائبين (${widget.targetDate})", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16)),
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
                      // 🌟 البوستر رسمياً مخفي خارج أبعاد الشاشة لمنع ظهوره
                      Positioned(
                        left: -9999,
                        top: -9999,
                        child: WidgetsToImage(
                          controller: controller,
                          child: SizedBox(
                            width: 600, // 🎯 عرض عالي الدقة للبوستر HD
                            child: _buildExportablePoster(absentDocs),
                          ),
                        ),
                      ),

                      // 📱 القائمة الأساسية الأنيقة التي تظهر للمستخدم حصراً
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
                                margin: const EdgeInsets.only(bottom: 15),
                                padding: const EdgeInsets.all(16),
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
                                            Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
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
                                      const SizedBox(height: 10),
                                      Text("السبب: $absenceReason", style: TextStyle(fontSize: 12, fontFamily: 'Cairo', color: isDarkMode ? Colors.white70 : Colors.black87)),
                                    ],
                                    if (parentPhone.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          style: TextButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                          onPressed: () => _makePhoneCall(parentPhone),
                                          icon: const Icon(Icons.phone, size: 16, color: Colors.green),
                                          label: const Text("اتصال بولي الأمر", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 12)),
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

  // 🎨 تصميم البوستر الاحترافي فائق الدقة المخصص للتصدير حصراً
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
// 🚀 2. واجهة التسميعات والجلسات اليومية
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
        backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text("جلسات التسميع (${widget.targetDate})", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16)),
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
    String oldHw = data['homework']?.toString().trim() ?? '';

    List<dynamic>? supNamesList = data['supervisorNames'];
    String supervisorsDisplay = (supNamesList != null && supNamesList.isNotEmpty) ? supNamesList.join(' ، ') : (data['supervisorName'] ?? 'غير محدد');

    List<Widget> activeBoxes = [];
    if (!didNotRecite && !isExam) {
      if (nMemo.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.star_rounded, "الحفظ الجديد", nMemo, Colors.amber, isDarkMode));
      if (nRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.menu_book_rounded, "مراجعة جديد", nRev, isDarkMode ? Colors.tealAccent : Colors.teal, isDarkMode));
      if (fRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.history_toggle_off_rounded, "مراجعة قديم", fRev, Colors.blueGrey, isDarkMode));
      if (sight.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.chrome_reader_mode_rounded, "قراءة نظراً", sight, Colors.indigoAccent, isDarkMode));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: isExam ? Colors.teal.withOpacity(0.4) : (didNotRecite ? Colors.blueGrey.withOpacity(0.4) : (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6))), width: 1.5),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                    color: isExam ? Colors.teal.withOpacity(isDarkMode ? 0.2 : 0.15) : (didNotRecite ? Colors.blueGrey.withOpacity(isDarkMode ? 0.2 : 0.15) : (isDarkMode ? Colors.white.withOpacity(0.05) : primaryColor.withOpacity(0.05))),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
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
                        const SizedBox(height: 10),
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
                      Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                      if (!isExam && !didNotRecite && activeBoxes.isNotEmpty) ...[
                        for (int i = 0; i < activeBoxes.length; i += 2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(child: activeBoxes[i]),
                                const SizedBox(width: 10),
                                if (i + 1 < activeBoxes.length) Expanded(child: activeBoxes[i + 1]) else const Expanded(child: SizedBox()),
                              ],
                            ),
                          ),
                        Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                      ],
                      if (nHw.isNotEmpty || nRevHw.isNotEmpty || oRevHw.isNotEmpty || oldHw.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: accentGold.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: accentGold.withOpacity(0.2))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.menu_book, size: 16, color: accentGold),
                                  const SizedBox(width: 6),
                                  Text("الواجب القادم:", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                ],
                              ),
                              const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(bottom: 4, right: 10),
      child: Row(
        children: [
          Text("• $label: ", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildGridInfoBox(IconData icon, String title, String val, Color iconColor, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : const Color(0xfff8fafc).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDarkMode ? Colors.white12 : const Color(0xffe2e8f0), width: 0.8),
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
          const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }
}