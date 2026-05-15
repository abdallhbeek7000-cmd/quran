import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: sessionService.getStudentSessions(studentId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data!.docs;

          if (sessions.isEmpty) {
            return _buildEmptyState();
          }

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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          // رأس الكرت (التاريخ والتقييم)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: isAbsent ? Colors.red[50] : primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: isAbsent ? Colors.red : primaryColor),
                    const SizedBox(width: 8),
                    Text(data['date'], style: TextStyle(fontWeight: FontWeight.bold, color: isAbsent ? Colors.red : primaryColor)),
                  ],
                ),
                if (isAbsent)
                  _buildBadge("غائب", Colors.red)
                else
                  _buildBadge(data['rating'], ratingColor),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isAbsent) ...[
                  _buildInfoRow(Icons.star, "الحفظ الجديد", data['newMemorization']),
                  const Divider(height: 20),
                  _buildInfoRow(Icons.auto_stories, "المراجعة", data['review']),
                  const Divider(height: 20),
                  _buildInfoRow(Icons.edit_note, "الواجب", data['homework']),
                  const Divider(height: 20),
                  _buildInfoRow(Icons.mood, "حالة الطالب", data['studentStatus']),
                ],
                
                if (data['notes'] != null && data['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                    child: Text("ملاحظات: ${data['notes']}", style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87)),
                  ),
                ],

                const SizedBox(height: 10),

                // أزرار التحكم
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _navToEdit(context, sessionId, data),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text("تعديل"),
                    ),
                    if (role == "manager")
                      TextButton.icon(
                        onPressed: () => _deleteSession(context, sessionId),
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        label: const Text("حذف", style: TextStyle(color: Colors.red)),
                      ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, dynamic value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Text("$label: ", style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Expanded(child: Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text("لا يوجد سجل جلسات لهذا الطالب"),
        ],
      ),
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

  void _navToEdit(BuildContext context, String id, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditSessionPage(sessionId: id, data: data)));
  }

  void _deleteSession(BuildContext context, String id) async {
    final service = SessionService();
    await service.deleteSession(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حذف الجلسة")));
  }
}