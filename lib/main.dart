import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart'; 
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart'; 

// 🔑 مكاتب التوقيت والمنطقة الزمنية للإشعارات المجدولة
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/splash_screen.dart'; 
import 'pages/update_checker.dart'; 
import 'pages/leave_requests_page.dart'; // 📝 استيراد صفحة طلبات الاستئذان المعدلة
import 'services/theme_provider.dart'; 
import 'services/prayer_service.dart'; // 🕌 خدمة أوقات الصلاة
import 'services/cycle_service.dart';  // 🔄 خدمة الدورات
import 'models/cycle_model.dart';      // 📖 موديل الدورة
import 'widgets/offline_wrapper.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const String syncTaskName = "sync_sessions_data_forced";

// 💬 إنشاء كائن الإشعارات المحلية لتجميع الرسائل والتنبيهات
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// 🚀 محرك الخلفية: يستيقظ فوراً عند توفر الإنترنت والتطبيق مغلق لرفع الكاش أوتوماتيكياً
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print("🎯 [Background Worker] تم استشعار تغيير بالشبكة! بدء رفع الجلسات المعلقة بالخلفية...");
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      
      // ⚡ إجبار محرك الفايرستور على دفع ومزامنة كافة التغييرات الجاهزة بالذاكرة المحلية للسيرفر
      await FirebaseFirestore.instance.waitForPendingWrites();

      print("✅ [Background Worker] تم مزامنة ورفع كاش الجلسات المعلقة بنجاح دون أي تكرار!");
      return Future.value(true);
    } catch (e) {
      print("❌ [Background Worker] خطأ أثناء المزامنة بالخلفية: $e");
      return Future.value(false);
    }
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Background message received: ${message.messageId}");
}

// 💬 دالة إظهار الإشعار المحلي التجميعي الذكي مثل واتساب
Future<void> _showGroupedLocalNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;
  Map<String, dynamic> data = message.data;

  if (notification == null) return;

  String studentId = data['studentId'] ?? 'default_group';
  String groupKey = 'com.quran_habal.MESSAGES_$studentId';

  int messageId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  int summaryId = studentId.hashCode.abs();

  AndroidNotificationDetails androidIndividualDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'إشعارات المحادثات والرسائل',
    channelDescription: 'قناة تجميع إشعارات المحادثات اليومية',
    importance: Importance.max,
    priority: Priority.high,
    groupKey: groupKey,
  );

  NotificationDetails platformIndividualDetails = NotificationDetails(android: androidIndividualDetails);

  await flutterLocalNotificationsPlugin.show(
    messageId,
    notification.title ?? '',
    notification.body ?? '',
    platformIndividualDetails,
    payload: jsonEncode(data),
  );

  AndroidNotificationDetails androidSummaryDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'إشعارات المحادثات والرسائل',
    channelDescription: 'قناة تجميع إشعارات المحادثات اليومية',
    importance: Importance.max,
    priority: Priority.high,
    groupKey: groupKey,
    setAsGroupSummary: true,
  );

  NotificationDetails platformSummaryDetails = NotificationDetails(android: androidSummaryDetails);

  await flutterLocalNotificationsPlugin.show(
    summaryId,
    notification.title ?? '',
    notification.body ?? '',
    platformSummaryDetails,
    payload: jsonEncode(data),
  );
}

