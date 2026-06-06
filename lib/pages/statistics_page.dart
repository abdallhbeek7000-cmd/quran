import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/theme_provider.dart';
import '../services/cycle_service.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  bool isMonthly = false; 
  bool isLoading = true;
  List<Map<String, dynamic>> studentsStats = [];
  
  int periodsBack = 0; 
  String currentPeriodLabel = "";

  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _bgAnimation = Tween<double>(begin: -10, end: 20).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine)
    );

    _calculateStats();
  }

  @override
  void dispose() {
    _bgController.dispose(); 
    super.dispose();
  }

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

  bool _isDateInRange(String dateStr, DateTime start, DateTime end) {
    DateTime? d = _parseDate(dateStr);
    if (d == null) return false;
    return d.isAfter(start.subtract(const Duration(seconds: 1))) && 
           d.isBefore(end.add(const Duration(seconds: 1)));
  }

  int _getMinNumber(String? text) {
    if (text == null || text.trim().isEmpty) return -1;
    var matches = RegExp(r'\d+').allMatches(text);
    if (matches.isEmpty) return -1;
    return matches.map((m) => int.parse(m.group(0)!)).reduce((a, b) => a < b ? a : b);
  }

  int _getMaxNumber(String? text) {
    if (text == null || text.trim().isEmpty) return -1;
    var matches = RegExp(r'\d+').allMatches(text);
    if (matches.isEmpty) return -1;
    return matches.map((m) => int.parse(m.group(0)!)).reduce((a, b) => a > b ? a : b);
  }

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

      if (isMonthly) {
        targetStart = DateTime(now.year, now.month - periodsBack, 1);
        targetEnd = DateTime(now.year, now.month - periodsBack + 1, 0, 23, 59, 59);
        currentPeriodLabel = "شهر ${targetStart.month} / ${targetStart.year}";
      } else {
        int daysToSubtract = (now.weekday + 1) % 7; 
        DateTime currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
        targetStart = currentWeekStart.subtract(Duration(days: periodsBack * 7));
        targetEnd = targetStart.add(const Duration(days: 6, hours: 23, minutes: 59));
        currentPeriodLabel = "${targetStart.day}/${targetStart.month}  إلى  ${targetEnd.day}/${targetEnd.month}";
      }

      List<Map<String, dynamic>> tempStats = [];

      for (var student in studentsSnap.docs) {
        String sId = student.id;
        String sName = student['name'];
        String imageUrl = student.data().toString().contains('imageUrl') ? student['imageUrl'] ?? '' : '';
        bool isCompleted = student['studentType'] == 'completed';

        var sSessions = sessionsSnap.docs.where((doc) {
          var data = doc.data();
          if (data['studentId'] != sId) return false;
          return _isDateInRange(data['date'] ?? '', targetStart, targetEnd);
        }).map((d) => d.data()).toList();

        int sessionsCount = sSessions.where((s) => s['absent'] != true).length;
        int absentCount = sSessions.where((s) => s['absent'] == true).length;

        var validSessions = sSessions.where((s) => s['absent'] != true && s['isExam'] != true).toList();
        
        validSessions.sort((a, b) {
          DateTime? dA = _parseDate(a['date']);
          DateTime? dB = _parseDate(b['date']);
          if (dA != null && dB != null) return dA.compareTo(dB);
          return 0;
        });

        int totalPages = 0;
        int reviewPages = 0; // 🚀 متغير جديد لحساب المراجعة للخاتمين
        
        if (validSessions.isNotEmpty) {
          if (!isCompleted) {
            // حساب صفحات الحفظ للطالب العادي
            int minPage = 999999;
            int maxPage = -1;

            for (var s in validSessions) {
              int currentMin = _getMinNumber(s['newMemorization']);
              if (currentMin != -1) { minPage = currentMin; break; }
            }

            for (var s in validSessions.reversed) {
              int currentMax = _getMaxNumber(s['newMemorization']);
              if (currentMax != -1) { maxPage = currentMax; break; }
            }

            if (minPage != 999999 && maxPage != -1 && maxPage >= minPage) {
              totalPages = (maxPage - minPage) + 1; 
            }
          } else {
            // 🚀 حساب صفحات المراجعة للطالب الخاتم من حقل farReview
            int minR = 999999;
            int maxR = -1;

            for (var s in validSessions) {
              int currentMin = _getMinNumber(s['farReview']);
              if (currentMin != -1) { minR = currentMin; break; }
            }

            for (var s in validSessions.reversed) {
              int currentMax = _getMaxNumber(s['farReview']);
              if (currentMax != -1) { maxR = currentMax; break; }
            }

            if (minR != 999999 && maxR != -1 && maxR >= minR) {
              reviewPages = (maxR - minR) + 1; 
            }
          }
        }

        tempStats.add({
          'name': sName,
          'imageUrl': imageUrl,
          'pages': totalPages,
          'reviewPages': reviewPages, // 🚀 تمرير المراجعة للبطاقة
          'isCompleted': isCompleted,
          'sessionsCount': sessionsCount,
          'absentCount': absentCount,
        });
      }

      // 🚀 ترتيب البطاقات بذكاء:
      tempStats.sort((a, b) {
        if (a['isCompleted'] && !b['isCompleted']) return 1;
        if (!a['isCompleted'] && b['isCompleted']) return -1;
        
        if (!a['isCompleted'] && !b['isCompleted']) {
          // ترتيب الطلاب العاديين حسب الحفظ
          return (b['pages'] as int).compareTo(a['pages'] as int);
        } else {
          // 🚀 ترتيب الخاتمين حسب المراجعة
          return (b['reviewPages'] as int).compareTo(a['reviewPages'] as int);
        }
      });

      setState(() {
        studentsStats = tempStats;
        isLoading = false;
      });

    } catch (e) {
      print("Error in stats: $e");
      setState(() => isLoading = false);
    }
  }

  void _changePeriod(int amount) {
    setState(() {
      periodsBack += amount;
      if (periodsBack < 0) periodsBack = 0; 
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
        title: Text("لوحة الإحصائيات الشاملة 📊", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 18)),
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                  ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] 
                  : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)], 
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          
          AnimatedBuilder(
            animation: _bgAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -50 + _bgAnimation.value, 
                    right: -50 - (_bgAnimation.value / 2), 
                    child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)))
                  ),
                  Positioned(
                    bottom: 100 - _bgAnimation.value, 
                    left: -80 + _bgAnimation.value, 
                    child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)))
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
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
                                setState(() { isMonthly = false; periodsBack = 0; }); 
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
                                setState(() { isMonthly = true; periodsBack = 0; }); 
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
                        IconButton(
                          icon: Icon(Icons.chevron_right_rounded, color: isDark ? accentGold : primaryColor),
                          onPressed: () => _changePeriod(1),
                          tooltip: "السابق",
                        ),
                        Expanded(
                          child: Text(
                            currentPeriodLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 13),
                          ),
                        ),
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

                Expanded(
                  child: isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : (studentsStats.isEmpty 
                        ? Center(child: Text("لا توجد بيانات في هذه الفترة 📭", style: TextStyle(color: isDark ? Colors.white54 : primaryColor, fontFamily: 'Cairo', fontWeight: FontWeight.bold)))
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: studentsStats.length,
                            itemBuilder: (context, index) {
                              return _buildStudentStatCard(studentsStats[index], index, isDark);
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

  Widget _buildStudentStatCard(Map<String, dynamic> stat, int index, bool isDark) {
    bool isCompleted = stat['isCompleted'];
    int pages = stat['pages'];
    int reviewPages = stat['reviewPages']; // 🚀 استقبال قيمة المراجعة
    int absentCount = stat['absentCount'];
    String imageUrl = stat['imageUrl'];
    String firstLetter = stat['name'].isNotEmpty ? stat['name'].trim().substring(0, 1) : "?";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!isCompleted && pages > 0 && index < 3)
                      Container(
                        margin: const EdgeInsets.only(left: 10),
                        child: Text(
                          index == 0 ? "🥇" : (index == 1 ? "🥈" : "🥉"),
                          style: const TextStyle(fontSize: 22),
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(left: 10),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: isDark ? Colors.black26 : Colors.white54,
                          child: Text("${index + 1}", style: TextStyle(color: isDark ? Colors.white54 : primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.white10 : primaryColor.withOpacity(0.1)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (c, u) => const CircularProgressIndicator(strokeWidth: 2), errorWidget: (c, u, e) => Center(child: Text(firstLetter, style: TextStyle(color: isDark ? accentGold : primaryColor, fontWeight: FontWeight.bold))))
                            : Center(child: Text(firstLetter, style: TextStyle(color: isDark ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stat['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87, fontFamily: 'Cairo')),
                          if (isCompleted)
                            Text("خاتم للمصحف 👑", style: TextStyle(fontSize: 11, color: accentGold, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 15),
                Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                const SizedBox(height: 15),

                Row(
                  children: [
                    // 🚀 صندوق الحفظ (يظهر لغير الخاتمين)
                    if (!isCompleted)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: pages > 0 ? Colors.green.withOpacity(isDark ? 0.15 : 0.1) : Colors.blueGrey.withOpacity(isDark ? 0.15 : 0.1), 
                            borderRadius: BorderRadius.circular(15), 
                            border: Border.all(color: pages > 0 ? Colors.green.withOpacity(0.4) : Colors.blueGrey.withOpacity(0.3))
                          ),
                          child: Column(
                            children: [
                              Text("صافي الحفظ", style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                              Text("$pages صفحة", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: pages > 0 ? Colors.green : Colors.blueGrey, fontFamily: 'Cairo')),
                            ],
                          ),
                        ),
                      )
                    // 🚀 صندوق المراجعة (يظهر للخاتمين فقط)
                    else
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: reviewPages > 0 ? Colors.blueAccent.withOpacity(isDark ? 0.15 : 0.1) : Colors.blueGrey.withOpacity(isDark ? 0.15 : 0.1), 
                            borderRadius: BorderRadius.circular(15), 
                            border: Border.all(color: reviewPages > 0 ? Colors.blueAccent.withOpacity(0.4) : Colors.blueGrey.withOpacity(0.3))
                          ),
                          child: Column(
                            children: [
                              Text("مقدار المراجعة", style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                              Text("$reviewPages صفحة", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: reviewPages > 0 ? Colors.blueAccent : Colors.blueGrey, fontFamily: 'Cairo')),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(width: 10),

                    // 🚀 صندوق الغياب (يظهر للجميع)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: absentCount > 0 ? Colors.red.withOpacity(isDark ? 0.15 : 0.1) : Colors.blueGrey.withOpacity(isDark ? 0.15 : 0.1), 
                          borderRadius: BorderRadius.circular(15), 
                          border: Border.all(color: absentCount > 0 ? Colors.red.withOpacity(0.4) : Colors.blueGrey.withOpacity(0.3))
                        ),
                        child: Column(
                          children: [
                            Text("أيام الغياب", style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            Text("$absentCount يوم", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: absentCount > 0 ? Colors.redAccent : Colors.blueGrey, fontFamily: 'Cairo')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}