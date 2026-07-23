import 'dart:ui'; // 🎯 لتأثير الزجاج والـ Blur
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // 🎯 لقراءة المظهر
import 'package:share_plus/share_plus.dart';
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider الخاص بك
import '../widgets/offline_wrapper.dart';
import 'edit_student_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // لون الإنعكاس الزجاجي

  @override
  Widget build(BuildContext context) {
    // قراءة حالة المظهر
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف بالكامل
        title: Text("إحصائيات المعهد", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية الانسيابية مع الدوائر العائمة (Blobs)
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
            top: -20,
            left: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 50,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          // 🏢 2. المحتوى الأساسي للواجهة
          SafeArea(
            child: FutureBuilder(
              future: Future.wait([
                FirebaseFirestore.instance.collection('students').where('archived', isEqualTo: false).get(),
                FirebaseFirestore.instance.collection('supervisors').get(),
                FirebaseFirestore.instance.collection('sessions').get(),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = snapshot.data![0].docs;
                final supervisors = snapshot.data![1].docs;
                final sessions = snapshot.data![2].docs;

                int absentCount = 0;
                int noSupervisor = 0;

                for (var s in sessions) {
                  final data = s.data() as Map<String, dynamic>;
                  if (data['absent'] == true) absentCount++;
                }

                for (var s in students) {
                  final data = s.data() as Map<String, dynamic>;
                  if (data['supervisorId'] == null || data['supervisorId'] == '') noSupervisor++;
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // 🧊 Header زجاجي خفيف
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "نظرة عامة", 
                              style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontSize: 28, fontWeight: FontWeight.bold)
                            ),
                            Text(
                              "إليك ملخص أداء المعهد لهذه الدورة", 
                              style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey[700], fontSize: 15)
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // قسم الكروت (Grid) الزجاجية
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                              childAspectRatio: 1.1,
                              children: [
                                _buildGlassCard(title: "الطلاب", value: students.length.toString(), icon: Icons.people_alt_rounded, color: isDarkMode ? Colors.lightBlueAccent : Colors.blue, isDarkMode: isDarkMode),
                                _buildGlassCard(title: "المشرفين", value: supervisors.length.toString(), icon: Icons.admin_panel_settings_rounded, color: isDarkMode ? accentGold : Colors.amber.shade700, isDarkMode: isDarkMode),
                                _buildGlassCard(title: "إجمالي الجلسات", value: sessions.length.toString(), icon: Icons.menu_book_rounded, color: Colors.greenAccent.shade400, isDarkMode: isDarkMode),
                                
                                // 🚀 تجعل كرت الغائبين قابلاً للضغط للانتقال لشاشة التفاصيل التراكمية
                                InkWell(
                                  borderRadius: BorderRadius.circular(25),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AllAbsentStudentsSummaryPage(),
                                      ),
                                    );
                                  },
                                  child: _buildGlassCard(title: "طلاب غائبون", value: absentCount.toString(), icon: Icons.person_off_rounded, color: Colors.redAccent, isDarkMode: isDarkMode),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // 🚀 🧊 كرت عريض للطلاب غير الموزعين أصبح قابلاً للضغط لرؤية الأسماء والتفاصيل
                            InkWell(
                              borderRadius: BorderRadius.circular(25),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const UnassignedStudentsPage(),
                                  ),
                                );
                              },
                              child: _buildGlassContainer(
                                isDarkMode: isDarkMode,
                                padding: const EdgeInsets.all(20),
                                customColor: isDarkMode ? Colors.orange.withOpacity(0.15) : Colors.orange.withOpacity(0.2),
                                customBorderColor: Colors.orange.withOpacity(0.5),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 38),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("طلاب بدون مشرف", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDarkMode ? Colors.white : primaryColor)),
                                          Text("هناك $noSupervisor طالباً لم يتم توزيعهم بعد", style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white70 : Colors.black54)),
                                        ],
                                      ),
                                    ),
                                    Text(noSupervisor.toString(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // 🧊 كرت ملاحظات الإدارة الزجاجي
                            _buildNotesSection(isDarkMode),
                            
                            const SizedBox(height: 30),
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
    );
  }

  // 🧊 أداة الكرت المربع الإحصائي (Glassmorphism)
  Widget _buildGlassCard({required String title, required String value, required IconData icon, required Color color, required bool isDarkMode}) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : primaryColor,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.white60 : Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 🧊 قسم الملاحظات الزجاجي
  Widget _buildNotesSection(bool isDarkMode) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: isDarkMode ? accentGold : primaryColor, size: 24),
              const SizedBox(width: 10),
              Text("توصيات الإدارة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
            ],
          ),
          Divider(height: 30, color: isDarkMode ? Colors.white24 : Colors.black12),
          _noteItem("تأكد من توزيع الطلاب الجدد فور تسجيلهم.", isDarkMode),
          _noteItem("راجع تقارير الغياب بشكل أسبوعي.", isDarkMode),
          _noteItem("كرم المشرفين المتميزين في لوحة الشرف.", isDarkMode),
        ],
      ),
    );
  }

  // أداة فرعية لنقاط الملاحظات
  Widget _noteItem(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDarkMode ? accentGold : primaryColor)),
          Expanded(child: Text(text, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 14, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  // 🧊 أداة مساعدة لتغليف العناصر وتأثير الزجاج الأساسية (Glassmorphism)
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero, Color? customColor, Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ?? (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: customBorderColor ?? (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6)),
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
// 🚀 1. صفحة تقرير الغيابات التراكمية الشاملة لجميع الطلاب
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
        backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text("سجل غيابات الطلاب", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16)),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400,
                                        borderRadius: BorderRadius.circular(15),
                                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 6)],
                                      ),
                                      child: Text(
                                        "$totalAbsences غيابات",
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text("المشرف: $supervisorName", style: TextStyle(fontSize: 12, fontFamily: 'Cairo', color: isDarkMode ? Colors.white60 : Colors.black54)),
                                if (parentPhone.isNotEmpty) ...[
                                  const SizedBox(height: 10),
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
// 🚀 2. صفحة عرض الطلاب غير الموزعين على مشرفين
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
        backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text("الطلاب غير الموزعين", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16)),
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

                  // تصفية الطلاب غير الموزعين (الذين ليس لديهم مشرف)
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
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(16),
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
                                    const Icon(Icons.person_search_rounded, color: Colors.orange, size: 24),
                                    const SizedBox(width: 8),
                                    Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
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
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (parentPhone.isNotEmpty)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    onPressed: () => _makePhoneCall(parentPhone),
                                    icon: const Icon(Icons.phone, size: 16, color: Colors.green),
                                    label: const Text("اتصال بولي الأمر", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 12)),
                                  ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(backgroundColor: (isDarkMode ? accentGold : primaryColor).withOpacity(0.15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => EditStudentPage(student: doc)));
                                  },
                                  icon: Icon(Icons.edit_note_rounded, size: 18, color: isDarkMode ? accentGold : primaryColor),
                                  label: Text("تعيين مشرف", style: TextStyle(color: isDarkMode ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 12)),
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