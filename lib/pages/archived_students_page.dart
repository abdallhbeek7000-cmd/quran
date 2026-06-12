import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class ArchivedStudentsPage extends StatelessWidget {
  const ArchivedStudentsPage({super.key});

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        title: Text(
          "الطلاب المؤرشفين (قيد الانتظار)",
          style: TextStyle(color: isDark ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ⚠️ تأكد إن اسم الكولكشن مطابق للي عندك بالمشروع (students أو users)
        stream: FirebaseFirestore.instance.collection('students').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(isDark);
          }

          // 🚀 تصفية الطلاب: نجلب فقط من لديهم isArchived == true
          final archivedStudents = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['isArchived'] == true;
          }).toList();

          if (archivedStudents.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: archivedStudents.length,
            itemBuilder: (context, index) {
              final student = archivedStudents[index];
              final data = student.data() as Map<String, dynamic>;

              return Card(
                color: isDark ? const Color(0xff1e293b) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orangeAccent.withOpacity(0.2),
                    child: const Icon(Icons.pause_circle_filled_rounded, color: Colors.orangeAccent),
                  ),
                  title: Text(data['name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  subtitle: const Text("طالب متوقف مؤقتاً\n(ضغطة مطولة لاسترجاعه)", style: TextStyle(fontSize: 12, fontFamily: 'Cairo')),
                  onLongPress: () {
                    // 🚀 رسالة استرجاع الطالب
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text("استرجاع الطالب", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        content: Text("هل تريد إعادة الطالب ${data['name']} إلى الدوام النشط؟", style: const TextStyle(fontFamily: 'Cairo')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: accentGold),
                            onPressed: () async {
                              // 🚀 إعادة الطالب للصفحة الرئيسية
                              await FirebaseFirestore.instance
                                  .collection('students')
                                  .doc(student.id)
                                  .set({'isArchived': false}, SetOptions(merge: true));
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إرجاع الطالب بنجاح", style: TextStyle(fontFamily: 'Cairo'))));
                              }
                            },
                            child: const Text("استرجاع", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined, size: 80, color: isDark ? Colors.white24 : primaryColor.withOpacity(0.3)),
          const SizedBox(height: 15),
          Text("لا يوجد طلاب مؤرشفين حالياً", style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: isDark ? Colors.white54 : Colors.black54)),
        ],
      ),
    );
  }
}