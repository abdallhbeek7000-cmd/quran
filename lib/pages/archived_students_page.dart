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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
            appBar: AppBar(
              title: Text(
                "الطلاب المتوقفين (الأرشيف)",
                style: TextStyle(color: isDark ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo'),
              ),
              iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // 🚀 تصفية الطلاب: نجلب فقط من لديهم isArchived == true أو archived == true
        final archivedStudents = (snapshot.hasData && snapshot.data!.docs.isNotEmpty)
            ? snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['isArchived'] == true || data['archived'] == true;
              }).toList()
            : [];

        int totalArchived = archivedStudents.length;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Text(
              "الطلاب المتوقفين (الأرشيف) ($totalArchived)",
              style: TextStyle(color: isDark ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo'),
            ),
            centerTitle: true,
            iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
          ),
          body: archivedStudents.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: archivedStudents.length,
                  itemBuilder: (context, index) {
                    final student = archivedStudents[index];
                    final data = student.data() as Map<String, dynamic>;
                    
                    String supervisorName = data['supervisorName'] ?? data['supervisor'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff1e293b).withOpacity(0.6) : Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        // زر الاسترجاع السريع من اليسار (طابق الأيقونة الخضراء في الواجهة)
                        leading: IconButton(
                          icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.greenAccent),
                          tooltip: "استرجاع الطالب",
                          onPressed: () => _confirmRestore(context, student.id, data['name'] ?? ''),
                        ),
                        // اسم الطالب والمعلومات على اليمين
                        title: Text(
                          data['name'] ?? 'بدون اسم',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : primaryColor,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (supervisorName.isNotEmpty)
                              Text(
                                "المشرف: $supervisorName",
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            Text(
                              "(ضغط مطول للاسترجاع)",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                        // أيقونة التوقف البرتقالية في أقصى اليمين بدون ترقيم
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.pause_circle_filled_rounded,
                            color: Colors.orange,
                            size: 22,
                          ),
                        ),
                        onLongPress: () => _confirmRestore(context, student.id, data['name'] ?? ''),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _confirmRestore(BuildContext context, String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("استرجاع الطالب", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Text("هل تريد إعادة الطالب ($studentName) إلى الدوام النشط؟", style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentGold),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('students')
                  .doc(studentId)
                  .set({'isArchived': false, 'archived': false}, SetOptions(merge: true));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم إرجاع الطالب بنجاح", style: TextStyle(fontFamily: 'Cairo'))),
                );
              }
            },
            child: const Text("استرجاع", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
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
          Text("لا يوجد طلاب متوقفين حالياً", style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: isDark ? Colors.white54 : Colors.black54)),
        ],
      ),
    );
  }
}