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

  // 🔮 🚀 إشعار التنبيه الزجاجي الفخم المنزلق
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
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1e293b).withOpacity(0.85) : Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: statusColor.withOpacity(0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: statusColor.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))
                      ],
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

  Future<void> _updateRequestStatus({
    required BuildContext context,
    required String docId,
    required String studentId,
    required String studentName,
    required String status,
    required String date,
    required String reason,
    required String requestSupervisorId,
    required bool isDark,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('leave_requests').doc(docId).update({
        'status': status,
        'actionByRole': role,
      });

      if (status == 'approved') {
        String activeSupervisorId = requestSupervisorId.isNotEmpty ? requestSupervisorId : supervisorId;
        String activeSupervisorName = "المشرف";

        try {
          var studentDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
          if (studentDoc.exists) {
            var sData = studentDoc.data()!;
            activeSupervisorName = sData['supervisorName'] ?? "المشرف";
            if (activeSupervisorId.isEmpty) {
              activeSupervisorId = sData['supervisorId'] ?? '';
            }
          }
        } catch (_) {}

        String customSessionId = "${studentId}_$date";

        await FirebaseFirestore.instance.collection('sessions').doc(customSessionId).set({
          'studentId': studentId,
          'studentName': studentName,
          'supervisorId': activeSupervisorId,
          'supervisorName': activeSupervisorName,
          'supervisorIds': [activeSupervisorId],
          'supervisorNames': [activeSupervisorName],
          'date': date,
          'absent': true,
          'absenceType': "بعذر",
          'absenceReason': reason,
          'isExam': false,
          'didNotRecite': false,
          'newMemorization': '',
          'nearReview': '',
          'farReview': '',
          'homework': '',
          'notes': 'تم توثيق الغياب بعذر بناءً على طلب استئذان مقبول.',
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      String title = status == 'approved' ? "✅ تم قبول إذن الغياب" : "❌ اعتذر المعهد عن قبول الإذن";
      String body = status == 'approved' 
          ? "تمت الموافقة على إذن الغياب الخاص بالطالب $studentName ليوم $date وتوثيقه تلقائياً بعذر."
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
        message: status == 'approved' ? "تم قبول الطلب وتوثيق الاستئذان بنجاح 🎉" : "تم رفض الطلب وإبلاغ عائلة الطالب 📌",
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
        backgroundColor: isDarkMode ? const Color(0xff0b1120) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            "طلبات الاستئذان 📑",
            style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 20),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        ),
        body: Stack(
          children: [
            // 🌈 خلفية تدرج خرافية مع دوائر خلفية مضيئة (Glow Effect)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode 
                      ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] 
                      : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode ? primaryColor.withOpacity(0.2) : primaryColor.withOpacity(0.15),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode ? accentGold.withOpacity(0.12) : accentGold.withOpacity(0.2),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // 🌟 TabBar زجاجي معلق وأنيق
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white.withOpacity(0.7), width: 1.2),
                          ),
                          child: TabBar(
                            indicator: BoxDecoration(
                              color: isDarkMode ? accentGold : primaryColor,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDarkMode ? accentGold : primaryColor).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            labelColor: isDarkMode ? Colors.black87 : Colors.white,
                            unselectedLabelColor: isDarkMode ? Colors.white60 : Colors.black54,
                            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                            tabs: const [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.mark_email_unread_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text("معلقة 📥"),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text("السجل 📁"),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // 📜 قائمة الطلبات بحسب التبويب المختار
                  Expanded(
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

        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String currentStatus = data['status'] ?? 'pending';
          
          bool statusMatches = isHistory ? (currentStatus != 'pending') : (currentStatus == 'pending');
          bool isMyStudent = true; 
          
          if (role == 'supervisor') {
            isMyStudent = data['supervisorId'] == supervisorId;
          }
          
          return statusMatches && isMyStudent;
        }).toList();

        if (docs.isEmpty) return _buildEmptyState(isDarkMode, isHistory);

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String currentStatus = data['status'] ?? 'pending';
            String requestTime = data['requestTime'] ?? 'غير محدد';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDarkMode ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.8),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: اسم الطالب والشارة
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: (isDarkMode ? accentGold : primaryColor).withOpacity(0.15),
                                  child: Icon(Icons.person, color: isDarkMode ? accentGold : primaryColor, size: 22),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  data['studentName'] ?? 'طالب',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDarkMode ? Colors.white : primaryColor,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                            if (isHistory) _buildStatusBadge(currentStatus),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // معلومات الإذن بطريقة أنيقة ومقسمة
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.redAccent),
                                  const SizedBox(width: 8),
                                  Text(
                                    "التاريخ المطلوب: ${data['date']}",
                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.notes_rounded, size: 16, color: isDarkMode ? accentGold : primaryColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "السبب: ${data['reason']}",
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                        fontFamily: 'Cairo',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // وقت الإرسال
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: isDarkMode ? Colors.white54 : Colors.black45),
                            const SizedBox(width: 6),
                            Text(
                              "وقت الطلب: $requestTime",
                              style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black45, fontFamily: 'Cairo', fontSize: 11),
                            ),
                          ],
                        ),

                        // أزرار اتخاذ القرار (تظهر فقط في الطلبات المعلقة)
                        if (!isHistory) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _updateRequestStatus(
                                      context: context,
                                      docId: doc.id,
                                      studentId: data['studentId'] ?? '',
                                      studentName: data['studentName'] ?? 'طالب',
                                      status: 'approved',
                                      date: data['date'] ?? '',
                                      reason: data['reason'] ?? 'بعذر',
                                      requestSupervisorId: data['supervisorId'] ?? '',
                                      isDark: isDarkMode,
                                    ),
                                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    label: const Text("قبول العذر", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(color: Colors.redAccent.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _updateRequestStatus(
                                      context: context,
                                      docId: doc.id,
                                      studentId: data['studentId'] ?? '',
                                      studentName: data['studentName'] ?? 'طالب',
                                      status: 'rejected',
                                      date: data['date'] ?? '',
                                      reason: data['reason'] ?? '',
                                      requestSupervisorId: data['supervisorId'] ?? '',
                                      isDark: isDarkMode,
                                    ),
                                    icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                                    label: const Text("رفض الإذن", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isApproved ? Colors.green.withOpacity(0.6) : Colors.redAccent.withOpacity(0.6), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: isApproved ? Colors.green.shade400 : Colors.redAccent.shade200,
          ),
          const SizedBox(width: 4),
          Text(
            isApproved ? "مقبول" : "مرفوض",
            style: TextStyle(
              color: isApproved ? Colors.green.shade400 : Colors.redAccent.shade200,
              fontSize: 12,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, bool isHistory) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHistory ? Icons.folder_off_rounded : Icons.event_available_rounded,
              size: 70,
              color: isDarkMode ? accentGold.withOpacity(0.6) : primaryColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isHistory ? "لا يوجد سجل سابق لطلبات الغياب 📁" : "جميع الطلبات مُعتاذة ولا يوجد معلق ☕", 
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}