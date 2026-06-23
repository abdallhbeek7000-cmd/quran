import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  // 🚀 وضع الفلترة: 0 = أسبوعي، 1 = شهري، 2 = كامل الدورة
  int filterMode = 0; 
  bool isLoading = true;
  
  List<Map<String, dynamic>> newStudentsStats = [];
  List<Map<String, dynamic>> oldStudentsStats = [];
  List<Map<String, dynamic>> completedStudentsStats = [];
  
  int periodsBack = 0; 
  String currentPeriodLabel = "";

  int cycleTotalPages = 0;
  int cycleTotalReview = 0;

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  @override
  void dispose() {
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

  int _calculatePagesFromText(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    
    int totalPages = 0;
    String processedText = text.replaceAll(' و ', '|');
    List<String> parts = processedText.split(RegExp(r'[|،,+]'));
    
    for (String part in parts) {
      var matches = RegExp(r'\d+').allMatches(part);
      if (matches.isEmpty) continue;

      List<int> numbers = matches.map((m) => int.parse(m.group(0)!)).toList();
      
      if (numbers.length == 1) {
        totalPages += 1; 
      } else {
        int minP = numbers.reduce((a, b) => a < b ? a : b);
        int maxP = numbers.reduce((a, b) => a > b ? a : b);

        if (maxP >= minP) {
          totalPages += (maxP - minP) + 1; 
        }
      }
    }
    
    return totalPages;
  }

  Future<void> _calculateStats() async {
    setState(() {
      isLoading = true;
      cycleTotalPages = 0;
      cycleTotalReview = 0;
      newStudentsStats.clear();
      oldStudentsStats.clear();
      completedStudentsStats.clear();
    });
    
    try {
      final cycle = await CycleService().getCurrentCycle();
      if (cycle == null) {
        setState(() => isLoading = false);
        return;
      }

      final studentsSnap = await FirebaseFirestore.instance.collection('students').where('cycleId', isEqualTo: cycle.id).get();
      final sessionsSnap = await FirebaseFirestore.instance.collection('sessions').get();

      DateTime now = DateTime.now();
      DateTime targetStart = DateTime.now();
      DateTime targetEnd = DateTime.now();

      // ضبط نطاق التواريخ بحسب الوضع المختار
      if (filterMode == 0) { // أسبوعي
        int daysToSubtract = (now.weekday + 1) % 7; 
        DateTime currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
        targetStart = currentWeekStart.subtract(Duration(days: periodsBack * 7));
        targetEnd = targetStart.add(const Duration(days: 6, hours: 23, minutes: 59));
        currentPeriodLabel = "${targetStart.day}/${targetStart.month}  إلى  ${targetEnd.day}/${targetEnd.month}";
      } else if (filterMode == 1) { // شهري
        targetStart = DateTime(now.year, now.month - periodsBack, 1);
        targetEnd = DateTime(now.year, now.month - periodsBack + 1, 0, 23, 59, 59);
        currentPeriodLabel = "شهر ${targetStart.month} / ${targetStart.year}";
      } else { // 🚀 كامل الدورة
        currentPeriodLabel = "إحصائيات الدورة التراكمية 🎯";
      }

      List<Map<String, dynamic>> tempNew = [];
      List<Map<String, dynamic>> tempOld = [];
      List<Map<String, dynamic>> tempCompleted = [];

      for (var student in studentsSnap.docs) {
        Map<String, dynamic> sData = student.data();

        bool isArchived = sData['archived'] ?? false;
        if (isArchived) continue;

        String sId = student.id;
        String sName = sData['name'];
        String imageUrl = sData.containsKey('imageUrl') ? sData['imageUrl'] ?? '' : '';
        
        String studentType = sData.containsKey('studentType') ? sData['studentType'] : 'new';
        bool isCompleted = studentType == 'completed';

        // فحص فلترة الجلسات تاريخياً بناءً على النطاق المختار أو جلبها بالكامل للدورة
        var sSessions = sessionsSnap.docs.where((doc) {
          var data = doc.data();
          if (data['studentId'] != sId) return false;
          if (filterMode == 2) return true; // 🚀 كامل الدورة: لا يوجد قيود على التاريخ
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
        int reviewPages = 0; 
        
        if (validSessions.isNotEmpty) {
          if (!isCompleted) {
            // 🚀 إذا كان وضع "كامل الدورة" بنحسب مجموع الصفحات الفعلي التراكمي لكل جلسة تيسيراً وتجنباً لثغرات تقليب الأجزاء
            if (filterMode == 2) {
              for (var s in validSessions) {
                totalPages += _calculatePagesFromText(s['newMemorization']?.toString());
              }
            } else {
              // الوضع الطبيعي للأسبوعي والشهري (أول صفحة وآخر صفحة بالنطاق)
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
            }

            for (var s in validSessions) {
              reviewPages += _calculatePagesFromText(s['nearReview']?.toString());
              reviewPages += _calculatePagesFromText(s['farReview']?.toString());
            }

          } else {
            // للطالب الخاتم
            if (filterMode == 2) {
              for (var s in validSessions) {
                reviewPages += _calculatePagesFromText(s['farReview']?.toString());
              }
            } else {
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
        }

        if (!isCompleted) cycleTotalPages += totalPages;
        cycleTotalReview += reviewPages;

        var statData = {
          'name': sName,
          'imageUrl': imageUrl,
          'pages': totalPages,
          'reviewPages': reviewPages, 
          'isCompleted': isCompleted,
          'sessionsCount': sessionsCount,
          'absentCount': absentCount,
        };

        if (isCompleted) {
          tempCompleted.add(statData);
        } else if (studentType == 'old') {
          tempOld.add(statData);
        } else {
          tempNew.add(statData); 
        }
      }

      tempNew.sort((a, b) {
        int totalA = (a['pages'] as int) + (a['reviewPages'] as int);
        int totalB = (b['pages'] as int) + (b['reviewPages'] as int);
        return totalB.compareTo(totalA);
      });
      
      tempOld.sort((a, b) {
        int totalA = (a['pages'] as int) + (a['reviewPages'] as int);
        int totalB = (b['pages'] as int) + (b['reviewPages'] as int);
        return totalB.compareTo(totalA);
      });
      
      tempCompleted.sort((a, b) => (b['reviewPages'] as int).compareTo(a['reviewPages'] as int));

      setState(() {
        newStudentsStats = tempNew;
        oldStudentsStats = tempOld;
        completedStudentsStats = tempCompleted;
        isLoading = false;
      });

    } catch (e) {
      print("Error in stats: $e");
      setState(() => isLoading = false);
    }
  }

  void _changePeriod(int amount) {
    if (filterMode == 2) return; // تعطيل التنقل في وضع الدورة الكاملة
    setState(() {
      periodsBack += amount;
      if (periodsBack < 0) periodsBack = 0; 
    });
    _calculateStats();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    bool hasAnyData = newStudentsStats.isNotEmpty || oldStudentsStats.isNotEmpty || completedStudentsStats.isNotEmpty;

    return OfflineWrapper(
      child: Scaffold(
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
            
            Stack(
              children: [
                Positioned(
                  top: -50, 
                  right: -50, 
                  child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)))
                ),
                Positioned(
                  bottom: 100, 
                  left: -80, 
                  child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)))
                ),
              ],
            ),

            SafeArea(
              child: Column(
                children: [
                  // 🚀 شريط التبديل الجديد المطور ليحوي 3 خيارات (أسبوعي / شهري / كامل الدورة)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton(0, "أسبوعي", isDark),
                          _buildTabButton(1, "شهري", isDark),
                          _buildTabButton(2, "كامل الدورة", isDark), // 🚀 الخيار التراكمي المضاف
                        ],
                      ),
                    ),
                  ),

                  // شريط التحكم بالزمن (يظهر نص توضيحي ثابت في وضع كامل الدورة)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.white70),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_right_rounded, color: filterMode == 2 ? Colors.transparent : (isDark ? accentGold : primaryColor)), 
                            onPressed: filterMode == 2 ? null : () => _changePeriod(1), 
                            tooltip: "السابق"
                          ),
                          Expanded(child: Text(currentPeriodLabel, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 13))),
                          IconButton(
                            icon: Icon(Icons.chevron_left_rounded, color: (filterMode != 2 && periodsBack > 0) ? (isDark ? accentGold : primaryColor) : Colors.transparent), 
                            onPressed: (filterMode != 2 && periodsBack > 0) ? () => _changePeriod(-1) : null, 
                            tooltip: "التالي"
                          ),
                        ],
                      ),
                    ),
                  ),

                  // بطاقة حصاد الفترة الإجمالية
                  if (!isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: isDark ? [const Color(0xff1e293b), const Color(0xff0f172a)] : [Colors.white, const Color(0xffe2e8f0)]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accentGold.withOpacity(0.5), width: 1.5),
                          boxShadow: [BoxShadow(color: accentGold.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem("إجمالي الحفظ", "$cycleTotalPages", Icons.menu_book_rounded, Colors.green, isDark),
                            Container(width: 1, height: 40, color: isDark ? Colors.white24 : Colors.black12),
                            _buildSummaryItem("إجمالي المراجعة", "$cycleTotalReview", Icons.loop_rounded, Colors.blueAccent, isDark),
                          ],
                        ),
                      ),
                    ),

                  Expanded(
                    child: isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : (!hasAnyData 
                          ? Center(child: Text("لا توجد بيانات في هذه الفترة 📭", style: TextStyle(color: isDark ? Colors.white54 : primaryColor, fontFamily: 'Cairo', fontWeight: FontWeight.bold)))
                          : ListView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 80),
                              children: [
                                _buildCategorySection("الطلاب الجدد", newStudentsStats, isDark, Icons.fiber_new_rounded, Colors.blueAccent),
                                _buildCategorySection("الطلاب القدامى", oldStudentsStats, isDark, Icons.history_edu_rounded, Colors.orangeAccent),
                                _buildCategorySection("الطلاب الخاتمين 👑", completedStudentsStats, isDark, Icons.verified_rounded, accentGold),
                              ],
                            )
                      ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ويدجت بناء أزرار الشريط العلوي لفلترة الوضع
  Widget _buildTabButton(int mode, String text, bool isDark) {
    bool isSelected = filterMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (filterMode != mode) {
            setState(() { 
              filterMode = mode; 
              periodsBack = 0; 
            }); 
            _calculateStats();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? accentGold : Colors.transparent, 
            borderRadius: BorderRadius.circular(18)
          ),
          child: Text(
            text, 
            textAlign: TextAlign.center, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontFamily: 'Cairo', 
              color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.black54)
            )
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, List<Map<String, dynamic>> stats, bool isDark, IconData icon, Color color) {
    if (stats.isEmpty) return const SizedBox(); 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: isDark ? Colors.white : primaryColor, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            return _buildModernStudentCard(stats[index], index, isDark);
          },
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(title, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
      ],
    );
  }

  Widget _buildModernStudentCard(Map<String, dynamic> stat, int index, bool isDark) {
    bool isCompleted = stat['isCompleted'];
    int pages = stat['pages'];
    int reviewPages = stat['reviewPages']; 
    int absentCount = stat['absentCount'];
    String imageUrl = stat['imageUrl'];
    String firstLetter = stat['name'].isNotEmpty ? stat['name'].trim().substring(0, 1) : "?";

    Color rankColor = Colors.transparent;
    
    bool isTopThree = ((!isCompleted && (pages + reviewPages) > 0) || (isCompleted && reviewPages > 0)) && index < 3;
    
    if (isTopThree) {
      if (index == 0) rankColor = const Color(0xFFFFD700); 
      if (index == 1) rankColor = const Color(0xFFC0C0C0); 
      if (index == 2) rankColor = const Color(0xFFCD7F32); 
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isTopThree ? rankColor.withOpacity(0.6) : (isDark ? Colors.white12 : Colors.white), width: isTopThree ? 2 : 1.2),
        boxShadow: isTopThree ? [BoxShadow(color: rankColor.withOpacity(0.15), blurRadius: 15, spreadRadius: 1)] : [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, 
                    color: isDark ? Colors.white10 : primaryColor.withOpacity(0.1),
                    border: Border.all(color: isTopThree ? rankColor : Colors.transparent, width: isTopThree ? 2.5 : 0),
                    boxShadow: isTopThree ? [BoxShadow(color: rankColor.withOpacity(0.5), blurRadius: 8)] : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (c, u) => const CircularProgressIndicator(strokeWidth: 2), errorWidget: (c, u, e) => Center(child: Text(firstLetter, style: TextStyle(color: isDark ? accentGold : primaryColor, fontWeight: FontWeight.bold))))
                        : Center(child: Text(firstLetter, style: TextStyle(color: isDark ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo'))),
                  ),
                ),
                const SizedBox(width: 15),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stat['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87, fontFamily: 'Cairo')),
                      if (isCompleted)
                        Text("خاتم للمصحف 👑", style: TextStyle(fontSize: 12, color: accentGold, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    ],
                  ),
                ),

                if (isTopThree)
                  Text(index == 0 ? "🥇" : (index == 1 ? "🥈" : "🥉"), style: const TextStyle(fontSize: 26))
                else
                  Text("#${index + 1}", style: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ],
            ),
            
            const SizedBox(height: 15),
            
            Row(
              children: [
                if (!isCompleted)
                  Expanded(child: _buildGradientStatBox("الحفظ", "$pages ص", Colors.green, Icons.menu_book_rounded, pages > 0, isDark)),
                if (!isCompleted) const SizedBox(width: 8),

                Expanded(child: _buildGradientStatBox("المراجعة", "$reviewPages ص", Colors.blueAccent, Icons.loop_rounded, reviewPages > 0, isDark)),
                const SizedBox(width: 8),

                Expanded(child: _buildGradientStatBox("الغياب", "$absentCount ي", Colors.redAccent, Icons.person_off_rounded, absentCount > 0, isDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientStatBox(String title, String value, Color color, IconData icon, bool hasValue, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasValue 
              ? [color.withOpacity(isDark ? 0.2 : 0.15), color.withOpacity(isDark ? 0.05 : 0.05)] 
              : [Colors.grey.withOpacity(isDark ? 0.1 : 0.05), Colors.transparent],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasValue ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -10, bottom: -10,
            child: Icon(icon, size: 40, color: hasValue ? color.withOpacity(0.1) : Colors.transparent),
          ),
          Column(
            children: [
              Text(title, style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: hasValue ? color : Colors.blueGrey, fontFamily: 'Cairo')),
            ],
          ),
        ],
      ),
    );
  }
}