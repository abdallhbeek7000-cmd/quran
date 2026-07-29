import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cycle_model.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart';

class InitialAttendancePage extends StatefulWidget {
  final CycleModel cycle;

  const InitialAttendancePage({super.key, required this.cycle});

  @override
  State<InitialAttendancePage> createState() => _InitialAttendancePageState();
}

class _InitialAttendancePageState extends State<InitialAttendancePage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  Map<String, Map<String, dynamic>> attendanceData = {};
  bool isLoading = true;
  bool isSaving = false;

  // 🔍 حقل التحكم بالبحث
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  DateTime now = DateTime.now();
  String get todayDate => DateFormat('yyyy-MM-dd').format(now);

  final List<String> excuseReasons = [
    'مرض 🏥',
    'سفر ✈️',
    'دراسة 📚',
    'حالة وفاة 🖤',
    'عمل 💼',
    'زيارة 🚗',
    'استئذان مسبق 📄',
    'لم يحضر الطالب 🚪',
  ];

  String _normalizeDate(String rawDate) {
    if (rawDate.isEmpty) return '';
    try {
      List<String> parts = rawDate.split(RegExp(r'[-/.]'));
      if (parts.length == 3) {
        int y, m, d;
        if (parts[0].length == 4) {
          y = int.parse(parts[0]);
          m = int.parse(parts[1]);
          d = int.parse(parts[2]);
        } else {
          d = int.parse(parts[0]);
          m = int.parse(parts[1]);
          y = int.parse(parts[2]);
        }
        return "$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
      }
    } catch (_) {}
    return rawDate.trim();
  }

  @override
  void initState() {
    super.initState();
    _loadExistingAttendance();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingAttendance() async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('daily_attendance')
          .doc(todayDate)
          .get();

      if (snap.exists && snap.data() != null) {
        var data = snap.data()!['records'] as Map<String, dynamic>? ?? {};
        data.forEach((studentId, record) {
          if (record is Map) {
            attendanceData[studentId] = Map<String, dynamic>.from(record);
          } else if (record is String) {
            attendanceData[studentId] = {'status': record};
          }
        });
      }
    } catch (e) {
      print("خطأ في تحميل تفقد اليوم: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showTopGlassNotification(String title, String message, bool isDark) {
    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              tween: Tween(begin: -100.0, end: 0.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xff1e293b).withOpacity(0.85) : Colors.white.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : primaryColor,
                                    ),
                                  ),
                                  Text(
                                    message,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black87,
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
            ),
          ),
        );
      },
    );

    overlayState.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  void _showAbsenceDialog(String studentId, String studentName, bool isDark) {
    String selectedType = 'بدون عذر';
    String selectedReason = excuseReasons.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1e293b).withOpacity(0.85) : Colors.white.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.8),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.event_busy_rounded, color: Colors.redAccent, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "تسجيل غياب",
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    studentName,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "نوع الغياب:",
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() => selectedType = 'بدون عذر'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selectedType == 'بدون عذر' ? Colors.redAccent : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.4)),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selectedType == 'بدون عذر' ? Colors.redAccent : (isDark ? Colors.white12 : Colors.black12),
                                    ),
                                  ),
                                  child: Text(
                                    "بدون عذر 🔴",
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      color: selectedType == 'بدون عذر' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() => selectedType = 'بعذر'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selectedType == 'بعذر' ? Colors.orange : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.4)),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selectedType == 'بعذر' ? Colors.orange : (isDark ? Colors.white12 : Colors.black12),
                                    ),
                                  ),
                                  child: Text(
                                    "بعذر 📄",
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      color: selectedType == 'بعذر' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (selectedType == 'بعذر') ...[
                          const SizedBox(height: 18),
                          Text(
                            "سبب الغياب بعذر:",
                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withOpacity(0.25) : Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.white),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedReason,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xff1e293b) : Colors.white,
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                                items: excuseReasons.map((reason) {
                                  return DropdownMenuItem(value: reason, child: Text(reason));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedReason = val);
                                },
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  setState(() {
                                    attendanceData[studentId] = {
                                      'status': 'absent',
                                      'absenceType': selectedType,
                                      'reason': selectedType == 'بعذر' ? selectedReason : 'غياب بدون عذر',
                                    };
                                  });
                                  Navigator.pop(ctx);
                                },
                                child: const Text("تأكيد الغياب", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
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
          },
        );
      },
    );
  }

  Future<void> _saveAttendance(bool isDark) async {
    setState(() => isSaving = true);
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference attendanceDoc = FirebaseFirestore.instance
          .collection('daily_attendance')
          .doc(todayDate);

      batch.set(attendanceDoc, {
        'date': todayDate,
        'cycleId': widget.cycle.id,
        'records': attendanceData,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      int absentCount = 0;
      int presentCount = 0;

      for (var entry in attendanceData.entries) {
        String studentId = entry.key;
        var record = entry.value;
        String status = record['status'] ?? 'none';

        if (status == 'present') {
          presentCount++;
        } else if (status == 'absent') {
          absentCount++;
          String absenceType = record['absenceType'] ?? 'بدون عذر';
          String reason = record['reason'] ?? 'غياب عن الدوام المبدئي';

          var studentDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
          if (studentDoc.exists) {
            var sData = studentDoc.data()!;

            String customSessionId = "${studentId}_$todayDate";

            var existingSession = await FirebaseFirestore.instance
                .collection('sessions')
                .doc(customSessionId)
                .get();

            if (!existingSession.exists) {
              await FirebaseFirestore.instance.collection('sessions').doc(customSessionId).set({
                'studentId': studentId,
                'studentName': sData['name'] ?? 'طالب',
                'supervisorId': sData['supervisorId'] ?? '',
                'supervisorName': sData['supervisorName'] ?? 'المشرف',
                'date': todayDate,
                'absent': true,
                'absenceType': absenceType,
                'absenceReason': reason,
                'isExam': false,
                'didNotRecite': false,
                'newMemorization': '',
                'nearReview': '',
                'farReview': '',
                'homework': '',
                'notes': 'تم تسجيل الغياب تلقائياً من التفتيش المبدئي للمدير ($absenceType: $reason).',
                'timestamp': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              NotificationService.sendAndSaveNotification(
                studentId: studentId,
                title: "تنبيه غياب 🔴",
                body: "تم تسجيل غياب ولدكم (${sData['name']}) اليوم ($todayDate) - الحالة: $absenceType ($reason).",
                type: "absence_alert",
                context: context,
              ).catchError((e) => print("فشل إرسال إشعار الغياب لأهل الطالب $studentId: $e"));
            }
          }
        }
      }

      if (!mounted) return;
      _showTopGlassNotification(
        "تم حفظ التفقد المبدئي بنجاح 🎉",
        "حاضر: $presentCount | غائب كجلسة رسمية: $absentCount",
        isDark,
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("حدث خطأ أثناء الحفظ: $e", style: const TextStyle(fontFamily: 'Cairo')),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
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
        title: Text(
          "تسجيل الحضور المبدئي 📋",
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? primaryColor.withOpacity(0.18) : primaryColor.withOpacity(0.25),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? accentGold.withOpacity(0.12) : accentGold.withOpacity(0.2),
              ),
            ),
          ),

          SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // 1️⃣ كارت تفاصيل اليوم مع شريط البحث التفاعلي
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.7), width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.today_rounded, color: isDark ? accentGold : primaryColor),
                                          const SizedBox(width: 10),
                                          Text(
                                            "التاريخ: $todayDate",
                                            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDark ? Colors.white : primaryColor),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "الدورة: ${widget.cycle.name}",
                                        style: TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // 🔍 شريط البحث المصمم بزجاجية أنيقة
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (val) {
                                    setState(() {
                                      searchQuery = val.trim().toLowerCase();
                                    });
                                  },
                                  style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: "ابحث باسم الطالب أو رقمه التسلسلي...",
                                    hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
                                    prefixIcon: Icon(Icons.search_rounded, color: isDark ? accentGold : primaryColor),
                                    suffixIcon: searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(Icons.clear, color: isDark ? Colors.white54 : Colors.black54),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => searchQuery = '');
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.5),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.white),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.white.withOpacity(0.7)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(color: isDark ? accentGold : primaryColor, width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 📡 1. الاستماع الحي لجدول الجلسات وطلبات الاستئذان المعتمدة
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
                          builder: (context, sessionsSnap) {
                            Map<String, String> approvedAbsentStudentsMap = {};

                            if (sessionsSnap.hasData) {
                              for (var doc in sessionsSnap.data!.docs) {
                                var sData = doc.data() as Map<String, dynamic>;
                                String sId = sData['studentId'] ?? '';
                                String rawDate = sData['date'] ?? '';
                                bool isAbsent = sData['absent'] ?? false;
                                String absenceReason = sData['absenceReason'] ?? sData['notes'] ?? 'استئذان مقبول';

                                if (sId.isNotEmpty && isAbsent && _normalizeDate(rawDate) == _normalizeDate(todayDate)) {
                                  approvedAbsentStudentsMap[sId] = absenceReason.isNotEmpty ? absenceReason : 'طلب استئذان مقبول';
                                }
                              }
                            }

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('leave_requests')
                                  .where('status', isEqualTo: 'approved')
                                  .snapshots(),
                              builder: (context, leaveSnap) {
                                if (leaveSnap.hasData) {
                                  for (var doc in leaveSnap.data!.docs) {
                                    var lData = doc.data() as Map<String, dynamic>;
                                    String sId = lData['studentId'] ?? '';
                                    String rawDate = lData['date'] ?? '';
                                    if (sId.isNotEmpty && _normalizeDate(rawDate) == _normalizeDate(todayDate)) {
                                      approvedAbsentStudentsMap[sId] = lData['reason'] ?? 'طلب استئذان مقبول';
                                    }
                                  }
                                }

                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('students')
                                      .where('cycleId', isEqualTo: widget.cycle.id)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return Center(child: Text("خطأ: ${snapshot.error}", style: const TextStyle(fontFamily: 'Cairo')));
                                    }
                                    if (!snapshot.hasData) {
                                      return const Center(child: CircularProgressIndicator());
                                    }

                                    var docs = snapshot.data!.docs;

                                    // 🛑 تصفية الطلاب النشطين واستبعاد المتوقفين والمؤرشفين
                                    List<DocumentSnapshot> activeDocs = docs.where((doc) {
                                      var data = doc.data() as Map<String, dynamic>;
                                      bool isArchived = data['archived'] == true || data['isArchived'] == true;
                                      bool isStopped = data['isStopped'] == true;
                                      String status = data['status']?.toString().toLowerCase() ?? '';
                                      return !isArchived && !isStopped && status != 'stopped' && status != 'archived';
                                    }).toList();

                                    if (activeDocs.isEmpty) {
                                      return const Center(
                                        child: Text("لا يوجد طلاب نشطون مسجلون بالدورة الحالية.", style: TextStyle(fontFamily: 'Cairo')),
                                      );
                                    }

                                    // 🔢 فرز الطلاب النشطين بحسب الرقم التسلسلي (serial) المعتمد
                                    activeDocs.sort((a, b) {
                                      var dataA = a.data() as Map<String, dynamic>;
                                      var dataB = b.data() as Map<String, dynamic>;

                                      int serialA = int.tryParse(dataA['serial']?.toString() ?? '') ?? 99999999;
                                      int serialB = int.tryParse(dataB['serial']?.toString() ?? '') ?? 99999999;

                                      return serialA.compareTo(serialB);
                                    });

                                    // 🔍 تطبيق الفلترة والتصفية بالبحث الحقيقي
                                    if (searchQuery.isNotEmpty) {
                                      activeDocs = activeDocs.where((doc) {
                                        var data = doc.data() as Map<String, dynamic>;
                                        String name = (data['name'] ?? '').toString().toLowerCase();
                                        String serial = (data['serial'] ?? '').toString().toLowerCase();
                                        return name.contains(searchQuery) || serial.contains(searchQuery);
                                      }).toList();
                                    }

                                    if (activeDocs.isEmpty) {
                                      return const Center(
                                        child: Text("لا يطابق بحثك أي طالب مسجل 🔍", style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                                      );
                                    }

                                    return ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      itemCount: activeDocs.length,
                                      itemBuilder: (context, index) {
                                        var studentDoc = activeDocs[index];
                                        var student = studentDoc.data() as Map<String, dynamic>;
                                        String studentId = studentDoc.id;

                                        bool isPreApproved = approvedAbsentStudentsMap.containsKey(studentId);
                                        String leaveReason = approvedAbsentStudentsMap[studentId] ?? 'طلب استئذان مقبول';

                                        if (isPreApproved) {
                                          attendanceData[studentId] = {
                                            'status': 'absent',
                                            'absenceType': 'بعذر',
                                            'reason': leaveReason,
                                            'isPreApproved': true,
                                          };
                                        }

                                        var currentRecord = attendanceData[studentId] ?? {};
                                        String currentStatus = currentRecord['status'] ?? 'none';
                                        String absenceType = currentRecord['absenceType'] ?? '';
                                        String reason = currentRecord['reason'] ?? '';

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(20),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: isPreApproved
                                                      ? Colors.orange.withOpacity(0.14)
                                                      : (isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.5)),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: isPreApproved
                                                        ? Colors.orange.withOpacity(0.6)
                                                        : (isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6)),
                                                    width: isPreApproved ? 1.5 : 1.2,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    // 🔢 شارة الرقم التسلسلي
                                                    if (student['serial'] != null)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        margin: const EdgeInsets.only(left: 8),
                                                        decoration: BoxDecoration(
                                                          color: primaryColor.withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          "#${student['serial']}",
                                                          style: TextStyle(
                                                            fontFamily: 'Cairo',
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: isDark ? accentGold : primaryColor,
                                                          ),
                                                        ),
                                                      ),

                                                    CircleAvatar(
                                                      radius: 20,
                                                      backgroundColor: primaryColor.withOpacity(0.15),
                                                      backgroundImage: student['imageUrl'] != null && student['imageUrl'].toString().isNotEmpty
                                                          ? NetworkImage(student['imageUrl'])
                                                          : null,
                                                      child: (student['imageUrl'] == null || student['imageUrl'].toString().isEmpty)
                                                          ? Icon(Icons.person, color: isDark ? Colors.white : primaryColor)
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  student['name'] ?? 'طالب',
                                                                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDark ? Colors.white : primaryColor),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                              if (isPreApproved) ...[
                                                                const SizedBox(width: 4),
                                                                const Icon(Icons.verified_user_rounded, color: Colors.orange, size: 14),
                                                              ]
                                                            ],
                                                          ),
                                                          if (isPreApproved)
                                                            Text(
                                                              "مستأذن مسبقاً 📄: $leaveReason",
                                                              style: const TextStyle(
                                                                fontSize: 11,
                                                                fontFamily: 'Cairo',
                                                                color: Colors.orange,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            )
                                                          else if (currentStatus == 'absent' && absenceType.isNotEmpty)
                                                            Text(
                                                              "$absenceType: $reason",
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontFamily: 'Cairo',
                                                                color: absenceType == 'بعذر' ? Colors.orange : Colors.redAccent,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            )
                                                          else
                                                            Text(
                                                              "المشرف: ${student['supervisorName'] ?? 'غير محدد'}",
                                                              style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54),
                                                            ),
                                                        ],
                                                      ),
                                                    ),

                                                    Row(
                                                      children: [
                                                        InkWell(
                                                          onTap: isPreApproved
                                                              ? null
                                                              : () {
                                                                  setState(() {
                                                                    if (currentStatus == 'present') {
                                                                      attendanceData.remove(studentId);
                                                                    } else {
                                                                      attendanceData[studentId] = {'status': 'present'};
                                                                    }
                                                                  });
                                                                },
                                                          borderRadius: BorderRadius.circular(12),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                            decoration: BoxDecoration(
                                                              color: currentStatus == 'present' ? Colors.green : Colors.transparent,
                                                              borderRadius: BorderRadius.circular(12),
                                                              border: Border.all(color: currentStatus == 'present' ? Colors.green : (isDark ? Colors.white24 : Colors.black26)),
                                                            ),
                                                            child: Icon(Icons.check_circle_rounded, size: 18, color: currentStatus == 'present' ? Colors.white : Colors.green),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),

                                                        InkWell(
                                                          onTap: isPreApproved
                                                              ? null
                                                              : () {
                                                                  if (currentStatus == 'absent') {
                                                                    setState(() => attendanceData.remove(studentId));
                                                                  } else {
                                                                    _showAbsenceDialog(studentId, student['name'] ?? 'طالب', isDark);
                                                                  }
                                                                },
                                                          borderRadius: BorderRadius.circular(12),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                            decoration: BoxDecoration(
                                                              color: currentStatus == 'absent' ? (isPreApproved ? Colors.orange : Colors.redAccent) : Colors.transparent,
                                                              borderRadius: BorderRadius.circular(12),
                                                              border: Border.all(color: currentStatus == 'absent' ? (isPreApproved ? Colors.orange : Colors.redAccent) : (isDark ? Colors.white24 : Colors.black26)),
                                                            ),
                                                            child: Icon(Icons.cancel_rounded, size: 18, color: currentStatus == 'absent' ? Colors.white : Colors.redAccent),
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
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),

                      // 💾 زر حفظ الحضور المبدئي
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 4,
                            ),
                            onPressed: isSaving ? null : () => _saveAttendance(isDark),
                            icon: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.save_rounded, color: Colors.white),
                            label: Text(
                              isSaving ? "جاري الحفظ..." : "حفظ التفقد المبدئي 🚀",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}