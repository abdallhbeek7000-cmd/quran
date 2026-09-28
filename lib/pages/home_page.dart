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
import '../services/notification_service.dart'; 
import 'quran_completions_page.dart';
import 'qiblah_page.dart';
import '../services/prayer_service.dart';
import 'institute_expenses_page.dart'; 

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

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); 
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

    // فحص آمن: فقط إذا كان الحساب مسجلاً بجدول المدير الرسمي
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
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff1e293b) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Text("إدارة الحسابات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
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
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
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
              Text("الدخول كـ مشرف:", style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54, fontFamily: 'Cairo')),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('supervisors').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text("لا يوجد مشرفين", style: TextStyle(fontFamily: 'Cairo')));
                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var sup = docs[index].data() as Map<String, dynamic>;
                        String supId = docs[index].id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.2),
                              backgroundImage: sup['imageUrl'] != null && sup['imageUrl'].isNotEmpty ? NetworkImage(sup['imageUrl']) : null,
                              child: (sup['imageUrl'] == null || sup['imageUrl'].isEmpty) ? Icon(Icons.person, color: primaryColor) : null,
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث الصورة بنجاح 🎉", style: TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      print("خطأ في رفع الصورة: $e");
    } finally {
      setState(() => _isUploadingManagerImage = false);
    }
  }

  void _showUpdateNotificationDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.system_update_rounded, color: Colors.blueAccent, size: 28),
                  const SizedBox(width: 10),
                  Text("إشعار التحديثات", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              content: Text("هل أنت متأكد أنك تريد إرسال إشعار بوجود تحديث جديد لجميع أجهزة المشرفين الآن لايف؟", style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 1.5)),
              actions: [
                if (isSending)
                  const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator())
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      setStateDialog(() => isSending = true);

                      try {
                        await FirebaseFirestore.instance.collection('global_notifications').add({
                          'topic': 'app_updates',
                          'title': 'تحديث جديد متاح 🚀',
                          'body': 'تم إطلاق نسخة جديدة من التطبيق. يرجى التحديث الآن للحصول على أفضل تجربة وأحدث الميزات.',
                          'timestamp': FieldValue.serverTimestamp(),
                          'sentBy': widget.uid,
                        });

                        var supervisorsSnap = await FirebaseFirestore.instance.collection('supervisors').get();
                        
                        for (var doc in supervisorsSnap.docs) {
                          String supervisorId = doc.id;
                          var supData = doc.data();
                          String? token = supData['fcmToken']?.toString();
                          
                          if (token != null && token.isNotEmpty) {
                            NotificationService.sendAndSaveNotification(
                              studentId: supervisorId,
                              title: "تحديث جديد متاح 🚀",
                              body: "تم إطلاق نسخة جديدة من نظام الحلقات القرآني. يرجى التحديث الآن للحصول على أحدث الميزات والاستقرار.",
                              type: "app_update_alert",
                              context: context,
                            ).catchError((e) => print("فشل الإرسال: $e"));

                            await FirebaseFirestore.instance.collection('notifications').add({
                              'recipientId': supervisorId,
                              'fcmToken': token,
                              'title': "تحديث جديد متاح 🚀",
                              'body': "تم إطلاق نسخة جديدة من نظام الحلقات القرآني. يرجى التحديث الآن.",
                              'type': "app_update_alert",
                              'timestamp': FieldValue.serverTimestamp(),
                              'read': false,
                            });
                          }
                        }

                        await Future.delayed(const Duration(seconds: 1)); 
                        
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(backgroundColor: Colors.green, content: Text("تم بث إشعار التحديث لجميع أجهزة المشرفين بنجاح! 🚀", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                        );
                      } catch (e) {
                        setStateDialog(() => isSending = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(backgroundColor: Colors.redAccent, content: Text("حدث خطأ أثناء الإرسال: $e", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                        );
                      }
                    },
                    child: const Text("نعم، أرسل للجميع", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ]
              ],
            );
          }
        );
      }
    );
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
        backgroundColor: isDark ? const Color(0xff0b1120) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent, 
          centerTitle: true,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? Colors.white12 : Colors.white60),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.apps_rounded, color: isDark ? accentGold : primaryColor, size: 22),
              color: isDark ? const Color(0xff1e293b) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (value) {
                switch (value) {
                  case 'cycles':
                    _nav(const CyclesPage());
                    break;
                  case 'expenses':
                    _nav(const InstituteExpensesPage());
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
                      Icon(Icons.view_list_rounded, color: isDark ? accentGold : primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Text('عرض الدورات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ),
                // 🔒 المصروفات محصورة بالمدير فقط
                if (widget.role == "manager")
                  PopupMenuItem(
                    value: 'expenses',
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 20),
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
            widget.role == "manager" ? "لوحة المدير" : "لوحة المشرف",
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo'),
          ),
          actions: [
            if (isAlsoManager)
              IconButton(
                icon: Icon(Icons.people_alt_rounded, color: isDark ? accentGold : primaryColor),
                onPressed: () => _showSupervisorsList(isDark),
              ),
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? Colors.orangeAccent : primaryColor),
              onPressed: () => themeProvider.toggleTheme(),
            ),
            IconButton(
              onPressed: logout,
              icon: Icon(Icons.logout, color: isDark ? Colors.redAccent : Colors.red),
            ),
          ],
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
                  top: -50, left: -50,
                  child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2))),
                ),
                Positioned(
                  top: 200, right: -80,
                  child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? accentGold.withOpacity(0.1) : accentGold.withOpacity(0.15))),
                ),
              ],
            ),

            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    sliver: SliverToBoxAdapter(
                      child: _buildRealGlassHeader(isDark, currentCollection),
                    ),
                  ),
                  
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      child: _buildUltraPrayerGlassCard(isDark),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 1.1,
                      ),
                      delegate: SliverChildListDelegate([
                        if (widget.role == "manager") ...[
                          _buildPerformanceMenuCard(Icons.fact_check_rounded, "تسجيل حضور مبدئي 📋", () {
                            _nav(InitialAttendancePage(cycle: fallbackCycle));
                          }, isDark),

                          _buildPerformanceMenuCard(Icons.campaign_rounded, "إرسال إعلان للجميع", () => _nav(const BroadcastPage()), isDark),
                          _buildPerformanceMenuCard(Icons.directions_bus_rounded, "الأنشطة والرحلات 🚌⚽", () => _nav(const ActivitiesManagePage()), isDark),
                          _buildPerformanceMenuCard(Icons.update_rounded, "إشعار تحديث", () => _showUpdateNotificationDialog(isDark), isDark),
                          _buildPerformanceMenuCard(Icons.add_circle_outline, "إنشاء دورة", () => _nav(const CreateCyclePage()), isDark),
                          _buildPerformanceMenuCard(Icons.dashboard_customize, "لوحة التحكم", () => _nav(const DashboardPage()), isDark),
                          _buildPerformanceMenuCard(Icons.wb_sunny_rounded, "إدارة الإشراقات", () => _nav(const InspirationsManagePage()), isDark),
                          
                          _buildPerformanceMenuCard(Icons.person_add_alt_1, "إضافة طالب", () {
                            _nav(AddStudentPage(cycle: fallbackCycle));
                          }, isDark),
                          
                          _buildPerformanceMenuCard(Icons.group_add, "إضافة مشرفين", () => _nav(const SupervisorPage()), isDark),
                          
                          _buildPerformanceMenuCard(Icons.shuffle, "توزيع الطلاب", () {
                            _nav(AssignStudentsPage(cycle: fallbackCycle));
                          }, isDark),
                          
                          _buildPerformanceMenuCard(Icons.diamond_rounded, "بنك النقاط 💎", () => _nav(const PointsBankPage()), isDark),
                          _buildPerformanceMenuCard(Icons.query_stats, "الإحصائيات اليومية", () => _nav(const DailyStatsPage()), isDark),
                        ],

                        _buildPerformanceMenuCard(Icons.groups, "عرض الطلاب", () {
                          _nav(StudentsPage(cycle: fallbackCycle, role: widget.role, uid: widget.uid));
                        }, isDark),

                        _buildPerformanceMenuCard(Icons.mark_chat_unread_rounded, "رسائل الأهالي", () => _nav(SupervisorInboxPage(supervisorId: widget.uid)), isDark),
                        _buildPerformanceMenuCard(Icons.pie_chart_rounded, "الإحصائيات", () => _nav(const StatisticsPage()), isDark),
                        _buildPerformanceMenuCard(Icons.workspace_premium, "لوحة الشرف", () => _nav(HonorBoardPage(role: widget.role)), isDark),
                        _buildPerformanceMenuCard(Icons.event_busy_rounded, "طلبات الاستئذان", () => _nav(LeaveRequestsPage(supervisorId: widget.uid, role: widget.role)), isDark),
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

      String countdownStr = "";
      if (hoursLeft > 0) {
        countdownStr = "باقي $hoursLeft س و $minutesLeft د";
      } else {
        countdownStr = "باقي $minutesLeft دقيقة";
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff1e293b).withOpacity(0.5) : Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? accentGold.withOpacity(0.3) : primaryColor.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.3) : primaryColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? accentGold.withOpacity(0.12) : primaryColor.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isDark ? accentGold.withOpacity(0.2) : primaryColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(nextPrayer["icon"], color: isDark ? accentGold : primaryColor, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "الصلاة القادمة: ${nextPrayer['name']}",
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : primaryColor,
                                ),
                              ),
                              Text(
                                _formatTime12(nextPrayer['time'] as DateTime),
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: isDark ? accentGold : primaryColor.withOpacity(0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black38 : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? accentGold.withOpacity(0.4) : primaryColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          countdownStr,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? accentGold : primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    Color activeColor = isDark ? accentGold : primaryColor;
    String formatted = _formatTime12(time);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isNext 
            ? (isDark ? accentGold.withOpacity(0.2) : primaryColor.withOpacity(0.15))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext ? activeColor.withOpacity(0.6) : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isNext ? 18 : 15,
            color: isNext ? activeColor : (isDark ? Colors.white54 : Colors.black45),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
              color: isNext ? (isDark ? Colors.white : primaryColor) : (isDark ? Colors.grey[400] : Colors.black54),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatted,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isNext ? activeColor : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime12(DateTime time) {
    int hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Widget _buildRealGlassHeader(bool isDark, String currentCollection) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
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
                  return Column(
                    children: [
                      GestureDetector(
                        onTap: !_isUploadingManagerImage ? _updateManagerImage : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: isDark ? Colors.white12 : Colors.white54,
                              backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                              child: (imageUrl == null || imageUrl.isEmpty) && !_isUploadingManagerImage ? Icon(Icons.person, size: 45, color: isDark ? Colors.white : primaryColor) : null,
                            ),
                            if (_isUploadingManagerImage) const Positioned.fill(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.white))),
                            if (!_isUploadingManagerImage)
                              Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 14, backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white, child: Icon(Icons.camera_alt, size: 16, color: primaryColor))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.role == "manager" ? "أهلاً مدير المعهد" : (currentName != null ? "المشرف: $currentName" : "أهلاً أيها المشرف"),
                        style: TextStyle(color: isDark ? Colors.white : primaryColor, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: isDark ? accentGold : primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("الدورة الحالية", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700], fontFamily: 'Cairo')),
                          isLoadingCycle 
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(currentCycle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
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

  Widget _buildPerformanceMenuCard(IconData icon, String title, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white12 : Colors.white.withOpacity(0.75), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 38, color: isDark ? accentGold : primaryColor),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDark ? Colors.white.withOpacity(0.9) : primaryColor)),
          ],
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