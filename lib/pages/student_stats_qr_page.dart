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

  String? scannedStudentId;

  /// فتح كاميرا المسح وقراءة ID الطالب فورياً
  void _openQrScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
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
                      Navigator.pop(context); // إغلاق الكاميرا مباشرة عند التقاط الرمز
                      break;
                    }
                  }
                },
              ),
              // زر إغلاق الكاميرا
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // إطار توجيه الماسح الضوئي
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: accentGold, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: const Center(
                  child: Text(
                    "وجه الكاميرا نحو الـ QR Code المطبوع على البطاقة",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff0b1120) : const Color(0xfff8fafc),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : primaryNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "إحصائيات البطاقة 📊",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : primaryNavy,
          ),
        ),
        actions: [
          if (scannedStudentId != null)
            IconButton(
              icon: Icon(Icons.qr_code_scanner_rounded, color: accentGold),
              tooltip: "مسح طالب آخر",
              onPressed: _openQrScanner,
            ),
        ],
      ),
      body: scannedStudentId == null
          ? _buildEmptyState(isDark)
          : _buildStudentStatsView(scannedStudentId!, isDark),
    );
  }

  /// 1️⃣ الواجهة الفارغة عند فتح الصفحة أول مرة
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: accentGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.qr_code_scanner_rounded, size: 85, color: accentGold),
            ),
            const SizedBox(height: 24),
            Text(
              "لم يتم مسح أي بطاقة طالب بعد",
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "اضغط على الزر أدناه لمسح الـ QR المطبوع على بطاقة الطالب واستعراض تقريره وإحصائياته فورياً",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              icon: const Icon(Icons.camera_alt_rounded, color: Colors.black),
              label: const Text(
                "مسح QR الطالب 📷",
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black, fontSize: 15),
              ),
              onPressed: _openQrScanner,
            )
          ],
        ),
      ),
    );
  }

  /// 2️⃣ جلب بيانات الطالب وإحصائياته وعرضها في كروت مرتبة
  Widget _buildStudentStatsView(String studentId, bool isDark) {
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
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 65),
                const SizedBox(height: 14),
                const Text(
                  "رمز الـ QR غير صالح أو أن الطالب غير موجود!",
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: accentGold),
                  onPressed: _openQrScanner,
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
                  label: const Text("محاولة مسح أخرى", style: TextStyle(fontFamily: 'Cairo', color: Colors.black, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        }

        var stData = studentSnap.data!.data() as Map<String, dynamic>;
        String stName = stData['name'] ?? 'طالب';
        String imageUrl = stData['imageUrl'] ?? '';
        String supName = stData['supervisorName'] ?? 'غير محدد';
        bool isCompleted = stData['studentType'] == 'completed';

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sessions')
              .where('studentId', isEqualTo: studentId)
              .snapshots(),
          builder: (context, sessionsSnap) {
            if (!sessionsSnap.hasData) return const Center(child: CircularProgressIndicator());

            var docs = sessionsSnap.data!.docs;

            // 🧮 إجراء الحسابات الإحصائية
            int totalSessions = docs.length;
            int totalAbsences = 0;
            int totalExams = 0;
            
            DateTime now = DateTime.now();
            DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            DateTime startOfMonth = DateTime(now.year, now.month, 1);

            int weeklyAttendances = 0;
            int monthlyAttendances = 0;

            for (var doc in docs) {
              var data = doc.data() as Map<String, dynamic>;
              bool isAbsent = data['absent'] == true;
              bool isExam = data['isExam'] == true;

              if (isAbsent) totalAbsences++;
              if (isExam) totalExams++;

              String dateStr = data['date'] ?? '';
              try {
                List<String> parts = dateStr.split('-');
                if (parts.length == 3) {
                  DateTime sessionDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));

                  if (!isAbsent) {
                    if (sessionDate.isAfter(startOfWeek)) weeklyAttendances++;
                    if (sessionDate.isAfter(startOfMonth)) monthlyAttendances++;
                  }
                }
              } catch (_) {}
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // كارت تعريف الطالب
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1e293b) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: accentGold.withValues(alpha: 0.35), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black26 : Colors.grey.shade200,
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: accentGold.withValues(alpha: 0.2),
                          backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                          child: imageUrl.isEmpty ? Icon(Icons.person, size: 38, color: accentGold) : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stName,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "المشرف: $supName",
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              if (isCompleted) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "خاتم للقرآن الكريم ✨",
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                                  ),
                                )
                              ]
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.qr_code_scanner_rounded, color: accentGold, size: 28),
                          onPressed: _openQrScanner,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 📊 شبكة الإحصائيات (الأسبوعية والشهرية)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      _buildStatCard("حضور الأسبوع 📅", "$weeklyAttendances جلسات", Colors.blueAccent, isDark),
                      _buildStatCard("حضور الشهر 🗓️", "$monthlyAttendances جلسة", Colors.green, isDark),
                      _buildStatCard("إجمالي التسميعات 📖", "$totalSessions جلسة", Colors.amber.shade800, isDark),
                      _buildStatCard("إجمالي الغياب ❌", "$totalAbsences أيام", Colors.redAccent, isDark),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // زر لإتاحة مسح طالب آخر بسهولة
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentGold, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: Icon(Icons.camera_alt_rounded, color: accentGold),
                      label: Text(
                        "مسح بطاقة طالب آخر 📷",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : primaryNavy,
                        ),
                      ),
                      onPressed: _openQrScanner,
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

  Widget _buildStatCard(String title, String val, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1e293b) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black12 : Colors.grey.shade100,
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            val,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}