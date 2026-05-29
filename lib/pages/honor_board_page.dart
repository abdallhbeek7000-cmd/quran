import 'dart:ui'; // 🎯 ضرورية لتأثير الزجاج والـ Blur
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../services/theme_provider.dart';
import 'manage_honor_board_page.dart'; 

class HonorBoardPage extends StatelessWidget {
  final String role; 

  const HonorBoardPage({super.key, required this.role}); 

  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37); 
  final Color silverColor = const Color(0xffC0C0C0); 
  final Color bronzeColor = const Color(0xffCD7F32); 

  Stream<DocumentSnapshot> getHonorCategory(String categoryId) {
    return FirebaseFirestore.instance.collection('honor_board').doc(categoryId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف
        title: Text("لوحة الشرف والتميز", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
        actions: [
          if (role == "manager")
            IconButton(
              icon: Icon(Icons.edit_calendar, color: isDarkMode ? goldColor : primaryColor),
              tooltip: "إدارة لوحة الشرف",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageHonorBoardPage())),
            )
        ],
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية الانسيابية مع الدوائر العائمة (Blobs)
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
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? goldColor.withOpacity(0.08) : goldColor.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          // 🏢 2. المحتوى الأساسي للواجهة
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // 🧊 كرت "فرسان الحلقة" بستايل زجاجي ملكي
                _buildGlassContainer(
                  isDarkMode: isDarkMode,
                  padding: const EdgeInsets.all(20),
                  customColor: isDarkMode ? goldColor.withOpacity(0.15) : goldColor.withOpacity(0.2),
                  customBorderColor: goldColor.withOpacity(0.5),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 55),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("فرسان الحلقة", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            const SizedBox(height: 5),
                            Text("الطلاب الثلاثة الأكثر تميزاً وإنجازاً باختيار الإدارة", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 25),

                // 🧊 الأقسام الزجاجية للفرسان
                _buildCategorySection("الطلاب الجدد", "new_students", isDarkMode ? Colors.lightBlueAccent : Colors.blue, Icons.auto_awesome, isDarkMode),
                const SizedBox(height: 25),
                _buildCategorySection("الطلاب القدماء", "old_students", Colors.orange, Icons.history_edu, isDarkMode),
                const SizedBox(height: 25),
                _buildCategorySection("الطلاب الخاتمين", "completed_students", Colors.green, Icons.verified, isDarkMode),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String title, String categoryId, Color accentColor, IconData icon, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
            ],
          ),
        ),
        StreamBuilder<DocumentSnapshot>(
          stream: getHonorCategory(categoryId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }
            if (!snapshot.data!.exists) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text("لم يتم اختيار فرسان هذه الفئة بعد.", style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              );
            }

            var data = snapshot.data!.data() as Map<String, dynamic>;
            List<dynamic> positions = [data['first'], data['second'], data['third']];

            return Column(
              children: List.generate(3, (index) {
                var student = positions[index];
                if (student == null || student['name'] == "لم يحدد") return const SizedBox();

                Color medalColor = index == 0 ? goldColor : (index == 1 ? silverColor : bronzeColor);
                bool isFirst = index == 0;

                // 1️⃣ قراءة الرقم التسلسلي بأمان بجميع حالاته
                final dynamic rawSerial = student['serial'];
                final int serialNumber = rawSerial is int 
                    ? rawSerial 
                    : (int.tryParse(rawSerial?.toString() ?? '') ?? 0);

                // 2️⃣ جلب بيانات الطالب الأصلية وصورته
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('students')
                      .where('serial', whereIn: [serialNumber, serialNumber.toString()])
                      .limit(1)
                      .get(),
                  builder: (context, studentSnapshot) {
                    String imageUrl = '';
                    if (studentSnapshot.hasData && studentSnapshot.data!.docs.isNotEmpty) {
                      var studentData = studentSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                      imageUrl = studentData['imageUrl'] ?? '';
                    }

                    final String studentName = student['name'] ?? '';
                    final String firstLetter = studentName.isNotEmpty ? studentName.trim().substring(0, 1) : "?";

                    // 🧊 تصميم كرت الفارس بستايل الزجاج
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: _buildGlassContainer(
                        isDarkMode: isDarkMode,
                        padding: const EdgeInsets.all(12),
                        customColor: isDarkMode ? Colors.white.withOpacity(0.05) : (isFirst ? goldColor.withOpacity(0.08) : Colors.white.withOpacity(0.4)),
                        customBorderColor: medalColor.withOpacity(isDarkMode ? 0.6 : 0.8), // لون الإطار يتوافق مع الميدالية
                        child: Row(
                          children: [
                            // قسم الميدالية والترتيب
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(Icons.workspace_premium, color: medalColor, size: 50),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 15),

                            // عرض صورة الفارس باستخدام الكاش السريع
                            Container(
                              width: 55,
                              height: 55,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: medalColor.withOpacity(0.8),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(color: medalColor.withOpacity(0.2), blurRadius: 10, spreadRadius: 2),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(
                                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                        ),
                                        errorWidget: (context, url, error) => Center(
                                          child: Text(
                                            firstLetter,
                                            style: TextStyle(color: medalColor, fontWeight: FontWeight.bold, fontSize: 20),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          firstLetter,
                                          style: TextStyle(color: medalColor, fontWeight: FontWeight.bold, fontSize: 20),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 15),

                            // بيانات الطالب
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 16, 
                                      fontFamily: 'Cairo',
                                      color: isDarkMode ? Colors.white : primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "الرقم التسلسلي: $serialNumber", 
                                    style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey[700], fontWeight: FontWeight.w600)
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                );
              }),
            );
          },
        ),
      ],
    );
  }

  // 🧊 أداة مساعدة لتغليف العناصر وتأثير الزجاج الأساسية (Glassmorphism)
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero, Color? customColor, Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ?? (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: customBorderColor ?? (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6)),
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