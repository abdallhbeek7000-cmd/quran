import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quran_habal/pages/leave_requests_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_habal/services/cloudinary_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'login_page.dart';
import 'create_cycle_page.dart';
import 'cycles_page.dart';
import 'add_student_page.dart';
import 'students_page.dart';
import 'assign_students_page.dart';
import '../models/cycle_model.dart';
import '../services/cycle_service.dart';
import '../services/theme_provider.dart';
import 'honor_board_page.dart';
import 'dashboard_page.dart';
import 'daily_stats_page.dart';
import 'supervisor_page.dart';
import 'inspirations_manage_page.dart';
import 'supervisor_inbox_page.dart';
import 'statistics_page.dart';
import 'broadcast_page.dart';
import 'activities_manage_page.dart';
import '../services/notification_queue_manager.dart';
import '../widgets/offline_wrapper.dart';
import 'points_bank_page.dart';
import 'initial_attendance_page.dart';
import 'quran_completions_page.dart';
import 'qiblah_page.dart';
import '../services/prayer_service.dart';
import 'institute_expenses_page.dart';
import 'all_cycles_students_page.dart';
import 'archived_student_sessions_page.dart';
import 'holiday_management_page.dart';
import 'honors_record_page.dart';
import 'honor_suggestions_page.dart';
import 'student_stats_qr_page.dart';

class HomePage extends StatefulWidget {
  final String uid;
  final String role;

