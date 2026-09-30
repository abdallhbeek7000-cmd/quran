import 'dart:async';
import 'dart:ui';
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
  String currentCycle = "صيف 2026 (1)";
  CycleModel? currentCycleModel;
  bool isLoadingCycle = true;

  final Color primaryNavy = const Color(0xff1e293b);
  final Color accentGold = const Color(0xffD4AF37); 
  final Color neonCyan = const Color(0xff06b6d4);
  final Color softBlue = const Color(0xff3b82f6);

  bool _isUploadingManagerImage = false; 
  bool isAlsoManager = false;
  Timer? _prayerTimer;

  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _fetchCycleDirectlyFromFirebase(); 
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

  Future<void> _initAndSchedulePrayerNotifications() async {
    try {
      tz.initializeTimeZones();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(initSettings);

      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }

      await _localNotifications.cancelAll();

      final times = PrayerService.getSyriaPrayerTimes();
      final now = DateTime.now();

      final List<Map<String, dynamic>> list = [
        {"name": "الفجر", "time": times.fajr, "id": 101},
        {"name": "الظهر", "time": times.dhuhr, "id": 102},
        {"name": "العصر", "time": times.asr, "id": 103},
        {"name": "المغرب", "time": times.maghrib, "id": 104},
        {"name": "العشاء", "time": times.isha, "id": 105},
      ];

      for (var item in list) {
        DateTime prayerTime = item["time"] as DateTime;
        DateTime notificationTime = prayerTime.subtract(const Duration(minutes: 5));

        if (notificationTime.isBefore(now)) {
          notificationTime = notificationTime.add(const Duration(days: 1));
        }

        await _scheduleNotification(
          id: item["id"],
          title: "اقتربت صلاة ${item['name']} 🕌",
          body: "باقي 5 دقائق على أذان صلاة ${item['name']}. استعد للصلاة!",
          scheduledDate: notificationTime,
        );
      }
      print("✅ تم جدولة إشعارات الصلوات بنجاح!");
    } catch (e) {
      print("❌ خطأ في جدولة إشعارات الصلاة: $e");
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'prayer_channel_id_v2',
      'إشعارات أوقات الصلاة',
      channelDescription: 'تنبيهات اقتراب موعد الصلاة قبل 5 دقائق',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const notificationDetails = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true));

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _fetchCycleDirectlyFromFirebase() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('cycles').get();
      
      if (snapshot.docs.isNotEmpty) {
        var doc = snapshot.docs.first;
        var data = doc.data();
        
        String name = data['name'] ?? 'صيف 2026';
        int cycleNum = int.tryParse(data['cycleNumber'].toString()) ?? 1;
        String displayName = "$name ($cycleNum)";

        CycleModel parsedModel = CycleModel(
          id: doc.id,
          name: name,
          type: data['type']?.toString() ?? 'cycle',
          year: int.tryParse(data['year']?.toString() ?? '') ?? DateTime.now().year,
          cycleNumber: cycleNum,
          startDate: data['startDate']?.toString() ?? "2026-05-23",
          endDate: data['endDate']?.toString() ?? "2026-10-02",
          active: data['active'] ?? true,
          archived: data['archived'] ?? false,
        );

        if (mounted) {
          setState(() {
            currentCycle = displayName;
            currentCycleModel = parsedModel;
            isLoadingCycle = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            currentCycle = "لا يوجد دورة";
            isLoadingCycle = false;
          });
        }
      }
    } catch (e) {
      print("❌ خطأ أثناء جلب الدورة من فايربيس: $e");
      if (mounted) {
        setState(() {
          currentCycle = "صيف 2026 (1)";
          isLoadingCycle = false;
        });
      }
    }
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

    var userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    
    if (userDoc.exists && widget.role == "manager") {
      if (mounted) setState(() => isAlsoManager = true);
    } else {
      if (mounted) setState(() => isAlsoManager = false);
    }
  }

  Future<void> _setupNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      String? token = await messaging.getToken();

      if (token != null && widget.uid.isNotEmpty) {
        String collection = widget.role == "manager" ? "users" : "supervisors";
        await FirebaseFirestore.instance.collection(collection).doc(widget.uid).set(
          {'fcmToken': token}, SetOptions(merge: true)
        );
      }
    } catch (e) {
      print("❌ خطأ في إعداد الإشعارات: $e");
    }
  }

  void _showSupervisorsList(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff0f172a).withOpacity(0.95) : Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: accentGold.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Container(width: 45, height: 5, decoration: BoxDecoration(color: accentGold.withOpacity(0.5), borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text("إدارة الحسابات المشرفة 👑", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryNavy, fontFamily: 'Cairo')),
                  if (isAlsoManager && widget.role == 'supervisor') ...[
                    const SizedBox(height: 15),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _returnToManager();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, color: Colors.orange.shade800),
                            const SizedBox(width: 10),
                            Text("العودة للوحة الإدارة الأساسية", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.orange.shade800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(color: isDark ? Colors.white24 : Colors.black12),
                  ],
                  const SizedBox(height: 10),
                  Text("اختر الحساب للدخول كـ مشرف:", style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo')),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('supervisors').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) return const Center(child: Text("لا يوجد مشرفين حالياً", style: TextStyle(fontFamily: 'Cairo')));
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var sup = docs[index].data() as Map<String, dynamic>;
                            String supId = docs[index].id;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: accentGold.withOpacity(0.2),
                                  backgroundImage: sup['imageUrl'] != null && sup['imageUrl'].isNotEmpty ? NetworkImage(sup['imageUrl']) : null,
                                  child: (sup['imageUrl'] == null || sup['imageUrl'].isEmpty) ? Icon(Icons.person, color: accentGold) : null,
                                ),
                                title: Text(sup['name'] ?? 'مشرف', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87)),
                                subtitle: Text(sup['phone'] ?? '', style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                                trailing: Icon(Icons.login_rounded, color: accentGold),
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
        );
      }
    );
  }

  void _impersonateSupervisor(String supId) async {
    Navigator.pop(context); 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'supervisor');
    await prefs.setString('userId', supId); 
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(uid: supId, role: 'supervisor')));
  }

  void _returnToManager() async {
    String realUid = FirebaseAuth.instance.currentUser?.uid ?? widget.uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'manager');
    await prefs.setString('userId', realUid);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(uid: realUid, role: 'manager')));
  }

  logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _updateManagerImage() async {
    setState(() => _isUploadingManagerImage = true);
    try {
      String? url = await CloudinaryHelper.pickAndUploadProfileImage();
      if (url != null) {
        await FirebaseFirestore.instance.collection(widget.role == "manager" ? "users" : "supervisors").doc(widget.uid).set({'imageUrl': url}, SetOptions(merge: true));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث صورة البروفايل بنجاح 🎉", style: TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      print("خطأ في رفع الصورة: $e");
    } finally {
      setState(() => _isUploadingManagerImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final String currentCollection = widget.role == "manager" ? "users" : "supervisors";
    final bool isDark = themeProvider.isDarkMode;

    final fallbackCycle = currentCycleModel ?? CycleModel(
      id: "rRDaBmGjfo6RMOXcF5fm",
      name: "صيف 2026",
      type: "summer",
      year: 2026,
      cycleNumber: 1,
      startDate: "2026-05-23",
      endDate: "2026-10-02",
      active: true,
      archived: false,
    );

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true, 
        backgroundColor: isDark ? const Color(0xff0b1120) : const Color(0xfff8fafc),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent, 
          centerTitle: true,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? Colors.white12 : Colors.white),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.grid_view_rounded, color: isDark ? accentGold : primaryNavy, size: 22),
              color: isDark ? const Color(0xff0f172a) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              onSelected: (value) {
                switch (value) {
                  case 'cycles':
                    _nav(const CyclesPage());
                    break;
                  case 'all_cycles_students':
                    _nav(const AllCyclesStudentsPage());
                    break;
                  case 'create_cycle':
                    _nav(const CreateCyclePage());
                    break;
                  case 'broadcast':
                    _nav(const BroadcastPage());
                    break;
                  case 'inspirations':
                    _nav(const InspirationsManagePage());
                    break;
                  case 'points_bank':
                    _nav(const PointsBankPage());
                    break;
                  case 'activities':
                    _nav(const ActivitiesManagePage());
                    break;
                  case 'assign_students':
                    _nav(AssignStudentsPage(cycle: fallbackCycle));
                    break;
                  case 'expenses':
                    _nav(const InstituteExpensesPage());
                    break;
                  case 'honor_board':
                    _nav(HonorBoardPage(role: widget.role));
                    break;
                  case 'completions':
                    _nav(const QuranCompletionsPage());
                    break;
                  case 'qiblah':
                    _nav(const QiblahPage());
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'cycles',
                  child: Row(
                    children: [
                      Icon(Icons.view_list_rounded, color: isDark ? accentGold : primaryNavy, size: 20),
                      const SizedBox(width: 10),
                      Text('عرض الدورات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ),
                
                if (widget.role == "manager") ...[
                  PopupMenuItem(
                    value: 'all_cycles_students',
                    child: Row(
                      children: [
                        const Icon(Icons.badge_rounded, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 10),
                        Text('جميع طلاب الدورات 🎒', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'create_cycle',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, color: isDark ? accentGold : primaryNavy, size: 20),
                        const SizedBox(width: 10),
                        Text('إنشاء دورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'broadcast',
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_rounded, color: Colors.lightBlueAccent, size: 20),
                        const SizedBox(width: 10),
                        Text('إرسال إعلان للجميع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'inspirations',
                    child: Row(
                      children: [
                        const Icon(Icons.wb_sunny_rounded, color: Colors.orangeAccent, size: 20),
                        const SizedBox(width: 10),
                        Text('إدارة الإشراقات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'points_bank',
                    child: Row(
                      children: [
                        const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 20),
                        const SizedBox(width: 10),
                        Text('بنك النقاط', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'activities',
                    child: Row(
                      children: [
                        const Icon(Icons.directions_bus_rounded, color: Colors.tealAccent, size: 20),
                        const SizedBox(width: 10),
                        Text('الأنشطة والرحلات 🚌', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'assign_students',
                    child: Row(
                      children: [
                        const Icon(Icons.shuffle_rounded, color: Colors.indigoAccent, size: 20),
                        const SizedBox(width: 10),
                        Text('توزيع الطلاب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'expenses',
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.greenAccent, size: 20),
                        const SizedBox(width: 10),
                        Text('مصروفات المعهد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'completions',
                    child: Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: Colors.amber.shade600, size: 20),
                        const SizedBox(width: 10),
                        Text('سجل الختمات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                ],

                PopupMenuItem(
                  value: 'honor_board',
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      Text('لوحة الشرف 🏆', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'qiblah',
                  child: Row(
                    children: [
                      const Icon(Icons.compass_calibration_rounded, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 10),
                      Text('اتجاه القبلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            widget.role == "manager" ? "لوحة المدير 👑" : "لوحة المشرف 👤",
            style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : primaryNavy, fontFamily: 'Cairo', fontSize: 18),
          ),
          actions: [
            if (isAlsoManager)
              IconButton(
                icon: Icon(Icons.supervisor_account_rounded, color: isDark ? accentGold : primaryNavy),
                onPressed: () => _showSupervisorsList(isDark),
              ),
            IconButton(
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDark ? Colors.orangeAccent : primaryNavy),
              onPressed: () => themeProvider.toggleTheme(),
            ),
            IconButton(
              onPressed: logout,
              icon: Icon(Icons.power_settings_new_rounded, color: isDark ? Colors.redAccent : Colors.red),
            ),
          ],
        ),
        body: Stack(
          children: [
            // 🌌 خلفية نيون زجاجية متدرجة وحيوية للغاية
            Container(
              width: double.infinity, height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                      ? [const Color(0xff0b1120), const Color(0xff1e293b), const Color(0xff0f172a)] 
                      : [const Color(0xfff1f5f9), const Color(0xffe2e8f0), const Color(0xffcbd5e1)], 
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
            
            // 🔮 تأثير الدوائر السحرية المشعة
            Positioned(
              top: -80, left: -80,
              child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: accentGold.withOpacity(isDark ? 0.08 : 0.15))),
            ),
            Positioned(
              top: 250, right: -100,
              child: Container(width: 320, height: 320, decoration: BoxDecoration(shape: BoxShape.circle, color: softBlue.withOpacity(isDark ? 0.08 : 0.12))),
            ),

            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 👑 الهيدر الملكي الفاخر
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    sliver: SliverToBoxAdapter(
                      child: _buildRealGlassHeader(isDark, currentCollection),
                    ),
                  ),
                  
                  // 🕌 مركز أوقات الصلاة المستقبلي
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      child: _buildUltraPrayerGlassCard(isDark),
                    ),
                  ),

                  // 💎 شبكة التحكم والأزرار بتنسيق ثلاثي الأبعاد زجاجي
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.15,
                      ),
                      delegate: SliverChildListDelegate([
                        if (widget.role == "manager") ...[
                          _buildCreativeMenuCard(Icons.fact_check_rounded, "تسجيل الحضور 📋", const [Color(0xff10b981), Color(0xff059669)], () {
                            _nav(InitialAttendancePage(cycle: fallbackCycle));
                          }, isDark),
                          _buildCreativeMenuCard(Icons.dashboard_customize_rounded, "لوحة التحكم", const [Color(0xff3b82f6), Color(0xff1d4ed8)], () => _nav(const DashboardPage()), isDark),
                          
                          _buildCreativeMenuCard(Icons.person_add_alt_1_rounded, "إضافة طالب", const [Color(0xff8b5cf6), Color(0xff6d28d9)], () {
                            _nav(AddStudentPage(cycle: fallbackCycle));
                          }, isDark),
                          
                          _buildCreativeMenuCard(Icons.group_add_rounded, "إضافة مشرفين", const [Color(0xfff59e0b), Color(0xffd97706)], () => _nav(const SupervisorPage()), isDark),
                          _buildCreativeMenuCard(Icons.query_stats_rounded, "الإحصائيات اليومية", const [Color(0xffec4899), Color(0xffbe185d)], () => _nav(const DailyStatsPage()), isDark),
                        ],

                        _buildCreativeMenuCard(Icons.groups_rounded, "عرض الطلاب 🎒", const [Color(0xff06b6d4), Color(0xff0891b2)], () {
                          _nav(StudentsPage(cycle: fallbackCycle, role: widget.role, uid: widget.uid));
                        }, isDark),

                        _buildCreativeMenuCard(Icons.mark_chat_unread_rounded, "رسائل الأهالي", const [Color(0xff6366f1), Color(0xff4338ca)], () => _nav(SupervisorInboxPage(supervisorId: widget.uid)), isDark),
                        _buildCreativeMenuCard(Icons.pie_chart_rounded, "الإحصائيات العامة", const [Color(0xff14b8a6), Color(0xff0d9488)], () => _nav(const StatisticsPage()), isDark),
                        _buildCreativeMenuCard(Icons.event_busy_rounded, "طلبات الاستئذان", const [Color(0xfff43f5e), Color(0xffe11d48)], () => _nav(LeaveRequestsPage(supervisorId: widget.uid, role: widget.role)), isDark),
                      ]),
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

  // 🕌 كارد أوقات الصلاة المستقبلي المتألق
  Widget _buildUltraPrayerGlassCard(bool isDark) {
    try {
      final times = PrayerService.getSyriaPrayerTimes();
      final now = DateTime.now();

      final List<Map<String, dynamic>> list = [
        {"name": "الفجر", "time": times.fajr, "icon": Icons.wb_twilight_rounded},
        {"name": "الشروق", "time": times.sunrise, "icon": Icons.wb_sunny_outlined},
        {"name": "الظهر", "time": times.dhuhr, "icon": Icons.wb_sunny_rounded},
        {"name": "العصر", "time": times.asr, "icon": Icons.filter_drama_rounded},
        {"name": "المغرب", "time": times.maghrib, "icon": Icons.nights_stay_outlined},
        {"name": "العشاء", "time": times.isha, "icon": Icons.nights_stay_rounded},
      ];

      Map<String, dynamic>? nextPrayer;
      for (var item in list) {
        if ((item["time"] as DateTime).isAfter(now)) {
          nextPrayer = item;
          break;
        }
      }

      nextPrayer ??= list.first;

      DateTime nextTime = nextPrayer["time"] as DateTime;
      if (nextTime.isBefore(now)) {
        nextTime = nextTime.add(const Duration(days: 1));
      }

      final diff = nextTime.difference(now);
      final hoursLeft = diff.inHours;
      final minutesLeft = diff.inMinutes.remainder(60);

      String countdownStr = hoursLeft > 0 ? "باقي $hoursLeft س و $minutesLeft د" : "باقي $minutesLeft دقيقة";

      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff1e293b).withOpacity(0.55) : Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: isDark ? accentGold.withOpacity(0.35) : primaryNavy.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(color: isDark ? Colors.black.withOpacity(0.3) : primaryNavy.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? accentGold.withOpacity(0.12) : primaryNavy.withOpacity(0.06),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: isDark ? accentGold.withOpacity(0.2) : primaryNavy.withOpacity(0.12), shape: BoxShape.circle),
                            child: Icon(nextPrayer["icon"], color: isDark ? accentGold : primaryNavy, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "الصلاة القادمة: ${nextPrayer['name']}",
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : primaryNavy),
                              ),
                              Text(
                                _formatTime12(nextPrayer['time'] as DateTime),
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? accentGold : primaryNavy.withOpacity(0.8), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black45 : Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? accentGold.withOpacity(0.4) : primaryNavy.withOpacity(0.25)),
                        ),
                        child: Text(
                          countdownStr,
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? accentGold : primaryNavy),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: list.map((item) {
                      bool isNext = item["name"] == nextPrayer!["name"];
                      return _buildPrayerItemTile(
                        name: item["name"],
                        time: item["time"],
                        icon: item["icon"],
                        isNext: isNext,
                        isDark: isDark,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildPrayerItemTile({
    required String name,
    required DateTime time,
    required IconData icon,
    required bool isNext,
    required bool isDark,
  }) {
    Color activeColor = isDark ? accentGold : primaryNavy;
    String formatted = _formatTime12(time);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isNext ? (isDark ? accentGold.withOpacity(0.22) : primaryNavy.withOpacity(0.12)) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isNext ? activeColor.withOpacity(0.6) : Colors.transparent, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isNext ? 19 : 15, color: isNext ? activeColor : (isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 4),
          Text(name, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: isNext ? FontWeight.bold : FontWeight.normal, color: isNext ? (isDark ? Colors.white : primaryNavy) : (isDark ? Colors.grey[400] : Colors.black54))),
          const SizedBox(height: 2),
          Text(formatted, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: isNext ? activeColor : (isDark ? Colors.white70 : Colors.black87))),
        ],
      ),
    );
  }

  String _formatTime12(DateTime time) {
    int hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  // 👑 الهيدر الزجاجي الفاخر
  Widget _buildRealGlassHeader(bool isDark, String currentCollection) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.8), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
          ),
          child: Column(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection(currentCollection).doc(widget.uid).snapshots(),
                builder: (context, snapshot) {
                  String? imageUrl;
                  String? currentName;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    var userData = snapshot.data!.data() as Map<String, dynamic>?;
                    imageUrl = userData?['imageUrl'];
                    currentName = userData?['name'];
                  }

                  Widget buildGreetingText() {
                    if (widget.role == "manager") {
                      return Text(
                        "أهلاً مدير المعهد 👑",
                        style: TextStyle(color: isDark ? Colors.white : primaryNavy, fontSize: 19, fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
                      );
                    } else if (currentName != null && currentName.isNotEmpty) {
                      return Text(
                        "المشرف: $currentName",
                        style: TextStyle(color: isDark ? Colors.white : primaryNavy, fontSize: 19, fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
                      );
                    } else {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('supervisors').doc(widget.uid).get(),
                        builder: (context, supSnap) {
                          String nameToShow = "المشرف";
                          if (supSnap.hasData && supSnap.data!.exists) {
                            nameToShow = (supSnap.data!.data() as Map<String, dynamic>?)?['name'] ?? "المشرف";
                          }
                          return Text(
                            "المشرف: $nameToShow",
                            style: TextStyle(color: isDark ? Colors.white : primaryNavy, fontSize: 19, fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
                          );
                        },
                      );
                    }
                  }

                  return Column(
                    children: [
                      GestureDetector(
                        onTap: !_isUploadingManagerImage ? _updateManagerImage : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 90, height: 90,
                              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [accentGold, softBlue])),
                            ),
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
                              backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                              child: (imageUrl == null || imageUrl.isEmpty) && !_isUploadingManagerImage ? Icon(Icons.person, size: 45, color: accentGold) : null,
                            ),
                            if (_isUploadingManagerImage) const Positioned.fill(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.white))),
                            if (!_isUploadingManagerImage)
                              Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 14, backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white, child: Icon(Icons.camera_alt, size: 15, color: primaryNavy))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      buildGreetingText(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.25) : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_note_rounded, color: isDark ? accentGold : primaryNavy),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("الدورة الفعالة حالياً", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[700], fontFamily: 'Cairo')),
                          isLoadingCycle 
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(currentCycle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : primaryNavy, fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 💎 كارد تحكم زجاجي إبداعي ثلاثي الأبعاد
  Widget _buildCreativeMenuCard(IconData icon, String title, List<Color> gradientColors, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: isDark ? Colors.white12 : Colors.white.withOpacity(0.85), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.04), blurRadius: 12, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(color: gradientColors.first.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Icon(icon, size: 26, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDark ? Colors.white : primaryNavy),
                ),
              ],
            ),
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
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250), 
      ),
    );
  }
}