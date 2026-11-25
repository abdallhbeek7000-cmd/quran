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
  Map<String, String> approvedLeaveMap = {};
  List<Map<String, dynamic>> _allActiveStudents = [];

  bool isLoading = true;
  bool isSaving = false;

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  late final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get dailyDocId => "${widget.cycle.id}_$todayDate";

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
    _loadInitialDataFast();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ⚡ تحميل متوازٍ فوري للتفقد والطلاب والاستئذانات دفعة واحدة
  Future<void> _loadInitialDataFast() async {
    setState(() {
      isLoading = true;
      attendanceData.clear();
      approvedLeaveMap.clear();
    });

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('daily_attendance')
            .doc(dailyDocId)
            .get(),
        FirebaseFirestore.instance
            .collection('leave_requests')
            .where('cycleId', isEqualTo: widget.cycle.id)
            .where('status', isEqualTo: 'approved')
            .get(),
        FirebaseFirestore.instance
            .collection('students')
            .where('cycleId', isEqualTo: widget.cycle.id)
            .get(),
      ]);

        final attendanceSnap =
          results[0] as DocumentSnapshot<Map<String, dynamic>>;
        final leaveSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
        final studentsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;

      // 1. تفقد اليوم
      if (attendanceSnap.exists && attendanceSnap.data() != null) {
        final data = attendanceSnap.data()!;
        if (data['cycleId'] == widget.cycle.id && data.containsKey('records')) {
          final records = data['records'] as Map<String, dynamic>? ?? {};
          records.forEach((studentId, record) {
            if (record is Map) {
              attendanceData[studentId] = Map<String, dynamic>.from(record);
            } else if (record is String) {
              attendanceData[studentId] = {'status': record};
            }
          });
        }
      }

      // 2. الاستئذانات المقبولة لليوم
      final normToday = _normalizeDate(todayDate);
      for (final doc in leaveSnap.docs) {
        final lData = doc.data();
        final sId = lData['studentId']?.toString() ?? '';
        final rawDate = lData['date']?.toString() ?? '';
        if (sId.isNotEmpty && _normalizeDate(rawDate) == normToday) {
          approvedLeaveMap[sId] =
              lData['reason']?.toString() ?? 'طلب استئذان مقبول';
        }
      }

      // 3. فلترة وترتيب الطلاب النشطين مرة واحدة فقط
      final List<Map<String, dynamic>> activeList = [];
      for (final doc in studentsSnap.docs) {
        final data = doc.data();
        final bool isArchived =
            data['archived'] == true || data['isArchived'] == true;
        final bool isStopped = data['isStopped'] == true;
        final String status = data['status']?.toString().toLowerCase() ?? '';
        if (isArchived ||
            isStopped ||
            status == 'stopped' ||
            status == 'archived') {
          continue;
        }

        final studentId = doc.id;
        if (approvedLeaveMap.containsKey(studentId) &&
            !attendanceData.containsKey(studentId)) {
          attendanceData[studentId] = {
            'status': 'absent',
            'absenceType': 'بعذر',
            'reason': approvedLeaveMap[studentId] ?? 'طلب استئذان مقبول',
            'isPreApproved': true,
          };
        }

        activeList.add({
          'id': studentId,
          ...data,
          '_nameLower': (data['name'] ?? '').toString().toLowerCase(),
          '_serialLower': (data['serial'] ?? '').toString().toLowerCase(),
          '_serialInt':
              int.tryParse(data['serial']?.toString() ?? '') ?? 99999999,
        });
      }

      activeList.sort(
          (a, b) => (a['_serialInt'] as int).compareTo(b['_serialInt'] as int));

      if (mounted) {
        setState(() {
          _allActiveStudents = activeList;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في تحميل تفقد اليوم للدورة الحالية: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showTopGlassNotification(String title, String message, bool isDark) {
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;
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
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              tween: Tween(begin: -100.0, end: 0.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xff1e293b).withOpacity(0.88)
                              : Colors.white.withOpacity(0.92),
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
                              child: const Icon(Icons.check_circle_rounded,
                                  color: Colors.greenAccent, size: 28),
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
                                      color:
                                          isDark ? Colors.white : primaryColor,
                                    ),
                                  ),
                                  Text(
                                    message,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
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
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
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
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xff1e293b).withOpacity(0.9)
                          : Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.white.withOpacity(0.85),
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
                              child: const Icon(Icons.event_busy_rounded,
                                  color: Colors.redAccent, size: 26),
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
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    studentName,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color:
                                          isDark ? Colors.white : primaryColor,
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
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color:
                                  isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(
                                    () => selectedType = 'بدون عذر'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selectedType == 'بدون عذر'
                                        ? Colors.redAccent
                                        : (isDark
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.white.withOpacity(0.5)),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selectedType == 'بدون عذر'
                                          ? Colors.redAccent
                                          : (isDark
                                              ? Colors.white12
                                              : Colors.black12),
                                    ),
                                  ),
                                  child: Text(
                                    "بدون عذر 🔴",
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      color: selectedType == 'بدون عذر'
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setDialogState(() => selectedType = 'بعذر'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selectedType == 'بعذر'
                                        ? Colors.orange
                                        : (isDark
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.white.withOpacity(0.5)),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selectedType == 'بعذر'
                                          ? Colors.orange
                                          : (isDark
                                              ? Colors.white12
                                              : Colors.black12),
                                    ),
                                  ),
                                  child: Text(
                                    "بعذر 📄",
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      color: selectedType == 'بعذر'
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
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
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      isDark ? Colors.white12 : Colors.white),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedReason,
                                isExpanded: true,
                                dropdownColor: isDark
                                    ? const Color(0xff1e293b)
                                    : Colors.white,
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 13),
                                items: excuseReasons.map((reason) {
                                  return DropdownMenuItem(
                                      value: reason, child: Text(reason));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedReason = val);
                                  }
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
                                child: const Text("إلغاء",
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  setState(() {
                                    attendanceData[studentId] = {
                                      'status': 'absent',
                                      'absenceType': selectedType,
                                      'reason': selectedType == 'بعذر'
                                          ? selectedReason
                                          : 'غياب بدون عذر',
                                      'isManual': true,
                                    };
                                  });
                                  Navigator.pop(ctx);
                                },
                                child: const Text("تأكيد الغياب",
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
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

  // ⚡ حفظ سريع بدفعة واحدة (WriteBatch) مع دعم العطلة الفردية بدون احتسابها بالحضور أو الغياب
  Future<void> _saveAttendance(bool isDark) async {
    setState(() => isSaving = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final WriteBatch batch = firestore.batch();

      final DocumentReference attendanceDoc =
          firestore.collection('daily_attendance').doc(dailyDocId);

      batch.set(attendanceDoc, {
        'date': todayDate,
        'cycleId': widget.cycle.id,
        'records': attendanceData,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final Map<String, Map<String, dynamic>> studentById = {
        for (final s in _allActiveStudents) s['id'] as String: s,
      };

      int absentCount = 0;
      int presentCount = 0;
      int holidayCount = 0;

      final List<String> nonAbsentIdsToCheck = [];
      final List<Map<String, String>> absentNotifications = [];

      for (final entry in attendanceData.entries) {
        final String studentId = entry.key;
        final record = entry.value;
        final String status = record['status'] ?? 'none';
        final String customSessionId = "${studentId}_$todayDate";

        if (status == 'present') {
          presentCount++;
          nonAbsentIdsToCheck.add(customSessionId);
        } else if (status == 'holiday') {
          holidayCount++;
          nonAbsentIdsToCheck.add(customSessionId);
          final sData = studentById[studentId];
          final sessionRef = firestore.collection('sessions').doc(customSessionId);
          batch.set(sessionRef, {
            'studentId': studentId,
            'studentName': sData?['name'] ?? 'طالب',
            'supervisorId': sData?['supervisorId'] ?? '',
            'supervisorName': sData?['supervisorName'] ?? 'المشرف',
            'cycleId': widget.cycle.id,
            'date': todayDate,
            'absent': false,
            'isHoliday': true,
            'sessionType': 'holiday',
            'status': 'عطلة',
            'title': 'عطلة',
            'note': 'عطلة',
            'notes': 'عطلة',
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else if (status == 'absent') {
          absentCount++;
          final String absenceType = record['absenceType'] ?? 'بدون عذر';
          final String reason = record['reason'] ?? 'غياب عن الدوام المبدئي';
          final sData = studentById[studentId];

          if (sData != null) {
            final sessionRef =
                firestore.collection('sessions').doc(customSessionId);
            batch.set(sessionRef, {
              'studentId': studentId,
              'studentName': sData['name'] ?? 'طالب',
              'supervisorId': sData['supervisorId'] ?? '',
              'supervisorName': sData['supervisorName'] ?? 'المشرف',
              'cycleId': widget.cycle.id,
              'date': todayDate,
              'absent': true,
              'isHoliday': false,
              'absenceType': absenceType,
              'absenceReason': reason,
              'isExam': false,
              'didNotRecite': false,
              'newMemorization': '',
              'nearReview': '',
              'farReview': '',
              'homework': '',
              'notes':
                  'تم توثيق الغياب تلقائياً من التفتيش المبدئي ($absenceType: $reason).',
              'timestamp': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            absentNotifications.add({
              'studentId': studentId,
              'name': (sData['name'] ?? 'طالب').toString(),
              'absenceType': absenceType,
              'reason': reason,
            });
          }
        }
      }

      // حذف أي سجل غياب سابق إذا تم تحويل الطالب إلى حاضر أو عطلة
      if (nonAbsentIdsToCheck.isNotEmpty) {
        final existingSnaps = await Future.wait(
          nonAbsentIdsToCheck
              .map((id) => firestore.collection('sessions').doc(id).get()),
        );
        for (final docSnap in existingSnaps) {
          if (docSnap.exists && (docSnap.data()?['absent'] == true)) {
            batch.delete(docSnap.reference);
          }
        }
      }

      await batch.commit();

      // إرسال إشعارات الغياب فقط (بدون إرسال إشعار غياب للعطلة)
      for (final item in absentNotifications) {
        NotificationService.sendAndSaveNotification(
          studentId: item['studentId']!,
          title: "تنبيه غياب 🔴",
          body:
              "تم تسجيل غياب ولدكم (${item['name']}) اليوم ($todayDate) - الحالة: ${item['absenceType']} (${item['reason']}).",
          type: "absence_alert",
          context: context,
        ).catchError((e) => debugPrint("فشل إرسال إشعار الغياب: $e"));
      }

      if (!mounted) return;
      _showTopGlassNotification(
        "تم حفظ التفقد المبدئي بنجاح 🎉",
        "حاضر: $presentCount | غائب: $absentCount | عطلة: $holidayCount",
        isDark,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("حدث خطأ أثناء الحفظ: $e",
              style: const TextStyle(fontFamily: 'Cairo')),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final filteredStudents = searchQuery.isEmpty
        ? _allActiveStudents
        : _allActiveStudents.where((s) {
            return (s['_nameLower'] as String).contains(searchQuery) ||
                (s['_serialLower'] as String).contains(searchQuery);
          }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "تسجيل الحضور المبدئي 📋",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : primaryColor,
              fontFamily: 'Cairo'),
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
          SafeArea(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: isDark ? accentGold : primaryColor))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.white.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.12)
                                            : Colors.white.withOpacity(0.75),
                                        width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.today_rounded,
                                              color: isDark
                                                  ? accentGold
                                                  : primaryColor),
                                          const SizedBox(width: 10),
                                          Text(
                                            "التاريخ: $todayDate",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Cairo',
                                                color: isDark
                                                    ? Colors.white
                                                    : primaryColor),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "الدورة: ${widget.cycle.name}",
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'Cairo',
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  searchQuery = val.trim().toLowerCase();
                                });
                              },
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color:
                                      isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText:
                                    "ابحث باسم الطالب أو رقمه التسلسلي...",
                                hintStyle: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45),
                                prefixIcon: Icon(Icons.search_rounded,
                                    color: isDark ? accentGold : primaryColor),
                                suffixIcon: searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black54),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => searchQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white.withOpacity(0.65),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.white),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.white.withOpacity(0.75)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                      color:
                                          isDark ? accentGold : primaryColor,
                                      width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _allActiveStudents.isEmpty
                            ? const Center(
                                child: Text(
                                    "لا يوجد طلاب نشطون مسجلون بالدورة الحالية.",
                                    style: TextStyle(fontFamily: 'Cairo')),
                              )
                            : filteredStudents.isEmpty
                                ? const Center(
                                    child: Text(
                                        "لا يطابق بحثك أي طالب مسجل 🔍",
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 14)),
                                  )
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    itemCount: filteredStudents.length,
                                    itemBuilder: (context, index) {
                                      final student = filteredStudents[index];
                                      final String studentId =
                                          student['id'] as String;

                                      final bool isPreApproved =
                                          approvedLeaveMap
                                              .containsKey(studentId);
                                      final String leaveReason =
                                          approvedLeaveMap[studentId] ??
                                              'طلب استئذان مقبول';

                                      final currentRecord =
                                          attendanceData[studentId] ?? {};
                                      final String currentStatus =
                                          currentRecord['status'] ?? 'none';
                                      final bool isHoliday =
                                          currentStatus == 'holiday';
                                      final String absenceType =
                                          currentRecord['absenceType'] ?? '';
                                      final String reason =
                                          currentRecord['reason'] ?? '';

                                      return RepaintBoundary(
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isHoliday
                                                ? accentGold.withOpacity(0.14)
                                                : (isPreApproved
                                                    ? Colors.orange
                                                        .withOpacity(0.15)
                                                    : (isDark
                                                        ? Colors.white
                                                            .withOpacity(0.05)
                                                        : Colors.white
                                                            .withOpacity(0.68))),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isHoliday
                                                  ? accentGold.withOpacity(0.75)
                                                  : (isPreApproved
                                                      ? Colors.orange
                                                          .withOpacity(0.6)
                                                      : (isDark
                                                          ? Colors.white
                                                              .withOpacity(0.1)
                                                          : Colors.white
                                                              .withOpacity(
                                                                  0.8))),
                                              width: (isHoliday || isPreApproved)
                                                  ? 1.5
                                                  : 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              if (student['serial'] != null)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                  margin: const EdgeInsets.only(
                                                      left: 8),
                                                  decoration: BoxDecoration(
                                                    color: primaryColor
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    "#${student['serial']}",
                                                    style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark
                                                          ? accentGold
                                                          : primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: primaryColor
                                                    .withOpacity(0.15),
                                                backgroundImage: student[
                                                            'imageUrl'] !=
                                                        null &&
                                                    student['imageUrl']
                                                        .toString()
                                                        .isNotEmpty
                                                    ? NetworkImage(
                                                        student['imageUrl'])
                                                    : null,
                                                child: (student['imageUrl'] ==
                                                            null ||
                                                        student['imageUrl']
                                                            .toString()
                                                            .isEmpty)
                                                    ? Icon(Icons.person,
                                                        color: isDark
                                                            ? Colors.white
                                                            : primaryColor)
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            student['name'] ??
                                                                'طالب',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontFamily:
                                                                    'Cairo',
                                                                color: isDark
                                                                    ? Colors
                                                                        .white
                                                                    : primaryColor),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        if (isPreApproved &&
                                                            !isHoliday) ...[
                                                          const SizedBox(
                                                              width: 4),
                                                          const Icon(
                                                              Icons
                                                                  .verified_user_rounded,
                                                              color:
                                                                  Colors.orange,
                                                              size: 14),
                                                        ]
                                                      ],
                                                    ),
                                                    if (isHoliday)
                                                      Text(
                                                        "عطلة 🌴 (غير محتسب)",
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontFamily: 'Cairo',
                                                          color: isDark
                                                              ? accentGold
                                                              : const Color(
                                                                  0xff9a6b00),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      )
                                                    else if (isPreApproved)
                                                      Text(
                                                        "مستأذن مسبقاً 📄: $leaveReason",
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontFamily: 'Cairo',
                                                          color: Colors.orange,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      )
                                                    else if (currentStatus ==
                                                            'absent' &&
                                                        absenceType.isNotEmpty)
                                                      Text(
                                                        "$absenceType: $reason",
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontFamily: 'Cairo',
                                                          color: absenceType ==
                                                                  'بعذر'
                                                              ? Colors.orange
                                                              : Colors
                                                                  .redAccent,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      )
                                                    else
                                                      Text(
                                                        "المشرف: ${student['supervisorName'] ?? 'غير محدد'}",
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            fontFamily: 'Cairo',
                                                            color: isDark
                                                                ? Colors.white54
                                                                : Colors
                                                                    .black54),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  // زر الحاضر ✅
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        if (currentStatus ==
                                                            'present') {
                                                          attendanceData
                                                              .remove(studentId);
                                                        } else {
                                                          attendanceData[
                                                                  studentId] = {
                                                            'status': 'present',
                                                            'isManual': true,
                                                          };
                                                        }
                                                      });
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 9,
                                                          vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: currentStatus ==
                                                                'present'
                                                            ? Colors.green
                                                            : Colors.transparent,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                            color: currentStatus ==
                                                                    'present'
                                                                ? Colors.green
                                                                : (isDark
                                                                    ? Colors
                                                                        .white24
                                                                    : Colors
                                                                        .black26)),
                                                      ),
                                                      child: Icon(
                                                          Icons
                                                              .check_circle_rounded,
                                                          size: 18,
                                                          color: currentStatus ==
                                                                  'present'
                                                              ? Colors.white
                                                              : Colors.green),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),

                                                  // زر الغياب ❌
                                                  InkWell(
                                                    onTap: () {
                                                      if (currentStatus ==
                                                          'absent') {
                                                        setState(() =>
                                                            attendanceData
                                                                .remove(studentId));
                                                      } else {
                                                        _showAbsenceDialog(
                                                            studentId,
                                                            student['name'] ??
                                                                'طالب',
                                                            isDark);
                                                      }
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 9,
                                                          vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: currentStatus ==
                                                                'absent'
                                                            ? (absenceType ==
                                                                    'بعذر'
                                                                ? Colors.orange
                                                                : Colors
                                                                    .redAccent)
                                                            : Colors.transparent,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                            color: currentStatus ==
                                                                    'absent'
                                                                ? (absenceType ==
                                                                        'بعذر'
                                                                    ? Colors
                                                                        .orange
                                                                    : Colors
                                                                        .redAccent)
                                                                : (isDark
                                                                    ? Colors
                                                                        .white24
                                                                    : Colors
                                                                        .black26)),
                                                      ),
                                                      child: Icon(
                                                          Icons.cancel_rounded,
                                                          size: 18,
                                                          color: currentStatus ==
                                                                  'absent'
                                                              ? Colors.white
                                                              : Colors
                                                                  .redAccent),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),

                                                  // زر العطلة الفورية 🌴
                                                  Tooltip(
                                                    message: "عطلة",
                                                    child: InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          if (isHoliday) {
                                                            attendanceData
                                                                .remove(
                                                                    studentId);
                                                          } else {
                                                            attendanceData[
                                                                    studentId] = {
                                                              'status':
                                                                  'holiday',
                                                              'isHoliday': true,
                                                              'isManual': true,
                                                            };
                                                          }
                                                        });
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      child: Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 9,
                                                            vertical: 8),
                                                        decoration: BoxDecoration(
                                                          color: isHoliday
                                                              ? accentGold
                                                              : Colors
                                                                  .transparent,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          border: Border.all(
                                                              color: isHoliday
                                                                  ? accentGold
                                                                  : (isDark
                                                                      ? Colors
                                                                          .white24
                                                                      : Colors
                                                                          .black26)),
                                                        ),
                                                        child: Icon(
                                                            Icons
                                                                .beach_access_rounded,
                                                            size: 18,
                                                            color: isHoliday
                                                                ? Colors.black
                                                                : accentGold),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                              elevation: 4,
                            ),
                            onPressed:
                                isSaving ? null : () => _saveAttendance(isDark),
                            icon: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.save_rounded,
                                    color: Colors.white),
                            label: Text(
                              isSaving
                                  ? "جاري الحفظ..."
                                  : "حفظ التفقد المبدئي 🚀",
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                  color: Colors.white),
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