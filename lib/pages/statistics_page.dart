import 'dart:ui'; // 🎯 ضرورية لتأثير الزجاج والـ Blur
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // 🎯 لقراءة حالة المظهر
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider الخاص بك

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // لون الإنعكاس الزجاجي

  @override
  Widget build(BuildContext context) {
    // قراءة المظهر الحالي (داكن / فاتح)
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف بالكامل
        title: Text(
          "الإحصائيات الشاملة", 
          style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo'),
        ),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية المتدرجة الانسيابية مع الدوائر العائمة (Blobs)
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
            top: -30,
            left: -50,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.07) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
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
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // 🧊 كرت عدد الطلاب
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('students').snapshots(),
                    builder: (context, snapshot) {
                      String count = "0";
                      if (snapshot.hasData) {
                        count = snapshot.data!.docs.length.toString();
                      }
                      return _buildGlassCard(
                        title: "إجمالي الطلاب",
                        value: count,
                        icon: Icons.people_alt_rounded,
                        color: isDarkMode ? Colors.lightBlueAccent : Colors.blue,
                        isLoading: snapshot.connectionState == ConnectionState.waiting,
                        isDarkMode: isDarkMode,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 🧊 كرت عدد المشرفين
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'supervisor')
                        .snapshots(),
                    builder: (context, snapshot) {
                      String count = "0";
                      if (snapshot.hasData) {
                        count = snapshot.data!.docs.length.toString();
                      }
                      return _buildGlassCard(
                        title: "إجمالي المشرفين",
                        value: count,
                        icon: Icons.admin_panel_settings_rounded,
                        color: isDarkMode ? accentGold : Colors.amber.shade700,
                        isLoading: snapshot.connectionState == ConnectionState.waiting,
                        isDarkMode: isDarkMode,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 🧊 كرت عدد الجلسات
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
                    builder: (context, snapshot) {
                      String count = "0";
                      if (snapshot.hasData) {
                        count = snapshot.data!.docs.length.toString();
                      }
                      return _buildGlassCard(
                        title: "إجمالي الجلسات المُسجلة",
                        value: count,
                        icon: Icons.menu_book_rounded,
                        color: Colors.greenAccent.shade400,
                        isLoading: snapshot.connectionState == ConnectionState.waiting,
                        isDarkMode: isDarkMode,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 🧊 كرت عدد الغيابات التراكمية
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('sessions')
                        .where('absent', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      String count = "0";
                      if (snapshot.hasData) {
                        count = snapshot.data!.docs.length.toString();
                      }
                      return _buildGlassCard(
                        title: "إجمالي حالات الغياب",
                        value: count,
                        icon: Icons.person_off_rounded,
                        color: Colors.redAccent,
                        isLoading: snapshot.connectionState == ConnectionState.waiting,
                        isDarkMode: isDarkMode,
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🧊 أداة الكرت الإحصائي بستايل الزجاج (Glassmorphism)
  Widget _buildGlassCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required bool isDarkMode,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 25),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[700], fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 12),
                  isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(
                          value,
                          style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
                        ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDarkMode ? 0.15 : 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.2), width: 1),
                ),
                child: Icon(icon, color: color, size: 35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}