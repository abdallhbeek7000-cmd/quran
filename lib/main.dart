import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/app_colors.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


runApp(const MyApp());
}

class MyApp extends StatefulWidget {

  const MyApp({
    super.key,
  });

  @override
  State<MyApp> createState() =>
      _MyAppState();
}

class _MyAppState
    extends State<MyApp> {

  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  void checkLogin() async {

    final prefs =
        await SharedPreferences.getInstance();

    final logged =
        prefs.getBool(
              'isLoggedIn',
            ) ??
            false;

    setState(() {
      isLoggedIn = logged;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  debugShowCheckedModeBanner: false,

  title: "معهد القرآن",

  theme: ThemeData(
    scaffoldBackgroundColor:
        AppColors.background,

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1565C0),
      foregroundColor: Colors.white,
      centerTitle: true,
    ),

    elevatedButtonTheme:
        ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            AppColors.primary,
        foregroundColor:
            Colors.white,
      ),
    ),
  ),

  home: isLoggedIn
    ? HomePage(
        uid: '',
        role: '',
      )
    : const LoginPage(),

  routes: {
    '/home': (context) {
      final args =
          ModalRoute.of(context)!
                  .settings
                  .arguments
              as Map;

      return HomePage(
        uid: args['uid'],
        role: args['role'],
      );
    },
  },
);
  }
  
}