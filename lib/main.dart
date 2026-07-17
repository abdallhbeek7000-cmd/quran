import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart'; 
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

// 🚀 محرك الخلفية الصامت والقاطع: يستيقظ فور لقط الإنترنت والتطبيق مغلق تماماً لرفع طابور الجلسات
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print("🎯 [WorkManager] تم استشعار الإنترنت بالخلفية! بدء فحص طابور الجلسات الصامت...");
    try {
      // 1. تهيئة الفايربيز مع السيرفر بالخلفية
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final prefs = await SharedPreferences.getInstance();
      
      // 2. سحب طابور الجلسات المخزنة أوفلاين
      List<String> offlineSessions = prefs.getStringList('offline_sessions_queue') ?? [];
      
      if (offlineSessions.isEmpty) {
        print("☕ [WorkManager] طابور الانتظار فارغ، لا يوجد جلسات أوفلاين معلقة.");
        return Future.value(true);
      }

      print("🔥 [WorkManager] جاري رفع (${offlineSessions.length}) جلسة معلقة إلى السيرفر لايف صامتاً وبدون فتح التطبيق...");
      
      for (String sessionJson in offlineSessions) {
        Map<String, dynamic> sessionMap = jsonDecode(sessionJson);
        String studentId = sessionMap['studentId'] ?? '';
        bool isAbsent = sessionMap['absent'] ?? false;

        // إدراج التوقيت الرسمي للسيرفر فوراً عند الرفع بالخلفية
        sessionMap['timestamp'] = FieldValue.serverTimestamp();

        // أ. رفع الجلسة مباشرة
        await FirebaseFirestore.instance.collection('sessions').add(sessionMap);

        // ب. تحديث وتصفير عداد الطالب تلقائياً لمنع تعليق شريط التنبيهات
        if (!isAbsent) {
          await FirebaseFirestore.instance.collection('students').doc(studentId).update({
            'consecutiveAbsences': 0,
          });
        } else {
          // إعادة الحساب التراكمي في الخلفية للغياب لضمان الدقة
          final snap = await FirebaseFirestore.instance.collection('sessions').where('studentId', isEqualTo: studentId).get();
          List<Map<String, dynamic>> totalSessions = snap.docs.map((e) => e.data()).toList();
          totalSessions.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
          
          int consecutive = 0;
          for (var s in totalSessions) {
            if (s['absent'] ?? false) consecutive++; else break;
          }
          await FirebaseFirestore.instance.collection('students').doc(studentId).update({'consecutiveAbsences': consecutive});
        }
      }

      // 3. مسح وتطهير طابور الكاش المحلي تماماً بعد إتمام الرفع بنجاح
      await prefs.remove('offline_sessions_queue');
      print("✅ [WorkManager] تم إفراغ الطابور كلياً ومزامنة كل البيانات بنجاح والمشرف خارج التطبيق!");
      
      return Future.value(true);
    } catch (e) {
      print("❌ [WorkManager] فشل محرك الخلفية الصامت: $e");
      return Future.value(false); // إعادة المحاولة لاحقاً في حال انقطع الاتصال مجدداً
    }
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Background message received: ${message.messageId}");
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
  
  // الاحتفاظ بإعدادات الحفظ المحلي اللامحدود للـ Offline الطبيعي
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 🚀 تهيئة الـ Workmanager وربطها بالـ callbackDispatcher المستقلة
  if (!kIsWeb) {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, 
    );

    // 🚀 جدولة وتأمين محرك الفحص الدوري الصامت بالخلفية لتبحث عن طابور المزامنة فور شبك الواي فاي أو البيانات
    await Workmanager().registerPeriodicTask(
      "periodic_sync_id_01",
      syncTaskName,
      frequency: const Duration(minutes: 15), // يفحص تلقائياً كل 15 دقيقة بالخلفية بشكل صامت
      constraints: Constraints(
        networkType: NetworkType.connected, // يشتعل قسرياً فور وجود شبكة اتصال
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

class _MyAppState extends State<MyApp> {
  bool isLoggedIn = false;
  String userRole = '';
  String userId = '';

  @override
  void initState() {
    super.initState();
    checkLogin();
    _setupInteractedMessage();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates();
    });
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