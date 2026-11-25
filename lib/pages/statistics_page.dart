import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/theme_provider.dart';
import '../services/cycle_service.dart';
import '../widgets/offline_wrapper.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  static final RegExp _splitRegex = RegExp(r'[|،,+]');
  static final RegExp _digitRegex = RegExp(r'\d+');

  // 🚀 وضع الفلترة: 0 = أسبوعي، 1 = شهري، 2 = كامل الدورة
  int filterMode = 0;
  bool isLoading = true;
  bool isExporting = false;

  List<Map<String, dynamic>> newStudentsStats = [];
  List<Map<String, dynamic>> oldStudentsStats = [];
  List<Map<String, dynamic>> completedStudentsStats = [];

  int periodsBack = 0;
  String currentPeriodLabel = "";
  String currentCycleName = "";

  int cycleTotalPages = 0;
  int cycleTotalReview = 0;

  // ⚡ ذاكرة مؤقتة (Cache) لمنع إعادة التحميل من Firebase عند تغيير الأسبوع/الشهر
  bool _hasCachedData = false;
  String? _cachedCycleId;
  List<Map<String, dynamic>> _cachedStudents = [];
  Map<String, List<Map<String, dynamic>>> _cachedSessionsByStudent = {};

  @override
  void initState() {
    super.initState();
    _loadDataAndCalculate();
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      final p = dateStr.split('-');
      if (p.length == 3) {
        return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      }
    } catch (_) {}
    return null;
  }

  int _calculatePagesFromText(String? text) {
    if (text == null || text.trim().isEmpty) return 0;

    int totalPages = 0;
    final String processedText = text.replaceAll(' و ', '|');
    final List<String> parts = processedText.split(_splitRegex);

    for (final String part in parts) {
      final matches = _digitRegex.allMatches(part);
      if (matches.isEmpty) continue;

      int? minP;
      int? maxP;
      int count = 0;

      for (final m in matches) {
        final int val = int.parse(m.group(0)!);
        count++;
        if (minP == null || val < minP) minP = val;
        if (maxP == null || val > maxP) maxP = val;
      }

      if (count == 1) {
        totalPages += 1;
      } else if (minP != null && maxP != null && maxP >= minP) {
        totalPages += (maxP - minP) + 1;
      }
    }

    return totalPages;
  }

  // 🌐 جلب البيانات من السيرفر مرة واحدة فقط وتجهيزها في الذاكرة
  Future<void> _loadDataAndCalculate({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      if (!_hasCachedData || forceRefresh) {
        final cycle = await CycleService().getCurrentCycle();
        if (cycle == null) {
          if (mounted) setState(() => isLoading = false);
          return;
        }

        _cachedCycleId = cycle.id;
        currentCycleName = cycle.name.toString();

        // جلب الطلاب والجلسات بالتوازي في نفس اللحظة لتقليل وقت الانتظار للنصف!
        final results = await Future.wait([
          FirebaseFirestore.instance
              .collection('students')
              .where('cycleId', isEqualTo: cycle.id)
              .get(),
          FirebaseFirestore.instance
              .collection('sessions')
              .where('cycleId', isEqualTo: cycle.id)
              .get(),
        ]);

        final studentsSnap = results[0];
        var sessionsDocs = results[1].docs;

        // احتياطي في حال كانت الجلسات القديمة لا تحتوي على حقل cycleId
        if (sessionsDocs.isEmpty && studentsSnap.docs.isNotEmpty) {
          final fallbackSnap =
              await FirebaseFirestore.instance.collection('sessions').get();
          sessionsDocs = fallbackSnap.docs;
        }

        // تجهيز قائمة الطلاب النشطين فقط مرة واحدة
        final List<Map<String, dynamic>> parsedStudents = [];
        for (final doc in studentsSnap.docs) {
          final sData = doc.data();
          if (sData['archived'] == true) continue;
          if (sData['isJuzAmma'] == true) continue;

          final String studentType = (sData['studentType'] ?? 'new').toString();
          parsedStudents.add({
            'id': doc.id,
            'name': (sData['name'] ?? 'طالب').toString(),
            'imageUrl': (sData['imageUrl'] ?? '').toString(),
            'studentType': studentType,
            'isCompleted': studentType == 'completed',
          });
        }

        // تجميع الجلسات حسب studentId وحساب صفحات كل جلسة مسبقاً مرة واحدة!
        final Map<String, List<Map<String, dynamic>>> groupedSessions = {};
        for (final doc in sessionsDocs) {
          final data = doc.data();
          final String? studentId = data['studentId']?.toString();
          if (studentId == null || studentId.isEmpty) continue;

          if (data['isJuzAmma'] == true) continue;
          final int selJuz = (data['selectedJuz'] is int)
              ? data['selectedJuz']
              : int.tryParse(data['selectedJuz']?.toString() ?? '0') ?? 0;
          if (selJuz > 0) continue;

          if (data.containsKey('cycleId') &&
              data['cycleId'] != null &&
              data['cycleId'] != _cachedCycleId) {
            continue;
          }

          final bool isAbsent = data['absent'] == true;
          final DateTime? parsedDate =
              _parseDate((data['date'] ?? '').toString());

          int newPages = 0;
          int normalReviewPages = 0;
          int completedReviewPages = 0;

          if (!isAbsent) {
            final int newMem =
                _calculatePagesFromText(data['newMemorization']?.toString());
            final int nearRev =
                _calculatePagesFromText(data['nearReview']?.toString());
            final int farRev =
                _calculatePagesFromText(data['farReview']?.toString());
            final int genRev =
                _calculatePagesFromText(data['review']?.toString());

            newPages = newMem;
            normalReviewPages = nearRev + farRev;
            completedReviewPages = farRev + nearRev + genRev;
          }

          groupedSessions.putIfAbsent(studentId, () => []).add({
            'parsedDate': parsedDate,
            'absent': isAbsent,
            'newPages': newPages,
            'normalReviewPages': normalReviewPages,
            'completedReviewPages': completedReviewPages,
          });
        }

        _cachedStudents = parsedStudents;
        _cachedSessionsByStudent = groupedSessions;
        _hasCachedData = true;
      }

      _computeStatsFromCache();
    } catch (e) {
      debugPrint("Error in stats: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ⚡ حساب فوري من الذاكرة بدون أي تأخير (0ms) عند التنقل بين الأسابيع والشهور
  void _computeStatsFromCache() {
    final DateTime now = DateTime.now();
    DateTime targetStart = now;
    DateTime targetEnd = now;
    String periodLabel = "";

    if (filterMode == 0) {
      final int daysToSaturday = (now.weekday + 1) % 7;
      final DateTime currentWeekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysToSaturday));
      targetStart = currentWeekStart.subtract(Duration(days: periodsBack * 7));
      targetEnd = targetStart
          .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      periodLabel =
          "${targetStart.day}/${targetStart.month}  إلى  ${targetEnd.day}/${targetEnd.month}";
    } else if (filterMode == 1) {
      int targetYear = now.year;
      int targetMonth = now.month - periodsBack;

      while (targetMonth <= 0) {
        targetMonth += 12;
        targetYear -= 1;
      }

      targetStart = DateTime(targetYear, targetMonth, 1);
      targetEnd = DateTime(targetYear, targetMonth + 1, 0, 23, 59, 59);
      periodLabel = "شهر $targetMonth / $targetYear";
    } else {
      periodLabel = "إحصائيات الدورة التراكمية 🎯";
    }

    final DateTime startBoundary =
        targetStart.subtract(const Duration(seconds: 1));
    final DateTime endBoundary = targetEnd.add(const Duration(seconds: 1));

    int tempCyclePages = 0;
    int tempCycleReview = 0;

    final List<Map<String, dynamic>> tempNew = [];
    final List<Map<String, dynamic>> tempOld = [];
    final List<Map<String, dynamic>> tempCompleted = [];

    for (final student in _cachedStudents) {
      final String sId = student['id'];
      final List<Map<String, dynamic>>? allStudentSessions =
          _cachedSessionsByStudent[sId];
      if (allStudentSessions == null || allStudentSessions.isEmpty) continue;

      final bool isCompleted = student['isCompleted'] == true;
      int sessionsCount = 0;
      int absentCount = 0;
      int totalPages = 0;
      int reviewPages = 0;

      for (final s in allStudentSessions) {
        if (filterMode != 2) {
          final DateTime? d = s['parsedDate'] as DateTime?;
          if (d == null ||
              !d.isAfter(startBoundary) ||
              !d.isBefore(endBoundary)) {
            continue;
          }
        }

        if (s['absent'] == true) {
          absentCount++;
        } else {
          sessionsCount++;
          if (!isCompleted) {
            totalPages += s['newPages'] as int;
            reviewPages += s['normalReviewPages'] as int;
          } else {
            reviewPages += s['completedReviewPages'] as int;
          }
        }
      }

      if (totalPages == 0 &&
          reviewPages == 0 &&
          absentCount == 0 &&
          sessionsCount == 0) {
        continue;
      }

      if (!isCompleted) tempCyclePages += totalPages;
      tempCycleReview += reviewPages;

      final statData = <String, dynamic>{
        'name': student['name'],
        'imageUrl': student['imageUrl'],
        'pages': totalPages,
        'reviewPages': reviewPages,
        'isCompleted': isCompleted,
        'sessionsCount': sessionsCount,
        'absentCount': absentCount,
      };

      if (isCompleted) {
        tempCompleted.add(statData);
      } else if (student['studentType'] == 'old') {
        tempOld.add(statData);
      } else {
        tempNew.add(statData);
      }
    }

    tempNew.sort((a, b) => ((b['pages'] as int) + (b['reviewPages'] as int))
        .compareTo((a['pages'] as int) + (a['reviewPages'] as int)));

    tempOld.sort((a, b) => ((b['pages'] as int) + (b['reviewPages'] as int))
        .compareTo((a['pages'] as int) + (a['reviewPages'] as int)));

    tempCompleted.sort(
        (a, b) => (b['reviewPages'] as int).compareTo(a['reviewPages'] as int));

    if (mounted) {
      setState(() {
        currentPeriodLabel = periodLabel;
        cycleTotalPages = tempCyclePages;
        cycleTotalReview = tempCycleReview;
        newStudentsStats = tempNew;
        oldStudentsStats = tempOld;
        completedStudentsStats = tempCompleted;
        isLoading = false;
      });
    }
  }

  Future<void> _exportToExcel() async {
    setState(() => isExporting = true);
    try {
      var excel = excel_lib.Excel.createExcel();
      excel_lib.Sheet sheetObject = excel['الإحصائيات'];
      excel.delete('Sheet1');

      List<excel_lib.CellValue> headers = [
        excel_lib.TextCellValue('الفئة'),
        excel_lib.TextCellValue('اسم الطالب'),
        excel_lib.TextCellValue('صفحات الحفظ'),
        excel_lib.TextCellValue('صفحات المراجعة'),
        excel_lib.TextCellValue('أيام الغياب'),
        excel_lib.TextCellValue('أيام الحضور'),
      ];

      sheetObject.appendRow(headers);

      void addSectionRows(
          String categoryName, List<Map<String, dynamic>> stats) {
        for (var stat in stats) {
          sheetObject.appendRow([
            excel_lib.TextCellValue(categoryName),
            excel_lib.TextCellValue(stat['name'].toString()),
            excel_lib.IntCellValue((stat['pages'] as int?) ?? 0),
            excel_lib.IntCellValue((stat['reviewPages'] as int?) ?? 0),
            excel_lib.IntCellValue((stat['absentCount'] as int?) ?? 0),
            excel_lib.IntCellValue((stat['sessionsCount'] as int?) ?? 0),
          ]);
        }
      }

      addSectionRows('الطلاب الجدد', newStudentsStats);
      addSectionRows('الطلاب القدامى', oldStudentsStats);
      addSectionRows('الطلاب الخاتمين', completedStudentsStats);

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();
        String filterName = filterMode == 0
            ? "اسبوعي"
            : (filterMode == 1 ? "شهري" : "كامل_الدورة");
        String filePath = '${directory.path}/احصائيات_$filterName.xlsx';

        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles(
          [XFile(filePath)],
          text: '📊 تقرير الإحصائيات ($currentPeriodLabel)',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text("حدث خطأ أثناء تصدير الملف: $e",
                  style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  void _changePeriod(int amount) {
    if (filterMode == 2) return;
    periodsBack += amount;
    if (periodsBack < 0) periodsBack = 0;
    _computeStatsFromCache();
  }

  // 🖼️ فتح معاينة بطاقة الطالب ومشاركتها كصورة (واتساب وغيرها)
  void _showStudentSharePreview(
      Map<String, dynamic> stat, int index, String categoryTitle) {
    final String modeLabel = filterMode == 0
        ? "إحصائيات أسبوعية"
        : (filterMode == 1 ? "إحصائيات شهرية" : "إحصائيات الدورة");

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (dialogContext) => _StudentShareCardDialog(
        stat: stat,
        index: index,
        categoryTitle: categoryTitle,
        modeLabel: modeLabel,
        periodLabel: currentPeriodLabel,
        cycleName: currentCycleName,
        primaryColor: primaryColor,
        accentGold: accentGold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    bool hasAnyData = newStudentsStats.isNotEmpty ||
        oldStudentsStats.isNotEmpty ||
        completedStudentsStats.isNotEmpty;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor:
            isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: Text("لوحة الإحصائيات الشاملة 📊",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : primaryColor,
                  fontFamily: 'Cairo',
                  fontSize: 18)),
          iconTheme:
              IconThemeData(color: isDark ? Colors.white : primaryColor),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  color: isDark ? accentGold : primaryColor, size: 24),
              tooltip: "تحديث البيانات",
              onPressed: isLoading
                  ? null
                  : () => _loadDataAndCalculate(forceRefresh: true),
            ),
            IconButton(
              icon: isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.greenAccent))
                  : const Icon(Icons.explicit_outlined,
                      color: Colors.greenAccent, size: 26),
              tooltip: "تصدير إلى ملف إكسيل",
              onPressed: isExporting || isLoading ? null : _exportToExcel,
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Stack(
          children: [
            RepaintBoundary(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
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
            ),
            Positioned(
                top: -50,
                right: -50,
                child: IgnorePointer(
                  child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? accentGold.withOpacity(0.08)
                              : accentGold.withOpacity(0.12))),
                )),
            Positioned(
                bottom: 100,
                left: -80,
                child: IgnorePointer(
                  child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? primaryColor.withOpacity(0.15)
                              : primaryColor.withOpacity(0.2))),
                )),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isDark ? Colors.white12 : Colors.white,
                            width: 1.5),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton(0, "أسبوعي", isDark),
                          _buildTabButton(1, "شهري", isDark),
                          _buildTabButton(2, "كامل الدورة", isDark),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withOpacity(0.2)
                            : Colors.white.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color: isDark ? Colors.white12 : Colors.white70),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                              icon: Icon(Icons.chevron_right_rounded,
                                  color: filterMode == 2
                                      ? Colors.transparent
                                      : (isDark ? accentGold : primaryColor)),
                              onPressed: filterMode == 2
                                  ? null
                                  : () => _changePeriod(1),
                              tooltip: "السابق"),
                          Expanded(
                              child: Text(currentPeriodLabel,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : primaryColor,
                                      fontFamily: 'Cairo',
                                      fontSize: 13))),
                          IconButton(
                              icon: Icon(Icons.chevron_left_rounded,
                                  color: (filterMode != 2 && periodsBack > 0)
                                      ? (isDark ? accentGold : primaryColor)
                                      : Colors.transparent),
                              onPressed: (filterMode != 2 && periodsBack > 0)
                                  ? () => _changePeriod(-1)
                                  : null,
                              tooltip: "التالي"),
                        ],
                      ),
                    ),
                  ),

                  if (!isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 5),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      const Color(0xff1e293b),
                                      const Color(0xff0f172a)
                                    ]
                                  : [
                                      Colors.white,
                                      const Color(0xffe2e8f0)
                                    ]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: accentGold.withOpacity(0.5), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: accentGold.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: 1)
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem("إجمالي الحفظ", "$cycleTotalPages",
                                Icons.menu_book_rounded, Colors.green, isDark),
                            Container(
                                width: 1,
                                height: 38,
                                color: isDark
                                    ? Colors.white24
                                    : Colors.black12),
                            _buildSummaryItem(
                                "إجمالي المراجعة",
                                "$cycleTotalReview",
                                Icons.loop_rounded,
                                Colors.blueAccent,
                                isDark),
                          ],
                        ),
                      ),
                    ),

                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (!hasAnyData
                            ? Center(
                                child: Text(
                                    "لا توجد إحصائيات مسجلة لهذه الفترة 📭",
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : primaryColor,
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold)))
                            : CustomScrollView(
                                physics: const ClampingScrollPhysics(),
                                slivers: [
                                  ..._buildCategorySlivers(
                                      "الطلاب الجدد",
                                      newStudentsStats,
                                      isDark,
                                      Icons.fiber_new_rounded,
                                      Colors.blueAccent),
                                  ..._buildCategorySlivers(
                                      "الطلاب القدامى",
                                      oldStudentsStats,
                                      isDark,
                                      Icons.history_edu_rounded,
                                      Colors.orangeAccent),
                                  ..._buildCategorySlivers(
                                      "الطلاب الخاتمين 👑",
                                      completedStudentsStats,
                                      isDark,
                                      Icons.verified_rounded,
                                      accentGold),
                                  const SliverToBoxAdapter(
                                      child: SizedBox(height: 60)),
                                ],
                              )),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int mode, String text, bool isDark) {
    bool isSelected = filterMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (filterMode != mode) {
            filterMode = mode;
            periodsBack = 0;
            _computeStatsFromCache();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: isSelected ? accentGold : Colors.transparent,
              borderRadius: BorderRadius.circular(18)),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white54 : Colors.black54))),
        ),
      ),
    );
  }

  // ⚡ استخدام Slivers لبناء العناصر المرئية فقط على الشاشة بدون أي تقطيع
  List<Widget> _buildCategorySlivers(
      String title,
      List<Map<String, dynamic>> stats,
      bool isDark,
      IconData icon,
      Color color) {
    if (stats.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 12, 25, 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: isDark ? Colors.white : primaryColor,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo')),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return _buildModernStudentCard(
                  stats[index], index, isDark, title);
            },
            childCount: stats.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildSummaryItem(String title, String value, IconData icon,
      Color color, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(title,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : primaryColor,
                fontFamily: 'Cairo')),
      ],
    );
  }

  Widget _buildModernStudentCard(Map<String, dynamic> stat, int index,
      bool isDark, String categoryTitle) {
    bool isCompleted = stat['isCompleted'] == true;
    int pages = (stat['pages'] as int?) ?? 0;
    int reviewPages = (stat['reviewPages'] as int?) ?? 0;
    int absentCount = (stat['absentCount'] as int?) ?? 0;
    String imageUrl = (stat['imageUrl'] ?? '').toString();
    String studentName = (stat['name'] ?? '').toString();
    String firstLetter =
        studentName.isNotEmpty ? studentName.trim().substring(0, 1) : "?";

    Color rankColor = Colors.transparent;

    bool isTopThree = ((!isCompleted && (pages + reviewPages) > 0) ||
            (isCompleted && reviewPages > 0)) &&
        index < 3;

    if (isTopThree) {
      if (index == 0) rankColor = const Color(0xFFFFD700);
      if (index == 1) rankColor = const Color(0xFFC0C0C0);
      if (index == 2) rankColor = const Color(0xFFCD7F32);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: isTopThree
                ? rankColor.withOpacity(0.7)
                : (isDark
                    ? Colors.white12
                    : accentGold.withOpacity(0.35)),
            width: isTopThree ? 1.8 : 1.1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? Colors.white10
                        : primaryColor.withOpacity(0.1),
                    border: Border.all(
                        color: isTopThree
                            ? rankColor
                            : accentGold.withOpacity(0.4),
                        width: isTopThree ? 2.2 : 1.4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            memCacheWidth: 120,
                            memCacheHeight: 120,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Center(
                                child: Text(firstLetter,
                                    style: TextStyle(
                                        color: isDark
                                            ? accentGold
                                            : primaryColor,
                                        fontWeight: FontWeight.bold))),
                            errorWidget: (c, u, e) => Center(
                                child: Text(firstLetter,
                                    style: TextStyle(
                                        color: isDark
                                            ? accentGold
                                            : primaryColor,
                                        fontWeight: FontWeight.bold))))
                        : Center(
                            child: Text(firstLetter,
                                style: TextStyle(
                                    color:
                                        isDark ? accentGold : primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    fontFamily: 'Cairo'))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                              color: isDark ? Colors.white : Colors.black87,
                              fontFamily: 'Cairo')),
                      if (isCompleted)
                        Text("خاتم للمصحف 👑",
                            style: TextStyle(
                                fontSize: 11.5,
                                color: accentGold,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo')),
                    ],
                  ),
                ),
                // 📤 زر معاينة ومشاركة بطاقة الطالب كصورة لأهله
                InkWell(
                  onTap: () =>
                      _showStudentSharePreview(stat, index, categoryTitle),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xff25D366).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xff25D366).withOpacity(0.45),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.share_rounded,
                          size: 15,
                          color: Color(0xff128C7E),
                        ),
                        SizedBox(width: 4),
                        Text(
                          "مشاركة",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff128C7E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isTopThree)
                  Text(index == 0 ? "🥇" : (index == 1 ? "🥈" : "🥉"),
                      style: const TextStyle(fontSize: 22))
                else
                  Text("#${index + 1}",
                      style: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black26,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isCompleted)
                  Expanded(
                      child: _buildGradientStatBox("الحفظ", "$pages ص",
                          Colors.green, Icons.menu_book_rounded, pages > 0, isDark)),
                if (!isCompleted) const SizedBox(width: 8),
                Expanded(
                    child: _buildGradientStatBox(
                        "المراجعة",
                        "$reviewPages ص",
                        Colors.blueAccent,
                        Icons.loop_rounded,
                        reviewPages > 0,
                        isDark)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildGradientStatBox(
                        "الغياب",
                        "$absentCount ي",
                        Colors.redAccent,
                        Icons.person_off_rounded,
                        absentCount > 0,
                        isDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientStatBox(String title, String value, Color color,
      IconData icon, bool hasValue, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      decoration: BoxDecoration(
        color: hasValue
            ? color.withOpacity(isDark ? 0.16 : 0.11)
            : Colors.grey.withOpacity(isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: hasValue
                ? color.withOpacity(0.3)
                : Colors.grey.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: hasValue ? color : Colors.blueGrey,
                  fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}

// 🎴 نافذة معاينة بطاقة الطالب ومشاركتها كصورة عالية الدقة
class _StudentShareCardDialog extends StatefulWidget {
  final Map<String, dynamic> stat;
  final int index;
  final String categoryTitle;
  final String modeLabel;
  final String periodLabel;
  final String cycleName;
  final Color primaryColor;
  final Color accentGold;

  const _StudentShareCardDialog({
    required this.stat,
    required this.index,
    required this.categoryTitle,
    required this.modeLabel,
    required this.periodLabel,
    required this.cycleName,
    required this.primaryColor,
    required this.accentGold,
  });

  @override
  State<_StudentShareCardDialog> createState() => _StudentShareCardDialogState();
}

class _StudentShareCardDialogState extends State<_StudentShareCardDialog> {
  final GlobalKey _previewKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareAsImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      await Future.delayed(const Duration(milliseconds: 30));
      RenderRepaintBoundary? boundary =
          _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 2.2);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      Uint8List pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final safeName = (widget.stat['name'] ?? 'student')
          .toString()
          .replaceAll(RegExp(r'[^\w\u0600-\u06FF]+'), '_');
      final String filePath =
          '${directory.path}/بطاقة_${safeName}_${DateTime.now().millisecondsSinceEpoch}.png';

      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      final String studentName = (widget.stat['name'] ?? '').toString();
      await Share.shareXFiles(
        [XFile(filePath)],
        text: "📊 ${widget.modeLabel} للطالب: $studentName (${widget.periodLabel})",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              "تعذر مشاركة الصورة: $e",
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCompleted = widget.stat['isCompleted'] == true;
    int pages = (widget.stat['pages'] as int?) ?? 0;
    int reviewPages = (widget.stat['reviewPages'] as int?) ?? 0;
    int absentCount = (widget.stat['absentCount'] as int?) ?? 0;
    int sessionsCount = (widget.stat['sessionsCount'] as int?) ?? 0;
    String studentName = (widget.stat['name'] ?? 'طالب').toString();
    String imageUrl = (widget.stat['imageUrl'] ?? '').toString();
    String firstLetter =
        studentName.isNotEmpty ? studentName.trim().substring(0, 1) : "?";

    bool isTopThree = ((!isCompleted && (pages + reviewPages) > 0) ||
            (isCompleted && reviewPages > 0)) &&
        widget.index < 3;

    String rankText = isTopThree
        ? (widget.index == 0
            ? "المركز الأول 🥇"
            : (widget.index == 1 ? "المركز الثاني 🥈" : "المركز الثالث 🥉"))
        : "الترتيب #${widget.index + 1}";

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "معاينة بطاقة الطالب",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),

            // 🖼️ البطاقة التي ستتحول إلى صورة
            RepaintBoundary(
              key: _previewKey,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: widget.accentGold, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.primaryColor,
                            const Color(0xff2b3e50),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: widget.accentGold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: widget.accentGold.withOpacity(0.6),
                                  ),
                                ),
                                child: Text(
                                  widget.modeLabel,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: widget.accentGold,
                                  ),
                                ),
                              ),
                              if (widget.cycleName.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    widget.cycleName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                  color: widget.accentGold, width: 2.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Center(
                                        child: Text(
                                          firstLetter,
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: widget.primaryColor,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        firstLetter,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: widget.primaryColor,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            studentName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${widget.categoryTitle} • $rankText",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: widget.accentGold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      color: widget.accentGold.withOpacity(0.14),
                      child: Text(
                        "الفترة: ${widget.periodLabel}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.primaryColor,
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              if (!isCompleted) ...[
                                Expanded(
                                  child: _buildCardStatTile(
                                    "الحفظ",
                                    "$pages صفحة",
                                    Icons.menu_book_rounded,
                                    Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: _buildCardStatTile(
                                  "المراجعة",
                                  "$reviewPages صفحة",
                                  Icons.loop_rounded,
                                  Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCardStatTile(
                                  "أيام الحضور",
                                  "$sessionsCount يوم",
                                  Icons.check_circle_rounded,
                                  Colors.teal,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildCardStatTile(
                                  "أيام الغياب",
                                  "$absentCount يوم",
                                  Icons.person_off_rounded,
                                  Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xfff8fafc),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: widget.accentGold.withOpacity(0.4)),
                            ),
                            child: Text(
                              absentCount == 0 && (pages + reviewPages) > 0
                                  ? "ما شاء الله، التزام وحفظ متميز! بارك الله فيكم 🌟"
                                  : "نسأل الله للطالب دوام التوفيق والبركة في الحفظ 🌿",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: widget.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _isSharing ? null : _shareAsImage,
                icon: _isSharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _isSharing
                      ? "جاري تجهيز الصورة..."
                      : "مشاركة الصورة (واتساب)",
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardStatTile(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}