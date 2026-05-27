import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart'; 
import 'firebase_options.dart';
import 'utils/app_colors.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/update_checker.dart'; // تأكد من مسار الملف عندك
import 'services/theme_provider.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

// 🎯 المفتاح العالمي السحري للتحكم بالمنبثقات من أي مكان بالتطبيق
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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

    return MaterialApp(
      navigatorKey: navigatorKey, // 🎯 ربط المفتاح العالمي بالـ MaterialApp الحين غصب
      debugShowCheckedModeBanner: false,
      title: "معهد القرآن",
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xff121212),
        cardTheme: const CardTheme(
          color: Color(0xff1e1e1e),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff1f2d3d),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),

      home: isLoggedIn
          ? HomePage(uid: userId, role: userRole) 
          : const LoginPage(),
          
      routes: {
        '/home': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return HomePage(
            uid: args['uid'],
            role: args['role'],
          );
        },
      },
    );
  }
}