import 'dart:ui'; // 🎯 ضرورية جداً لتأثير الزجاج والـ Blur
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // 🎯 ضرورية لقراءة حالة المظهر
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider الخاص بك

class DailyStatsPage extends StatelessWidget {
  const DailyStatsPage({super.key});

  // الألوان المعتمدة الفخمة الخاصة بك
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // لون مكمل فخم للانعكاسات الزجاجية

  @override
  Widget build(BuildContext context) {
    // قراءة المظهر الحالي (داكن / فاتح)
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    // المنطق البرمجي الخاص بك لجلب تاريخ اليوم
    final String todayDate = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف بالكامل
        title: Text(
          "الإحصائيات اليومية", 
          style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🧊 كرت التاريخ الزجاجي الأنيق
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.event, color: isDarkMode ? accentGold : primaryColor, size: 22),
                        const SizedBox(width: 12),
                        Text("إحصائيات اليوم: ", style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(todayDate, style: TextStyle(color: isDarkMode ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🧊 كرت الغائبين الزجاجي لايف
                  _buildStreamCard(
                    title: "عدد الغائبين اليوم",
                    icon: Icons.person_off_rounded,
                    color: Colors.redAccent,
                    stream: FirebaseFirestore.instance
                        .collection('sessions')
                        .where('date', isEqualTo: todayDate)
                        .where('absent', isEqualTo: true)
                        .snapshots(),
                    isDarkMode: isDarkMode,
                  ),

                  const SizedBox(height: 16),

                  // 🧊 كرت الحاضرين والتسميعات الزجاجي لايف
                  _buildStreamCard(
                    title: "عدد التسميعات اليوم",
                    icon: Icons.menu_book_rounded,
                    color: Colors.green,
                    stream: FirebaseFirestore.instance
                        .collection('sessions')
                        .where('date', isEqualTo: todayDate)
                        .where('absent', isEqualTo: false)
                        .snapshots(),
                    isDarkMode: isDarkMode,
                  ),

                  const SizedBox(height: 16),

                  // 🧊 كرت النسبة المئوية للحضور زجاجي لايف
                  _buildPercentageCard(todayDate, isDarkMode),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة بناء الكروت الإحصائية عبر الـ Stream
  Widget _buildStreamCard({
    required String title,
    required IconData icon,
    required Color color,
    required Stream<QuerySnapshot> stream,
    required bool isDarkMode,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String value = "0";
        if (snapshot.hasData) {
          value = snapshot.data!.docs.length.toString();
        }
        return _statsUI(title, value, icon, color, snapshot.connectionState == ConnectionState.waiting, isDarkMode);
      },
    );
  }

  // دالة حساب النسبة المئوية الذكية للحضور
  Widget _buildPercentageCard(String todayDate, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('date', isEqualTo: todayDate)
          .snapshots(),
      builder: (context, snapshot) {
        String percentage = "0%";
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs;
          int presentCount = docs.where((doc) => doc['absent'] == false).length;
          percentage = "${((presentCount / docs.length) * 100).round()}%";
        }
        return _statsUI(
          "نسبة الحضور اليوم", 
          percentage, 
          Icons.pie_chart_rounded, 
          isDarkMode ? accentGold : Colors.blue, 
          snapshot.connectionState == ConnectionState.waiting, 
          isDarkMode
        );
      },
    );
  }

  // 🧊 التصميم الزجاجي الموحد والمحدث لكل كروت الإحصائيات (Liquid Glass)
  Widget _statsUI(String title, String value, IconData icon, Color color, bool isLoading, bool isDarkMode) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[700], fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(value, style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(isDarkMode ? 0.15 : 0.1), 
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
        ],
      ),
    );
  }

  // 🧊 أداة مساعدة لتغليف العناصر وتطبيق تأثير الزجاج (Glassmorphism)
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.02),
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
}