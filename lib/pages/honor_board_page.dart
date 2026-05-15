import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HonorBoardPage extends StatelessWidget {
  const HonorBoardPage({super.key});

  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37); // اللون الذهبي للتكريم

  Future<List<Map<String, dynamic>>> getTopStudents(String type) async {
    final students = await FirebaseFirestore.instance
        .collection('students')
        .where('studentType', isEqualTo: type)
        .where('archived', isEqualTo: false)
        .get();

    List<Map<String, dynamic>> result = [];

    for (var student in students.docs) {
      final sessions = await FirebaseFirestore.instance
          .collection('sessions')
          .where('studentId', isEqualTo: student.id)
          .get();

      int score = 0;
      for (var session in sessions.docs) {
        final data = session.data();
        if (data['absent'] == true) continue;

        // حساب النقاط بناءً على حجم النص المكتوب في الحفظ والتقييم
        final newMem = data['newMemorization'].toString();
        score += newMem.length; 

        if (data['rating'] == "ممتاز") score += 20;
        if (data['rating'] == "جيد") score += 10;
      }

      result.add({
        'name': student['name'],
        'serial': student['serial'],
        'score': score,
      });
    }

    result.sort((a, b) => b['score'].compareTo(a['score']));
    return result.take(5).toList();
  }

  Widget buildSection(String title, Color accentColor, IconData icon, List<Map<String, dynamic>> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ],
          ),
        ),
        if (data.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text("لا يوجد بيانات كافية حالياً"),
          )
        else
          ...data.asMap().entries.map((e) {
            final index = e.key;
            final student = e.value;
            bool isFirst = index == 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFirst ? goldColor.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isFirst ? Border.all(color: goldColor, width: 1.5) : null,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  // وسام المركز
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        isFirst ? Icons.workspace_premium : Icons.circle,
                        color: isFirst ? goldColor : accentColor.withOpacity(0.2),
                        size: 45,
                      ),
                      Text(
                        "${index + 1}",
                        style: TextStyle(
                          color: isFirst ? Colors.white : accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isFirst ? goldColor : Colors.black87,
                          ),
                        ),
                        Text("الرقم التسلسلي: ${student['serial']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  // كرت النقاط
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFirst ? goldColor : accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${student['score']} ن",
                      style: TextStyle(
                        color: isFirst ? Colors.white : accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text("لوحة الشرف والتميز", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder(
        future: Future.wait([
          getTopStudents("new"),
          getTopStudents("old"),
          getTopStudents("completed"),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final newStudents = snapshot.data![0];
          final oldStudents = snapshot.data![1];
          final completedStudents = snapshot.data![2];

          return ListView(
            padding: const EdgeInsets.all(15),
            children: [
              // كرت تعريفي في الأعلى
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
                          Text("الطلاب الأكثر تميزاً وإنجازاً لهذا الموسم", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 10),

              buildSection("المتميزون الجدد", Colors.blue, Icons.auto_awesome, newStudents),
              const SizedBox(height: 20),
              buildSection("أوفياء المعهد", Colors.orange, Icons.history_edu, oldStudents),
              const SizedBox(height: 20),
              buildSection("نخبة الخاتمين", Colors.green, Icons.verified, completedStudents),
              
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}