  const HomePage({
    super.key,
    required this.uid,
    required this.role,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final cycleService = CycleService();

  final Color primaryNavy = const Color(0xff1e293b);
  final Color accentGold = const Color(0xffD4AF37);
  final Color neonCyan = const Color(0xff06b6d4);
  final Color softBlue = const Color(0xff3b82f6);

  bool _isUploadingManagerImage = false;
  bool isAlsoManager = false;
  Timer? _prayerTimer;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _setupNotifications();
    _checkIfManager();
    _checkPendingNotifications();
    _initAndSchedulePrayerNotifications();

    _prayerTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _prayerTimer?.cancel();
    super.dispose();
  }

  /// إعداد وجدولة إشعارات الصلاة (قبل ساعة وقبل 10 دقائق)
  Future<void> _initAndSchedulePrayerNotifications() async {
    try {
      tz.initializeTimeZones();
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings =
          InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(initSettings);

      final androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }

      final times = PrayerService.getSyriaPrayerTimes();
      final now = DateTime.now();

      final List<Map<String, dynamic>> list = [
        {"name": "الفجر", "time": times.fajr, "baseId": 100},
        {"name": "الظهر", "time": times.dhuhr, "baseId": 200},
        {"name": "العصر", "time": times.asr, "baseId": 300},
        {"name": "المغرب", "time": times.maghrib, "baseId": 400},
        {"name": "العشاء", "time": times.isha, "baseId": 500},
      ];

      for (var item in list) {
        DateTime prayerTime = item["time"] as DateTime;
        int baseId = item["baseId"] as int;
        String name = item["name"] as String;

        DateTime hourBefore = prayerTime.subtract(const Duration(minutes: 60));
        if (hourBefore.isBefore(now)) {
          hourBefore = hourBefore.add(const Duration(days: 1));
        }
        await _scheduleNotification(
          id: baseId + 1,
          title: "اقترب موعد صلاة $name 🕌",
          body: "باقي ساعة واحدة على أذان صلاة $name. تجهّز للصلاة!",
          scheduledDate: hourBefore,
        );

        DateTime tenMinBefore =
            prayerTime.subtract(const Duration(minutes: 10));
        if (tenMinBefore.isBefore(now)) {
          tenMinBefore = tenMinBefore.add(const Duration(days: 1));
        }
        await _scheduleNotification(
          id: baseId + 2,
          title: "اقتربت صلاة $name جداً 🕌",
          body: "باقي 10 دقائق فقط على أذان صلاة $name. استعد للوضوء والصلاة!",
          scheduledDate: tenMinBefore,
        );
      }
    } catch (e) {
      debugPrint("❌ خطأ في جدولة إشعارات الصلاة: $e");
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'prayer_channel_v3',
      'تنبيهات مواقيت الصلاة',
      channelDescription: 'تنبيهات اقتراب موعد الصلاة قبل ساعة وقبل 10 دقائق',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
          presentSound: true, presentAlert: true, presentBadge: true),
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  void _checkPendingNotifications() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      await NotificationQueueManager.processPendingNotifications(context);
    }
  }

  void _checkIfManager() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (userDoc.exists && widget.role == "manager") {
      if (mounted) setState(() => isAlsoManager = true);
    } else {
      if (mounted) setState(() => isAlsoManager = false);
    }
  }

  /// إعداد وقراءة رمز FCM وتحديثه بداخل مجموعة users أو supervisors حسب الدور
  Future<void> _setupNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      String? token = await messaging.getToken();

      if (token != null && widget.uid.isNotEmpty) {
        String collection =
            widget.role == "manager" ? "users" : "supervisors";
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(widget.uid)
            .set(
          {
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (widget.uid.isNotEmpty) {
          String collection =
              widget.role == "manager" ? "users" : "supervisors";
          await FirebaseFirestore.instance
              .collection(collection)
              .doc(widget.uid)
              .set(
            {'fcmToken': newToken},
            SetOptions(merge: true),
          );
        }
      });
    } catch (e) {
      debugPrint("❌ خطأ في إعداد الإشعارات: $e");
    }
  }

  void _showSupervisorsList(bool isDark) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SupervisorsList',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve =
            CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero)
              .animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.72,
                    ),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? const [Color(0xff111827), Color(0xff0f172a)]
                            : const [Color(0xffffffff), Color(0xfff8fafc)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: accentGold.withValues(
                            alpha: isDark ? 0.45 : 0.48),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.45 : 0.14),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: accentGold.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.stars_rounded,
                                  color: accentGold, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "إدارة الحسابات المشرفة 👑",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : primaryNavy,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                        if (isAlsoManager && widget.role == 'supervisor') ...[
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _returnToManager();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.amber.shade700.withValues(alpha: 0.2),
                                  Colors.orange.shade900.withValues(alpha: 0.15)
                                ]),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.orange.shade600
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.admin_panel_settings_rounded,
                                      color: Colors.orange.shade600, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    "العودة للوحة الإدارة الأساسية",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                      color: isDark
                                          ? Colors.orange.shade300
                                          : Colors.orange.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "اختر الحساب للدخول كـ مشرف:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Flexible(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('supervisors')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              final docs = snapshot.data!.docs;
                              if (docs.isEmpty) {
                                return const Center(
                                    child: Text("لا يوجد مشرفين حالياً",
                                        style: TextStyle(fontFamily: 'Cairo')));
                              }
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  var sup = docs[index].data()
                                      as Map<String, dynamic>;
                                  String supId = docs[index].id;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark
                                            ? accentGold.withValues(alpha: 0.22)
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        radius: 21,
                                        backgroundColor:
                                            accentGold.withValues(alpha: 0.2),
                                        backgroundImage: sup['imageUrl'] !=
                                                    null &&
                                                sup['imageUrl'].isNotEmpty
                                            ? NetworkImage(sup['imageUrl'])
                                            : null,
                                        child: (sup['imageUrl'] == null ||
                                                sup['imageUrl'].isEmpty)
                                            ? Icon(Icons.person,
                                                color: accentGold)
                                            : null,
                                      ),
                                      title: Text(
                                        sup['name'] ?? 'مشرف',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Cairo',
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        sup['phone'] ?? '',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                          fontSize: 11,
                                        ),
                                      ),
                                      trailing: Icon(Icons.login_rounded,
                                          color: accentGold, size: 18),
                                      onTap: () => _impersonateSupervisor(supId),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _impersonateSupervisor(String supId) async {
    Navigator.pop(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'supervisor');
    await prefs.setString('userId', supId);
    if (!mounted) return;
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => HomePage(uid: supId, role: 'supervisor')));
  }

  void _returnToManager() async {
    String realUid = FirebaseAuth.instance.currentUser?.uid ?? widget.uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'manager');
    await prefs.setString('userId', realUid);
    if (!mounted) return;
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => HomePage(uid: realUid, role: 'manager')));
  }

  logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _updateManagerImage() async {
    setState(() => _isUploadingManagerImage = true);
    try {
      String? url = await CloudinaryHelper.pickAndUploadProfileImage();
      if (url != null) {
        await FirebaseFirestore.instance
            .collection(widget.role == "manager" ? "users" : "supervisors")
            .doc(widget.uid)
            .set({'imageUrl': url}, SetOptions(merge: true));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.green,
            content: Text("تم تحديث صورة البروفايل بنجاح 🎉",
                style: TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      debugPrint("خطأ في رفع الصورة: $e");
    } finally {
      setState(() => _isUploadingManagerImage = false);
    }
  }

  void _showNavigationMenu(
      bool isDark,
      CycleModel? activeCycleModel,
      Function(Widget Function(CycleModel)) openPageWithActiveCycle) {
    final List<Map<String, dynamic>> allTools = [
      {
        'group': 'الطلاب والمتابعة',
        'icon': Icons.qr_code_scanner_rounded,
        'title': 'مسح بطاقة QR',
        'subtitle': 'استعلام سريع بإحصائيات الطالب',
        'color': const Color(0xff06b6d4),
        'onTap': () => _nav(const StudentStatsQrPage()),
      },
      if (widget.role == "manager") ...[
        {
          'group': 'الطلاب والمتابعة',
          'icon': Icons.badge_rounded,
          'title': 'جميع الطلاب',
          'subtitle': 'سجل الطلاب عبر كافة الدورات',
          'color': const Color(0xff3b82f6),
          'onTap': () => _nav(const AllCyclesStudentsPage()),
        },
        {
          'group': 'الطلاب والمتابعة',
          'icon': Icons.history_edu_rounded,
          'title': 'أرشيف الجلسات',
          'subtitle': 'مراجعة الجلسات المؤرشفة',
          'color': const Color(0xfff97316),
          'onTap': () => _nav(const ArchivedStudentSessionsPage()),
        },
        {
          'group': 'الطلاب والمتابعة',
          'icon': Icons.shuffle_rounded,
          'title': 'توزيع الطلاب',
          'subtitle': 'إسناد الطلاب على المشرفين',
          'color': const Color(0xff8b5cf6),
          'onTap': () => openPageWithActiveCycle(
              (cycle) => AssignStudentsPage(cycle: cycle)),
        },
        {
          'group': 'الطلاب والمتابعة',
          'icon': Icons.menu_book_rounded,
          'title': 'سجل الختمات',
          'subtitle': 'توثيق الخاتمين لكتاب الله',
          'color': const Color(0xfff59e0b),
          'onTap': () => _nav(const QuranCompletionsPage()),
        },
        {
          'group': 'الطلاب والمتابعة',
          'icon': Icons.diamond_rounded,
          'title': 'بنك النقاط',
          'subtitle': 'إدارة رصيد النقاط والمكافآت',
          'color': const Color(0xffa855f7),
          'onTap': () => _nav(const PointsBankPage()),
        },
        {
          'group': 'إدارة الدورات والمعهد',
          'icon': Icons.view_list_rounded,
          'title': 'عرض الدورات',
          'subtitle': 'استعراض الدورات الحالية والسابقة',
          'color': const Color(0xff6366f1),
          'onTap': () => _nav(const CyclesPage()),
        },
        {
          'group': 'إدارة الدورات والمعهد',
          'icon': Icons.add_circle_outline_rounded,
          'title': 'إنشاء دورة',
          'subtitle': 'فتح دورة قرآنية جديدة',
          'color': accentGold,
          'onTap': () => _nav(const CreateCyclePage()),
        },
        {
          'group': 'إدارة الدورات والمعهد',
          'icon': Icons.beach_access_rounded,
          'title': 'تسجيل العطلات',
          'subtitle': 'تحديد أيام الإجازات والعطل',
          'color': const Color(0xffd97706),
          'onTap': () => openPageWithActiveCycle((cycle) =>
              HolidayManagementPage(cycle: cycle, role: widget.role)),
        },
        {
          'group': 'إدارة الدورات والمعهد',
          'icon': Icons.account_balance_wallet_rounded,
          'title': 'مصروفات المعهد',
          'subtitle': 'متابعة النفقات والميزانية',
          'color': const Color(0xff10b981),
          'onTap': () => _nav(const InstituteExpensesPage()),
        },
        {
          'group': 'إدارة الدورات والمعهد',
          'icon': Icons.campaign_rounded,
          'title': 'إرسال إعلان',
          'subtitle': 'نشر تعميم أو إشعار عام',
          'color': const Color(0xff0ea5e9),
          'onTap': () => _nav(const BroadcastPage()),
        },
        {
          'group': 'إدارة الدورات والمعهد',
          'icon': Icons.wb_sunny_rounded,
          'title': 'إدارة الإشراقات',
          'subtitle': 'إضافة وتعديل الإشراقات اليومية',
          'color': const Color(0xffeab308),
          'onTap': () => _nav(const InspirationsManagePage()),
        },
        {
          'group': 'إدارة الدورات والمعهد',
          'icon': Icons.directions_bus_rounded,
          'title': 'الأنشطة والرحلات',
          'subtitle': 'تنظيم الفعاليات والرحلات',
          'color': const Color(0xff14b8a6),
          'onTap': () => _nav(const ActivitiesManagePage()),
        },
      ] else ...[
        {
          'group': 'إدارة الدورات والمعهد',
          'icon': Icons.view_list_rounded,
          'title': 'عرض الدورات',
          'subtitle': 'استعراض دورات المعهد',
          'color': const Color(0xff6366f1),
          'onTap': () => _nav(const CyclesPage()),
        },
      ],
      {
        'group': 'التكريم وأدوات إضافية',
        'icon': Icons.workspace_premium_rounded,
        'title': 'لوحة الشرف',
        'subtitle': 'المتميزون والمتفوقون',
        'color': const Color(0xfff59e0b),
        'onTap': () => _nav(HonorBoardPage(role: widget.role)),
      },
      {
        'group': 'التكريم وأدوات إضافية',
        'icon': Icons.military_tech_rounded,
        'title': 'سجل التكريمات',
        'subtitle': 'أرشيف التكريمات في الدورة',
        'color': accentGold,
        'onTap': () => openPageWithActiveCycle(
            (cycle) => HonorsRecordPage(cycle: cycle, role: widget.role)),
      },
      {
        'group': 'التكريم وأدوات إضافية',
        'icon': Icons.tips_and_updates_rounded,
        'title': 'اقتراحات التكريم',
        'subtitle': 'إرسال مقترحات تكريم الطلاب',
        'color': const Color(0xfffbbf24),
        'onTap': () => openPageWithActiveCycle((cycle) => HonorSuggestionsPage(
              cycle: cycle,
              role: widget.role,
              uid: widget.uid,
            )),
      },
      {
        'group': 'التكريم وأدوات إضافية',
        'icon': Icons.compass_calibration_rounded,
        'title': 'اتجاه القبلة',
        'subtitle': 'تحديد القبلة بدقة',
        'color': const Color(0xff06b6d4),
        'onTap': () => _nav(const QiblahPage()),
      },
    ];

    String searchQuery = '';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'TopNavigationSheet',
      barrierColor: Colors.black.withValues(alpha: 0.58),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve =
            CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero)
                  .animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final filtered = searchQuery.trim().isEmpty
                    ? allTools
                    : allTools.where((item) {
                        final t = (item['title'] as String).toLowerCase();
                        final s = (item['subtitle'] as String).toLowerCase();
                        final q = searchQuery.trim().toLowerCase();
                        return t.contains(q) || s.contains(q);
                      }).toList();

                final List<String> groups = [
                  'الطلاب والمتابعة',
                  'إدارة الدورات والمعهد',
                  'التكريم وأدوات إضافية',
                ];

                return SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.78,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? const [
                                    Color(0xff111827),
                                    Color(0xff0f172a),
                                  ]
                                : const [
                                    Color(0xffffffff),
                                    Color(0xfff8fafc),
                                  ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: accentGold.withValues(
                                alpha: isDark ? 0.42 : 0.48),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.5 : 0.14),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 16, 18, 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: accentGold.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.apps_rounded,
                                      color: isDark ? accentGold : primaryNavy,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "بقية الأدوات والصفحات",
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : primaryNavy,
                                          ),
                                        ),
                                        Text(
                                          activeCycleModel != null
                                              ? "الدورة: ${activeCycleModel.name}"
                                              : "وصول سريع لكافة أقسام المعهد",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => Navigator.pop(context),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (allTools.length > 6)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 0, 18, 12),
                                child: TextField(
                                  onChanged: (val) =>
                                      setDialogState(() => searchQuery = val),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12.5,
                                    color:
                                        isDark ? Colors.white : primaryNavy,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "ابحث عن أداة أو صفحة...",
                                    hintStyle: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      size: 19,
                                      color: isDark ? accentGold : primaryNavy,
                                    ),
                                    isDense: true,
                                    filled: true,
                                    fillColor: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.grey.shade100,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            Flexible(
                              child: filtered.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(28),
                                      child: Text(
                                        "لا توجد أداة مطابقة للبحث",
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 2, 16, 18),
                                      itemCount: groups.length,
                                      itemBuilder: (context, gIndex) {
                                        final groupName = groups[gIndex];
                                        final itemsInGroup = filtered
                                            .where((e) => e['group'] == groupName)
                                            .toList();
                                        if (itemsInGroup.isEmpty) {
                                          return const SizedBox.shrink();
                                        }

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 10,
                                                  bottom: 8,
                                                  right: 4),
                                              child: Text(
                                                groupName,
                                                style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark
                                                      ? accentGold
                                                      : primaryNavy,
                                                ),
                                              ),
                                            ),
                                            ...itemsInGroup.map((tool) {
                                              return _buildSheetItem(
                                                icon: tool['icon'] as IconData,
                                                title: tool['title'] as String,
                                                subtitle:
                                                    tool['subtitle'] as String,
                                                color: tool['color'] as Color,
                                                isDark: isDark,
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  (tool['onTap']
                                                      as VoidCallback)();
                                                },
                                              );
                                            }),
                                          ],
                                        );
                                      },
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
  }

  Widget _buildSheetItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: 0.045) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : primaryNavy,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 13,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String currentCollection =
        widget.role == "manager" ? "users" : "supervisors";
    final bool isDark = themeProvider.isDarkMode;

    return OfflineWrapper(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('cycles').snapshots(),
        builder: (context, cycleSnap) {
          CycleModel? activeCycleModel;

          if (cycleSnap.hasData && cycleSnap.data!.docs.isNotEmpty) {
            for (var doc in cycleSnap.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              bool isCurrent = data['isCurrent'] == true;
              bool isActive =
                  data['status'] == 'active' || data['active'] == true;
              bool isNotClosed =
                  data['isClosed'] != true && data['archived'] != true;

              if ((isCurrent || isActive) && isNotClosed) {
                activeCycleModel = CycleModel(
                  id: doc.id,
                  name: data['name'] ?? '',
                  type: data['type']?.toString() ?? '',
                  year: int.tryParse(data['year']?.toString() ?? '') ??
                      DateTime.now().year,
                  cycleNumber:
                      int.tryParse(data['cycleNumber']?.toString() ?? '') ?? 1,
                  startDate: data['startDate']?.toString() ?? '',
                  endDate: data['endDate']?.toString() ?? '',
                  active: data['active'] == true,
                  archived: data['archived'] == true,
                );
                break;
              }
            }
          }

          void openPageWithActiveCycle(
              Widget Function(CycleModel cycle) pageBuilder) {
            if (activeCycleModel == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.orange,
                  content: Text(
                      "لا توجد دورة نشطة حالياً 🚫 يرجى إنشاء دورة جديدة من القائمة.",
                      style: TextStyle(fontFamily: 'Cairo')),
                ),
              );
              return;
            }
            _nav(pageBuilder(activeCycleModel!));
          }

          return Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor:
                isDark ? const Color(0xff0b1120) : const Color(0xfff8fafc),
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              centerTitle: true,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentGold.withValues(alpha: 0.45)),
                ),
                child: IconButton(
                  icon: Icon(Icons.grid_view_rounded,
                      color: isDark ? accentGold : primaryNavy, size: 22),
                  onPressed: () => _showNavigationMenu(
                      isDark, activeCycleModel, openPageWithActiveCycle),
                ),
              ),
              title: Text(
                widget.role == "manager"
                    ? "لوحة المدير 👑"
                    : "لوحة المشرف 👤",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : primaryNavy,
                    fontFamily: 'Cairo',
                    fontSize: 18),
              ),
              actions: [
                if (isAlsoManager)
                  IconButton(
                    icon: Icon(Icons.supervisor_account_rounded,
                        color: isDark ? accentGold : primaryNavy),
                    onPressed: () => _showSupervisorsList(isDark),
                  ),
                IconButton(
                  icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: isDark ? Colors.orangeAccent : primaryNavy),
                  onPressed: () => themeProvider.toggleTheme(),
                ),
                IconButton(
                  onPressed: logout,
                  icon: Icon(Icons.power_settings_new_rounded,
                      color: isDark ? Colors.redAccent : Colors.red),
                ),
              ],
            ),
            body: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [
                              Color(0xff0b1120),
                              Color(0xff1e293b),
                              Color(0xff0f172a)
                            ]
                          : const [
                              Color(0xfff8fafc),
                              Color(0xfff1f5f9),
                              Color(0xfff6f2e7)
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  top: -80,
                  left: -80,
                  child: IgnorePointer(
                    child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentGold.withValues(
                                alpha: isDark ? 0.09 : 0.16))),
                  ),
                ),
                Positioned(
                  top: 250,
                  right: -100,
                  child: IgnorePointer(
                    child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: softBlue.withValues(
                                alpha: isDark ? 0.08 : 0.11))),
                  ),
                ),
                SafeArea(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        sliver: SliverToBoxAdapter(
                          child: _buildRealGlassHeader(
                              isDark, currentCollection, activeCycleModel),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 5),
                          child: _buildUltraPrayerGlassCard(isDark),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.15,
                          ),
                          delegate: SliverChildListDelegate(
                            [
                              if (widget.role == "manager") ...[
                                _buildCreativeMenuCard(
                                    Icons.fact_check_rounded,
                                    "تسجيل الحضور 📋",
                                    const [Color(0xff10b981), Color(0xff059669)],
                                    () {
                                  openPageWithActiveCycle((cycle) =>
                                      InitialAttendancePage(cycle: cycle));
                                }, isDark),
                                _buildCreativeMenuCard(
                                    Icons.dashboard_customize_rounded,
                                    "لوحة التحكم",
                                    const [Color(0xff3b82f6), Color(0xff1d4ed8)],
                                    () => _nav(const DashboardPage()),
                                    isDark),
                                _buildCreativeMenuCard(
                                    Icons.person_add_alt_1_rounded,
                                    "إضافة طالب",
                                    const [Color(0xff8b5cf6), Color(0xff6d28d9)],
                                    () {
                                  openPageWithActiveCycle((cycle) =>
                                      AddStudentPage(cycle: cycle));
                                }, isDark),
                                _buildCreativeMenuCard(
                                    Icons.group_add_rounded,
                                    "إضافة مشرفين",
                                    const [Color(0xfff59e0b), Color(0xffd97706)],
                                    () => _nav(const SupervisorPage()),
                                    isDark),
                                _buildCreativeMenuCard(
                                    Icons.query_stats_rounded,
                                    "الإحصائيات اليومية",
                                    const [Color(0xffec4899), Color(0xffbe185d)],
                                    () => _nav(const DailyStatsPage()),
                                    isDark),
                              ],
                              _buildCreativeMenuCard(
                                  Icons.groups_rounded,
                                  "عرض الطلاب 🎒",
                                  const [Color(0xff06b6d4), Color(0xff0891b2)],
                                  () {
                                openPageWithActiveCycle((cycle) => StudentsPage(
                                    cycle: cycle,
                                    role: widget.role,
                                    uid: widget.uid));
                              }, isDark),
                              _buildCreativeMenuCard(
                                  Icons.mark_chat_unread_rounded,
                                  "رسائل الأهالي",
                                  const [Color(0xff6366f1), Color(0xff4338ca)],
                                  () => _nav(
                                      SupervisorInboxPage(supervisorId: widget.uid)),
                                  isDark),
                              _buildCreativeMenuCard(
                                  Icons.pie_chart_rounded,
                                  "الإحصائيات العامة",
                                  const [Color(0xff14b8a6), Color(0xff0d9488)],
                                  () => _nav(const StatisticsPage()),
                                  isDark),
                              _buildCreativeMenuCard(
                                  Icons.event_busy_rounded,
                                  "طلبات الاستئذان",
                                  const [Color(0xfff43f5e), Color(0xffe11d48)],
                                  () => _nav(LeaveRequestsPage(
                                      supervisorId: widget.uid,
                                      role: widget.role)),
                                  isDark),
                            ],
                            addRepaintBoundaries: true,
                          ),
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

  Widget _buildUltraPrayerGlassCard(bool isDark) {
    try {
      final times = PrayerService.getSyriaPrayerTimes();
      final now = DateTime.now();

      final List<Map<String, dynamic>> list = [
        {"name": "الفجر", "time": times.fajr, "icon": Icons.wb_twilight_rounded},
        {
          "name": "الشروق",
          "time": times.sunrise,
          "icon": Icons.wb_sunny_outlined
        },
        {"name": "الظهر", "time": times.dhuhr, "icon": Icons.wb_sunny_rounded},
        {"name": "العصر", "time": times.asr, "icon": Icons.filter_drama_rounded},
        {
          "name": "المغرب",
          "time": times.maghrib,
          "icon": Icons.nights_stay_outlined
        },
        {
          "name": "العشاء",
          "time": times.isha,
          "icon": Icons.nights_stay_rounded
        },
      ];

      Map<String, dynamic>? nextPrayer;
      for (var item in list) {
        if ((item["time"] as DateTime).isAfter(now)) {
          nextPrayer = item;
          break;
        }
      }

      nextPrayer ??= list.first;
      final Map<String, dynamic> currentPrayer = nextPrayer;

      DateTime nextTime = currentPrayer["time"] as DateTime;
      if (nextTime.isBefore(now)) {
        nextTime = nextTime.add(const Duration(days: 1));
      }

      final diff = nextTime.difference(now);
      final hoursLeft = diff.inHours;
      final minutesLeft = diff.inMinutes.remainder(60);

      String countdownStr = hoursLeft > 0
          ? "باقي $hoursLeft س و $minutesLeft د"
          : "باقي $minutesLeft دقيقة";

      return RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xff1e293b).withValues(alpha: 0.58)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: accentGold.withValues(alpha: isDark ? 0.38 : 0.42),
                width: 1.4),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? accentGold.withValues(alpha: 0.14)
                      : primaryNavy.withValues(alpha: 0.06),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: accentGold.withValues(alpha: 0.2),
                              shape: BoxShape.circle),
                          child: Icon(currentPrayer["icon"],
                              color: isDark ? accentGold : primaryNavy,
                              size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("الصلاة القادمة: ${currentPrayer['name']}",
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color:
                                        isDark ? Colors.white : primaryNavy)),
                            Text(
                                _formatTime12(
                                    currentPrayer['time'] as DateTime),
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: isDark
                                        ? accentGold
                                        : primaryNavy.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black45
                            : Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: accentGold.withValues(alpha: 0.5)),
                      ),
                      child: Text(countdownStr,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? accentGold : primaryNavy)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: list.map((item) {
                    bool isNext = item["name"] == currentPrayer["name"];
                    return _buildPrayerItemTile(
                        name: item["name"],
                        time: item["time"],
                        icon: item["icon"],
                        isNext: isNext,
                        isDark: isDark);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildPrayerItemTile(
      {required String name,
      required DateTime time,
      required IconData icon,
      required bool isNext,
      required bool isDark}) {
    Color activeColor = isDark ? accentGold : primaryNavy;
    String formatted = _formatTime12(time);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isNext
            ? (isDark
                ? accentGold.withValues(alpha: 0.22)
                : primaryNavy.withValues(alpha: 0.12))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isNext
                ? activeColor.withValues(alpha: 0.65)
                : Colors.transparent,
            width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: isNext ? 19 : 15,
              color: isNext
                  ? activeColor
                  : (isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 4),
          Text(name,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                  color: isNext
                      ? (isDark ? Colors.white : primaryNavy)
                      : (isDark ? Colors.grey[400] : Colors.black54))),
          const SizedBox(height: 2),
          Text(formatted,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isNext
                      ? activeColor
                      : (isDark ? Colors.white70 : Colors.black87))),
        ],
      ),
    );
  }

  String _formatTime12(DateTime time) {
    int hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Widget _buildRealGlassHeader(
      bool isDark, String currentCollection, CycleModel? activeCycle) {
    bool isManager = widget.role == "manager";

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xff1e293b).withValues(alpha: 0.58)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: accentGold.withValues(alpha: isDark ? 0.35 : 0.45),
              width: 1.4),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: -2,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(currentCollection)
                  .doc(widget.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                String? imageUrl;
                String? currentName;
                if (snapshot.hasData && snapshot.data!.exists) {
                  var userData = snapshot.data!.data() as Map<String, dynamic>?;
                  imageUrl = userData?['imageUrl'];
                  currentName = userData?['name'];
                }

                Widget buildGreetingText() {
                  if (isManager) {
                    return Text("أهلاً مدير المعهد 👑",
                        style: TextStyle(
                            color: isDark ? Colors.white : primaryNavy,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo'));
                  } else if (currentName != null && currentName.isNotEmpty) {
                    return Text("أهلاً المشرف: $currentName 👤",
                        style: TextStyle(
                            color: isDark ? Colors.white : primaryNavy,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo'));
                  } else {
                    return Text("أهلاً بالمشرف 👤",
                        style: TextStyle(
                            color: isDark ? Colors.white : primaryNavy,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo'));
                  }
                }

                return Column(
                  children: [
                    GestureDetector(
                      onTap: (isManager && !_isUploadingManagerImage)
                          ? _updateManagerImage
                          : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                  colors: [accentGold, primaryNavy]),
                              boxShadow: [
                                BoxShadow(
                                  color: accentGold.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: isDark
                                ? const Color(0xff1e293b)
                                : Colors.white,
                            backgroundImage:
                                imageUrl != null && imageUrl.isNotEmpty
                                    ? NetworkImage(imageUrl)
                                    : null,
                            child: (imageUrl == null || imageUrl.isEmpty) &&
                                    !_isUploadingManagerImage
                                ? Icon(Icons.person,
                                    size: 45, color: accentGold)
                                : null,
                          ),
                          if (_isUploadingManagerImage)
                            const Positioned.fill(
                                child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                        color: Colors.white))),
                          if (!_isUploadingManagerImage && isManager)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: accentGold,
                                child: Icon(Icons.camera_alt,
                                    size: 15, color: primaryNavy),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildGreetingText(),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentGold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: accentGold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        isManager ? "صلاحية الإدارة العليا" : "إشراف الحلقات",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? accentGold : primaryNavy,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: activeCycle != null
                      ? accentGold.withValues(alpha: 0.4)
                      : Colors.redAccent.withValues(alpha: 0.35),
                  width: 1.1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (activeCycle != null
                              ? accentGold
                              : Colors.redAccent)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      activeCycle != null
                          ? Icons.event_note_rounded
                          : Icons.event_busy_rounded,
                      color: activeCycle != null
                          ? (isDark ? accentGold : primaryNavy)
                          : Colors.redAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("الدورة الفعالة حالياً",
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                                fontFamily: 'Cairo')),
                        Text(
                          activeCycle?.name ?? "لا توجد دورة نشطة حالياً 🚫",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: activeCycle != null
                                ? (isDark ? Colors.white : primaryNavy)
                                : Colors.redAccent,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (activeCycle != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xff10b981).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "نشطة",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff10b981),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreativeMenuCard(IconData icon, String title,
      List<Color> gradientColors, VoidCallback onTap, bool isDark) {
    return RepaintBoundary(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xff1e293b).withValues(alpha: 0.56)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: accentGold.withValues(alpha: isDark ? 0.24 : 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                spreadRadius: -1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, size: 25, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.white : primaryNavy),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nav(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }
}