import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class ArchivedStudentDetailSessionsPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String cycleId;
  final String cycleName;
  final bool isFirstCycle;

  const ArchivedStudentDetailSessionsPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.cycleId,
    required this.cycleName,
    required this.isFirstCycle,
  });

  @override
  State<ArchivedStudentDetailSessionsPage> createState() => _ArchivedStudentDetailSessionsPageState();
}

class _ArchivedStudentDetailSessionsPageState extends State<ArchivedStudentDetailSessionsPage> {
  final Color primaryNavy = const Color(0xff0f172a);
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);
  final Color softGold = const Color(0xffccb273);

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
        return const Color(0xff16a34a);
      case "جيد جداً":
        return const Color(0xff0d9488);
      case "جيد":
        return const Color(0xffd97706);
      case "مقبول":
        return const Color(0xff475569);
      case "ضعيف":
        return const Color(0xffef4444);
      default:
        return primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDarkMode ? const Color(0xff090d16) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        title: Column(
          children: [
            Text(
              widget.studentName,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDarkMode ? Colors.white : primaryColor,
                fontFamily: 'Cairo',
                fontSize: 16.5,
              ),
            ),
            Text(
              "أرشيف: ${widget.cycleName}",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
                color: isDarkMode ? softGold : primaryColor.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          RepaintBoundary(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [const Color(0xff090d16), const Color(0xff111b2e), const Color(0xff0b1120)]
                      : [const Color(0xfff4f7fb), const Color(0xffe9eff6), const Color(0xfff7f2e4)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
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
                  color: primaryColor.withOpacity(isDarkMode ? 0.20 : 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 90,
            left: -70,
            child: IgnorePointer(
              child: Container(
                width: 270,
                height: 270,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentGold.withOpacity(isDarkMode ? 0.09 : 0.13),
                ),
              ),
            ),
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
                  stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(color: accentGold, strokeWidth: 2.5),
                      );
                    }

                    final allDocs = snapshot.data!.docs;

                    // تصفية الجلسات الخاصة بالطالب وفي هذه الدورة
                    final filteredDocs = allDocs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      bool isMatchStudent = (data['studentId'] == widget.studentId) || (data['studentName'] == widget.studentName);
                      if (!isMatchStudent) return false;

                      String? docCycleId = data['cycleId'];
                      if (widget.isFirstCycle) {
                        return docCycleId == null || docCycleId.isEmpty || docCycleId == widget.cycleId;
                      } else {
                        return docCycleId == widget.cycleId;
                      }
                    }).toList();

                    if (filteredDocs.isEmpty) return _buildEmptyState(isDarkMode);

                    // ترتيب الجلسات أحدثها أولاً
                    filteredDocs.sort((a, b) {
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
                      physics: const ClampingScrollPhysics(),
                      cacheExtent: 500,
                      padding: const EdgeInsets.only(left: 18, right: 18, top: 8, bottom: 30),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final session = filteredDocs[index];
                        final data = session.data() as Map<String, dynamic>;
                        int sessionNum = filteredDocs.length - index;
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
    );
  }

  Widget _buildSessionTimelineItem(BuildContext context, String sessionId, Map<String, dynamic> data, bool isDarkMode, bool isCompletedStudent, int sessionNumber) {
    bool isAbsent = data['absent'] ?? false;
    bool isExam = data['isExam'] ?? false;
    bool didNotRecite = data['didNotRecite'] ?? false;
    int selectedJuz = data['selectedJuz'] ?? (data['isJuzAmma'] == true ? 30 : 0);

    String sessionDateRaw = data['date'] ?? '';
    String dayName = _getArabicDayName(sessionDateRaw);
    String displayDate = dayName.isNotEmpty ? "$dayName • $sessionDateRaw" : sessionDateRaw;

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

    String absenceType = data['absenceType']?.toString().trim() ?? 'بدون عذر';
    String absenceReason = data['absenceReason']?.toString().trim() ?? '';

    List<dynamic>? memoSupList = data['newMemoSupervisorNames'] ?? data['supervisorNames'];
    String memoSupervisors = (memoSupList != null && memoSupList.isNotEmpty) ? memoSupList.join(' ، ') : (data['supervisorName'] ?? 'غير محدد');

    List<dynamic>? revSupList = data['reviewSupervisorNames'] ?? data['supervisorNames'];
    String revSupervisors = (revSupList != null && revSupList.isNotEmpty) ? revSupList.join(' ، ') : (data['supervisorName'] ?? 'غير محدد');

    List<Widget> activeBoxes = [];
    if (!didNotRecite && !isAbsent && !isExam) {
      if (isCompletedStudent && fRev.isNotEmpty) {
        activeBoxes.add(_buildGridInfoBox(Icons.verified_user_rounded, "مراجعة الختمة الشاملة", fRev, const Color(0xff0d9488), isDarkMode));
      } else {
        if (nMemo.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.star_rounded, "الحفظ الجديد", nMemo, accentGold, isDarkMode));
        if (nRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.menu_book_rounded, "مراجعة جديد", nRev, const Color(0xff0d9488), isDarkMode));
        if (fRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.history_toggle_off_rounded, "مراجعة قديم", fRev, primaryColor, isDarkMode));
      }
      if (sight.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.chrome_reader_mode_rounded, "قراءة نظراً", sight, const Color(0xff6366f1), isDarkMode));
    }

    String juzChipTitle = _getJuzName(selectedJuz);
    final Color headerAccent = isAbsent
        ? const Color(0xffef4444)
        : (isExam ? const Color(0xff0d9488) : (didNotRecite ? const Color(0xff64748b) : accentGold));

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        customBorderColor: isAbsent
            ? const Color(0xffef4444).withOpacity(0.45)
            : (isExam
                ? const Color(0xff0d9488).withOpacity(0.45)
                : (didNotRecite
                    ? const Color(0xff64748b).withOpacity(0.4)
                    : accentGold.withOpacity(isDarkMode ? 0.25 : 0.35))),
        child: Column(
          children: [
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [headerAccent, headerAccent.withOpacity(0.35)],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: isAbsent
                    ? const Color(0xffef4444).withOpacity(isDarkMode ? 0.14 : 0.08)
                    : (isExam
                        ? const Color(0xff0d9488).withOpacity(isDarkMode ? 0.14 : 0.08)
                        : (didNotRecite
                            ? const Color(0xff64748b).withOpacity(isDarkMode ? 0.14 : 0.08)
                            : (isDarkMode ? Colors.white.withOpacity(0.03) : primaryColor.withOpacity(0.04)))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentGold.withOpacity(isDarkMode ? 0.2 : 0.16),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: accentGold.withOpacity(0.5)),
                              ),
                              child: Text(
                                "#$sessionNumber",
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isDarkMode ? accentGold : primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayDate,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: isAbsent
                                      ? const Color(0xffef4444)
                                      : (isExam
                                          ? const Color(0xff0d9488)
                                          : (didNotRecite
                                              ? const Color(0xff64748b)
                                              : (isDarkMode ? Colors.white : primaryNavy))),
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (juzChipTitle.isNotEmpty && !isAbsent && !isExam) ...[
                            _buildBadge(juzChipTitle, const Color(0xff7c3aed)),
                            const SizedBox(width: 4),
                          ],
                          if (isAbsent)
                            _buildBadge("غائب", const Color(0xffef4444))
                          else if (isExam)
                            _buildBadge("اختبار", const Color(0xff0d9488))
                          else if (didNotRecite)
                            _buildBadge("بدون تسميع", const Color(0xff64748b)),
                        ],
                      ),
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
                  if (actualCreatedAt.isNotEmpty || actualEditedAt.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: accentGold.withOpacity(isDarkMode ? 0.11 : 0.09),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accentGold.withOpacity(0.4), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, color: accentGold, size: 17),
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
                                      color: isDarkMode ? softGold : primaryColor,
                                    ),
                                  ),
                                if (actualEditedAt.isNotEmpty)
                                  Text(
                                    "تاريخ آخر تعديل: $actualEditedAt",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                      color: isDarkMode ? accentGold : const Color(0xffb45309),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (nMemo.isNotEmpty && memoSupervisors == revSupervisors) ...[
                    _buildMinimalistDetailRow(Icons.person_outline, "المشرف المسجِّل", memoSupervisors, isDarkMode, isBold: true),
                  ] else ...[
                    if (nMemo.isNotEmpty)
                      _buildMinimalistDetailRow(Icons.person_pin_rounded, "مشرف الحفظ الجديد", memoSupervisors, isDarkMode, isBold: true),
                    if (fRev.isNotEmpty || nRev.isNotEmpty) ...[
                      if (nMemo.isNotEmpty) const SizedBox(height: 6),
                      _buildMinimalistDetailRow(Icons.supervisor_account_rounded, "مشرف المراجعة", revSupervisors, isDarkMode, isBold: true),
                    ],
                  ],

                  Divider(color: isDarkMode ? Colors.white12 : Colors.black12, height: 20),

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
                      Divider(color: isDarkMode ? Colors.white12 : Colors.black12, height: 20),
                    ],

                    if (nHw.isNotEmpty || nRevHw.isNotEmpty || oRevHw.isNotEmpty || oldHw.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: accentGold.withOpacity(isDarkMode ? 0.08 : 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: accentGold.withOpacity(0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.assignment_outlined, size: 16, color: accentGold),
                                const SizedBox(width: 6),
                                Text(
                                  isCompletedStudent ? "المقدار المطلوب للمرة القادمة:" : "الواجب القادم:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.white : primaryNavy,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
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
                      Divider(color: isDarkMode ? Colors.white12 : Colors.black12, height: 20),
                    ],
                  ],

                  if (data['religiousActivities'] != null && data['religiousActivities'].toString().trim().isNotEmpty) ...[
                    _buildMinimalistDetailRow(Icons.mosque_outlined, "الأنشطة الدينية", data['religiousActivities'], isDarkMode),
                    Divider(color: isDarkMode ? Colors.white12 : Colors.black12, height: 20),
                  ],

                  if (!didNotRecite && selectedJuz == 0) ...[
                    _buildMinimalistDetailRow(
                      Icons.analytics_outlined,
                      "إجمالي الحفظ للختمة",
                      isCompletedStudent ? "604 صفحة (مكتملة)" : (data['total_memorized_pages'] != null ? "${data['total_memorized_pages']} صفحة" : "---"),
                      isDarkMode,
                    ),
                    Divider(color: isDarkMode ? Colors.white12 : Colors.black12, height: 20),
                  ],

                  if (data['studentStatus'] != null && data['studentStatus'].toString().trim().isNotEmpty && !isAbsent && !isExam) ...[
                    _buildMinimalistDetailRow(Icons.mood, "حالة الطالب", data['studentStatus'], isDarkMode),
                    Divider(color: isDarkMode ? Colors.white12 : Colors.black12, height: 20),
                  ],

                  if (isExam && !isAbsent) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xff0d9488).withOpacity(isDarkMode ? 0.14 : 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xff0d9488).withOpacity(0.4), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium_rounded, color: Color(0xff0d9488), size: 32),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "نتيجة الاختبار النهائي للجلسة",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.white70 : primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "${data['examScore'] ?? '0'} / 100",
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  color: isDarkMode ? const Color(0xff5eead4) : const Color(0xff0f766e),
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (isAbsent) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xffef4444).withOpacity(isDarkMode ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xffef4444).withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xffef4444), size: 17),
                              const SizedBox(width: 6),
                              Text(
                                "نوع الغياب: $absenceType",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xffef4444),
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (absenceReason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              "السبب: $absenceReason",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.white70 : primaryNavy,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  if (data['notes'] != null && data['notes'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildNotesBox(data['notes'], isDarkMode),
                  ],
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
          Text(
            "• $label: ",
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white60 : primaryColor.withOpacity(0.8),
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: isDarkMode ? Colors.white : primaryNavy,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridInfoBox(IconData icon, String title, String val, Color iconColor, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.03) : primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDarkMode ? Colors.white12 : accentGold.withOpacity(0.28), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.white60 : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
              height: 1.4,
            ),
          ),
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
          child: Icon(icon, size: 17, color: isDarkMode ? accentGold : primaryColor.withOpacity(0.75)),
        ),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white60 : Colors.grey.shade700,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '---' : value,
            style: TextStyle(
              fontSize: 13,
              color: isBold ? (isDarkMode ? Colors.white : primaryColor) : (isDarkMode ? Colors.white70 : primaryNavy),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    required bool isDarkMode,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    Color? customColor,
    Color? customBorderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: customColor ?? (isDarkMode ? const Color(0xff141e30).withOpacity(0.92) : Colors.white.withOpacity(0.94)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: customBorderColor ?? (isDarkMode ? Colors.white.withOpacity(0.11) : accentGold.withOpacity(0.32)),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(isDarkMode ? 0.24 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildNotesBox(String notes, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.03) : primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDarkMode ? Colors.white12 : accentGold.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.comment_outlined, size: 16, color: isDarkMode ? accentGold : primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "ملاحظات: $notes",
              style: TextStyle(
                fontSize: 12.5,
                color: isDarkMode ? Colors.white70 : primaryNavy,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.45), width: 0.9),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'Cairo',
        ),
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
            Icon(Icons.history_toggle_off_rounded, size: 64, color: accentGold),
            const SizedBox(height: 14),
            Text(
              "لا يوجد سجل جلسات لهذا الطالب في هذه الدورة",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : primaryColor,
                fontSize: 14,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}