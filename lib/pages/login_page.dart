import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; 
import 'dart:math' as math; // 🚀 أضفنا مكتبة الرياضيات للزوايا
import 'home_page.dart'; 
import '../services/zego_service.dart'; // 🚀 استدعاء خدمة الاتصال (تأكد من مسار المجلد عندك)

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// 🚀 أضفنا SingleTickerProviderStateMixin عشان نشغل الأنيميشن
class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool rememberMe = false;
  bool isPasswordVisible = false;

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  late AnimationController _spinController; // 🚀 متحكم الدوران

  @override
  void initState() {
    super.initState();
    // 🚀 تهيئة الدوران ليأخذ 15 ثانية للفة الواحدة ويستمر للأبد
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose(); // تنظيف الذاكرة
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("يرجى ملء جميع الحقول", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    try {
      setState(() => loading = true);

      // 1. تسجيل الدخول عبر الفايربيز
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = credential.user!.uid;
      
      // 2. الفحص الصارم: نبحث في جدول المشرفين أولاً
      DocumentSnapshot supervisorDoc = await FirebaseFirestore.instance.collection('supervisors').doc(uid).get();
      String role = '';
      String userName = 'مستخدم'; // متغير لاسم المستخدم لخدمة الاتصال

      if (supervisorDoc.exists) {
        role = 'supervisor';
        var data = supervisorDoc.data() as Map<String, dynamic>?;
        userName = data != null && data.containsKey('name') ? data['name'] : 'مشرف';
      } else {
        // إذا لم يكن مشرفاً، نبحث في جدول المدراء
        DocumentSnapshot managerDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (managerDoc.exists) {
          role = 'manager';
          var data = managerDoc.data() as Map<String, dynamic>?;
          userName = data != null && data.containsKey('name') ? data['name'] : 'مدير';
        } else {
          throw Exception("حساب المستخدم غير موجود في النظام");
        }
      }

      // 3. 🧹 تنظيف الذاكرة القديمة بالكامل قبل الحفظ لمنع التداخل!
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); 

      // 4. 💾 حفظ البيانات الجديدة بشكل نظيف
      await prefs.setString('userRole', role); 
      await prefs.setString('role', role); 
      await prefs.setString('userId', uid);    
      
      if (rememberMe) {
        await prefs.setBool('isLoggedIn', true);
      }

      if (!mounted) return;
      
      // 🚀 5. تشغيل خدمة الاتصال ZegoCloud فوراً بعد تسجيل الدخول
      ZegoService.initCall(userId: uid, userName: userName);

      // 6. التوجيه الآمن لصفحة الهوم
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(uid: uid, role: role),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            "خطأ في تسجيل الدخول: تأكد من صحة الإيميل وكلمة المرور", 
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xffe2e8f0),
                  Color(0xffcfdef3), 
                  Color(0xffe0eafc),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // 🚀 الدائرة العلوية (بتدور مع عقارب الساعة ومدموجة بتدرج لتظهر الحركة)
          Positioned(
            top: -50,
            left: -50,
            child: RotationTransition(
              turns: _spinController,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(120), // شكل شبه دائري يعطي حركة لطيفة
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.4), primaryColor.withOpacity(0.05)],
                  ),
                ),
              ),
            ),
          ),
          
          // 🚀 الدائرة السفلية (بتدور عكس عقارب الساعة)
          Positioned(
            bottom: -100,
            right: -50,
            child: AnimatedBuilder(
              animation: _spinController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: -_spinController.value * 2 * math.pi, // الدوران العكسي
                  child: child,
                );
              },
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(140), // شكل شبه دائري
                  gradient: LinearGradient(
                    colors: [accentGold.withOpacity(0.3), accentGold.withOpacity(0.05)],
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [primaryColor, const Color(0xff1e293b)], 
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ).createShader(bounds),
                      child: Text(
                        "معهد الشيخ سعيد العبدالله",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white, 
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 3.5,
                      width: 50,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 40),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), 
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25), 
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5), 
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "أهلاً بك مجدداً 👋",
                                style: GoogleFonts.cairo(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "سجل دخولك للمتابعة والوصول للوحة التحكم",
                                style: GoogleFonts.cairo(color: Colors.black54, fontSize: 12, height: 1.4, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 28),

                              TextField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: primaryColor),
                                decoration: _glassInputDecoration("البريد الإلكتروني", Icons.mail_outline_rounded),
                              ),
                              const SizedBox(height: 16),

                              TextField(
                                controller: passwordController,
                                obscureText: !isPasswordVisible,
                                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: primaryColor),
                                decoration: _glassInputDecoration("كلمة المرور", Icons.lock_outline_rounded).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                      color: primaryColor.withOpacity(0.6),
                                      size: 18,
                                    ),
                                    onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              Theme(
                                data: Theme.of(context).copyWith(
                                  unselectedWidgetColor: primaryColor.withOpacity(0.5),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        activeColor: primaryColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        value: rememberMe,
                                        onChanged: (v) => setState(() => rememberMe = v!),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "البقاء متصلاً دائماً",
                                      style: GoogleFonts.cairo(fontSize: 12, color: primaryColor.withOpacity(0.8), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: loading ? null : login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor.withOpacity(0.9), 
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: primaryColor.withOpacity(0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    elevation: 5,
                                    shadowColor: primaryColor.withOpacity(0.4),
                                  ),
                                  child: loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                      : Text(
                                          "تسجيل الدخول",
                                          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _glassInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(color: primaryColor.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.4), 
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
    );
  }
}