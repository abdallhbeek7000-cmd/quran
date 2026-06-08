import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🎯 استيراد للتحكم بشريط الحالة (Status Bar)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🚀 استدعاء مكتبة الفايرستور للتحكم بالأوفلاين
import 'package:provider/provider.dart'; 
// 🚀 استدعاء مكتبة اللغات لقلب التطبيق من اليمين لليسار
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_habal/widgets/offline_wrapper.dart'; 
import 'firebase_options.dart';
import 'utils/app_colors.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/update_checker.dart'; 
import 'services/theme_provider.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

// 🎯 المفتاح العالمي السحري للتحكم بالمنبثقات من أي مكان بالتطبيق
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🎯 اللمسة السحرية: جعل شريط البطارية والساعة شفاف بالكامل ليتناسب مع الزجاج الانسيابي
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      statusBarIconBrightness: Brightness.dark, 
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 🚀 السحر الحقيقي: تفعيل وضع الأوفلاين وحفظ البيانات محلياً بذاكرة الجوال
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  FirebaseStorage.instanceFor(bucket: "gs://quran-habal.firebasestorage.app");
  
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
    
    // 🎯 تشغيل الفحص فوراً عند تشغيل التطبيق بأمان كامل وبدون الاعتماد على الـ Build Context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates();
    });
  }

  void checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final logged = prefs.getBool('isLoggedIn') ?? false;
    final role = prefs.getString('userRole') ?? '';
    final uid = prefs.getString('userId') ?? '';

    setState(() {
      isLoggedIn = logged;
      userRole = role;
      userId = uid;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    const Color primaryColor = Color(0xff425c75); 
    const Color accentGold = Color(0xffd4af37); // 🎯 لون الزجاج الذهبي

    return MaterialApp(
      navigatorKey: navigatorKey, // 🎯 ربط المفتاح العالمي بالـ MaterialApp
      debugShowCheckedModeBanner: false,
      title: "معهد الشيخ سعيد العبدالله",
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // 🚀 الأسطر السحرية لقلب التطبيق بالكامل ليصبح عربي (RTL)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'), // 👈 دعم اللغة العربية
      ],
      locale: const Locale('ar', 'AE'), // 👈 فرض العربية كلغة أساسية وإجبارية

      // ☀️ السمة النهارية (الزجاج الفاتح)
      theme: ThemeData(
        fontFamily: 'Cairo', // 🎯 توحيد خط Cairo على مستوى التطبيق بالكامل
        brightness: Brightness.light,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xfff1f5f9), // خلفية زجاجية فاتحة
        colorScheme: const ColorScheme.light(
          primary: primaryColor,
          secondary: accentGold,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // شفاف ليسمح بظهور التدرج الزجاجي
          foregroundColor: primaryColor,
          centerTitle: true,
          elevation: 0,
        ),
        dialogBackgroundColor: Colors.white.withOpacity(0.95), // شفافية للـ Dialogs
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
        ),
      ),

      // 🌙 السمة الليلية (الزجاج الداكن الفخم)
      darkTheme: ThemeData(
        fontFamily: 'Cairo', // 🎯 توحيد خط Cairo
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xff121212), // خلفية ليلية عميقة
        colorScheme: const ColorScheme.dark(
          primary: accentGold,
          secondary: primaryColor,
        ),
        cardTheme: const CardTheme(
          color: Color(0xff1e293b),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // شفاف 
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        dialogBackgroundColor: const Color(0xff1e293b).withOpacity(0.95),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: const Color(0xff1e293b).withOpacity(0.95),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
        ),
      ),

      // 🚀 تغليف الصفحة الرئيسية عند فتح التطبيق
      home: isLoggedIn
          ? OfflineWrapper(child: HomePage(uid: userId, role: userRole)) 
          : const LoginPage(),
          
      // 🚀 استخدام onGenerateRoute بدلاً من routes لتفادي مشاكل الـ Context والـ Null 
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          // فحص أمان لتفادي الكراش إذا تم استدعاء الصفحة بدون Arguments
          final args = (settings.arguments as Map<String, dynamic>?) ?? {'uid': '', 'role': ''};
          
          return MaterialPageRoute(
            builder: (context) => OfflineWrapper( // 👈 التغليف شغال بكل أمان هنا
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