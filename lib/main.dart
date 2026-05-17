import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart'; // استيراد مكتبة الاستورج الجديدة
import 'package:provider/provider.dart'; 
import 'firebase_options.dart';
import 'utils/app_colors.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'services/theme_provider.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 🔥 إجبار التطبيق على الاتصال بالـ Storage وتفعيله برابط المشروع لتخطي تعليق الموقع
  FirebaseStorage.instanceFor(bucket: "gs://quran-habal.firebasestorage.app");
  
  runApp(
    // تغليف التطبيق بالـ Provider لتمرير حالة الثيم لكل الصفحات
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
    // مراقبة حالة الوضع الليلي من الـ Provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // اللون الكحلي الفخم الخاص بتطبيقك
    const Color primaryColor = Color(0xff425c75); 

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "معهد القرآن",
      
      // تحديد الثيم بناءً على اختيار المستخدم عبر الزر
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // 1. ثيم الوضع الفاتح (Light Theme)
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

      // 2. ثيم الوضع الليلي الفخم (Dark Theme)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xff121212), // أسود مريح للعين
        cardTheme: const CardTheme(
          color: Color(0xff1e1e1e), // لون الكروت بالوضع الليلي
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff1f2d3d), // لون الـ AppBar بالوضع الليلي
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