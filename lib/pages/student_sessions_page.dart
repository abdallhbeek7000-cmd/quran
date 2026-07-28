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
import '../widgets/offline_wrapper.dart'; 

class StudentSessionsPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String role;

  const StudentSessionsPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.role,
  });

  @override
  State<StudentSessionsPage> createState() => _StudentSessionsPageState();
}

class _StudentSessionsPageState extends State<StudentSessionsPage> with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); 

  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: -10, end: 20).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  DateTime _parseDate(String dateStr) {
    try {
      List<String> parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (e) {
      return DateTime(2000); 
    }
    return DateTime(2000);
  }

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

  // 📊 دالة التصدير للإكسل (محدثة لتصدير تاريخ التسجيل الفعلي للمدير)
  Future<void> exportSessionsToExcel(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("جاري تجهيز سجل الجلسات الشامل...", style: TextStyle(fontFamily: 'Cairo'))),
      );

      DocumentSnapshot studentDoc = await FirebaseFirestore.instance.collection('students').doc(widget.studentId).get();
      bool isCompleted = false;
      if (studentDoc.exists && studentDoc.data() != null) {
        var sData = studentDoc.data() as Map<String, dynamic>;
        isCompleted = sData['studentType'] == 'completed';
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('studentId', isEqualTo: widget.studentId)
          .get();

      final docs = snapshot.docs;
      
      docs.sort((a, b) {
        var dataA = a.data();
        var dataB = b.data();

        DateTime dateAObj = _parseDate(dataA['date'] ?? '');
        DateTime dateBObj = _parseDate(dataB['date'] ?? '');

        int dateComparison = dateBObj.compareTo(dateAObj);

        if (dateComparison == 0) {
          Timestamp? tA = dataA['timestamp'] as Timestamp?;
          Timestamp? tB = dataB['timestamp'] as Timestamp?;
          if (tA != null && tB != null) return tB.compareTo(tA);
          if (tA == null && tB != null) return -1; 
          if (tB == null && tA != null) return 1;
        }
        return dateComparison;
      });

      var excel = pkg_excel.Excel.createExcel();
      pkg_excel.Sheet sheetObject = excel['سجل التسميع'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        pkg_excel.TextCellValue('رقم الجلسة'),
        pkg_excel.TextCellValue('التاريخ المعتمد'),
        pkg_excel.TextCellValue('اليوم'), 
        pkg_excel.TextCellValue('وقت التسجيل الفعلي بالنظام'), // 🕵️‍♂️ حقل خفي إداري
        pkg_excel.TextCellValue('نوع الجلسة'),
        pkg_excel.TextCellValue('المشرف / المشرفين'), 
        pkg_excel.TextCellValue('تقييم الحفظ'), 
        pkg_excel.TextCellValue('تقييم مراجعة جديد'),    
        pkg_excel.TextCellValue('تقييم مراجعة قديم / الختمة'),    
        pkg_excel.TextCellValue('الحفظ الجديد'),
        pkg_excel.TextCellValue('مراجعة جديد'),
        pkg_excel.TextCellValue(isCompleted ? 'مراجعة الختمة الشاملة' : 'مراجعة قديم'),
        pkg_excel.TextCellValue('قراءة نظراً'),
        pkg_excel.TextCellValue('واجب حفظ جديد'),
        pkg_excel.TextCellValue('واجب مراجعة جديد'),
        pkg_excel.TextCellValue('واجب مراجعة قديم'),
        pkg_excel.TextCellValue('الأنشطة الدينية'), 
        pkg_excel.TextCellValue('إجمالي الحفظ للختمة'), 
        pkg_excel.TextCellValue('ملاحظات'),
      ]);

      int totalSessions = docs.length;

      for (int i = 0; i < docs.length; i++) {
        var doc = docs[i];
        var data = doc.data();
        
        int sessionNum = totalSessions - i;
        
        bool isAbsent = data['absent'] ?? false;
        bool isExam = data['isExam'] ?? false;
        bool didNotRecite = data['didNotRecite'] ?? false;

        String sessionType = isAbsent ? 'غائب' : (isExam ? 'اختبار' : (didNotRecite ? 'بدون تسميع' : 'حلقة عادية'));
        String dateStr = data['date']?.toString() ?? '';
        String dayName = _getArabicDayName(dateStr);
        String actualTime = data['actualCreatedAt']?.toString() ?? 'غير مسجل';

        List<dynamic>? supNamesList = data['supervisorNames'];
        String supervisorResult = (supNamesList != null && supNamesList.isNotEmpty) ? supNamesList.join(' ، ') : (data['supervisorName'] ?? 'غير محدد');

        String memRatingResult = data['memorizationRating'] ?? data['rating'] ?? '---';
        String newRevRatingResult = data['newReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? '---';
        String oldRevRatingResult = data['oldReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? '---';
        
        if (isExam && !isAbsent) {
          memRatingResult = 'علامة: ${data['examScore'] ?? 0} من 100';
          newRevRatingResult = 'اختبار';
          oldRevRatingResult = 'اختبار';
        } else if (isAbsent || didNotRecite) {
          memRatingResult = '---';
          newRevRatingResult = '---';
          oldRevRatingResult = '---';
        } else if (isCompleted) {
          memRatingResult = '---';
          newRevRatingResult = '---';
        }

        String nMemo = data['newMemorization']?.toString().trim() ?? '';
        String nRev = data['nearReview']?.toString().trim() ?? '';
        String fRev = data['farReview']?.toString().trim() ?? (isCompleted ? (data['review']?.toString().trim() ?? '') : '');
        String sight = data['readingBySight']?.toString().trim() ?? '';

        String hwNew = data['newHomework'] ?? '';
        String hwNewRev = data['newReviewHomework'] ?? '';
        String hwOldRev = data['oldReviewHomework'] ?? '';
        String hwLegacy = data['homework'] ?? '';

        if (hwNew.isEmpty && hwNewRev.isEmpty && hwOldRev.isEmpty && hwLegacy.isNotEmpty) {
          hwOldRev = hwLegacy; 
        }

        sheetObject.appendRow([
          pkg_excel.TextCellValue(sessionNum.toString()),
          pkg_excel.TextCellValue(dateStr),
          pkg_excel.TextCellValue(dayName), 
          pkg_excel.TextCellValue(actualTime),
          pkg_excel.TextCellValue(sessionType),
          pkg_excel.TextCellValue(supervisorResult), 
          pkg_excel.TextCellValue((memRatingResult.isEmpty || nMemo.isEmpty) ? '---' : memRatingResult),
          pkg_excel.TextCellValue((newRevRatingResult.isEmpty || nRev.isEmpty) ? '---' : newRevRatingResult),
          pkg_excel.TextCellValue((oldRevRatingResult.isEmpty || fRev.isEmpty) ? '---' : oldRevRatingResult),
          pkg_excel.TextCellValue((isAbsent || isExam || didNotRecite || isCompleted) ? '---' : nMemo),
          pkg_excel.TextCellValue((isAbsent || isExam || didNotRecite || isCompleted) ? '---' : nRev),
          pkg_excel.TextCellValue((isAbsent || isExam || didNotRecite) ? '---' : fRev),
          pkg_excel.TextCellValue((isAbsent || isExam || didNotRecite) ? '---' : sight),
          pkg_excel.TextCellValue((isAbsent || isExam || didNotRecite) ? '---' : hwNew),
          pkg_excel.TextCellValue((isAbsent || isExam || didNotRecite) ? '---' : hwNewRev),
          pkg_excel.TextCellValue((isAbsent || isExam || didNotRecite) ? '---' : hwOldRev),
          pkg_excel.TextCellValue((isAbsent || isExam) ? '---' : (data['religiousActivities'] ?? '')), 
          pkg_excel.TextCellValue(isCompleted ? '604 صفحة' : (isAbsent ? '---' : (data['total_memorized_pages']?.toString() ?? '---'))), 
          pkg_excel.TextCellValue(data['notes']?.toString() ?? ''),
        ]);
      }

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/سجل_${widget.studentName}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);
      
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(filePath)], text: 'سجل الطالب: ${widget.studentName}');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e", style: const TextStyle(fontFamily: 'Cairo'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = SessionService();
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true, 
        backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent, 
          title: Text(widget.studentName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
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
            
            AnimatedBuilder(
              animation: _bgAnimation,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned(
                      top: -20 + _bgAnimation.value,
                      left: -50 - (_bgAnimation.value / 2),
                      child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12))),
                    ),
                    Positioned(
                      bottom: 100 - _bgAnimation.value,
                      right: -60 + _bgAnimation.value,
                      child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2))),
                    ),
                  ],
                );
              },
            ),

            SafeArea(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('students').doc(widget.studentId).get(),
                builder: (context, studentSnapshot) {
                  bool isCompletedStudent = false;
                  if (studentSnapshot.hasData && studentSnapshot.data!.exists) {
                    var sData = studentSnapshot.data!.data() as Map<String, dynamic>;
                    isCompletedStudent = sData['studentType'] == 'completed';
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: sessionService.getStudentSessions(widget.studentId), 
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final sessions = snapshot.data!.docs;
                      if (sessions.isEmpty) return _buildEmptyState(isDarkMode);

                      List<QueryDocumentSnapshot> sortedSessions = List.from(sessions);
                      
                      sortedSessions.sort((a, b) {
                        var dataA = a.data() as Map<String, dynamic>;
                        var dataB = b.data() as Map<String, dynamic>;

                        DateTime dateAObj = _parseDate(dataA['date'] ?? '');
                        DateTime dateBObj = _parseDate(dataB['date'] ?? '');

                        int dateComparison = dateBObj.compareTo(dateAObj);

                        if (dateComparison == 0) {
                          Timestamp? tA = dataA['timestamp'] as Timestamp?;
                          Timestamp? tB = dataB['timestamp'] as Timestamp?;
                          if (tA != null && tB != null) return tB.compareTo(tA);
                          if (tA == null && tB != null) return -1; 
                          if (tB == null && tA != null) return 1;
                        }
                        return dateComparison;
                      });

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 30),
                        itemCount: sortedSessions.length,
                        itemBuilder: (context, index) {
                          final session = sortedSessions[index];
                          final data = session.data() as Map<String, dynamic>;
                          int sessionNum = sortedSessions.length - index;
                          return _buildSessionTimelineItem(context, session.id, data, isDarkMode, isCompletedStudent, sessionNum);
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

  Widget _buildSessionTimelineItem(BuildContext context, String sessionId, Map<String, dynamic> data, bool isDarkMode, bool isCompletedStudent, int sessionNumber) {
    bool isAbsent = data['absent'] ?? false;
    bool isExam = data['isExam'] ?? false;
    bool didNotRecite = data['didNotRecite'] ?? false;

    String sessionDateRaw = data['date'] ?? '';
    String dayName = _getArabicDayName(sessionDateRaw);
    String displayDate = dayName.isNotEmpty ? "$dayName، $sessionDateRaw" : sessionDateRaw;

    // 🕵️‍♂️ استخراج التوقيت الفعلي
    String actualCreatedAt = data['actualCreatedAt']?.toString() ?? '';
    String actualEditedAt = data['actualEditedAt']?.toString() ?? '';

    String nMemo = data['newMemorization']?.toString().trim() ?? '';
    String nRev = data['nearReview']?.toString().trim() ?? '';
    String fRev = data['farReview']?.toString().trim() ?? (isCompletedStudent ? (data['review']?.toString().trim() ?? '') : '');
    String sight = data['readingBySight']?.toString().trim() ?? '';

    String memRating = data['memorizationRating'] ?? data['rating'] ?? "";
    String newRevRating = data['newReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? "";
    String oldRevRating = data['oldReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? "";
    String revRatingLegacy = data['reviewRating'] ?? data['rating'] ?? "";
    
    String nHw = data['newHomework']?.toString().trim() ?? '';
    String nRevHw = data['newReviewHomework']?.toString().trim() ?? '';
    String oRevHw = data['oldReviewHomework']?.toString().trim() ?? '';
    String oldHw = data['homework']?.toString().trim() ?? '';

    List<dynamic>? supNamesList = data['supervisorNames'];
    String supervisorsDisplay = (supNamesList != null && supNamesList.isNotEmpty) ? supNamesList.join(' ، ') : (data['supervisorName'] ?? 'غير محدد');

    List<Widget> activeBoxes = [];
    if (!didNotRecite && !isAbsent && !isExam) {
      if (isCompletedStudent && fRev.isNotEmpty) {
        activeBoxes.add(_buildGridInfoBox(Icons.verified_user_rounded, "المقدار المسموع من مراجعة الختمة الشاملة", fRev, isDarkMode ? Colors.tealAccent : Colors.teal, isDarkMode));
      } else {
        if (nMemo.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.star_rounded, "الحفظ الجديد", nMemo, Colors.amber, isDarkMode));
        if (nRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.menu_book_rounded, "مراجعة جديد", nRev, isDarkMode ? Colors.tealAccent : Colors.teal, isDarkMode));
        if (fRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.history_toggle_off_rounded, "مراجعة قديم", fRev, Colors.blueGrey, isDarkMode));
      }
      if (sight.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.chrome_reader_mode_rounded, "قراءة نظراً", sight, Colors.indigoAccent, isDarkMode));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        customBorderColor: isAbsent ? Colors.red.withOpacity(0.4) : (isExam ? Colors.teal.withOpacity(0.4) : (didNotRecite ? Colors.blueGrey.withOpacity(0.4) : null)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: isAbsent 
                    ? Colors.red.withOpacity(isDarkMode ? 0.2 : 0.15) 
                    : (isExam ? Colors.teal.withOpacity(isDarkMode ? 0.2 : 0.15) 
                        : (didNotRecite ? Colors.blueGrey.withOpacity(isDarkMode ? 0.2 : 0.15) 
                            : (isDarkMode ? Colors.white.withOpacity(0.05) : primaryColor.withOpacity(0.05)))),
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
                          Icon(
                            isAbsent ? Icons.event_busy : (isExam ? Icons.workspace_premium : (didNotRecite ? Icons.speaker_notes_off_outlined : Icons.calendar_today)), 
                            size: 16, 
                            color: isAbsent ? Colors.redAccent : (isExam ? Colors.teal : (didNotRecite ? Colors.blueGrey : (isDarkMode ? accentGold : primaryColor)))
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "الجلسة #$sessionNumber | $displayDate", 
                            style: TextStyle(fontWeight: FontWeight.bold, color: isAbsent ? Colors.redAccent : (isExam ? Colors.teal : (didNotRecite ? Colors.blueGrey : (isDarkMode ? Colors.white : primaryColor))), fontFamily: 'Cairo', fontSize: 13)
                          ),
                        ],
                      ),
                      if (isAbsent) 
                        _buildBadge("غائب ❌", Colors.redAccent) 
                      else if (isExam)
                        _buildBadge("جلسة اختبار 📝", Colors.teal) 
                      else if (didNotRecite)
                        _buildBadge("بدون تسميع ℹ️", Colors.blueGrey)
                    ],
                  ),
                  
                  if (!isAbsent && !isExam && !didNotRecite) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isCompletedStudent && revRatingLegacy.isNotEmpty)
                          _buildBadge("مراجعة الختمة: $revRatingLegacy", _getRatingColor(revRatingLegacy)),
                        if (!isCompletedStudent) ...[
                          if (nMemo.isNotEmpty && memRating.isNotEmpty)
                            _buildBadge("حفظ: $memRating", _getRatingColor(memRating)),
                          if (nRev.isNotEmpty && newRevRating.isNotEmpty)
                            _buildBadge("م.جديد: $newRevRating", _getRatingColor(newRevRating)),
                          if (fRev.isNotEmpty && oldRevRating.isNotEmpty)
                            _buildBadge("م.قديم: $oldRevRating", _getRatingColor(oldRevRating)),
                        ],
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
                  // 🕵️‍♂️👑 شريط التوثيق الزمني الفعلي للإدارة فقط (manager)
                  if (widget.role == 'manager' && (actualCreatedAt.isNotEmpty || actualEditedAt.isNotEmpty)) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(isDarkMode ? 0.12 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (actualCreatedAt.isNotEmpty)
                                  Text(
                                    "تاريخ ووقت الإدخال الفعلي: $actualCreatedAt",
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDarkMode ? Colors.amberAccent : Colors.orange.shade900),
                                  ),
                                if (actualEditedAt.isNotEmpty)
                                  Text(
                                    "تاريخ آخر تعديل: $actualEditedAt",
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDarkMode ? Colors.orangeAccent : Colors.deepOrange.shade800),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  _buildMinimalistDetailRow(
                    Icons.person_outline, 
                    (supNamesList != null && supNamesList.length > 1) ? "المشرفين" : "المشرف المسجِّل", 
                    supervisorsDisplay, 
                    isDarkMode, 
                    isBold: true
                  ),
                  Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),

                  if (!isAbsent && !isExam && !didNotRecite) ...[
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
                      Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                    ],

                    if (nHw.isNotEmpty || nRevHw.isNotEmpty || oRevHw.isNotEmpty || oldHw.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentGold.withOpacity(isDarkMode ? 0.05 : 0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: accentGold.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.menu_book, size: 16, color: accentGold),
                                const SizedBox(width: 6),
                                Text(isCompletedStudent ? "المقدار المطلوب للمرة القادمة:" : "الواجب القادم:", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (nHw.isNotEmpty) _buildHomeworkRow("حفظ جديد", nHw, isDarkMode),
                            if (nRevHw.isNotEmpty) _buildHomeworkRow("مراجعة جديد", nRevHw, isDarkMode),
                            if (oRevHw.isNotEmpty) _buildHomeworkRow(isCompletedStudent ? "مراجعة الختمة" : "مراجعة قديم", oRevHw, isDarkMode),
                            if (oldHw.isNotEmpty && nHw.isEmpty && nRevHw.isEmpty && oRevHw.isEmpty) _buildHomeworkRow("الواجب", oldHw, isDarkMode),
                          ],
                        ),
                      ),
                      Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                    ],
                  ],
                  
                  if (data['religiousActivities'] != null && data['religiousActivities'].toString().isNotEmpty) ...[
                    _buildMinimalistDetailRow(Icons.mosque_outlined, "الأنشطة الدينية", data['religiousActivities'], isDarkMode),
                    Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                  ],

                  if (!didNotRecite) ...[
                    _buildMinimalistDetailRow(
                      Icons.analytics_outlined, 
                      "إجمالي الحفظ للختمة", 
                      isCompletedStudent ? "604 صفحة (مكتملة ✨)" : (data['total_memorized_pages'] != null ? "${data['total_memorized_pages']} صفحة" : "---"), 
                      isDarkMode
                    ),
                    Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                  ],

                  if (data['studentStatus'] != null && data['studentStatus'].toString().isNotEmpty)
                    _buildMinimalistDetailRow(Icons.mood, "حالة الطالب", data['studentStatus'], isDarkMode),
                  
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
                              Text("نتيجة الاختبار النهائي للجلسة", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              const SizedBox(height: 4),
                              Text("${data['examScore'] ?? '0'} / 100", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.tealAccent : Colors.teal.shade900, fontFamily: 'Cairo')),
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
                  
                  const SizedBox(height: 15),
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
      padding: const EdgeInsets.only(bottom: 4, right: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• $label: ", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildGridInfoBox(IconData icon, String title, String val, Color iconColor, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
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
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white60 : Colors.grey[700], fontWeight: FontWeight.bold, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            val.trim().isEmpty ? '---' : val,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', height: 1.5),
          )
        ],
      ),
    );
  }

  Widget _buildMinimalistDetailRow(IconData icon, String label, String value, bool isDarkMode, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 17, color: isDarkMode ? accentGold : primaryColor.withOpacity(0.6)),
        ),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey[700], fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '---' : value,
            style: TextStyle(
              fontSize: 13, 
              color: isBold ? (isDarkMode ? Colors.white : primaryColor) : (isDarkMode ? Colors.white70 : Colors.black87), 
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600, 
              fontFamily: 'Cairo'
            ),
          ),
        ),
      ],
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
    if (widget.role == "readonly") {
      return const SizedBox();
    }

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
        if (widget.role == "manager") ...[
          const SizedBox(width: 10),
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () async {
              await SessionService().deleteSession(id);
              SessionService().recalculateConsecutiveAbsences(data['studentId']);
              
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