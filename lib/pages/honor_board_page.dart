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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
        title: const Text("لوحة الشرف والتميز", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (role == "manager")
            IconButton(
              icon: const Icon(Icons.edit_calendar),
              tooltip: "إدارة لوحة الشرف",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageHonorBoardPage())),
            )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, const Color(0xff5a7a96)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 50),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("فرسان الحلقة", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("الطلاب الثلاثة الأكثر تميزاً وإنجازاً باختيار الإدارة", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 15),

          _buildCategorySection("الطلاب الجدد", "new_students", Colors.blue, Icons.auto_awesome, isDarkMode),
          const SizedBox(height: 20),
          _buildCategorySection("الطلاب القدماء", "old_students", Colors.orange, Icons.history_edu, isDarkMode),
          const SizedBox(height: 20),
          _buildCategorySection("الطلاب الخاتمين", "completed_students", Colors.green, Icons.verified, isDarkMode),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String title, String categoryId, Color accentColor, IconData icon, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 26),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
            ],
          ),
        ),
        StreamBuilder<DocumentSnapshot>(
          stream: getHonorCategory(categoryId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: LinearProgressIndicator());
            if (!snapshot.data!.exists) {
              return const Text("لم يتم اختيار فرسان هذه الفئة بعد.", style: TextStyle(color: Colors.grey, fontSize: 13));
            }

            var data = snapshot.data!.data() as Map<String, dynamic>;
            List<dynamic> positions = [data['first'], data['second'], data['third']];

            return Column(
              children: List.generate(3, (index) {
                var student = positions[index];
                if (student == null || student['name'] == "لم يحدد") return const SizedBox();

                Color medalColor = index == 0 ? goldColor : (index == 1 ? silverColor : bronzeColor);
                bool isFirst = index == 0;

                // 1️⃣ قراءة الرقم التسلسلي بأمان بجميع حالاته (نص أو رقم) لمنع الشاشة الحمراء
                final dynamic rawSerial = student['serial'];
                final int serialNumber = rawSerial is int 
                    ? rawSerial 
                    : (int.tryParse(rawSerial?.toString() ?? '') ?? 0);

                // 2️⃣ جلب بيانات الطالب الأصلية وصورته من الكولكشن الأساسي بأمان التام
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xff1e1e1e) : (isFirst ? goldColor.withOpacity(0.08) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: isFirst ? Border.all(color: goldColor, width: 1.2) : null,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
                      ),
                      child: Row(
                        children: [
                          // قسم الميدالية والترتيب
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.workspace_premium, color: medalColor, size: 45),
                              Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // عرض صورة الفارس باستخدام الكاش السريع أو الحرف الافتراضي
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isFirst ? goldColor : (isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
                                width: isFirst ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Center(
                                        child: Text(
                                          firstLetter,
                                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        firstLetter,
                                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
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
                                    fontSize: 15, 
                                    color: isFirst ? goldColor : (isDarkMode ? Colors.white : Colors.black87)
                                  ),
                                ),
                                Text("الرقم التسلسلي: $serialNumber", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                );
              }),
            );
          },
        )
      ],
    );
  }
}