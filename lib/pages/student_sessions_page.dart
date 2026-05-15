import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'edit_session_page.dart';
import '../services/session_service.dart';

class StudentSessionsPage extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String role;

  const StudentSessionsPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.role,
  });

  final Color primaryColor = const Color(0xff425c75);

  // دالة التصدير للإكسل (محدثة لتشمل الحقول الجديدة)
  Future<void> exportSessionsToExcel(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("جاري تجهيز سجل الجلسات...")),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('studentId', isEqualTo: studentId)
          .orderBy('date', descending: true)
          .get();

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['سجل التسميع'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        TextCellValue('التاريخ'),
        TextCellValue('الحالة'),
        TextCellValue('التقييم'),
        TextCellValue('الحفظ الجديد'),
        TextCellValue('مراجعة قريبة'),
        TextCellValue('مراجعة بعيدة'),
        TextCellValue('الواجب'),
        TextCellValue('ملاحظات'),
      ]);

      for (var doc in snapshot.docs) {
        var data = doc.data();
        bool isAbsent = data['absent'] ?? false;
        sheetObject.appendRow([
          TextCellValue(data['date']?.toString() ?? ''),
          TextCellValue(isAbsent ? 'غائب' : 'حاضر'),
          TextCellValue(isAbsent ? '---' : (data['rating'] ?? '')),
          TextCellValue(isAbsent ? '---' : (data['newMemorization'] ?? '')),
          TextCellValue(isAbsent ? '---' : (data['nearReview'] ?? '')),
          TextCellValue(isAbsent ? '---' : (data['farReview'] ?? '')),
          TextCellValue(isAbsent ? '---' : (data['homework'] ?? '')),
          TextCellValue(data['notes']?.toString() ?? ''),
        ]);
      }

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/سجل_$studentName.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);
      await Share.shareXFiles([XFile(filePath)], text: 'سجل الطالب: $studentName');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = SessionService();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => exportSessionsToExcel(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: sessionService.getStudentSessions(studentId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final sessions = snapshot.data!.docs;
          if (sessions.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final data = session.data() as Map<String, dynamic>;
              return _buildSessionTimelineItem(context, session.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildSessionTimelineItem(BuildContext context, String sessionId, Map<String, dynamic> data) {
    bool isAbsent = data['absent'] ?? false;
    Color ratingColor = _getRatingColor(data['rating']);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // رأس الكرت (التاريخ والتقييم)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: isAbsent ? Colors.red.withOpacity(0.1) : primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: isAbsent ? Colors.red : primaryColor),
                    const SizedBox(width: 8),
                    Text(data['date'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: isAbsent ? Colors.red : primaryColor)),
                  ],
                ),
                if (isAbsent) _buildBadge("غائب", Colors.red) else _buildBadge(data['rating'] ?? "غير مقيم", ratingColor),
              ],
            ),
          ),
          
          // تفاصيل الجلسة (عرض الحقول الجديدة هنا)
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                if (!isAbsent) ...[
                  _buildInfoRow(Icons.star, "الحفظ الجديد", data['newMemorization']),
                  const Divider(),
                  _buildInfoRow(Icons.menu_book, "مراجعة جديد", data['nearReview']),
                  const Divider(),
                  _buildInfoRow(Icons.history_edu, "مراجعة قديم", data['farReview']),
                  const Divider(),
                  _buildInfoRow(Icons.edit_note, "الواجب", data['homework']),
                  const Divider(),
                  _buildInfoRow(Icons.mood, "حالة الطالب", data['studentStatus']),
                ],
                if (data['notes'] != null && data['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildNotesBox(data['notes']),
                ],
                const SizedBox(height: 10),
                _buildActionButtons(context, sessionId, data),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(child: Text(value?.toString() ?? "---", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildNotesBox(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 1)],
      ),
      child: Text("ملاحظات: $notes", style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
    );
  }

  Widget _buildActionButtons(BuildContext context, String id, Map<String, dynamic> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditSessionPage(sessionId: id, data: data))),
          icon: const Icon(Icons.edit, size: 16),
          label: const Text("تعديل"),
        ),
        if (role == "manager")
          TextButton.icon(
            onPressed: () async {
              await SessionService().deleteSession(id);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حذف الجلسة")));
            },
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            label: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text("لا يوجد سجل جلسات لهذا الطالب"));
  }

  Color _getRatingColor(String? rating) {
    switch (rating) {
      case "ممتاز": return Colors.green;
      case "جيد": return Colors.orange;
      case "سيء": return Colors.red;
      default: return Colors.blue;
    }
  }
}