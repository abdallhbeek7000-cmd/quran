import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyStatsPage extends StatelessWidget {
  const DailyStatsPage({super.key});

  // تأكد أن هذا المتغير هنا بالضبط
  final Color primaryColor = const Color(0xff425c75);

  @override
  Widget build(BuildContext context) {
    // المنطق البرمجي الخاص بك لجلب تاريخ اليوم
    final String todayDate = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text("الإحصائيات اليومية", 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // كرت التاريخ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.event, color: primaryColor),
                  const SizedBox(width: 12),
                  Text("إحصائيات اليوم: ", style: TextStyle(color: Colors.grey[600])),
                  Text(todayDate, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // كرت الغائبين
            _buildStreamCard(
              title: "عدد الغائبين اليوم",
              icon: Icons.person_off_rounded,
              color: Colors.red,
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .where('date', isEqualTo: todayDate)
                  .where('absent', isEqualTo: true)
                  .snapshots(),
            ),

            const SizedBox(height: 15),

            // كرت الحاضرين
            _buildStreamCard(
              title: "عدد التسميعات اليوم",
              icon: Icons.menu_book_rounded,
              color: Colors.green,
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .where('date', isEqualTo: todayDate)
                  .where('absent', isEqualTo: false)
                  .snapshots(),
            ),

            const SizedBox(height: 15),

            // كرت النسبة المئوية
            _buildPercentageCard(todayDate),
          ],
        ),
      ),
    );
  }

  // دالة بناء الكروت الإحصائية
  Widget _buildStreamCard({
    required String title,
    required IconData icon,
    required Color color,
    required Stream<QuerySnapshot> stream,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String value = "0";
        if (snapshot.hasData) {
          value = snapshot.data!.docs.length.toString();
        }
        return _statsUI(title, value, icon, color, snapshot.connectionState == ConnectionState.waiting);
      },
    );
  }

  // دالة حساب النسبة المئوية بناءً على المنطق الخاص بك
  Widget _buildPercentageCard(String todayDate) {
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
        return _statsUI("نسبة الحضور اليوم", percentage, Icons.pie_chart_rounded, Colors.blue, snapshot.connectionState == ConnectionState.waiting);
      },
    );
  }

  // التصميم الموحد للواجهة
  Widget _statsUI(String title, String value, IconData icon, Color color, bool isLoading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              const SizedBox(height: 10),
              isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(value, style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 30),
          ),
        ],
      ),
    );
  }
}