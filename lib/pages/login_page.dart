import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool rememberMe = false;
  bool isPasswordVisible = false;

  // اللون المعتمد الفخم الخاص بك
  final Color primaryColor = const Color(0xff425c75);

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

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = credential.user!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        userDoc = await FirebaseFirestore.instance.collection('supervisors').doc(uid).get();
      }

      if (!userDoc.exists) throw Exception("المستخدم غير موجود");

      final role = userDoc['role'];

      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userRole', role); 
        await prefs.setString('userId', uid);    
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {'uid': uid, 'role': role},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            "خطأ: ${e.toString().replaceAll('Exception: ', '')}", 
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🎨 1. الخلفية الانسيابية المتدرجة الناعمة
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xfff1f5f9), 
                  Color(0xffe2e8f0), 
                  Color(0xfff8fafc), 
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),

          // 📐 2. دوائر هندسية عائمة هادئة جداً بالخلفية
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.04), 
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff6482a2).withOpacity(0.05),
              ),
            ),
          ),

          // 🏢 3. المحتوى الأساسي للواجهة
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20), // تعويض المسافة لراحة بصرية أفضل بعد الحذف

                    // 🏢 شعار المعهد الملوكي بـ التدرج اللوني وخط Cairo الصافي
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [primaryColor, const Color(0xff6482a2)], 
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
                      width: 40,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 35),

                    // 💳 كرت تسجيل الدخول العائم الـ Minimalist
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.035),
                            blurRadius: 25,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "أهلاً بك مجدداً 👋",
                            style: GoogleFonts.cairo(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "سجل دخولك للمتابعة والوصول للوحة التحكم",
                            style: GoogleFonts.cairo(color: Colors.grey.shade500, fontSize: 11.5, height: 1.4),
                          ),
                          const SizedBox(height: 28),

                          // ✉️ حقل الإيميل الذكي
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: "البريد الإلكتروني",
                              labelStyle: GoogleFonts.cairo(color: Colors.grey.shade500, fontSize: 12.5),
                              prefixIcon: Icon(Icons.mail_outline_rounded, color: primaryColor, size: 20),
                              filled: true,
                              fillColor: const Color(0xfff8fafc),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(color: Colors.grey.shade100, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(color: primaryColor, width: 1.2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 🔒 حقل كلمة المرور الذكي
                          TextField(
                            controller: passwordController,
                            obscureText: !isPasswordVisible,
                            style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: "كلمة المرور",
                              labelStyle: GoogleFonts.cairo(color: Colors.grey.shade500, fontSize: 12.5),
                              prefixIcon: Icon(Icons.lock_outline_rounded, color: primaryColor, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  color: Colors.grey.shade400,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                              ),
                              filled: true,
                              fillColor: const Color(0xfff8fafc),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(color: Colors.grey.shade100, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(color: primaryColor, width: 1.2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ☑️ خيار البقاء مسجلاً (Remember Me)
                          Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: Colors.grey.shade300,
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
                                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // 🚀 زر الدخول الملوكي الصافي
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: loading ? null : login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: primaryColor.withOpacity(0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 0,
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
                                      style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                                    ),
                            ),
                          ),
                        ],
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
}