import 'dart:ui';
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

class _ArchivedStudentDetailSessionsPageState extends State<ArchivedStudentDetailSessionsPage> with SingleTickerProviderStateMixin {
  final Color primaryNavy = const Color(0xff1e293b);
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

  String _getJuzName(int juzNum) {
    switch (juzNum) {
      case 30: return "جزء عمَّ 👶";
      case 29: return "جزء تبارك 📖";
      case 28: return "قد سمع 📜";
      case 27: return "الذاريات 🌟";
      case 26: return "الأحقاف ✨";
      default: return "";
    }
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          children: [
            Text(widget.studentName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 16)),
            Text("أرشيف: ${widget.cycleName}", style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: isDarkMode ? accentGold : primaryNavy.withOpacity(0.8))),
          ],
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
                  stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

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
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 30),
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
    String displayDate = dayName.isNotEmpty ? "$dayName، $sessionDateRaw" : sessionDateRaw;

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
        activeBoxes.add(_buildGridInfoBox(Icons.verified_user_rounded, "مراجعة الختمة الشاملة", fRev, isDarkMode ? Colors.tealAccent : Colors.teal, isDarkMode));
      } else {
        if (nMemo.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.star_rounded, "الحفظ الجديد", nMemo, Colors.amber, isDarkMode));
        if (nRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.menu_book_rounded, "مراجعة جديد", nRev, isDarkMode ? Colors.tealAccent : Colors.teal, isDarkMode));
        if (fRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.history_toggle_off_rounded, "مراجعة قديم", fRev, Colors.blueGrey, isDarkMode));
      }
      if (sight.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.chrome_reader_mode_rounded, "قراءة نظراً", sight, Colors.indigoAccent, isDarkMode));
    }

    String juzChipTitle = _getJuzName(selectedJuz);

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
                    : (isExam
                        ? Colors.teal.withOpacity(isDarkMode ? 0.2 : 0.15)
                        : (didNotRecite
                            ? Colors.blueGrey.withOpacity(isDarkMode ? 0.2 : 0.15)
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
                            color: isAbsent ? Colors.redAccent : (isExam ? Colors.teal : (didNotRecite ? Colors.blueGrey : (isDarkMode ? accentGold : primaryColor))),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "الجلسة #$sessionNumber | $displayDate",
                            style: TextStyle(fontWeight: FontWeight.bold, color: isAbsent ? Colors.redAccent : (isExam ? Colors.teal : (didNotRecite ? Colors.blueGrey : (isDarkMode ? Colors.white : primaryColor))), fontFamily: 'Cairo', fontSize: 13),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (juzChipTitle.isNotEmpty && !isAbsent && !isExam) ...[
                            _buildBadge(juzChipTitle, Colors.purple),
                            const SizedBox(width: 4),
                          ],
                          if (isAbsent)
                            _buildBadge("غائب ❌", Colors.redAccent)
                          else if (isExam)
                            _buildBadge("اختبار 📝", Colors.teal)
                          else if (didNotRecite)
                            _buildBadge("بدون تسميع ℹ️", Colors.blueGrey)
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
                                  Text("تاريخ ووقت الإدخال الفعلي: $actualCreatedAt", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDarkMode ? Colors.amberAccent : Colors.orange.shade900)),
                                if (actualEditedAt.isNotEmpty)
                                  Text("تاريخ آخر تعديل: $actualEditedAt", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDarkMode ? Colors.orangeAccent : Colors.deepOrange.shade800)),
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
                          color: accentGold.withOpacity(isDarkMode ? 0.08 : 0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: accentGold.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.assignment_outlined, size: 16, color: accentGold),
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

                  if (data['religiousActivities'] != null && data['religiousActivities'].toString().trim().isNotEmpty) ...[
                    _buildMinimalistDetailRow(Icons.mosque_outlined, "الأنشطة الدينية", data['religiousActivities'], isDarkMode),
                    Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                  ],

                  if (!didNotRecite && selectedJuz == 0) ...[
                    _buildMinimalistDetailRow(
                      Icons.analytics_outlined,
                      "إجمالي الحفظ للختمة",
                      isCompletedStudent ? "604 صفحة (مكتملة ✨)" : (data['total_memorized_pages'] != null ? "${data['total_memorized_pages']} صفحة" : "---"),
                      isDarkMode,
                    ),
                    Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                  ],

                  if (data['studentStatus'] != null && data['studentStatus'].toString().trim().isNotEmpty && !isAbsent && !isExam) ...[
                    _buildMinimalistDetailRow(Icons.mood, "حالة الطالب", data['studentStatus'], isDarkMode),
                    Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 20),
                  ],

                  if (isExam && !isAbsent) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.teal.withOpacity(0.12) : Colors.teal.shade50.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.teal.withOpacity(0.4), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium, color: Colors.teal, size: 32),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("نتيجة الاختبار النهائي للجلسة", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey[800], fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              const SizedBox(height: 4),
                              Text("${data['examScore'] ?? '0'} / 100", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.tealAccent : Colors.teal.shade900, fontFamily: 'Cairo')),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(isDarkMode ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 6),
                              Text("نوع الغياب: $absenceType", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontFamily: 'Cairo', fontSize: 13)),
                            ],
                          ),
                          if (absenceReason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text("السبب: $absenceReason", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                          ]
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
          Text("• $label: ", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12.5, color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
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
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', height: 1.4),
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
              fontFamily: 'Cairo',
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.comment, size: 16, color: isDarkMode ? accentGold : primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "ملاحظات: $notes",
              style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: isDarkMode ? Colors.white70 : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4)]),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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
              "لا يوجد سجل جلسات لهذا الطالب في هذه الدورة",
              textAlign: TextAlign.center,
              style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}