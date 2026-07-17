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

  // 🔮 🚀 إشعار السائل الزجاجي الفخم المنزلق من الأعلى
  void _showTopPremiumToast(BuildContext context, {required String message, required IconData icon, required Color statusColor, required bool isDark}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 15,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: Opacity(opacity: (value + 100) / 100, child: child),
              );
            },
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1e293b).withOpacity(0.85) : Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.06), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), shape: BoxShape.circle),
                          child: Icon(icon, color: statusColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () => overlayEntry.remove());
  }

  Future<void> _updateRequestStatus(BuildContext context, String docId, String studentId, String studentName, String status, String date, bool isDark) async {
    try {
      // 1. تحديث حالة الطلب بالفايربيز
      await FirebaseFirestore.instance.collection('leave_requests').doc(docId).update({
        'status': status,
        'actionByRole': role, // توثيق الفئة المصلحة للإذن (مدير أو مشرف)
      });

      // 2. إرسال إشعار فوري للأهل بالنتيجة لايف
      String title = status == 'approved' ? "✅ تم قبول إذن الغياب" : "❌ اعتذر المعهد عن قبول الإذن";
      String body = status == 'approved' 
          ? "تمت الموافقة على إذن الغياب الخاص بالطالب $studentName ليوم $date."
          : "نعتذر، لم تتم الموافقة على إذن الغياب للطالب $studentName ليوم $date.";

      await NotificationService.sendAndSaveNotification(
        studentId: studentId,
        title: title,
        body: body,
        type: "leave_status",
        context: context,
      );

      if (!context.mounted) return;
      _showTopPremiumToast(
        context,
        message: status == 'approved' ? "تم قبول العذر الطبي/الخاص وإشعار الأهل بنجاح 🎉" : "تم رفض الطلب وإبلاغ عائلة الطالب 📌",
        icon: status == 'approved' ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
        statusColor: status == 'approved' ? Colors.green.shade600 : Colors.redAccent,
        isDark: isDark,
      );
    } catch (e) {
      _showTopPremiumToast(context, message: "حدث خطأ غير متوقع: $e", icon: Icons.error_outline_rounded, statusColor: Colors.redAccent, isDark: isDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0, 
          backgroundColor: Colors.transparent,
          title: Text("طلبات الاستئذان", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
          centerTitle: true, 
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
          bottom: TabBar(
            indicatorColor: isDarkMode ? accentGold : primaryColor,
            labelColor: isDarkMode ? accentGold : primaryColor,
            unselectedLabelColor: isDarkMode ? Colors.white60 : Colors.black54,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: "طلبات معلقة 📥", icon: Icon(Icons.pending_actions_rounded, size: 20)),
              Tab(text: "السجل القديم 📁", icon: Icon(Icons.history_toggle_off_rounded, size: 20)),
            ],
          ),
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode ? [const Color(0xff0f172a), const Color(0xff1e293b)] : [const Color(0xffe2e8f0), const Color(0xffe0eafc)], 
                  begin: Alignment.topLeft, 
                  end: Alignment.bottomRight
                )
              ),
            ),
            
            SafeArea(
              child: TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildRequestsList(context, isDarkMode, isHistory: false),
                  _buildRequestsList(context, isDarkMode, isHistory: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList(BuildContext context, bool isDarkMode, {required bool isHistory}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('leave_requests')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("حدث خطأ: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent, fontFamily: 'Cairo')));
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isDarkMode, isHistory);
        }

        // 🚀 الفلترة المحلية المزدوجة والمقواة (المدير يرى كل شيء والمشرف يرى طلابه فقط)
        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String currentStatus = data['status'] ?? 'pending';
          
          bool statusMatches = isHistory ? (currentStatus != 'pending') : (currentStatus == 'pending');
          bool isMyStudent = true; 
          
          // قفل الأمان: الفلترة تطبق فقط على المشرف، بينما المدير مستثنى ليرى الجميع
          if (role == 'supervisor') {
            isMyStudent = data['supervisorId'] == supervisorId;
          }
          
          return statusMatches && isMyStudent;
        }).toList();

        if (docs.isEmpty) return _buildEmptyState(isDarkMode, isHistory);

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String currentStatus = data['status'] ?? 'pending';

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.75), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: isDarkMode ? accentGold : primaryColor), 
                            const SizedBox(width: 8),
                            Text(data['studentName'] ?? 'طالب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                          ],
                        ),
                        if (isHistory) _buildStatusBadge(currentStatus),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text("تاريخ الغياب المطلوب: ${data['date']}", style: TextStyle(color: Colors.redAccent.shade200, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                    const SizedBox(height: 5),
                    Text("السبب: ${data['reason']}", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                    
                    if (!isHistory) ...[
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2),
                              onPressed: () => _updateRequestStatus(context, doc.id, data['studentId'], data['studentName'], 'approved', data['date'], isDarkMode),
                              icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                              label: const Text("قبول العذر", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2),
                              onPressed: () => _updateRequestStatus(context, doc.id, data['studentId'], data['studentName'], 'rejected', data['date'], isDarkMode),
                              icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
                              label: const Text("رفض", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    bool isApproved = status == 'approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isApproved ? Colors.green.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5), width: 1),
      ),
      child: Text(
        isApproved ? "مقبول ✓" : "مرفوض ✗",
        style: TextStyle(color: isApproved ? Colors.green.shade400 : Colors.redAccent.shade200, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, bool isHistory) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isHistory ? Icons.folder_off_rounded : Icons.event_available_rounded, size: 80, color: isDarkMode ? Colors.white24 : Colors.black12),
          const SizedBox(height: 15),
          Text(
            isHistory ? "السجل التاريخي فارغ تماماً 📁" : "لا يوجد طلبات غياب معلقة ☕", 
            style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }
}