import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
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

  // دالة التصدير للإكسل (محدثة لتشمل خانة القراءة نظراً)
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
        TextCellValue('مراجعة جديد'),
        TextCellValue('مراجعة قديم'),
        TextCellValue('قراءة نظراً'), // الحقل الجديد المضاف للإكسل
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
          TextCellValue(isAbsent ? '---' : (data['readingBySight'] ?? '')), // تصدير القراءة نظراً
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
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
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
          if (sessions.isEmpty) return _buildEmptyState(isDarkMode);

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final data = session.data() as Map<String, dynamic>;
              return _buildSessionTimelineItem(context, session.id, data, isDarkMode);
            },
          );
        },
      ),
    );
  }

  Widget _buildSessionTimelineItem(BuildContext context, String sessionId, Map<String, dynamic> data, bool isDarkMode) {
    bool isAbsent = data['absent'] ?? false;
    Color ratingColor = _getRatingColor(data['rating']);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05), 
            blurRadius: 8
          )
        ],
      ),
      child: Column(
        children: [
          // رأس الكرت (التاريخ والتقييم)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: isAbsent 
                  ? Colors.red.withOpacity(0.15) 
                  : (isDarkMode ? Colors.white.withOpacity(0.03) : primaryColor.withOpacity(0.05)),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: isAbsent ? Colors.red : (isDarkMode ? Colors.orange : primaryColor)),
                    const SizedBox(width: 8),
                    Text(
                      data['date'] ?? '', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: isAbsent ? Colors.red : (isDarkMode ? Colors.white : primaryColor)
                      )
                    ),
                  ],
                ),
                if (isAbsent) _buildBadge("غائب", Colors.red) else _buildBadge(data['rating'] ?? "غير مقيم", ratingColor),
              ],
            ),
          ),
          
          // تفاصيل الجلسة 
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                if (!isAbsent) ...[
                  _buildInfoRow(Icons.star, "الحفظ الجديد", data['newMemorization'], isDarkMode),
                  Divider(color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                  _buildInfoRow(Icons.auto_stories_outlined, "مراجعة جديد", data['nearReview'], isDarkMode),
                  Divider(color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                  _buildInfoRow(Icons.history_edu, "مراجعة قديم", data['farReview'], isDarkMode),
                  Divider(color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                  _buildInfoRow(Icons.menu_book_outlined, "قراءة نظراً", data['readingBySight'], isDarkMode), // الخانة المحدثة في الواجهة
                  Divider(color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                  _buildInfoRow(Icons.edit_note, "الواجب", data['homework'], isDarkMode),
                  Divider(color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                  _buildInfoRow(Icons.mood, "حالة الطالب", data['studentStatus'], isDarkMode),
                ],
                if (data['notes'] != null && data['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildNotesBox(data['notes'], isDarkMode),
                ],
                const SizedBox(height: 10),
                _buildActionButtons(context, sessionId, data, isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, dynamic value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDarkMode ? Colors.orange : primaryColor),
          const SizedBox(width: 10),
          Text("$label: ", style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(
              (value == null || value.toString().trim().isEmpty) ? "---" : value.toString(), 
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87)
            )
          ),
        ],
      ),
    );
  }

  Widget _buildNotesBox(String notes, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xff2b2b2b) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 1)],
      ),
      child: Text(
        "ملاحظات: $notes", 
        style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: isDarkMode ? Colors.white70 : Colors.black87)
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String id, Map<String, dynamic> data, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditSessionPage(sessionId: id, data: data))),
          icon: Icon(Icons.edit, size: 16, color: isDarkMode ? Colors.orange : primaryColor),
          label: Text("تعديل", style: TextStyle(color: isDarkMode ? Colors.orange : primaryColor)),
        ),
        if (role == "manager")
          TextButton.icon(
            onPressed: () async {
              await SessionService().deleteSession(id);
              if (!context.mounted) return;
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

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Text(
        "لا يوجد سجل جلسات لهذا الطالب", 
        style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontSize: 15)
      )
    );
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