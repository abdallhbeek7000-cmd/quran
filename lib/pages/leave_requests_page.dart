import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/cycle_model.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart';
import '../widgets/offline_wrapper.dart';

class LeaveRequestsPage extends StatefulWidget {
  final String supervisorId;
  final String role;
  final String? studentId;
  final String? requestId;

  const LeaveRequestsPage({
    super.key,
    this.supervisorId = '',
    this.role = 'manager',
    this.studentId,
    this.requestId,
  });

  @override
  State<LeaveRequestsPage> createState() => _LeaveRequestsPageState();
}

class _LeaveRequestsPageState extends State<LeaveRequestsPage> with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _hasCheckedInitialTab = false;
  DocumentSnapshot? _directTargetDoc;
  bool _triedDirectFetch = false;
  String _searchQuery = '';
  String _reasonFilter = 'all';

  // عدادات فورية تُحدَّث من نفس الـ Stream الرئيسي دون استعلام إضافي
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;

  static const List<Map<String, dynamic>> _reasonChips = [
    {'key': 'all', 'label': 'الكل', 'icon': Icons.layers_rounded},
    {'key': 'دراسة', 'label': 'دراسة', 'icon': Icons.menu_book_rounded},
    {'key': 'سفر', 'label': 'سفر', 'icon': Icons.flight_takeoff_rounded},
    {'key': 'مرض', 'label': 'مرض', 'icon': Icons.medical_services_outlined},
    {'key': 'زيارة', 'label': 'زيارة', 'icon': Icons.people_alt_rounded},
    {'key': 'عمل', 'label': 'عمل', 'icon': Icons.work_outline_rounded},
    {'key': 'حالة وفاة', 'label': 'حالة وفاة', 'icon': Icons.sentiment_dissatisfied_rounded},
    {'key': 'لم يحضر الطالب', 'label': 'لم يحضر الطالب', 'icon': Icons.person_off_rounded},
  ];

  static const List<String> _arabicDays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDirectRequestIfNeeded();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _extractArabicDayName(Map<String, dynamic> data) {
    final rawDate = data['date']?.toString().trim() ?? '';
    DateTime? parsed;

    if (rawDate.isNotEmpty) {
      // يدعم صيغ مثل 2026-11-24 أو 24/11/2026 أو 24-11-2026
      final isoTry = DateTime.tryParse(rawDate);
      if (isoTry != null) {
        parsed = isoTry;
      } else {
        final parts = rawDate.split(RegExp(r'[-/]'));
        if (parts.length == 3) {
          final p0 = int.tryParse(parts[0]);
          final p1 = int.tryParse(parts[1]);
          final p2 = int.tryParse(parts[2]);
          if (p0 != null && p1 != null && p2 != null) {
            if (parts[0].length == 4) {
              parsed = DateTime.tryParse('$p0-${p1.toString().padLeft(2, '0')}-${p2.toString().padLeft(2, '0')}');
            } else if (parts[2].length == 4) {
              parsed = DateTime.tryParse('$p2-${p1.toString().padLeft(2, '0')}-${p0.toString().padLeft(2, '0')}');
            }
          }
        }
      }
    }

    if (parsed == null && data['timestamp'] is Timestamp) {
      parsed = (data['timestamp'] as Timestamp).toDate();
    }

    if (parsed == null) return '';
    final idx = (parsed.weekday - 1).clamp(0, _arabicDays.length - 1);
    return _arabicDays[idx];
  }

  String _formatDateWithDay(Map<String, dynamic> data) {
    final dateStr = data['date']?.toString().trim() ?? '';
    final dayName = _extractArabicDayName(data);
    if (dayName.isNotEmpty && dateStr.isNotEmpty) {
      return "$dayName • $dateStr";
    }
    if (dayName.isNotEmpty) return dayName;
    return dateStr;
  }

  Future<void> _fetchDirectRequestIfNeeded() async {
    if (_triedDirectFetch) return;
    _triedDirectFetch = true;

    try {
      if (widget.requestId != null && widget.requestId!.trim().isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('leave_requests')
            .doc(widget.requestId!.trim())
            .get();
        if (doc.exists && mounted) {
          setState(() => _directTargetDoc = doc);
          _applyTabForStatus((doc.data() as Map<String, dynamic>?)?['status']?.toString());
          return;
        }
      }

      if (widget.studentId != null && widget.studentId!.trim().isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('leave_requests')
            .where('studentId', isEqualTo: widget.studentId!.trim())
            .get();
        if (snap.docs.isNotEmpty && mounted) {
          final docs = snap.docs.toList()
            ..sort((a, b) {
              final tA = (a.data()['timestamp'] as Timestamp?) ?? Timestamp(0, 0);
              final tB = (b.data()['timestamp'] as Timestamp?) ?? Timestamp(0, 0);
              return tB.compareTo(tA);
            });
          setState(() => _directTargetDoc = docs.first);
          _applyTabForStatus(docs.first.data()['status']?.toString());
        }
      }
    } catch (e) {
      debugPrint("⚠️ خطأ جلب طلب الاستئذان المباشر: $e");
    }
  }

  void _applyTabForStatus(String? status) {
    if (_hasCheckedInitialTab || status == null) return;
    _hasCheckedInitialTab = true;
    if (status != 'pending') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index != 1) {
          _tabController.animateTo(1);
        }
      });
    }
  }

  static Future<void> notifyManagersOnly({
    required String studentName,
    required String reason,
    required String date,
  }) async {
    try {
      var managersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .get();

      for (var doc in managersSnapshot.docs) {
        await NotificationService.sendAndSaveNotification(
          studentId: doc.id,
          title: "طلب استئذان جديد 📝",
          body: "قدم الطالب ($studentName) طلب استئذان ليوم ($date) - السبب: $reason",
          type: "leave_request",
        );
      }
    } catch (e) {
      debugPrint("❌ خطأ أثناء إرسال إشعارات الاستئذان للمدراء: $e");
    }
  }

  void _showTopPremiumToast(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color statusColor,
    required bool isDark,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry overlayEntry;
    bool removed = false;

    void safeRemove() {
      if (!removed) {
        removed = true;
        try {
          overlayEntry.remove();
        } catch (_) {}
      }
    }

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 15,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: Opacity(opacity: ((value + 100) / 100).clamp(0.0, 1.0), child: child),
              );
            },
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xff1e293b).withOpacity(0.94)
                          : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: accentGold.withOpacity(0.55), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: statusColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), safeRemove);
  }

  Future<void> _updateRequestStatus({
    required BuildContext context,
    required String docId,
    required String studentId,
    required String studentName,
    required String status,
    required String date,
    required String reason,
    required String requestSupervisorId,
    required bool isDark,
    String? cycleId,
  }) async {
    HapticFeedback.mediumImpact();
    try {
      await FirebaseFirestore.instance.collection('leave_requests').doc(docId).update({
        'status': status,
        'actionByRole': widget.role,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      String customSessionId = "${studentId}_$date";

      if (status == 'approved') {
        String activeSupervisorId = requestSupervisorId.isNotEmpty
            ? requestSupervisorId
            : widget.supervisorId;
        String activeSupervisorName = "المشرف";

        try {
          var studentDoc = await FirebaseFirestore.instance
              .collection('students')
              .doc(studentId)
              .get();
          if (studentDoc.exists) {
            var sData = studentDoc.data()!;
            activeSupervisorName = sData['supervisorName'] ?? "المشرف";
            if (activeSupervisorId.isEmpty) {
              activeSupervisorId = sData['supervisorId'] ?? '';
            }
          }
        } catch (_) {}

        Map<String, dynamic> sessionData = {
          'studentId': studentId,
          'studentName': studentName,
          'supervisorId': activeSupervisorId,
          'supervisorName': activeSupervisorName,
          'supervisorIds': [activeSupervisorId],
          'supervisorNames': [activeSupervisorName],
          'date': date,
          'absent': true,
          'absenceType': "بعذر",
          'absenceReason': reason,
          'isExam': false,
          'didNotRecite': false,
          'newMemorization': '',
          'nearReview': '',
          'farReview': '',
          'homework': '',
          'notes': 'تم توثيق الغياب بعذر بناءً على طلب استئذان مقبول.',
          'timestamp': FieldValue.serverTimestamp(),
        };

        if (cycleId != null && cycleId.isNotEmpty) {
          sessionData['cycleId'] = cycleId;
        }

        await FirebaseFirestore.instance.collection('sessions').doc(customSessionId).set(
              sessionData,
              SetOptions(merge: true),
            );
      } else if (status == 'rejected') {
        var existingSession = await FirebaseFirestore.instance.collection('sessions').doc(customSessionId).get();
        if (existingSession.exists && (existingSession.data()?['absenceReason'] == reason)) {
          await FirebaseFirestore.instance.collection('sessions').doc(customSessionId).delete();
        }
      }

      String title = status == 'approved'
          ? "✅ تم قبول إذن الغياب"
          : "❌ اعتذر المعهد عن قبول الإذن";
      String body = status == 'approved'
          ? "تمت الموافقة على إذن الغياب الخاص بالطالب $studentName ليوم $date وتوثيقه تلقائياً بعذر."
          : "نعتذر، لم تتم الموافقة على إذن الغياب للطالب $studentName ليوم $date.";

      await NotificationService.sendAndSaveNotification(
        studentId: studentId,
        title: title,
        body: body,
        type: "leave_status",
        context: context,
      );

      if (!context.mounted) return;
      _showTopPremiumToast(
        context,
        message: status == 'approved'
            ? "تم قبول الطلب وتوثيق الاستئذان بنجاح 🎉"
            : "تم رفض الطلب وإبلاغ عائلة الطالب 📌",
        icon: status == 'approved'
            ? Icons.check_circle_rounded
            : Icons.remove_circle_outline_rounded,
        statusColor: status == 'approved' ? Colors.green.shade600 : Colors.redAccent,
        isDark: isDark,
      );
    } catch (e) {
      if (!context.mounted) return;
      _showTopPremiumToast(
        context,
        message: "حدث خطأ غير متوقع: $e",
        icon: Icons.error_outline_rounded,
        statusColor: Colors.redAccent,
        isDark: isDark,
      );
    }
  }

  void _checkTargetTab(List<QueryDocumentSnapshot> docs) {
    if (_hasCheckedInitialTab) return;
    for (var doc in docs) {
      final matchesRequest = widget.requestId != null && doc.id == widget.requestId;
      final data = doc.data() as Map<String, dynamic>;
      final matchesStudent = widget.studentId != null && data['studentId'] == widget.studentId;
      if (matchesRequest || matchesStudent) {
        _applyTabForStatus(data['status']?.toString());
        break;
      }
    }
  }

  bool _isTargetedRequest(String docId, Map<String, dynamic> data) {
    if (widget.requestId != null && widget.requestId!.isNotEmpty && widget.requestId == docId) {
      return true;
    }
    if (widget.studentId != null && widget.studentId!.isNotEmpty && widget.studentId == data['studentId']) {
      return true;
    }
    return false;
  }

  bool _matchesReasonFilter(String reason) {
    if (_reasonFilter == 'all') return true;
    return reason.trim().contains(_reasonFilter);
  }

  void _syncCountsFromEntries(List<MapEntry<String, Map<String, dynamic>>> entries) {
    int p = 0;
    int a = 0;
    int r = 0;
    for (final e in entries) {
      final st = e.value['status']?.toString() ?? 'pending';
      if (st == 'approved') {
        a++;
      } else if (st == 'rejected') {
        r++;
      } else {
        p++;
      }
    }
    if ((p != _pendingCount || a != _approvedCount || r != _rejectedCount) && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _pendingCount = p;
            _approvedCount = a;
            _rejectedCount = r;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('cycles').snapshots(),
        builder: (context, cycleSnap) {
          CycleModel? activeCycle;

          if (cycleSnap.hasData && cycleSnap.data!.docs.isNotEmpty) {
            for (var doc in cycleSnap.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              bool isCurrent = data['isCurrent'] == true || data['isActive'] == true;
              bool isActive = data['status'] == 'active' || data['active'] == true;
              bool isNotClosed = data['isClosed'] != true && data['archived'] != true;

              if ((isCurrent || isActive) && isNotClosed) {
                activeCycle = CycleModel(
                  id: doc.id,
                  name: data['name'] ?? '',
                  type: data['type']?.toString() ?? '',
                  year: int.tryParse(data['year']?.toString() ?? '') ?? DateTime.now().year,
                  cycleNumber: int.tryParse(data['cycleNumber']?.toString() ?? '') ?? 1,
                  startDate: data['startDate']?.toString() ?? '',
                  endDate: data['endDate']?.toString() ?? '',
                  active: true,
                  archived: false,
                );
                break;
              }
            }
          }

          return Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: isDarkMode ? const Color(0xff090d16) : const Color(0xfff1f5f9),
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              title: Column(
                children: [
                  Text(
                    "طلبات الاستئذان",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : primaryColor,
                      fontFamily: 'Cairo',
                      fontSize: 18,
                    ),
                  ),
                  if (activeCycle != null)
                    Text(
                      activeCycle.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: accentGold,
                        fontFamily: 'Cairo',
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              centerTitle: true,
              iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
            ),
            body: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [const Color(0xff090d16), const Color(0xff131e30), const Color(0xff090d16)]
                          : [const Color(0xfff1f5f9), const Color(0xffe7eef5), const Color(0xfff7f3e8)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                ),
                Positioned(
                  top: -70,
                  right: -60,
                  child: Container(
                    width: 270,
                    height: 270,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withOpacity(isDarkMode ? 0.22 : 0.11),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 60,
                  left: -70,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentGold.withOpacity(isDarkMode ? 0.12 : 0.14),
                    ),
                  ),
                ),

                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 6),

                      // بطاقة إحصاءات فورية بدون استعلام إضافي
                      _buildLiveSummaryStrip(isDarkMode),

                      const SizedBox(height: 9),

                      // حقل بحث سريع
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white.withOpacity(0.84),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: accentGold.withOpacity(isDarkMode ? 0.3 : 0.4),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: isDarkMode ? Colors.white : primaryColor,
                                ),
                                decoration: InputDecoration(
                                  hintText: "ابحث باسم الطالب أو سبب الاستئذان...",
                                  hintStyle: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12.5,
                                    color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
                                  ),
                                  prefixIcon: Icon(Icons.search_rounded, color: accentGold, size: 20),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // شريط فلترة الأسباب الكاملة
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          itemCount: _reasonChips.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 7),
                          itemBuilder: (context, idx) {
                            final item = _reasonChips[idx];
                            return _buildReasonChip(
                              item['key'] as String,
                              item['label'] as String,
                              item['icon'] as IconData,
                              isDarkMode,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      // تبويبات المعلقة والأرشيف
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white.withOpacity(0.68),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDarkMode ? Colors.white12 : Colors.white.withOpacity(0.9),
                                  width: 1.2,
                                ),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                indicator: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDarkMode
                                        ? [accentGold, const Color(0xffc29d29)]
                                        : [primaryColor, const Color(0xff31465a)],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDarkMode ? accentGold : primaryColor).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                labelColor: isDarkMode ? const Color(0xff090d16) : Colors.white,
                                unselectedLabelColor: isDarkMode ? Colors.white60 : primaryColor.withOpacity(0.75),
                                labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12.5),
                                tabs: const [
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.hourglass_top_rounded, size: 17),
                                        SizedBox(width: 6),
                                        Text("طلبات معلقة"),
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.archive_rounded, size: 17),
                                        SizedBox(width: 6),
                                        Text("السجل والأرشيف"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildRequestsList(context, isDarkMode, isHistory: false, activeCycle: activeCycle),
                            _buildRequestsList(context, isDarkMode, isHistory: true, activeCycle: activeCycle),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveSummaryStrip(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: "معلقة",
              count: _pendingCount,
              color: accentGold,
              icon: Icons.pending_actions_rounded,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              title: "مقبولة",
              count: _approvedCount,
              color: const Color(0xff16a34a),
              icon: Icons.verified_rounded,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              title: "مرفوضة",
              count: _rejectedCount,
              color: Colors.redAccent,
              icon: Icons.block_rounded,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(
            "$count",
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDarkMode ? Colors.white : primaryColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: isDarkMode ? Colors.white60 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonChip(String key, String label, IconData icon, bool isDarkMode) {
    final bool active = _reasonFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _reasonFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? primaryColor
              : (isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.86)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? accentGold : accentGold.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.5, color: active ? accentGold : (isDarkMode ? Colors.white70 : primaryColor)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : (isDarkMode ? Colors.white70 : primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList(
    BuildContext context,
    bool isDarkMode, {
    required bool isHistory,
    CycleModel? activeCycle,
  }) {
    final Stream<QuerySnapshot> requestsStream = activeCycle != null
        ? FirebaseFirestore.instance
            .collection('leave_requests')
            .where('cycleId', isEqualTo: activeCycle.id)
            .snapshots()
        : FirebaseFirestore.instance.collection('leave_requests').snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: requestsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "حدث خطأ في جلب البيانات: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'Cairo'),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData && _directTargetDoc == null) {
          return Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: accentGold, strokeWidth: 2.5),
            ),
          );
        }

        final Map<String, Map<String, dynamic>> mergedDocsById = {};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            mergedDocsById[doc.id] = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          }
        }

        if (_directTargetDoc != null && _directTargetDoc!.exists) {
          mergedDocsById.putIfAbsent(
            _directTargetDoc!.id,
            () => Map<String, dynamic>.from(_directTargetDoc!.data() as Map<String, dynamic>),
          );
        }

        final List<MapEntry<String, Map<String, dynamic>>> roleScopedEntries =
            mergedDocsById.entries.where((entry) {
          final String docId = entry.key;
          final Map<String, dynamic> data = entry.value;
          if (_isTargetedRequest(docId, data)) return true;
          if (widget.role == 'supervisor' && widget.supervisorId.isNotEmpty) {
            return data['supervisorId'] == widget.supervisorId;
          }
          return true;
        }).toList();

        _syncCountsFromEntries(roleScopedEntries);

        if (roleScopedEntries.isEmpty) {
          return activeCycle == null
              ? _buildNoActiveCycleState(isDarkMode)
              : _buildEmptyState(isDarkMode, isHistory);
        }

        _checkTargetTab(snapshot.data?.docs ?? []);

        final List<MapEntry<String, Map<String, dynamic>>> filteredEntries =
            roleScopedEntries.where((entry) {
          final String docId = entry.key;
          final Map<String, dynamic> data = entry.value;
          final String currentStatus = data['status']?.toString() ?? 'pending';
          final bool isTargeted = _isTargetedRequest(docId, data);

          final bool statusMatches = isHistory ? (currentStatus != 'pending') : (currentStatus == 'pending');
          if (!statusMatches) return false;

          final String studentName = data['studentName']?.toString() ?? '';
          final String reason = data['reason']?.toString() ?? '';
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            if (!studentName.toLowerCase().contains(q) && !reason.toLowerCase().contains(q)) {
              return false;
            }
          }

          if (!_matchesReasonFilter(reason)) return false;

          if (isTargeted) return true;
          if (activeCycle == null) return false;
          return true;
        }).toList();

        if (filteredEntries.isEmpty) {
          return activeCycle == null
              ? _buildNoActiveCycleState(isDarkMode)
              : _buildEmptyState(isDarkMode, isHistory);
        }

        filteredEntries.sort((a, b) {
          final bool targetA = _isTargetedRequest(a.key, a.value);
          final bool targetB = _isTargetedRequest(b.key, b.value);
          if (targetA != targetB) return targetA ? -1 : 1;

          final Timestamp tA = (a.value['timestamp'] as Timestamp?) ?? Timestamp(0, 0);
          final Timestamp tB = (b.value['timestamp'] as Timestamp?) ?? Timestamp(0, 0);
          return tB.compareTo(tA);
        });

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
          itemCount: filteredEntries.length,
          itemBuilder: (context, index) {
            final String docId = filteredEntries[index].key;
            final Map<String, dynamic> data = filteredEntries[index].value;
            final String currentStatus = data['status']?.toString() ?? 'pending';
            final String requestTime = data['requestTime']?.toString() ?? 'غير محدد';
            final String studentName = data['studentName']?.toString() ?? 'طالب';
            final String formattedDateWithDay = _formatDateWithDay(data);
            final String effectiveCycleId =
                (data['cycleId']?.toString().isNotEmpty == true)
                    ? data['cycleId'].toString()
                    : (activeCycle?.id ?? '');

            final bool isHighlighted = _isTargetedRequest(docId, data);
            final Color stripeColor = currentStatus == 'approved'
                ? const Color(0xff16a34a)
                : (currentStatus == 'rejected' ? Colors.redAccent : accentGold);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.055)
                          : Colors.white.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isHighlighted
                            ? accentGold
                            : (isDarkMode
                                ? Colors.white.withOpacity(0.12)
                                : accentGold.withOpacity(0.28)),
                        width: isHighlighted ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isHighlighted
                              ? accentGold.withOpacity(0.22)
                              : Colors.black.withOpacity(isDarkMode ? 0.32 : 0.06),
                          blurRadius: isHighlighted ? 18 : 14,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 4.5,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [stripeColor, stripeColor.withOpacity(0.35)],
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isHighlighted)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: accentGold.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: accentGold.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.notifications_active_rounded, size: 13, color: accentGold),
                                      const SizedBox(width: 5),
                                      Text(
                                        "الطلب الوارد من الإشعار",
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode ? accentGold : primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: accentGold.withOpacity(0.7), width: 1.4),
                                        ),
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundColor: primaryColor.withOpacity(0.14),
                                          child: Text(
                                            studentName.isNotEmpty ? studentName.characters.first : 'ط',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isDarkMode ? accentGold : primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            studentName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15.5,
                                              color: isDarkMode ? Colors.white : primaryColor,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                          if (data['supervisorName'] != null)
                                            Text(
                                              "المشرف: ${data['supervisorName']}",
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 11,
                                                color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (isHistory) _buildStatusBadge(currentStatus),
                                ],
                              ),

                              const SizedBox(height: 14),

                              Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.black.withOpacity(0.25)
                                      : primaryColor.withOpacity(0.045),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.06)
                                        : primaryColor.withOpacity(0.08),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(9),
                                          ),
                                          child: const Icon(Icons.event_available_rounded, size: 15, color: Colors.redAccent),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "تاريخ الاستئذان: $formattedDateWithDay",
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Cairo',
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: accentGold.withOpacity(0.16),
                                            borderRadius: BorderRadius.circular(9),
                                          ),
                                          child: Icon(Icons.description_outlined, size: 15, color: accentGold),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "السبب: ${data['reason'] ?? ''}",
                                            style: TextStyle(
                                              color: isDarkMode ? Colors.white : const Color(0xff0f172a),
                                              fontFamily: 'Cairo',
                                              fontSize: 13,
                                              height: 1.4,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.schedule_rounded, size: 13.5, color: isDarkMode ? Colors.white54 : Colors.grey.shade600),
                                      const SizedBox(width: 5),
                                      Text(
                                        "وقت الطلب: $requestTime",
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
                                          fontFamily: 'Cairo',
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isHistory)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _updateRequestStatus(
                                        context: context,
                                        docId: docId,
                                        studentId: data['studentId']?.toString() ?? '',
                                        studentName: studentName,
                                        status: 'pending',
                                        date: data['date']?.toString() ?? '',
                                        reason: data['reason']?.toString() ?? 'بعذر',
                                        requestSupervisorId: data['supervisorId']?.toString() ?? '',
                                        isDark: isDarkMode,
                                        cycleId: effectiveCycleId,
                                      ),
                                      icon: Icon(Icons.undo_rounded, size: 14, color: accentGold),
                                      label: Text(
                                        "تراجع عن القرار",
                                        style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: accentGold),
                                      ),
                                    )
                                ],
                              ),

                              if (!isHistory) ...[
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 44,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xff16a34a),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                            elevation: 0,
                                          ),
                                          onPressed: () => _updateRequestStatus(
                                            context: context,
                                            docId: docId,
                                            studentId: data['studentId']?.toString() ?? '',
                                            studentName: studentName,
                                            status: 'approved',
                                            date: data['date']?.toString() ?? '',
                                            reason: data['reason']?.toString() ?? 'بعذر',
                                            requestSupervisorId: data['supervisorId']?.toString() ?? '',
                                            isDark: isDarkMode,
                                            cycleId: effectiveCycleId,
                                          ),
                                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                          label: const Text(
                                            "قبول العذر",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: SizedBox(
                                        height: 44,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                            elevation: 0,
                                          ),
                                          onPressed: () => _updateRequestStatus(
                                            context: context,
                                            docId: docId,
                                            studentId: data['studentId']?.toString() ?? '',
                                            studentName: studentName,
                                            status: 'rejected',
                                            date: data['date']?.toString() ?? '',
                                            reason: data['reason']?.toString() ?? '',
                                            requestSupervisorId: data['supervisorId']?.toString() ?? '',
                                            isDark: isDarkMode,
                                            cycleId: effectiveCycleId,
                                          ),
                                          icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                                          label: const Text(
                                            "رفض الإذن",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ]
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
  }

  Widget _buildStatusBadge(String status) {
    bool isApproved = status == 'approved';
    final Color c = isApproved ? const Color(0xff16a34a) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.withOpacity(0.55), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 13.5,
            color: c,
          ),
          const SizedBox(width: 4),
          Text(
            isApproved ? "مقبول" : "مرفوض",
            style: TextStyle(
              color: c,
              fontSize: 11.5,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveCycleState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: accentGold.withOpacity(0.4)),
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 56,
              color: Colors.redAccent.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "لا توجد دورة نشطة حالياً",
            style: TextStyle(
              color: isDarkMode ? Colors.white : primaryColor,
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "تم إغلاق الدورة السابقة، يرجى تفعيل أو إنشاء دورة جديدة لعرض استئذاناتها.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.grey[600],
                fontFamily: 'Cairo',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, bool isHistory) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: accentGold.withOpacity(0.4)),
            ),
            child: Icon(
              isHistory ? Icons.folder_off_rounded : Icons.mark_email_read_rounded,
              size: 56,
              color: accentGold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isHistory ? "لا يوجد سجل سابق لطلبات الغياب" : "جميع الطلبات مُعالجة ولا يوجد معلق",
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : primaryColor,
              fontFamily: 'Cairo',
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}