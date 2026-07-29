import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_provider.dart';
import '../widgets/offline_wrapper.dart';
import 'home_page.dart';
import 'login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  @override
  void initState() {
    super.initState();

    // ⏳ إعداد أنيميشن سريع وخفيف جُداً لا يرهق معالج الهاتف
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    // 🚀 الانتقال السريع بعد 2 ثانية فقط لراحة المستخدم
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 2000));

    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String userRole = prefs.getString('userRole') ?? '';
    final String userId = prefs.getString('userId') ?? '';

    if (!mounted) return;

    Widget targetPage = isLoggedIn
        ? OfflineWrapper(child: HomePage(uid: userId, role: userRole))
        : const LoginPage();

    // 🚀 انتقال خفيف وسريع بدون استهلاك الذاكرة
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      // خلفية متدرجة خفيفة بدون بلور ثقيل
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [const Color(0xff0f172a), const Color(0xff1e293b)]
                : [const Color(0xffe2e8f0), const Color(0xffcfdef3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // 🕌 الشعار المباشر الانسيابي
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🌟 حاوية خفيفة وأنيقة بحواف ناعمة ودون معالجة رسومية ثقيلة
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.black26 : Colors.white.withOpacity(0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode ? accentGold.withOpacity(0.5) : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo500.png', // 👈 الشعار الخاص بالمسجد والمعهد
                          width: 130,
                          height: 140,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.mosque_rounded,
                            size: 100,
                            color: accentGold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // 🕌 اسم المعهد والوصف
                      Text(
                        "معهد الشيخ سعيد العبدالله",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: isDarkMode ? Colors.white : primaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "خدمة القرآن الكريم وعلومه 📖",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? accentGold : primaryColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ⏳ مؤشر تحميل خفيف وجذاب
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(accentGold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}