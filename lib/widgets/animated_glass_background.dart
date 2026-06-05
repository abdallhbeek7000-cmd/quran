import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart'; // تأكد من مسار الثيم عندك

class AnimatedGlassBackground extends StatefulWidget {
  final Widget child; // محتوى الصفحة اللي رح يجي فوق الخلفية

  const AnimatedGlassBackground({super.key, required this.child});

  @override
  State<AnimatedGlassBackground> createState() => _AnimatedGlassBackgroundState();
}

class _AnimatedGlassBackgroundState extends State<AnimatedGlassBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // 🚀 الأنيميشن مدته 4 ثواني وبيرجع بيكرر نفسه بشكل عكسي ليعطي تأثير "التنفس"
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    // حركة ناعمة جداً باستخدام منحنى EaseInOut
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine)
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final Color primaryColor = const Color(0xff425c75);
    final Color accentGold = const Color(0xffd4af37);

    return Stack(
      children: [
        // 🌌 التدرج اللوني الأساسي (ثابت)
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
        
        // 🟡 الكرة الذهبية (أعلى اليسار): تتحرك للأسفل واليمين قليلاً وتكبر
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Positioned(
              top: -20 + (_animation.value * 25), // تنزل 25 بيكسل
              left: -50 + (_animation.value * 20), // تروح يمين 20 بيكسل
              child: Transform.scale(
                scale: 1.0 + (_animation.value * 0.15), // تكبر بنسبة 15%
                child: Container(
                  width: 250, height: 250, 
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, 
                    color: isDark ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)
                  )
                ),
              ),
            );
          }
        ),

        // 🔵 الكرة الكحلية (أسفل اليمين): تتحرك للأعلى واليسار وتصغر قليلاً
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Positioned(
              bottom: 100 + (_animation.value * 30), // تطلع 30 بيكسل
              right: -60 + (_animation.value * 25), // تروح يسار 25 بيكسل
              child: Transform.scale(
                scale: 1.1 - (_animation.value * 0.1), // تصغر بنسبة 10%
                child: Container(
                  width: 300, height: 300, 
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, 
                    color: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)
                  )
                ),
              ),
            );
          }
        ),

        // 📝 محتوى الصفحة الحقيقي بيجي هون فوق الخلفية
        widget.child,
      ],
    );
  }
}