// 🎯 دالة التوجيه المباشر لصفحة الاستئذان بناءً على بيانات الإشعار
void _navigateToTargetPage(Map<String, dynamic> data) {
  print("🚀 جاري التوجيه من الإشعار مع البيانات: $data");

  String type = data['type']?.toString().toLowerCase() ?? '';

  // 📝 عند استقبال إشعار طلب استئذان جديد أو إشعارات الاستئذان المرتبطة
  if (type == 'leave_request' || type == 'permission_request' || type == 'permission' || type == 'leave_status') {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => LeaveRequestsPage(
          studentId: data['studentId']?.toString(),
          requestId: data['requestId']?.toString(),
          supervisorId: data['supervisorId']?.toString() ?? '',
          role: data['role']?.toString() ?? 'manager',
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      statusBarIconBrightness: Brightness.dark, 
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ⚡ إعداد الكاش المحلي وحفظ البيانات أوفلاين لـ Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 🚀 تهيئة التخزين المحلي المبكر
  await SharedPreferences.getInstance();

  // 🌍 🔑 تهيئة التوقيت والمنطقة الزمنية المحلية لحساب الجدولة الدقيقة للإشعارات
  try {
    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));
  } catch (e) {
    print("⚠️ فشل تحديد المنطقة الزمنية تلقائياً، سيتم استخدام UTC: $e");
  }

  // 💬 تهيئة الإشعارات المحلية وإشعارات أوقات الصلاة
  if (!kIsWeb) {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final InitializationSettings initSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // 🔔 ربط الاستماع للنقر على الإشعارات المحلية التجميعية
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            Map<String, dynamic> data = jsonDecode(response.payload!);
            _navigateToTargetPage(data);
          } catch (e) {
            print("❌ خطأ في فك تشفير حمولة الإشعار المحلي: $e");
          }
        }
      },
    );

    // 🔑 طلب صلاحية الإشعارات لأندرويد 13+
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    // 🕌 جدولة تنبيهات أوقات الصلاة لـ (المغرب والعشاء) قبل 10 و5 دقائق
    try {
      await PrayerService.schedulePrayerAlerts(flutterLocalNotificationsPlugin);
    } catch (e) {
      print("❌ خطأ في جدولة إشعارات الصلاة: $e");
    }
  }

  // 🚀 تهيئة محرك الخلفية الفوري
  if (!kIsWeb) {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, 
    );

    await Workmanager().registerPeriodicTask(
      "periodic_sync_id_01",
      syncTaskName,
      frequency: const Duration(minutes: 15), 
      constraints: Constraints(
        networkType: NetworkType.connected, 
      ),
    );
  }

  FirebaseStorage.instanceFor(bucket: "gs://quran-habal.firebasestorage.app");
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // 3️⃣ استخدام MultiProvider لبث الدورة النشطة + الثيمات لجميع أرجاء التطبيق
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        StreamProvider<CycleModel?>(
          create: (_) => CycleService().streamCurrentCycle(),
          initialData: null,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupInteractedMessage();
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showGroupedLocalNotification(message);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates();
      _triggerInstantSyncIfOnline();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerInstantSyncIfOnline();
    }
  }

  void _triggerInstantSyncIfOnline() {
    if (!kIsWeb) {
      Workmanager().registerOneOffTask(
        "instant_sync_${DateTime.now().millisecondsSinceEpoch}",
        syncTaskName,
        constraints: Constraints(networkType: NetworkType.connected),
      ).catchError((_) {});
    }
  }

  Future<void> _setupInteractedMessage() async {
    // 1️⃣ عند فتح التطبيق من حالة الإغلاق التام عبر ضغط الإشعار
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // 2️⃣ عند فتح التطبيق من الخلفية عبر ضغط الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  void _handleNotificationTap(RemoteMessage message) {
    print("Notification tapped! Data: ${message.data}");
    _navigateToTargetPage(message.data);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    const Color primaryColor = Color(0xff425c75); 
    const Color accentGold = Color(0xffd4af37); 

    return MaterialApp(
      navigatorKey: navigatorKey, 
      debugShowCheckedModeBanner: false,
      title: "معهد الشيخ سعيد العبدالله",
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'), 
      ],
      locale: const Locale('ar', 'AE'), 

      theme: ThemeData(
        fontFamily: 'Cairo', 
        brightness: Brightness.light,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xfff1f5f9), 
        colorScheme: const ColorScheme.light(
          primary: primaryColor,
          secondary: accentGold,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, 
          foregroundColor: primaryColor,
          centerTitle: true, 
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white.withOpacity(0.95),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
        ),
      ),

      darkTheme: ThemeData(
        fontFamily: 'Cairo', 
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xff121212), 
        colorScheme: const ColorScheme.dark(
          primary: accentGold,
          secondary: primaryColor,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xff1e293b), 
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, 
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xff1e293b).withOpacity(0.95),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: const Color(0xff1e293b).withOpacity(0.95),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
        ),
      ),

      home: const SplashScreen(),
        
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          final args = (settings.arguments as Map<String, dynamic>?) ?? {'uid': '', 'role': ''};
          
          return MaterialPageRoute(
            builder: (context) => OfflineWrapper( 
              child: HomePage(
                uid: args['uid'],
                role: args['role'],
              ),
            ),
          );
        }
        return null;
      },
    );
  }
}