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

  // 🚀 إحصائيات المعهد الإجمالية (حصاد الفترة)
  int cycleTotalPages = 0;
  int cycleTotalReview = 0;

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

  // 🚀 الخوارزمية الجديدة لحساب الصفحات المفصولة
  int _calculatePagesFromText(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    
    int totalPages = 0;
    
    // 1. تحويل كلمة " و " إلى فاصل | لتسهيل المعالجة
    String processedText = text.replaceAll(' و ', '|');
    
    // 2. تقسيم النص لأجزاء بناءً على الفواصل ( | أو , أو ، أو + )
    List<String> parts = processedText.split(RegExp(r'[|،,+]'));
    
    for (String part in parts) {
      var matches = RegExp(r'\d+').allMatches(part);
      if (matches.isEmpty) continue; // إذا الجزء ما فيه أرقام، تجاوزه

      List<int> numbers = matches.map((m) => int.parse(m.group(0)!)).toList();
      
      // إذا كان رقم واحد فقط، نعتبره صفحة واحدة
      if (numbers.length == 1) {
        totalPages += 1; 
      } else {
        // إذا كان أكثر من رقم (مثلاً 55 - 80)، نحسب الفرق بين أكبر وأصغر رقم في هذا الجزء فقط
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
        int reviewPages = 0; 
        
        if (validSessions.isNotEmpty) {
          if (!isCompleted) {
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

            for (var s in validSessions) {
              reviewPages += _calculatePagesFromText(s['nearReview']?.toString());
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

        // إضافة للمجموع الكلي
        if (!isCompleted) cycleTotalPages += totalPages;
        cycleTotalReview += reviewPages;

        tempStats.add({
          'name': sName,
          'imageUrl': imageUrl,
          'pages': totalPages,
          'reviewPages': reviewPages, 
          'isCompleted': isCompleted,
          'sessionsCount': sessionsCount,
          'absentCount': absentCount,
        });
      }

      tempStats.sort((a, b) {
        if (a['isCompleted'] && !b['isCompleted']) return 1;
        if (!a['isCompleted'] && b['isCompleted']) return -1;
        
        if (!a['isCompleted'] && !b['isCompleted']) {
          return (b['pages'] as int).compareTo(a['pages'] as int);
        } else {
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
                // أزرار التبديل (أسبوعي / شهري)
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
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (isMonthly) {
                                setState(() { isMonthly = false; periodsBack = 0; }); 
                                _calculateStats();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(color: !isMonthly ? accentGold : Colors.transparent, borderRadius: BorderRadius.circular(18)),
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
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(color: isMonthly ? accentGold : Colors.transparent, borderRadius: BorderRadius.circular(18)),
                              child: Text("شهري", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isMonthly ? Colors.white : (isDark ? Colors.white54 : Colors.black54))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // شريط التحكم بالزمن 
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
                        IconButton(icon: Icon(Icons.chevron_right_rounded, color: isDark ? accentGold : primaryColor), onPressed: () => _changePeriod(1), tooltip: "السابق"),
                        Expanded(child: Text(currentPeriodLabel, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 13))),
                        IconButton(icon: Icon(Icons.chevron_left_rounded, color: periodsBack > 0 ? (isDark ? accentGold : primaryColor) : Colors.transparent), onPressed: periodsBack > 0 ? () => _changePeriod(-1) : null, tooltip: "التالي"),
                      ],
                    ),
                  ),
                ),

                // 🚀 بطاقة حصاد الفترة (إجمالي המعهد)
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
                    : (studentsStats.isEmpty 
                        ? Center(child: Text("لا توجد بيانات في هذه الفترة 📭", style: TextStyle(color: isDark ? Colors.white54 : primaryColor, fontFamily: 'Cairo', fontWeight: FontWeight.bold)))
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(left: 20, right: 20, top: 5, bottom: 80),
                            itemCount: studentsStats.length,
                            itemBuilder: (context, index) {
                              return _buildModernStudentCard(studentsStats[index], index, isDark);
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

  // ويدجت داخلي لبطاقة الحصاد الإجمالي
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

  // 🚀 تصميم البطاقة العصرية (Premium Style)
  Widget _buildModernStudentCard(Map<String, dynamic> stat, int index, bool isDark) {
    bool isCompleted = stat['isCompleted'];
    int pages = stat['pages'];
    int reviewPages = stat['reviewPages']; 
    int absentCount = stat['absentCount'];
    String imageUrl = stat['imageUrl'];
    String firstLetter = stat['name'].isNotEmpty ? stat['name'].trim().substring(0, 1) : "?";

    // 👑 تجهيز ألوان وإضاءة الأوائل
    Color rankColor = Colors.transparent;
    bool isTopThree = (!isCompleted && pages > 0 && index < 3);
    if (isTopThree) {
      if (index == 0) rankColor = const Color(0xFFFFD700); // ذهبي
      if (index == 1) rankColor = const Color(0xFFC0C0C0); // فضي
      if (index == 2) rankColor = const Color(0xFFCD7F32); // برونزي
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
            // 👤 قسم المعلومات الشخصية
            Row(
              children: [
                // صورة الطالب مع إطار مضيء للأوائل
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

                // الشارة 🥇
                if (isTopThree)
                  Text(index == 0 ? "🥇" : (index == 1 ? "🥈" : "🥉"), style: const TextStyle(fontSize: 26))
                else
                  Text("#${index + 1}", style: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ],
            ),
            
            const SizedBox(height: 15),
            
            // 📊 قسم الإحصائيات (Bento Style)
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

  // 🚀 تصميم صندوق الإحصائيات الزجاجي مع تدرج خفيف
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
          // أيقونة خلفية (Watermark) شفافة جداً
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