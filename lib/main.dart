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
import 'package:quran_habal/widgets/offline_wrapper.dart'; 
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart'; 
import 'firebase_options.dart';
import 'utils/app_colors.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/update_checker.dart'; 
import 'services/theme_provider.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const String syncTaskName = "sync_sessions_data_forced";

// 💬 إنشاء كائن الإشعارات المحلية لتجميع الرسائل
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// 🚀 محرك الخلفية القاطع: يستيقظ فوراً عند توفر الإنترنت حتى لو التطبيق مغلق
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print("🎯 [Background Worker] تم استشعار تغيير بالشبكة! بدء الفحص والمزامنة الصامتة...");
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final prefs = await SharedPreferences.getInstance();
      
      List<String> offlineSessions = prefs.getStringList('offline_sessions_queue') ?? [];
      
      if (offlineSessions.isEmpty) {
        print("☕ [Background Worker] لا توجد جلسات أوفلاين معلقة.");
        return Future.value(true);
      }

      print("🔥 [Background Worker] جاري رفع (${offlineSessions.length}) جلسة معلقة للسيرفر فوراً...");
      
      List<String> remainingSessions = [];

      for (String sessionJson in offlineSessions) {
        try {
          Map<String, dynamic> sessionMap = jsonDecode(sessionJson);
          String studentId = sessionMap['studentId'] ?? '';
          bool isAbsent = sessionMap['absent'] ?? false;

          sessionMap['timestamp'] = FieldValue.serverTimestamp();

          // 1. الرفع الفوري
          await FirebaseFirestore.instance.collection('sessions').add(sessionMap);

          // 2. تصفير غيابات الطالب فوراً
          if (!isAbsent && studentId.isNotEmpty) {
            await FirebaseFirestore.instance.collection('students').doc(studentId).update({
              'consecutiveAbsences': 0,
            });
          }
        } catch (e) {
          print("⚠️ فشل رفع إحدى الجلسات، ستبقى بالطابور للمحاولة القادمة: $e");
          remainingSessions.add(sessionJson);
        }
      }

      // تحديث الطابور بما تبقى
      await prefs.setStringList('offline_sessions_queue', remainingSessions);
      print("✅ [Background Worker] إتمام معالجة طابور الأوفلاين بنجاح!");
      
      return Future.value(true);
    } catch (e) {
      print("❌ [Background Worker] خطأ أثناء المزامنة: $e");
      return Future.value(false);
    }
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Background message received: ${message.messageId}");
}

// 💬 دالة إظهار الإشعار المحلي التجميعي عند وصول رسائل شات
Future<void> _showGroupedLocalNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;
  Map<String, dynamic> data = message.data;

  if (notification == null) return;

  String studentId = data['studentId'] ?? 'default';

  // 🎯 توحيد معرف الإشعار حسب الطالب لدمجه واستبدال الإشعار القديم
  int targetId = studentId.hashCode.abs();

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'إشعارات عالية الأهمية',
    channelDescription: 'قناة إشعارات الرسائل والتنبيهات اليومية',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    targetId,
    notification.title ?? '',
    notification.body ?? '',
    platformDetails,
    payload: jsonEncode(data),
  );
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

  // 💬 تهيئة الإشعارات المحلية
  if (!kIsWeb) {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }
  
  // تفعيل الكاش المحلي اللامحدود لفايرستور
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 🚀 تهيئة محرك الخلفية الفوري
  if (!kIsWeb) {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, 
    );

    // تسجيل مهمة فورية ودورية تعمل عند الاتصال بالشبكة
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
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
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
  bool isLoggedIn = false;
  String userRole = '';
  String userId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    checkLogin();
    _setupInteractedMessage();
    
    // 💬 الاستماع المباشر للإشعارات القادمة أثناء عمل التطبيق
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

  // 🚀 تشغيل المزامنة الفورية فور عودة التطبيق للعمل
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
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  void _handleNotificationTap(RemoteMessage message) {
    print("Notification tapped! Data: ${message.data}");
  }

  void checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final logged = prefs.getBool('isLoggedIn') ?? false;
    final role = prefs.getString('userRole') ?? '';
    final uid = prefs.getString('userId') ?? '';

    if (mounted) {
      setState(() {
        isLoggedIn = logged;
        userRole = role;
        userId = uid;
      });
    }
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
          centerTitle: centerTitleDefault, 
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white.withValues(alpha: 0.95),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.white.withValues(alpha: 0.95),
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
          centerTitle: centerTitleDefault,
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xff1e293b).withValues(alpha: 0.95),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: const Color(0xff1e293b).withValues(alpha: 0.95),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
        ),
      ),

      home: isLoggedIn
          ? OfflineWrapper(child: HomePage(uid: userId, role: userRole)) 
          : const LoginPage(),
          
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

const bool centerTitleDefault = true;