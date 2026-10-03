import 'dart:ui';
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

class _ArchivedStudentSessionsPageState extends State<ArchivedStudentSessionsPage> with SingleTickerProviderStateMixin {
  final Color primaryNavy = const Color(0xff0f172a);
  final Color accentGold = const Color(0xffd4af37);
  final Color neonCyan = const Color(0xff06b6d4);
  final Color softBlue = const Color(0xff3b82f6);

  // 🎯 حل مشكلة اختفاء الكيبورد: استخدام ValueNotifier و FocusNode مستقلين
  final ValueNotifier<String> _searchNotifier = ValueNotifier<String>('');
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: -15, end: 25).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchNotifier.dispose();
    _bgController.dispose();
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
        title: Text(
          "أرشيف جلسات الطلاب 📜",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xff1e293b),
            fontFamily: 'Cairo',
            fontSize: 19,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xff1e293b)),
      ),
      body: Stack(
        children: [
          // 🌌 خلفية متدرجة زجاجية متحركة
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xff090d16), const Color(0xff0f172a), const Color(0xff1e293b)]
                    : [const Color(0xfff8fafc), const Color(0xffe2e8f0), const Color(0xffcbd5e1)],
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
                    top: -40 + _bgAnimation.value,
                    right: -60 - (_bgAnimation.value / 2),
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? accentGold.withOpacity(0.09) : accentGold.withOpacity(0.18),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 120 - _bgAnimation.value,
                    left: -80 + _bgAnimation.value,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? neonCyan.withOpacity(0.08) : softBlue.withOpacity(0.18),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // 🔍 شريط البحث الذكي الموعد بشكل يمنع إغلاق الكيبورد نهااائياً
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? accentGold.withOpacity(0.3) : const Color(0xff1e293b).withOpacity(0.15),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
                          onChanged: (val) {
                            _searchNotifier.value = val.trim().toLowerCase();
                          },
                          decoration: InputDecoration(
                            hintText: "ابحث عن اسم طالب أو برقم...",
                            hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: Icon(Icons.search_rounded, color: isDark ? accentGold : softBlue, size: 24),
                            ),
                            suffixIcon: ValueListenableBuilder<String>(
                              valueListenable: _searchNotifier,
                              builder: (context, query, child) {
                                if (query.isEmpty) return const SizedBox.shrink();
                                return IconButton(
                                  icon: Icon(Icons.clear_rounded, color: isDark ? Colors.white54 : Colors.black54),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchNotifier.value = '';
                                  },
                                );
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 📑 محتوى الدورات والتبويبات
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('cycles').snapshots(),
                    builder: (context, cycleSnap) {
                      if (cycleSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!cycleSnap.hasData || cycleSnap.data!.docs.isEmpty) {
                        return _buildEmptyState(isDark, "لا توجد دورات مسجلة في النظام 🚫");
                      }

                      var cycleDocs = cycleSnap.data!.docs;

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
                            // 📑 شريط الدورات
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                  child: Container(
                                    height: 52,
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: isDark ? Colors.white12 : Colors.white.withOpacity(0.8)),
                                    ),
                                    child: TabBar(
                                      isScrollable: true,
                                      physics: const BouncingScrollPhysics(),
                                      indicator: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isDark ? [accentGold, Colors.amber.shade700] : [softBlue, const Color(0xff1d4ed8)],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isDark ? accentGold : softBlue).withOpacity(0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          )
                                        ],
                                      ),
                                      labelColor: Colors.white,
                                      unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                                      labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                                      tabs: cycleDocs.map((doc) {
                                        var data = doc.data() as Map<String, dynamic>;
                                        String cycleName = data['name'] ?? 'دورة بدون اسم';
                                        bool isClosed = data['isClosed'] == true || data['archived'] == true;
                                        return Tab(
                                          child: Row(
                                            children: [
                                              Icon(
                                                isClosed ? Icons.lock_outline_rounded : Icons.star_rounded,
                                                size: 15,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(cycleName),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // 📇 قائمة عرض الطلاب
                            Expanded(
                              child: TabBarView(
                                physics: const BouncingScrollPhysics(),
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
                                    accentGold: accentGold,
                                    softBlue: softBlue,
                                    neonCyan: neonCyan,
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (isDark ? accentGold : softBlue).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_toggle_off_rounded, size: 55, color: isDark ? accentGold : softBlue),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.bold),
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
  final Color accentGold;
  final Color softBlue;
  final Color neonCyan;

  const CycleStudentsTabContent({
    super.key,
    required this.cycleId,
    required this.cycleName,
    required this.isFirstCycle,
    required this.searchNotifier,
    required this.isDark,
    required this.accentGold,
    required this.softBlue,
    required this.neonCyan,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').snapshots(),
      builder: (context, studentSnap) {
        if (studentSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
            if (sessionSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!sessionSnap.hasData || sessionSnap.data!.docs.isEmpty) {
              return _buildEmptyState("لا توجد جلسات مسجلة 📁");
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
                  return _buildEmptyState("لا توجد نتائج تطابق بحثك لهذه الدورة 🔍");
                }

                List<Map<String, dynamic>> studentsList = studentDataMap.values.toList();

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
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 5, 20, 25),
                  itemCount: studentsList.length,
                  itemBuilder: (context, index) {
                    var student = studentsList[index];
                    String imageUrl = student['imageUrl'] ?? '';
                    int serialNumber = student['serial'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, anim1, anim2) => ArchivedStudentDetailSessionsPage(
                                studentId: student['studentId'],
                                studentName: student['studentName'],
                                cycleId: cycleId,
                                cycleName: cycleName,
                                isFirstCycle: isFirstCycle,
                              ),
                              transitionsBuilder: (context, anim1, anim2, child) => FadeTransition(opacity: anim1, child: child),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(26),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.85),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.04),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  // 🖼️️ صورة الطالب
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: isDark ? [accentGold, softBlue] : [softBlue, neonCyan],
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 26,
                                      backgroundColor: isDark ? const Color(0xff0f172a) : Colors.white,
                                      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                                      child: imageUrl.isEmpty
                                          ? Icon(
                                              Icons.person_rounded,
                                              color: isDark ? accentGold : softBlue,
                                              size: 28,
                                            )
                                          : null,
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  // 📝 الاسم والرقم التسلسلي
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            // 🔢 شارة الرقم التسلسلي (serial)
                                            if (serialNumber != 999999) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: isDark
                                                        ? [accentGold.withOpacity(0.3), Colors.amber.shade900.withOpacity(0.2)]
                                                        : [softBlue.withOpacity(0.25), neonCyan.withOpacity(0.2)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: (isDark ? accentGold : softBlue).withOpacity(0.5),
                                                  ),
                                                ),
                                                child: Text(
                                                  "#$serialNumber",
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    color: isDark ? accentGold : softBlue,
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
                                                  color: isDark ? Colors.white : const Color(0xff1e293b),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            _buildPillBadge("الجلسات: ${student['totalSessions']}", isDark ? Colors.blue.shade300 : Colors.blue.shade800),
                                            _buildPillBadge("حضور: ${student['presentCount']}", Colors.green.shade600),
                                            if (student['absentCount'] > 0)
                                              _buildPillBadge("غياب: ${student['absentCount']}", Colors.red.shade600),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 🚀 سهم التنقل
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isDark ? accentGold : softBlue).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: (isDark ? accentGold : softBlue).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: isDark ? accentGold : softBlue,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildPillBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (isDark ? accentGold : softBlue).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_toggle_off_rounded, size: 55, color: isDark ? accentGold : softBlue),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}