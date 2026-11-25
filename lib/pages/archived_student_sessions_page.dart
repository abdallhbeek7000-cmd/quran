import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'archived_student_detail_sessions_page.dart';

class ArchivedStudentSessionsPage extends StatefulWidget {
  const ArchivedStudentSessionsPage({super.key});

  @override
  State<ArchivedStudentSessionsPage> createState() => _ArchivedStudentSessionsPageState();
}

class _ArchivedStudentSessionsPageState extends State<ArchivedStudentSessionsPage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color deepNavy = const Color(0xff0f172a);
  final Color accentGold = const Color(0xffd4af37);
  final Color softGold = const Color(0xffccb273);
  final Color emeraldGreen = const Color(0xff16a34a);
  final Color crimsonRed = const Color(0xffef4444);

  // 🎯 حل مشكلة اختفاء الكيبورد: استخدام ValueNotifier و FocusNode مستقلين
  final ValueNotifier<String> _searchNotifier = ValueNotifier<String>('');
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff090d16) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
        title: Column(
          children: [
            Text(
              "أرشيف جلسات الطلاب",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : primaryColor,
                fontFamily: 'Cairo',
                fontSize: 18.5,
              ),
            ),
            Text(
              "سجل الحضور والمتابعة حسب الدورات",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? softGold : primaryColor.withOpacity(0.68),
                fontFamily: 'Cairo',
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 🌌 خلفية متدرجة ثابتة وسريعة الأداء
          RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xff090d16), const Color(0xff111b2e), const Color(0xff0b1120)]
                      : [const Color(0xfff4f7fb), const Color(0xffe9eff6), const Color(0xfff7f2e4)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),
          ),

          Positioned(
            top: -55,
            right: -55,
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(isDark ? 0.20 : 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -75,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentGold.withOpacity(isDark ? 0.09 : 0.13),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // 🔍 شريط البحث الذكي مع الحفاظ الكامل على تركيز الكيبورد
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff141e30).withOpacity(0.92) : Colors.white.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: accentGold.withOpacity(isDark ? 0.35 : 0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(isDark ? 0.24 : 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : deepNavy,
                      ),
                      onChanged: (val) {
                        _searchNotifier.value = val.trim().toLowerCase();
                      },
                      decoration: InputDecoration(
                        hintText: "ابحث باسم الطالب أو بالرقم التسلسلي...",
                        hintStyle: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.search_rounded, color: accentGold, size: 21),
                        ),
                        suffixIcon: ValueListenableBuilder<String>(
                          valueListenable: _searchNotifier,
                          builder: (context, query, child) {
                            if (query.isEmpty) return const SizedBox.shrink();
                            return IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 19,
                                color: isDark ? Colors.white60 : primaryColor,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _searchNotifier.value = '';
                              },
                            );
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 📑 محتوى الدورات والتبويبات
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('cycles').snapshots(),
                    builder: (context, cycleSnap) {
                      if (cycleSnap.connectionState == ConnectionState.waiting && !cycleSnap.hasData) {
                        return Center(
                          child: CircularProgressIndicator(color: accentGold, strokeWidth: 2.5),
                        );
                      }

                      if (!cycleSnap.hasData || cycleSnap.data!.docs.isEmpty) {
                        return _buildEmptyState(isDark, "لا توجد دورات مسجلة في النظام حالياً");
                      }

                      var cycleDocs = cycleSnap.data!.docs.toList();

                      // ترتيب الدورات
                      cycleDocs.sort((a, b) {
                        var dataA = a.data() as Map<String, dynamic>;
                        var dataB = b.data() as Map<String, dynamic>;
                        int numA = int.tryParse(dataA['cycleNumber']?.toString() ?? '1') ?? 1;
                        int numB = int.tryParse(dataB['cycleNumber']?.toString() ?? '1') ?? 1;
                        return numA.compareTo(numB);
                      });

                      String firstCycleId = cycleDocs.first.id;

                      return DefaultTabController(
                        length: cycleDocs.length,
                        child: Column(
                          children: [
                            // 📑 شريط الدورات الأنيق
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xff131d2e).withOpacity(0.88) : Colors.white.withOpacity(0.84),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isDark ? Colors.white12 : accentGold.withOpacity(0.32),
                                    width: 1.1,
                                  ),
                                ),
                                child: TabBar(
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  dividerColor: Colors.transparent,
                                  physics: const ClampingScrollPhysics(),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  indicator: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isDark
                                          ? [accentGold, const Color(0xffb8921e)]
                                          : [primaryColor, const Color(0xff2d4154)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isDark ? accentGold : primaryColor).withOpacity(0.24),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  labelColor: isDark ? deepNavy : Colors.white,
                                  unselectedLabelColor: isDark ? Colors.white.withOpacity(0.65) : primaryColor.withOpacity(0.75),
                                  labelStyle: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  tabs: cycleDocs.map((doc) {
                                    var data = doc.data() as Map<String, dynamic>;
                                    String cycleName = data['name'] ?? 'دورة بدون اسم';
                                    bool isClosed = data['isClosed'] == true || data['archived'] == true;
                                    return Tab(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isClosed ? Icons.inventory_2_rounded : Icons.auto_awesome_rounded,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(cycleName),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // 📇 قائمة عرض الطلاب
                            Expanded(
                              child: TabBarView(
                                physics: const ClampingScrollPhysics(),
                                children: cycleDocs.map((cycleDoc) {
                                  var data = cycleDoc.data() as Map<String, dynamic>;
                                  String cycleName = data['name'] ?? 'دورة بدون اسم';
                                  bool isFirstCycle = (cycleDoc.id == firstCycleId);

                                  return CycleStudentsTabContent(
                                    cycleId: cycleDoc.id,
                                    cycleName: cycleName,
                                    isFirstCycle: isFirstCycle,
                                    searchNotifier: _searchNotifier,
                                    isDark: isDark,
                                    primaryColor: primaryColor,
                                    deepNavy: deepNavy,
                                    accentGold: accentGold,
                                    emeraldGreen: emeraldGreen,
                                    crimsonRed: crimsonRed,
                                  );
                                }).toList(),
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
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: accentGold.withOpacity(0.45), width: 1.2),
            ),
            child: Icon(Icons.auto_stories_rounded, size: 52, color: accentGold),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: isDark ? Colors.white70 : primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// 📦 ودجت التبويب المستقل للطلاب لتحديث البحث بسلاسة
class CycleStudentsTabContent extends StatelessWidget {
  final String cycleId;
  final String cycleName;
  final bool isFirstCycle;
  final ValueNotifier<String> searchNotifier;
  final bool isDark;
  final Color primaryColor;
  final Color deepNavy;
  final Color accentGold;
  final Color emeraldGreen;
  final Color crimsonRed;

  const CycleStudentsTabContent({
    super.key,
    required this.cycleId,
    required this.cycleName,
    required this.isFirstCycle,
    required this.searchNotifier,
    required this.isDark,
    required this.primaryColor,
    required this.deepNavy,
    required this.accentGold,
    required this.emeraldGreen,
    required this.crimsonRed,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').snapshots(),
      builder: (context, studentSnap) {
        if (studentSnap.connectionState == ConnectionState.waiting && !studentSnap.hasData) {
          return Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 2.5));
        }

        // 🎯 قراءة حقل serial الصحيح من قاعدة البيانات
        Map<String, Map<String, dynamic>> studentsMetaMap = {};
        if (studentSnap.hasData) {
          for (var sDoc in studentSnap.data!.docs) {
            var sData = sDoc.data() as Map<String, dynamic>;
            studentsMetaMap[sDoc.id] = {
              'imageUrl': sData['imageUrl'] ?? sData['photoUrl'] ?? sData['image'] ?? '',
              'serial': int.tryParse(sData['serial']?.toString() ?? '') ?? 999999,
            };
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
          builder: (context, sessionSnap) {
            if (sessionSnap.connectionState == ConnectionState.waiting && !sessionSnap.hasData) {
              return Center(child: CircularProgressIndicator(color: accentGold, strokeWidth: 2.5));
            }

            if (!sessionSnap.hasData || sessionSnap.data!.docs.isEmpty) {
              return _buildEmptyState("لا توجد جلسات مسجلة في هذه الدورة");
            }

            var docs = sessionSnap.data!.docs;

            return ValueListenableBuilder<String>(
              valueListenable: searchNotifier,
              builder: (context, searchQuery, child) {
                Map<String, Map<String, dynamic>> studentDataMap = {};

                for (var doc in docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  String studentName = data['studentName'] ?? 'طالب مجهول';
                  String studentId = data['studentId'] ?? '';
                  String? docCycleId = data['cycleId'];

                  bool belongsToThisCycle = isFirstCycle
                      ? (docCycleId == null || docCycleId.isEmpty || docCycleId == cycleId)
                      : (docCycleId == cycleId);

                  if (!belongsToThisCycle) continue;

                  var meta = studentsMetaMap[studentId] ?? {};
                  int serialNum = meta['serial'] ?? 999999;
                  String serialStr = serialNum != 999999 ? serialNum.toString() : '';

                  // تصفية البحث
                  if (searchQuery.isNotEmpty &&
                      !studentName.toLowerCase().contains(searchQuery) &&
                      !serialStr.contains(searchQuery)) {
                    continue;
                  }

                  if (!studentDataMap.containsKey(studentName)) {
                    studentDataMap[studentName] = {
                      'studentId': studentId,
                      'studentName': studentName,
                      'imageUrl': meta['imageUrl'] ?? '',
                      'serial': serialNum,
                      'totalSessions': 0,
                      'absentCount': 0,
                      'presentCount': 0,
                    };
                  }

                  studentDataMap[studentName]!['totalSessions'] += 1;
                  if (data['absent'] == true) {
                    studentDataMap[studentName]!['absentCount'] += 1;
                  } else {
                    studentDataMap[studentName]!['presentCount'] += 1;
                  }
                }

                if (studentDataMap.isEmpty) {
                  return _buildEmptyState("لا توجد نتائج مطابقة لبحثك في هذه الدورة");
                }

                List<Map<String, dynamic>> studentsList =
                  studentDataMap.values.toList();

                // 🔢 **الفرز حسب الرقم التسلسلي (serial) بصرامة**
                studentsList.sort((a, b) {
                  int serialA = a['serial'] ?? 999999;
                  int serialB = b['serial'] ?? 999999;
                  if (serialA != serialB) {
                    return serialA.compareTo(serialB);
                  }
                  return (a['studentName'] as String).compareTo(b['studentName'] as String);
                });

                return ListView.builder(
                  physics: const ClampingScrollPhysics(),
                  cacheExtent: 500,
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                  itemCount: studentsList.length,
                  itemBuilder: (context, index) {
                    var student = studentsList[index];
                    String imageUrl = student['imageUrl'] ?? '';
                    int serialNumber = student['serial'];
                    int total = student['totalSessions'] ?? 0;
                    int present = student['presentCount'] ?? 0;
                    int absent = student['absentCount'] ?? 0;
                    double attendanceRatio = total > 0 ? (present / total).clamp(0.0, 1.0) : 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: isDark
                            ? const Color(0xff141e30).withOpacity(0.90)
                            : Colors.white.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ArchivedStudentDetailSessionsPage(
                                  studentId: student['studentId'],
                                  studentName: student['studentName'],
                                  cycleId: cycleId,
                                  cycleName: cycleName,
                                  isFirstCycle: isFirstCycle,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.11)
                                    : accentGold.withOpacity(0.32),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(isDark ? 0.22 : 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
                                  child: Row(
                                    children: [
                                      // 🖼 صورة الطالب بإطار ذهبي/كحلي أنيق
                                      Container(
                                        padding: const EdgeInsets.all(2.5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [accentGold, primaryColor],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 26,
                                          backgroundColor: isDark ? deepNavy : Colors.white,
                                          backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                                          child: imageUrl.isEmpty
                                              ? Text(
                                                  (student['studentName'] as String).isNotEmpty
                                                      ? (student['studentName'] as String).characters.first
                                                      : 'ط',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 18,
                                                    color: isDark ? accentGold : primaryColor,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),

                                      const SizedBox(width: 13),

                                      // 📝 الاسم والرقم التسلسلي والإحصاءات
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                if (serialNumber != 999999) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: accentGold.withOpacity(isDark ? 0.2 : 0.16),
                                                      borderRadius: BorderRadius.circular(9),
                                                      border: Border.all(
                                                        color: accentGold.withOpacity(0.55),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "#$serialNumber",
                                                      style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: isDark ? accentGold : primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    student['studentName'],
                                                    style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 15,
                                                      color: isDark ? Colors.white : deepNavy,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 5,
                                              children: [
                                                _buildStatPill(
                                                  icon: Icons.layers_rounded,
                                                  label: "الجلسات: $total",
                                                  color: isDark ? const Color(0xff93c5fd) : primaryColor,
                                                ),
                                                _buildStatPill(
                                                  icon: Icons.check_circle_rounded,
                                                  label: "حضور: $present",
                                                  color: emeraldGreen,
                                                ),
                                                if (absent > 0)
                                                  _buildStatPill(
                                                    icon: Icons.cancel_rounded,
                                                    label: "غياب: $absent",
                                                    color: crimsonRed,
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // 🚀 زر فتح التفاصيل
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? accentGold.withOpacity(0.14)
                                              : primaryColor.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: accentGold.withOpacity(0.35),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: isDark ? accentGold : primaryColor,
                                          size: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 📊 شريط نسبة حضور رفيع وأنيق أسفل البطاقة
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(99),
                                          child: LinearProgressIndicator(
                                            value: attendanceRatio,
                                            minHeight: 5,
                                            backgroundColor: isDark
                                                ? Colors.white.withOpacity(0.08)
                                                : primaryColor.withOpacity(0.09),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              attendanceRatio >= 0.75
                                                  ? emeraldGreen
                                                  : (attendanceRatio >= 0.5 ? accentGold : crimsonRed),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        "${(attendanceRatio * 100).round()}% حضور",
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.28), width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: accentGold.withOpacity(0.45), width: 1.2),
            ),
            child: Icon(Icons.folder_open_rounded, size: 52, color: accentGold),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.5,
              color: isDark ? Colors.white70 : primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}