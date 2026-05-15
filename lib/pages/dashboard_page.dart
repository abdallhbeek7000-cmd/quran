import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_colors.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  final Color primaryColor = const Color(0xff425c75);

  Widget buildCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text("إحصائيات المعهد", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder(
        future: Future.wait([
          FirebaseFirestore.instance.collection('students').where('archived', isEqualTo: false).get(),
          FirebaseFirestore.instance.collection('supervisors').get(), // تأكد من اسم الكولكشن 'supervisors'
          FirebaseFirestore.instance.collection('sessions').get(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final students = snapshot.data![0].docs;
          final supervisors = snapshot.data![1].docs;
          final sessions = snapshot.data![2].docs;

          int absentCount = 0;
          int noSupervisor = 0;

          for (var s in sessions) {
            final data = s.data() as Map<String, dynamic>;
            if (data['absent'] == true) absentCount++;
          }

          for (var s in students) {
            final data = s.data() as Map<String, dynamic>;
            if (data['supervisorId'] == null || data['supervisorId'] == '') noSupervisor++;
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header الترحيبي مع الخلفية الملونة
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 40, left: 20, right: 20, top: 10),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("نظرة عامة", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text("إليك ملخص أداء المعهد لهذه الدورة", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),

                // قسم الكروت (Grid) مرتفع قليلاً ليتداخل مع الـ Header
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 1.1,
                          children: [
                            buildCard(title: "الطلاب", value: students.length.toString(), icon: Icons.people_alt_rounded, color: Colors.blue),
                            buildCard(title: "المشرفين", value: supervisors.length.toString(), icon: Icons.admin_panel_settings_rounded, color: Colors.amber),
                            buildCard(title: "إجمالي الجلسات", value: sessions.length.toString(), icon: Icons.menu_book_rounded, color: Colors.green),
                            buildCard(title: "طلاب غائبون", value: absentCount.toString(), icon: Icons.person_off_rounded, color: Colors.redAccent),
                          ],
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // كرت عريض للطلاب غير الموزعين
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("طلاب بدون مشرف", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text("هناك $noSupervisor طالباً لم يتم توزيعهم بعد", style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                  ],
                                ),
                              ),
                              Text(noSupervisor.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 25),

                        // كرت ملاحظات الإدارة
                        _buildNotesSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: primaryColor),
              const SizedBox(width: 10),
              const Text("توصيات الإدارة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 30),
          _noteItem("تأكد من توزيع الطلاب الجدد فور تسجيلهم."),
          _noteItem("راجع تقارير الغياب بشكل أسبوعي."),
          _noteItem("كرم المشرفين المتميزين في لوحة الشرف."),
        ],
      ),
    );
  }

  Widget _noteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 14))),
        ],
      ),
    );
  }
}