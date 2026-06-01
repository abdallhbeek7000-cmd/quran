import 'dart:io';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as pkg_excel;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'edit_session_page.dart';
import '../services/session_service.dart';

class StudentSessionsPage extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String role;

  const StudentSessionsPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.role,
  });

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); 

  // 📊 دالة التصدير للإكسل
  Future<void> exportSessionsToExcel(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("جاري تجهيز سجل الجلسات الشامل...", style: TextStyle(fontFamily: 'Cairo'))),
      );

      DocumentSnapshot studentDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
      bool isCompleted = false;
      if (studentDoc.exists && studentDoc.data() != null) {
        var sData = studentDoc.data() as Map<String, dynamic>;
        isCompleted = sData['studentType'] == 'completed';
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('studentId', isEqualTo: studentId)
          .get();

      final docs = snapshot.docs;
      docs.sort((a, b) {
        String dateA = a.data()['date'] ?? '';
        String dateB = b.data()['date'] ?? '';
        return dateB.compareTo(dateA); 
      });

      var excel = pkg_excel.Excel.createExcel();
      pkg_excel.Sheet sheetObject = excel['سجل التسميع'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        pkg_excel.TextCellValue('التاريخ'),
        pkg_excel.TextCellValue('نوع الجلسة'),
        pkg_excel.TextCellValue('المشرف المسجِّل'), 
        pkg_excel.TextCellValue(isCompleted ? 'تقييم مراجعة الختمة' : 'تقييم الحفظ الجديد'), 
        pkg_excel.TextCellValue(isCompleted ? 'الحالة' : 'تقييم المراجعة'),    
        pkg_excel.TextCellValue('الحفظ الجديد'),
        pkg_excel.TextCellValue('مراجعة جديد'),
        pkg_excel.TextCellValue(isCompleted ? 'مراجعة الختمة الشاملة' : 'مراجعة قديم'),
        pkg_excel.TextCellValue('قراءة نظراً'),
        pkg_excel.TextCellValue('الواجب'),
        pkg_excel.TextCellValue('الأنشطة الدينية'), 
        pkg_excel.TextCellValue('إجمالي الحفظ للختمة'), 
        pkg_excel.TextCellValue('ملاحظات'),
      ]);

      for (var doc in docs) {
        var data = doc.data();
        bool isAbsent = data['absent'] ?? false;
        bool isExam = data['isExam'] ?? false;

        String sessionType = isAbsent ? 'غائب' : (isExam ? 'اختبار' : 'حلقة عادية');
        String supervisorResult = data['supervisorName'] ?? 'غير محدد';

        String memRatingResult = data['memorizationRating'] ?? data['rating'] ?? '';
        String revRatingResult = data['reviewRating'] ?? data['rating'] ?? '';
        
        if (isExam && !isAbsent) {
          memRatingResult = 'علامة: ${data['examScore'] ?? 0} من 100';
          revRatingResult = 'اختبار';
        } else if (isAbsent) {
          memRatingResult = '---';
          revRatingResult = '---';
        }

        sheetObject.appendRow([
          pkg_excel.TextCellValue(data['date']?.toString() ?? ''),
          pkg_excel.TextCellValue(sessionType),
          pkg_excel.TextCellValue(supervisorResult), 
          pkg_excel.TextCellValue(isCompleted ? revRatingResult : (memRatingResult.isEmpty ? '---' : memRatingResult)),
          pkg_excel.TextCellValue(isCompleted ? (isAbsent ? '---' : 'خاتم 👑') : (revRatingResult.isEmpty ? '---' : revRatingResult)),
          pkg_excel.TextCellValue((isAbsent || isExam || isCompleted) ? '---' : (data['newMemorization'] ?? '')),
          pkg_excel.TextCellValue((isAbsent || isExam || isCompleted) ? '---' : (data['nearReview'] ?? '')),
          pkg_excel.TextCellValue((isAbsent || isExam) ? '---' : (data['farReview'] ?? (isCompleted ? (data['review'] ?? '') : ''))),
          pkg_excel.TextCellValue((isAbsent || isExam) ? '---' : (data['readingBySight'] ?? '')),
          pkg_excel.TextCellValue((isAbsent || isExam) ? '---' : (data['homework'] ?? '')), // الإكسل يستخدم الحقل المدمج القديم للسهولة
          pkg_excel.TextCellValue((isAbsent || isExam) ? '---' : (data['religiousActivities'] ?? '')), 
          pkg_excel.TextCellValue(isCompleted ? '604 صفحة' : (isAbsent ? '---' : (data['total_memorized_pages']?.toString() ?? '---'))), 
          pkg_excel.TextCellValue(data['notes']?.toString() ?? ''),
        ]);
      }

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/سجل_$studentName.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);
      await Share.shareXFiles([XFile(filePath)], text: 'سجل الطالب: $studentName');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e", style: const TextStyle(fontFamily: 'Cairo'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = SessionService();
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, 
        title: Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.download_rounded, color: isDarkMode ? accentGold : primaryColor),
            tooltip: "تصدير إلى Excel",
            onPressed: () => exportSessionsToExcel(context),
          ),
        ],
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
            top: -20,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          SafeArea(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('students').doc(studentId).get(),
              builder: (context, studentSnapshot) {
                bool isCompletedStudent = false;
                if (studentSnapshot.hasData && studentSnapshot.data!.exists) {
                  var sData = studentSnapshot.data!.data() as Map<String, dynamic>;
                  isCompletedStudent = sData['studentType'] == 'completed';
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: sessionService.getStudentSessions(studentId), 
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final sessions = snapshot.data!.docs;
                    if (sessions.isEmpty) return _buildEmptyState(isDarkMode);

                    List<QueryDocumentSnapshot> sortedSessions = List.from(sessions);
                    sortedSessions.sort((a, b) {
                      String dateA = (a.data() as Map<String, dynamic>)['date'] ?? '';
                      String dateB = (b.data() as Map<String, dynamic>)['date'] ?? '';
                      return dateB.compareTo(dateA); 
                    });

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 30),
                      itemCount: sortedSessions.length,
                      itemBuilder: (context, index) {
                        final session = sortedSessions[index];
                        final data = session.data() as Map<String, dynamic>;
                        return _buildSessionTimelineItem(context, session.id, data, isDarkMode, isCompletedStudent);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTimelineItem(BuildContext context, String sessionId, Map<String, dynamic> data, bool isDarkMode, bool isCompletedStudent) {
    bool isAbsent = data['absent'] ?? false;
    bool isExam = data['isExam'] ?? false;

    // 🚀 جلب التقييمات (إذا كانت مطفية في الجلسة ستكون فارغة)
    String memRating = data['memorizationRating'] ?? "";
    String revRating = data['reviewRating'] ?? "";
    
    // التوافق الرجعي للجلسات القديمة التي تستخدم 'rating' فقط
    if (memRating.isEmpty && data['rating'] != null && data['rating'].toString().isNotEmpty && data['newMemorization'] != null && data['newMemorization'].toString().isNotEmpty) {
      memRating = data['rating'];
    }
    if (revRating.isEmpty && data['rating'] != null && data['rating'].toString().isNotEmpty && !isCompletedStudent && memRating.isEmpty) {
      revRating = data['rating'];
    } else if (revRating.isEmpty && data['rating'] != null && data['rating'].toString().isNotEmpty && isCompletedStudent) {
      revRating = data['rating']; // الخاتم له تقييم واحد
    }

    // 🚀 جلب حقول الحفظ والمراجعة (للتحقق من وجودها)
    String nMemo = data['newMemorization']?.toString().trim() ?? '';
    String nRev = data['nearReview']?.toString().trim() ?? '';
    String fRev = data['farReview']?.toString().trim() ?? (isCompletedStudent ? (data['review']?.toString().trim() ?? '') : '');
    
    // 🚀 جلب حقول الواجب
    String nHw = data['newHomework']?.toString().trim() ?? '';
    String rHw = data['reviewHomework']?.toString().trim() ?? '';
    String oldHw = data['homework']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        customBorderColor: isAbsent ? Colors.red.withOpacity(0.4) : (isExam ? Colors.teal.withOpacity(0.4) : null),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: isAbsent 
                    ? Colors.red.withOpacity(isDarkMode ? 0.2 : 0.15) 
                    : (isExam ? Colors.teal.withOpacity(isDarkMode ? 0.2 : 0.15) : (isDarkMode ? Colors.white.withOpacity(0.05) : primaryColor.withOpacity(0.05))),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isAbsent ? Icons.event_busy : (isExam ? Icons.workspace_premium : Icons.calendar_today), 
                        size: 16, 
                        color: isAbsent ? Colors.redAccent : (isExam ? Colors.teal : (isDarkMode ? accentGold : primaryColor))
                      ),
                      const SizedBox(width: 8),
                      Text(
                        data['date'] ?? '', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: isAbsent ? Colors.redAccent : (isExam ? Colors.teal : (isDarkMode ? Colors.white : primaryColor)),
                          fontFamily: 'Cairo'
                        )
                      ),
                    ],
                  ),
                  if (isAbsent) 
                    _buildBadge("غائب ❌", Colors.redAccent) 
                  else if (isExam)
                    _buildBadge("جلسة اختبار 📝", Colors.teal) 
                  else 
                    // 🎯 عرض الشارات بذكاء (تظهر فقط إذا كان التقييم موجوداً)
                    Row(
                      children: [
                        if (isCompletedStudent && revRating.isNotEmpty)
                          _buildBadge("مراجعة الختمة: $revRating", _getRatingColor(revRating)),
                        if (!isCompletedStudent) ...[
                          if (memRating.isNotEmpty) ...[
                            _buildBadge("حفظ: $memRating", _getRatingColor(memRating)),
                            const SizedBox(width: 5),
                          ],
                          if (revRating.isNotEmpty)
                            _buildBadge("مراجعة: $revRating", _getRatingColor(revRating)),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              child: Column(
                children: [
                  _buildInfoRow(Icons.person_outline, "المشرف المسجِّل", data['supervisorName'] ?? "غير محدد", isDarkMode),
                  Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),

                  if (!isAbsent && !isExam) ...[
                    // 🎯 عرض حقول الحفظ والمراجعة بذكاء
                    if (!isCompletedStudent) ...[
                      if (nMemo.isNotEmpty) ...[
                        _buildInfoRow(Icons.star_rounded, "الحفظ الجديد", nMemo, isDarkMode),
                        Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                      ],
                      if (nRev.isNotEmpty) ...[
                        _buildInfoRow(Icons.auto_stories_outlined, "مراجعة جديد", nRev, isDarkMode),
                        Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                      ],
                    ],
                    
                    if (fRev.isNotEmpty) ...[
                      _buildInfoRow(
                        isCompletedStudent ? Icons.verified_user_rounded : Icons.history_edu, 
                        isCompletedStudent ? "مراجعة الختمة الشاملة" : "مراجعة قديم", 
                        fRev, 
                        isDarkMode
                      ),
                      Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                    ],
                    
                    if (data['readingBySight'] != null && data['readingBySight'].toString().isNotEmpty) ...[
                      _buildInfoRow(Icons.menu_book_outlined, "قراءة نظراً", data['readingBySight'], isDarkMode),
                      Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                    ],
                    
                    // 🎯 عرض حقول الواجب المنفصلة أو القديمة
                    if (nHw.isNotEmpty || rHw.isNotEmpty) ...[
                      if (nHw.isNotEmpty) ...[
                        _buildInfoRow(Icons.edit_document, "واجب الحفظ الجديد", nHw, isDarkMode),
                        Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                      ],
                      if (rHw.isNotEmpty) ...[
                        _buildInfoRow(Icons.import_contacts_rounded, isCompletedStudent ? "المقدار المطلوب للمرة القادمة" : "واجب المراجعة", rHw, isDarkMode),
                        Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                      ],
                    ] else if (oldHw.isNotEmpty) ...[
                      _buildInfoRow(Icons.edit_note, "الواجب (السابق)", oldHw, isDarkMode),
                      Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                    ],
                    
                    if (data['religiousActivities'] != null && data['religiousActivities'].toString().isNotEmpty) ...[
                      _buildInfoRow(Icons.mosque_outlined, "الأنشطة الدينية", data['religiousActivities'], isDarkMode),
                      Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                    ],

                    _buildInfoRow(
                      Icons.analytics_outlined, 
                      "إجمالي الحفظ للختمة", 
                      isCompletedStudent ? "604 صفحة (مكتملة ✨)" : (data['total_memorized_pages'] != null ? "${data['total_memorized_pages']} صفحة" : "---"), 
                      isDarkMode
                    ),
                    Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),

                    if (data['studentStatus'] != null && data['studentStatus'].toString().isNotEmpty)
                      _buildInfoRow(Icons.mood, "حالة الطالب", data['studentStatus'], isDarkMode),
                  ],

                  if (isExam && !isAbsent) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.teal.withOpacity(0.1) : Colors.teal.shade50.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium, color: Colors.teal, size: 30),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "نتيجة الاختبار النهائي للجلسة",
                                style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${data['examScore'] ?? '0'} / 100",
                                style: TextStyle(
                                  fontSize: 24, 
                                  fontWeight: FontWeight.bold, 
                                  color: isDarkMode ? Colors.tealAccent : Colors.teal.shade900,
                                  fontFamily: 'Cairo'
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (data['notes'] != null && data['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 15),
                    _buildNotesBox(data['notes'], isDarkMode),
                  ],
                  
                  const SizedBox(height: 10),
                  _buildActionButtons(context, sessionId, data, isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildInfoRow(IconData icon, String label, dynamic value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDarkMode ? accentGold : primaryColor),
          const SizedBox(width: 10),
          Text(
            "$label: ", 
            style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey[700], fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold)
          ),
          Expanded(
            child: Text(
              (value == null || value.toString().trim().isEmpty) ? "---" : value.toString(), 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo')
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesBox(String notes, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
      ),
      child: Text(
        "ملاحظات: $notes", 
        style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: isDarkMode ? Colors.white70 : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.w600)
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String id, Map<String, dynamic> data, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: isDarkMode ? Colors.orange.withOpacity(0.1) : Colors.orange.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditSessionPage(sessionId: id, data: data))),
          icon: Icon(Icons.edit_rounded, size: 16, color: isDarkMode ? Colors.orangeAccent : Colors.orange.shade800),
          label: Text("تعديل", style: TextStyle(color: isDarkMode ? Colors.orangeAccent : Colors.orange.shade800, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
        if (role == "manager") ...[
          const SizedBox(width: 10),
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () async {
              await SessionService().deleteSession(id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حذف الجلسة", style: TextStyle(fontFamily: 'Cairo'))));
            },
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
            label: const Text("حذف", style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ]
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4)]),
      child: Text(
        text, 
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 70, color: isDarkMode ? accentGold.withOpacity(0.6) : primaryColor.withOpacity(0.4)),
            const SizedBox(height: 15),
            Text(
              "لا يوجد سجل جلسات لهذا الطالب حتى الآن", 
              textAlign: TextAlign.center,
              style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.bold)
            ),
          ],
        ),
      )
    );
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
}