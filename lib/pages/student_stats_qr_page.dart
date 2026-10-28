import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class StudentStatsQrPage extends StatefulWidget {
  const StudentStatsQrPage({super.key});

  @override
  State<StudentStatsQrPage> createState() => _StudentStatsQrPageState();
}

class _StudentStatsQrPageState extends State<StudentStatsQrPage> {
  final Color primaryNavy = const Color(0xff1e293b);
  final Color accentGold = const Color(0xffD4AF37);
  final Color softBlue = const Color(0xff3b82f6);

  String? scannedStudentId;

  /// 🗓️ تحويل النص إلى تاريخ
  DateTime? _parseDate(String dateStr) {
    try {
      var p = dateStr.split('-');
      if (p.length == 3) {
        return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// 🗓️ تحويل التاريخ إلى اسم اليوم بالعربية
  String _getArabicDayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.saturday:
        return "السبت";
      case DateTime.sunday:
        return "الأحد";
      case DateTime.monday:
        return "الإثنين";
      case DateTime.tuesday:
        return "الثلاثاء";
      case DateTime.wednesday:
        return "الأربعاء";
      case DateTime.thursday:
        return "الخميس";
      case DateTime.friday:
        return "الجمعة";
      default:
        return "";
    }
  }

  /// 🗓️ التحقق من وقوع التاريخ ضمن نطاق محدد
  bool _isDateInRange(String dateStr, DateTime start, DateTime end) {
    DateTime? d = _parseDate(dateStr);
    if (d == null) return false;
    return d.isAfter(start.subtract(const Duration(seconds: 1))) &&
        d.isBefore(end.add(const Duration(seconds: 1)));
  }

  /// 🧮 حساب عدد الصفحات من النصوص
  int _calculatePagesFromText(String? text) {
    if (text == null || text.trim().isEmpty) return 0;

    int totalPages = 0;
    String processedText = text.replaceAll(' و ', '|');
    List<String> parts = processedText.split(RegExp(r'[|،,+]'));

    for (String part in parts) {
      var matches = RegExp(r'\d+').allMatches(part);
      if (matches.isEmpty) continue;

      List<int> numbers = matches.map((m) => int.parse(m.group(0)!)).toList();

      if (numbers.length == 1) {
        totalPages += 1;
      } else {
        int minP = numbers.reduce((a, b) => a < b ? a : b);
        int maxP = numbers.reduce((a, b) => a > b ? a : b);

        if (maxP >= minP) {
          totalPages += (maxP - minP) + 1;
        }
      }
    }

    return totalPages;
  }

  void _openQrScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              color: Colors.black.withValues(alpha: 0.8),
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                          String rawData = barcode.rawValue!.trim();
                          setState(() {
                            scannedStudentId = rawData;
                          });
                          Navigator.pop(context);
                          break;
                        }
                      }
                    },
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: accentGold, width: 3),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: accentGold.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 📖 فتح التفاصيل بدون إعادة بناء الصفحة الرئيسية
  void _openSessionDetails(Map<String, dynamic> sData, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SessionDetailsBottomSheet(
        sData: sData,
        isDark: isDark,
        primaryNavy: primaryNavy,
        accentGold: accentGold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff0b1120) : const Color(0xfff8fafc),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? Colors.white24 : Colors.white),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : primaryNavy, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          "البطاقة الذكية للطالب 💳",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : primaryNavy,
          ),
        ),
        actions: [
          if (scannedStudentId != null)
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentGold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: accentGold.withValues(alpha: 0.5)),
              ),
              child: IconButton(
                icon: Icon(Icons.qr_code_scanner_rounded, color: accentGold, size: 20),
                tooltip: "مسح طالب آخر",
                onPressed: () {
                  setState(() {
                    scannedStudentId = null;
                  });
                },
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xff0b1120), const Color(0xff1e293b), const Color(0xff0f172a)]
                      : [const Color(0xfff1f5f9), const Color(0xffe2e8f0), const Color(0xffcbd5e1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentGold.withValues(alpha: isDark ? 0.12 : 0.2),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: softBlue.withValues(alpha: isDark ? 0.12 : 0.18),
              ),
            ),
          ),

          SafeArea(
            child: scannedStudentId == null
                ? _buildInitialView(isDark)
                : _buildStudentDashboard(scannedStudentId!, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialView(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildLiquidCard(
              isDark: isDark,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: accentGold.withValues(alpha: 0.15),
                    child: Icon(Icons.qr_code_scanner_rounded, size: 50, color: accentGold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "مسح بطاقة الطالب 📷",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "وجه الكاميرا نحو الـ QR المطبوع على البطاقة للوصول للتقرير والبيانات فوريّاً",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 5,
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.black),
                    label: const Text(
                      "فتح كاميرا المسح 📷",
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    onPressed: _openQrScanner,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentDashboard(String studentId, bool isDark) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('students').doc(studentId).get(),
      builder: (context, studentSnap) {
        if (studentSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!studentSnap.hasData || !studentSnap.data!.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
                const SizedBox(height: 12),
                const Text("عذراً، الطالب غير موجود أو رمز الـ QR خطأ!", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentGold),
                  onPressed: () => setState(() => scannedStudentId = null),
                  child: const Text("رجوع", style: TextStyle(fontFamily: 'Cairo', color: Colors.black)),
                )
              ],
            ),
          );
        }

        var stData = studentSnap.data!.data() as Map<String, dynamic>;
        String stName = stData['name'] ?? 'طالب';
        String imageUrl = stData['imageUrl'] ?? '';
        String supName = stData['supervisorName'] ?? 'غير محدد';
        String cycleName = stData['cycleName'] ?? 'الدورة الحالية';
        String studentType = stData['studentType'] ?? 'new';
        bool isCompleted = studentType == 'completed';

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sessions')
              .where('studentId', isEqualTo: studentId)
              .snapshots(),
          builder: (context, sessionsSnap) {
            if (!sessionsSnap.hasData) return const Center(child: CircularProgressIndicator());

            var docs = sessionsSnap.data!.docs;

            List<Map<String, dynamic>> allSessions = docs.map((d) => d.data() as Map<String, dynamic>).toList();
            allSessions.sort((a, b) {
              DateTime? dA = _parseDate(a['date'] ?? '');
              DateTime? dB = _parseDate(b['date'] ?? '');
              if (dA == null || dB == null) return 0;
              return dB.compareTo(dA);
            });

            List<Map<String, dynamic>> recentThreeSessions = allSessions.take(3).toList();

            DateTime now = DateTime.now();

            int daysToSaturday = (now.weekday + 1) % 7;
            DateTime weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSaturday));
            DateTime weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

            DateTime monthStart = DateTime(now.year, now.month, 1);
            DateTime monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

            int weeklySavedPages = 0;
            int monthlySavedPages = 0;

            int weeklyReviewPages = 0;
            int monthlyReviewPages = 0;

            int weeklyAbsences = 0;
            int monthlyAbsences = 0;

            List<String> allAbsenceDates = [];

            int totalSessions = docs.length;
            int totalAttendances = 0;

            for (var data in allSessions) {
              bool isAbsent = data['absent'] == true;
              bool didNotRecite = data['didNotRecite'] == true;
              String dateStr = data['date'] ?? '';

              if (isAbsent) {
                if (dateStr.isNotEmpty) allAbsenceDates.add(dateStr);
              } else {
                totalAttendances++;
              }

              bool isCurrentWeek = _isDateInRange(dateStr, weekStart, weekEnd);
              bool isCurrentMonth = _isDateInRange(dateStr, monthStart, monthEnd);

              int savedP = 0;
              int revP = 0;

              if (!isAbsent && !didNotRecite) {
                if (!isCompleted) {
                  savedP = _calculatePagesFromText(data['newMemorization']?.toString());
                  revP += _calculatePagesFromText(data['nearReview']?.toString());
                  revP += _calculatePagesFromText(data['farReview']?.toString());
                } else {
                  revP += _calculatePagesFromText(data['farReview']?.toString());
                  revP += _calculatePagesFromText(data['nearReview']?.toString());
                  revP += _calculatePagesFromText(data['review']?.toString());
                }
              }

              if (isCurrentWeek) {
                if (isAbsent) {
                  weeklyAbsences++;
                } else {
                  weeklySavedPages += savedP;
                  weeklyReviewPages += revP;
                }
              }

              if (isCurrentMonth) {
                if (isAbsent) {
                  monthlyAbsences++;
                } else {
                  monthlySavedPages += savedP;
                  monthlyReviewPages += revP;
                }
              }
            }

            double attendanceRate = totalSessions > 0 ? (totalAttendances / totalSessions) * 100 : 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // 1️⃣ كارت البروفايل بالمنتصف
                  _buildLiquidCard(
                    isDark: isDark,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [accentGold, softBlue]),
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
                            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                            child: imageUrl.isEmpty ? Icon(Icons.person, size: 50, color: accentGold) : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          stName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "المشرف: $supName",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                        ),
                        Text(
                          "الدورة: $cycleName",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: accentGold),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              "خاتم للقرآن الكريم 👑",
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                            ),
                          )
                        ]
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2️⃣ سجل آخر 3 تسميعات
                  _buildLiquidCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history_toggle_off_rounded, color: accentGold, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "سجل أحدث 3 جلسات تسميع 📜 (اضغط للتفاصيل)",
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : primaryNavy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        recentThreeSessions.isEmpty
                            ? Center(
                                child: Text("لا توجد جلسات مسجلة سابقاً",
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                              )
                            : Column(
                                children: recentThreeSessions.map((sData) {
                                  String date = sData['date'] ?? 'تاريخ غير معروف';
                                  bool isAbsent = sData['absent'] == true;
                                  bool didNotRecite = sData['didNotRecite'] == true;

                                  String statusText;
                                  Color statusColor;
                                  IconData statusIcon;

                                  if (isAbsent) {
                                    statusText = "غائب عن الجلسة ❌";
                                    statusColor = Colors.redAccent;
                                    statusIcon = Icons.close_rounded;
                                  } else if (didNotRecite) {
                                    statusText = "حضر ولم يسمّع ⚠️";
                                    statusColor = Colors.orangeAccent;
                                    statusIcon = Icons.warning_amber_rounded;
                                  } else {
                                    statusText = "حضر وقرأ الواجب ✅";
                                    statusColor = Colors.green;
                                    statusIcon = Icons.check_circle_outline_rounded;
                                  }

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _openSessionDetails(sData, isDark),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(statusIcon, color: statusColor, size: 18),
                                                const SizedBox(width: 8),
                                                Text(
                                                  date,
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white70 : Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    statusText,
                                                    style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? Colors.white38 : Colors.black38),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 3️⃣ تواريخ الغيابات
                  _buildLiquidCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_busy_rounded, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "سجل تواريخ الغياب بالتفصيل 🗓️ (${allAbsenceDates.length})",
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : primaryNavy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        allAbsenceDates.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "لا يوجد أي غياب مسجل للطالب 🌟",
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.green.shade400, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: allAbsenceDates.map((dStr) {
                                  DateTime? dObj = _parseDate(dStr);
                                  String dayName = dObj != null ? _getArabicDayName(dObj) : "";
                                  String fullDisplay = dayName.isNotEmpty ? "$dayName $dStr" : dStr;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.redAccent),
                                        const SizedBox(width: 6),
                                        Text(
                                          fullDisplay,
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4️⃣ نسبة الالتزام بالحضور
                  _buildLiquidCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("نسبة الالتزام بالحضور 📊", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : primaryNavy)),
                            Text("${attendanceRate.toStringAsFixed(1)}%", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 15, color: attendanceRate >= 80 ? Colors.green : Colors.orange)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: attendanceRate / 100,
                            minHeight: 8,
                            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(attendanceRate >= 80 ? Colors.green : Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 5️⃣ شبكة الإحصائيات (أسبوعي وشكري)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      _buildLiquidStatTile("حفظ الأسبوع 📖", "$weeklySavedPages ص", Colors.green, isDark),
                      _buildLiquidStatTile("حفظ الشهر 📅", "$monthlySavedPages ص", Colors.teal, isDark),
                      _buildLiquidStatTile("مراجعة الأسبوع 🔄", "$weeklyReviewPages ص", Colors.blueAccent, isDark),
                      _buildLiquidStatTile("مراجعة الشهر 🗓️", "$monthlyReviewPages ص", Colors.indigoAccent, isDark),
                      _buildLiquidStatTile("غياب الأسبوع ❌", "$weeklyAbsences أيام", Colors.orangeAccent, isDark),
                      _buildLiquidStatTile("غياب الشهر ⚠️", "$monthlyAbsences أيام", Colors.redAccent, isDark),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // 6️⃣ زر مسح طالب آخر
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentGold, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: Icon(Icons.qr_code_scanner_rounded, color: accentGold),
                      label: Text(
                        "مسح بطاقة طالب آخر 📷",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : primaryNavy,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          scannedStudentId = null;
                        });
                        _openQrScanner();
                      },
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

  Widget _buildLiquidCard({required bool isDark, required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff1e293b).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLiquidStatTile(String title, String val, Color color, bool isDark) {
    return _buildLiquidCard(
      isDark: isDark,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.64),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            val,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 💡 ويدجت مستقل لعرض تفاصيل الجلسة بدون Re-render للصفحة الرئيسية
class SessionDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> sData;
  final bool isDark;
  final Color primaryNavy;
  final Color accentGold;

  const SessionDetailsBottomSheet({
    super.key,
    required this.sData,
    required this.isDark,
    required this.primaryNavy,
    required this.accentGold,
  });

  @override
  Widget build(BuildContext context) {
    String date = sData['date'] ?? 'تاريخ غير معروف';
    bool isAbsent = sData['absent'] == true;
    bool didNotRecite = sData['didNotRecite'] == true;

    String newMemo = sData['newMemorization']?.toString() ?? sData['newHomework']?.toString() ?? '';
    String nearRev = sData['nearReview']?.toString() ?? '';
    String farRev = sData['farReview']?.toString() ?? '';
    String homework = sData['homework']?.toString() ?? '';
    String rating = sData['rating']?.toString() ?? sData['memorizationRating']?.toString() ?? '';
    String notes = sData['notes']?.toString() ?? '';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(24),
          color: isDark ? const Color(0xff1e293b).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "تفاصيل جلسة $date 📖",
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : primaryNavy,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),

                if (isAbsent)
                  _buildDetailRow("الحالة:", "غائب عن الجلسة ❌", Colors.redAccent, isDark)
                else if (didNotRecite)
                  _buildDetailRow("الحالة:", "حضر ولم يسمّع ⚠️", Colors.orangeAccent, isDark)
                else ...[
                  if (newMemo.isNotEmpty) _buildDetailRow("الحفظ الجديد:", newMemo, Colors.green, isDark),
                  if (nearRev.isNotEmpty) _buildDetailRow("المراجعة القريبة:", nearRev, Colors.blueAccent, isDark),
                  if (farRev.isNotEmpty) _buildDetailRow("المراجعة البعيدة:", farRev, Colors.teal, isDark),
                  if (homework.isNotEmpty) _buildDetailRow("الواجب القادم:", homework, accentGold, isDark),
                  if (rating.isNotEmpty) _buildDetailRow("التقييم:", rating, Colors.amber.shade800, isDark),
                  if (notes.isNotEmpty) _buildDetailRow("ملاحظات:", notes, isDark ? Colors.white70 : Colors.black87, isDark),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String val, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54)),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Text(
              val,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}