import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // 🎯 ضرورية لقراءة المظهر
import 'package:quran_habal/services/cloudinary_helper.dart';
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider الخاص بك
import 'dart:ui'; // 🎯 ضرورية جداً لتأثير الزجاج والـ Blur

class AddSupervisorPage extends StatefulWidget {
  const AddSupervisorPage({super.key});

  @override
  State<AddSupervisorPage> createState() => _AddSupervisorPageState();
}

class _AddSupervisorPageState extends State<AddSupervisorPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // لون مكمل للانعكاسات الزجاجية
  bool _obscurePassword = true; 
  bool _loading = false;
  
  String? _uploadedImageUrl;
  bool _uploadingImage = false;

  Future<void> _pickAndUploadImage() async {
    setState(() => _uploadingImage = true);
    try {
      String? url = await CloudinaryHelper.pickAndUploadProfileImage();
      if (url != null) {
        setState(() {
          _uploadedImageUrl = url;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text("تم رفع الصورة بنجاح 🎉")),
        );
      }
    } catch (e) {
      print("خطأ في الرفع: $e");
    } finally {
      setState(() => _uploadingImage = false);
    }
  }

  Future<void> _createSupervisor() async {
    if (nameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى ملء جميع الحقول")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('supervisors')
          .doc(credential.user!.uid)
          .set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'uid': credential.user!.uid,
        'role': 'supervisor',
        'imageUrl': _uploadedImageUrl ?? '', 
        'createdAt': DateTime.now().toString(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("تمت إضافة المشرف بنجاح")),
      );
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(e.toString())),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف بالكامل
        title: Text("إضافة مشرف جديد", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية الانسيابية المتدرجة مع الأشكال العائمة
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -20,
            right: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          // 🏢 2. المحتوى الأساسي للواجهة
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  
                  // 🧊 3. هيدر اختيار الصورة بستايل زجاجي دائري فخم
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _uploadingImage ? null : _pickAndUploadImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08), blurRadius: 15, offset: const Offset(0, 5)),
                                  ]
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                  backgroundImage: _uploadedImageUrl != null
                                      ? NetworkImage(_uploadedImageUrl!)
                                      : null,
                                  child: _uploadedImageUrl == null && !_uploadingImage
                                      ? Icon(Icons.add_a_photo_outlined, size: 40, color: isDarkMode ? Colors.white70 : primaryColor)
                                      : null,
                                ),
                              ),
                              if (_uploadingImage)
                                const Positioned.fill(
                                  child: Padding(
                                    padding: EdgeInsets.all(10.0),
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _uploadedImageUrl == null ? "اضغط لإضافة صورة شخصية للمشرف" : "تم اختيار الصورة بنجاح ✨",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDarkMode ? Colors.white70 : primaryColor.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🧊 4. كرت البيانات الزجاجي الرئيسي للـ Form
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        // حقل الاسم زجاجي
                        TextField(
                          controller: nameController,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          decoration: _glassInputDecoration("اسم المشرف الكامل", Icons.person_outline, isDarkMode),
                        ),
                        const SizedBox(height: 16),

                        // حقل الإيميل زجاجي
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          decoration: _glassInputDecoration("البريد الإلكتروني", Icons.email_outlined, isDarkMode),
                        ),
                        const SizedBox(height: 16),

                        // حقل كلمة السر زجاجي مع خيار الإخفاء/الإظهار المتناسق
                        TextField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          decoration: _glassInputDecoration("كلمة السر", Icons.lock_outline, isDarkMode).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: isDarkMode ? accentGold : primaryColor),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // 🚀 زر إنشاء الحساب الزجاجي الملوكي
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _createSupervisor,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9),
                              foregroundColor: Colors.white,
                              elevation: 5,
                              shadowColor: Colors.black38,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: _loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    "إنشاء الحساب",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🧊 دالة بناء الحاوية الزجاجية المشتركة (Glassmorphism)
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // 🧊 دالة تنسيق الحقول بالستايل الزجاجي الشفاف النظيف
  InputDecoration _glassInputDecoration(String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600, fontSize: 13),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), 
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15), 
        borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15), 
        borderSide: BorderSide(color: isDarkMode ? accentGold : primaryColor, width: 1.5),
      ),
    );
  }
}