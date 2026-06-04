import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // تأكد من إضافة intl في pubspec.yaml إذا لزم الأمر لتنسيق أفضل
import '../services/theme_provider.dart';
import '../services/cycle_service.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  bool isMonthly = false; // false = أسبوعي, true = شهري
  bool isLoading = true;
  List<Map<String, dynamic>> studentsStats = [];
  
  // 🚀 متغير للتحكم بالزمن (0 = الحالي، 1 = السابق، 2 = اللي قبله...)
  int periodsBack = 0; 
  String currentPeriodLabel = "";

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  // 🚀 دالة تحويل النص إلى تاريخ
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

  // 🚀 دالة فحص هل التاريخ ضمن الفترة المطلوبة
  bool _isDateInRange(String dateStr, DateTime start, DateTime end) {
    DateTime? d = _parseDate(dateStr);
    if (d == null) return false;
    return d.isAfter(start.subtract(const Duration(seconds: 1))) && 
           d.isBefore(end.add(const Duration(seconds: 1)));
  }

  // 🚀 دالة استخراج أصغر رقم من النص
  int _getMinNumber(String? text) {
    if (text == null || text.trim().isEmpty) return -1;
    var matches = RegExp(r'\d+').allMatches(text);
    if (matches.isEmpty) return -1;
    return matches.map((m) => int.parse(m.group(0)!)).reduce((a, b) => a < b ? a : b);
  }

  // 🚀 دالة استخراج أكبر رقم من النص
  int _getMaxNumber(String? text) {
    if (text == null || text.trim().isEmpty) return -1;
    var matches = RegExp(r'\d+').allMatches(text);
    if (matches.isEmpty) return -1;
    return matches.map((m) => int.parse(m.group(0)!)).reduce((a, b) => a > b ? a : b);
  }

  // 🚀 المحرك الأساسي للإحصائيات 
  Future<void> _calculateStats() async {
    setState(() => isLoading = true);
    
    try {
      final cycle = await CycleService().getCurrentCycle();
      if (cycle == null) {
        setState(() => isLoading = false);
        return;
      }

      final studentsSnap = await FirebaseFirestore.instance.collection('students').where('cycleId', isEqualTo: cycle.id).get();
      final sessionsSnap = await FirebaseFirestore.instance.collection('sessions').get();

      DateTime now = DateTime.now();
      DateTime targetStart;
      DateTime targetEnd;

      // 🎯 حساب تواريخ الأسبوع والشهر مع ميزة (العودة بالزمن)
      if (isMonthly) {
        targetStart = DateTime(now.year, now.month - periodsBack, 1);
        targetEnd = DateTime(now.year, now.month - periodsBack + 1, 0, 23, 59, 59);
        currentPeriodLabel = "شهر ${targetStart.month} / ${targetStart.year}";
      } else {
        int daysToSubtract = (now.weekday + 1) % 7; // السبت هو بداية الأسبوع
        DateTime currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
        targetStart = currentWeekStart.subtract(Duration(days: periodsBack * 7));
        targetEnd = targetStart.add(const Duration(days: 6, hours: 23, minutes: 59));
        currentPeriodLabel = "${targetStart.day}/${targetStart.month}  إلى  ${targetEnd.day}/${targetEnd.month}";
      }

      List<Map<String, dynamic>> tempStats = [];

      for (var student in studentsSnap.docs) {
        String sId = student.id;
        String sName = student['name'];
        bool isCompleted = student['studentType'] == 'completed';

        var sSessions = sessionsSnap.docs.where((doc) {
          var data = doc.data();
          if (data['studentId'] != sId) return false;
          if (data['absent'] == true || data['isExam'] == true) return false; 
          return _isDateInRange(data['date'] ?? '', targetStart, targetEnd);
        }).map((d) => d.data()).toList();

        sSessions.sort((a, b) {
          DateTime? dA = _parseDate(a['date']);
          DateTime? dB = _parseDate(b['date']);
          if (dA != null && dB != null) return dA.compareTo(dB);
          return 0;
        });

        int minPage = 999999;
        int maxPage = -1;

        for (var s in sSessions) {
          int currentMin = _getMinNumber(s['newMemorization']);
          if (currentMin != -1) {
            minPage = currentMin;
            break; 
          }
        }

        for (var s in sSessions.reversed) {
          int currentMax = _getMaxNumber(s['newMemorization']);
          if (currentMax != -1) {
            maxPage = currentMax;
            break; 
          }
        }

        int totalPages = 0;
        if (minPage != 999999 && maxPage != -1 && maxPage >= minPage) {
          totalPages = (maxPage - minPage) + 1; 
        }

        tempStats.add({
          'name': sName,
          'pages': totalPages,
          'isCompleted': isCompleted,
          'sessionsCount': sSessions.length, 
        });
      }

      tempStats.sort((a, b) => (b['pages'] as int).compareTo(a['pages'] as int));

      setState(() {
        studentsStats = tempStats;
        isLoading = false;
      });

    } catch (e) {
      print("Error in stats: $e");
      setState(() => isLoading = false);
    }
  }

  // 🚀 تغيير الفترة (العودة للوراء أو التقدم للأمام)
  void _changePeriod(int amount) {
    setState(() {
      periodsBack += amount;
      if (periodsBack < 0) periodsBack = 0; // لا يمكن الذهاب للمستقبل
    });
    _calculateStats();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text("لوحة قياس الأداء 📊", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 18)),
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)], 
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(top: -50, right: -50, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)))),
          Positioned(bottom: 100, left: -80, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)))),

          SafeArea(
            child: Column(
              children: [
                // 🚀 أزرار التبديل (أسبوعي / شهري)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (isMonthly) {
                                setState(() { isMonthly = false; periodsBack = 0; }); // تصفير العداد عند التبديل
                                _calculateStats();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isMonthly ? accentGold : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text("أسبوعي", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: !isMonthly ? Colors.white : (isDark ? Colors.white54 : Colors.black54))),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!isMonthly) {
                                setState(() { isMonthly = true; periodsBack = 0; }); // تصفير العداد عند التبديل
                                _calculateStats();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isMonthly ? accentGold : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text("شهري", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isMonthly ? Colors.white : (isDark ? Colors.white54 : Colors.black54))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 🚀 شريط التحكم بالزمن (Time Navigator)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.white70),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // زر للعودة للماضي (سهم يمين لأن العربي من اليمين لليسار)
                        IconButton(
                          icon: Icon(Icons.chevron_right_rounded, color: isDark ? accentGold : primaryColor),
                          onPressed: () => _changePeriod(1),
                          tooltip: "السابق",
                        ),
                        
                        // اسم الفترة
                        Expanded(
                          child: Text(
                            currentPeriodLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 13),
                          ),
                        ),

                        // زر للتقدم للحاضر (مخفي إذا كنا بالوقت الحالي)
                        IconButton(
                          icon: Icon(Icons.chevron_left_rounded, color: periodsBack > 0 ? (isDark ? accentGold : primaryColor) : Colors.transparent),
                          onPressed: periodsBack > 0 ? () => _changePeriod(-1) : null,
                          tooltip: "التالي",
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 🚀 عرض القائمة مع الترتيب الفخم
                Expanded(
                  child: isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : (studentsStats.isEmpty 
                        ? Center(child: Text("لا توجد جلسات في هذه الفترة 📭", style: TextStyle(color: isDark ? Colors.white54 : primaryColor, fontFamily: 'Cairo', fontWeight: FontWeight.bold)))
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: studentsStats.length,
                            itemBuilder: (context, index) {
                              var stat = studentsStats[index];
                              bool hasDoneSomething = stat['pages'] > 0;
                              
                              // 🚀 تصميم ديناميكي للأوائل
                              Color borderColor = isDark ? Colors.white12 : Colors.white;
                              Color bgColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5);
                              Widget? rankBadge;

                              if (hasDoneSomething) {
                                if (index == 0) { // المركز الأول
                                  borderColor = const Color(0xFFFFD700); // ذهبي
                                  bgColor = const Color(0xFFFFD700).withOpacity(isDark ? 0.1 : 0.15);
                                  rankBadge = const Text("🥇", style: TextStyle(fontSize: 22));
                                } else if (index == 1) { // المركز الثاني
                                  borderColor = const Color(0xFFC0C0C0); // فضي
                                  bgColor = const Color(0xFFC0C0C0).withOpacity(isDark ? 0.1 : 0.15);
                                  rankBadge = const Text("🥈", style: TextStyle(fontSize: 22));
                                } else if (index == 2) { // المركز الثالث
                                  borderColor = const Color(0xFFCD7F32); // برونزي
                                  bgColor = const Color(0xFFCD7F32).withOpacity(isDark ? 0.1 : 0.15);
                                  rankBadge = const Text("🥉", style: TextStyle(fontSize: 22));
                                }
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: borderColor, width: index < 3 && hasDoneSomething ? 2.0 : 1.2),
                                      ),
                                      child: Row(
                                        children: [
                                          // الشارة أو الرقم
                                          SizedBox(
                                            width: 40,
                                            child: Center(
                                              child: rankBadge ?? CircleAvatar(
                                                radius: 14,
                                                backgroundColor: isDark ? Colors.black26 : Colors.white54,
                                                child: Text("${index + 1}", style: TextStyle(color: isDark ? Colors.white54 : primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          
                                          // الاسم والتفاصيل
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  stat['name'], 
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontFamily: 'Cairo')
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  "أيام الحضور الفعلي: ${stat['sessionsCount']}", 
                                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54, fontFamily: 'Cairo', fontWeight: FontWeight.w600)
                                                ),
                                              ],
                                            ),
                                          ),

                                          // النتيجة الصافية
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: hasDoneSomething ? Colors.green.withOpacity(isDark ? 0.15 : 0.1) : Colors.red.withOpacity(isDark ? 0.15 : 0.1),
                                              borderRadius: BorderRadius.circular(15),
                                              border: Border.all(color: hasDoneSomething ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4)),
                                            ),
                                            child: Column(
                                              children: [
                                                Text("صافي الحفظ", style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                                Text(
                                                  "${stat['pages']}", 
                                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: hasDoneSomething ? Colors.green : Colors.redAccent)
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
                          )
                      ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}