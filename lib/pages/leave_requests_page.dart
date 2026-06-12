import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart';

class LeaveRequestsPage extends StatelessWidget {
  final String supervisorId;
  final String role; 

  const LeaveRequestsPage({super.key, required this.supervisorId, required this.role});

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  Future<void> _updateRequestStatus(BuildContext context, String docId, String studentId, String studentName, String status, String date) async {
    // 1. تحديث حالة الطلب
    await FirebaseFirestore.instance.collection('leave_requests').doc(docId).update({
      'status': status,
    });

    // 2. إرسال إشعار فوري للأهل بالنتيجة
    String title = status == 'approved' ? "✅ تم قبول إذن الغياب" : "❌ اعتذر المشرف عن قبول إذن الغياب";
    String body = status == 'approved' 
        ? "وافق المشرف على إذن الغياب الخاص بالطالب $studentName ليوم $date."
        : "نعتذر، لم يتم الموافقة على إذن الغياب للطالب $studentName ليوم $date.";

    await NotificationService.sendAndSaveNotification(
      studentId: studentId,
      title: title,
      body: body,
      type: "leave_status",
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0, backgroundColor: Colors.transparent,
        title: Text("طلبات الاستئذان", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
        centerTitle: true, iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: isDarkMode ? [const Color(0xff0f172a), const Color(0xff1e293b)] : [const Color(0xffe2e8f0), const Color(0xffe0eafc)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              // 🚀 التعديل الجذري: سحبنا الداتا بدون where لنتجنب الـ Index نهائياً
              stream: FirebaseFirestore.instance.collection('leave_requests')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // إضافة فحص الأخطاء لحتى لو في مشكلة تظهر على الشاشة وما تضل مخفية
                if (snapshot.hasError) {
                  return Center(child: Text("حدث خطأ: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent, fontFamily: 'Cairo')));
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(isDarkMode);
                }

                // 🚀 الفلترة المحلية (Local Filtering)
                var docs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  bool isPending = data['status'] == 'pending'; // فلترة المعلق فقط
                  bool isMyStudent = true; // افتراضياً المدير يرى الكل
                  
                  // إذا كان مشرف، نفلتر طلابه فقط
                  if (role == 'supervisor') {
                    isMyStudent = data['supervisorId'] == supervisorId;
                  }
                  
                  return isPending && isMyStudent;
                }).toList();

                if (docs.isEmpty) return _buildEmptyState(isDarkMode);

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(15),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person, color: accentGold), const SizedBox(width: 8),
                                    Text(data['studentName'] ?? 'طالب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text("تاريخ الغياب المطلوب: ${data['date']}", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                                const SizedBox(height: 5),
                                Text("السبب: ${data['reason']}", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 15),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                        onPressed: () => _updateRequestStatus(context, doc.id, data['studentId'], data['studentName'], 'approved', data['date']),
                                        icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                                        label: const Text("قبول العذر", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                        onPressed: () => _updateRequestStatus(context, doc.id, data['studentId'], data['studentName'], 'rejected', data['date']),
                                        icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
                                        label: const Text("رفض", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_rounded, size: 80, color: isDarkMode ? Colors.white24 : Colors.black12),
          const SizedBox(height: 15),
          Text("لا يوجد طلبات غياب معلقة ☕", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}