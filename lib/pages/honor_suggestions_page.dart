import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../models/cycle_model.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart'; // استدعاء خدمة الإشعارات

class HonorSuggestionsPage extends StatefulWidget {
  final CycleModel cycle;
  final String role; // 'manager' أو 'supervisor'
  final String uid;

  const HonorSuggestionsPage({
    super.key,
    required this.cycle,
    required this.role,
    required this.uid,
  });

  @override
  State<HonorSuggestionsPage> createState() => _HonorSuggestionsPageState();
}

class _HonorSuggestionsPageState extends State<HonorSuggestionsPage> {
  final Color primaryNavy = const Color(0xff1e293b);
  final Color accentGold = const Color(0xffD4AF37);
  final Color softBlue = const Color(0xff3b82f6);

  bool get isManager => widget.role == 'manager';

  /// دالة جلب اسم المشرف الحقيقي من الفايربيس
  Future<String> _getActualSupervisorName(String supUid) async {
    try {
      var supDoc = await FirebaseFirestore.instance.collection('supervisors').doc(supUid).get();
      if (supDoc.exists && supDoc.data()?['name'] != null && (supDoc.data()?['name'] as String).isNotEmpty) {
        return supDoc.data()!['name'];
      }
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(supUid).get();
      if (userDoc.exists && userDoc.data()?['name'] != null && (userDoc.data()?['name'] as String).isNotEmpty) {
        return userDoc.data()!['name'];
      }
    } catch (e) {
      debugPrint("خطأ في جلب اسم المشرف: $e");
    }
    return "مشرف غير معروف";
  }

  /// 🔔 دالة إرسال الإشعارات للمشرفين عند إنشاء طلب اقتراح تكريم جديد
  Future<void> _sendNotificationToSupervisors({
    required List<String> targetSupervisors,
    required String requestTitle,
  }) async {
    try {
      QuerySnapshot supSnapshot;
      if (targetSupervisors.contains('all')) {
        supSnapshot = await FirebaseFirestore.instance.collection('supervisors').get();
      } else {
        supSnapshot = await FirebaseFirestore.instance
            .collection('supervisors')
            .where(FieldPath.documentId, whereIn: targetSupervisors)
            .get();
      }

      String notifTitle = "💡 طلب اقتراح أسماء للتكريم";
      String notifBody = "قام المدير بإضافة طلب اقتراح جديد: ($requestTitle). يرجى تقديم ترشيحاتك قبل انتهاء المهلة.";

      for (var doc in supSnapshot.docs) {
        String supId = doc.id;

        // 1. إضافة الإشعار في القائمة الفرعية notifications داخل مستند المشرف
        await FirebaseFirestore.instance
            .collection('supervisors')
            .doc(supId)
            .collection('notifications')
            .add({
          'title': notifTitle,
          'body': notifBody,
          'type': 'honor_suggestion_request',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        // 2. إرسال إشعار FCM للمشرف
        NotificationService.sendAndSaveNotification(
          studentId: supId,
          title: notifTitle,
          body: notifBody,
          type: 'honor_suggestion_request',
          context: context,
        ).catchError((_) {});
      }
    } catch (e) {
      debugPrint("خطأ أثناء إرسال إشعارات اقتراح التكريم: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff0b1120) : const Color(0xfff8fafc),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : primaryNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isManager ? "طلبات اقتراح التكريم 💡" : "ترشيح طلاب للتكريم 🎖️",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : primaryNavy,
          ),
        ),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              backgroundColor: accentGold,
              elevation: 6,
              icon: const Icon(Icons.add_comment_rounded, color: Colors.black),
              label: const Text(
                "طلب اقتراح جديد",
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black),
              ),
              onPressed: () => _showCreateRequestDialog(isDark),
            )
          : null,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentGold.withValues(alpha: isDark ? 0.08 : 0.12),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('honor_suggestion_requests')
                  .where('cycleId', isEqualTo: widget.cycle.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      "لا توجد طلبات اقتراح تكريم حالياً ✨",
                      style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  );
                }

                final docs = snapshot.data!.docs.toList();
                final filteredDocs = docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (isManager) return true;
                  List targetSups = data['targetSupervisors'] ?? [];
                  return targetSups.contains('all') || targetSups.contains(widget.uid);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      "لا توجد طلبات موجهة إليك حالياً 📩",
                      style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var reqData = filteredDocs[index].data() as Map<String, dynamic>;
                    String reqId = filteredDocs[index].id;
                    return _buildRequestCard(reqId, reqData, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(String reqId, Map<String, dynamic> data, bool isDark) {
    String title = data['title'] ?? 'طلب ترشيح';
    int maxStudents = data['maxStudents'] ?? 1;
    Timestamp deadlineTs = data['deadline'] ?? Timestamp.now();
    DateTime deadline = deadlineTs.toDate();
    bool isExpired = DateTime.now().isAfter(deadline);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1e293b).withValues(alpha: 0.7) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isExpired
              ? Colors.red.withValues(alpha: 0.3)
              : isDark
                  ? accentGold.withValues(alpha: 0.35)
                  : primaryNavy.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.tips_and_updates_rounded, color: accentGold, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : primaryNavy,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 12, color: isDark ? Colors.white54 : Colors.black45),
                          const SizedBox(width: 4),
                          Text(
                            "ينتهي في: ${intl.DateFormat('yyyy/MM/dd hh:mm a').format(deadline)}",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isExpired ? "مغلق 🔒" : "متاح ⏳",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isExpired ? Colors.red : Colors.green,
                    ),
                  ),
                ),
                if (isManager) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                    tooltip: "حذف الطلب",
                    onPressed: () => _confirmDeleteRequest(reqId),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "أقصى عدد للطلاب المسموح بهم: $maxStudents طالب لكل مشرف",
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? accentGold : primaryNavy),
              ),
            ),
            const SizedBox(height: 16),

            if (!isManager) ...[
              if (!isExpired)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('honor_suggestions')
                      .where('requestId', isEqualTo: reqId)
                      .where('supervisorId', isEqualTo: widget.uid)
                      .snapshots(),
                  builder: (context, hasSubmittedSnap) {
                    bool alreadySubmitted =
                        hasSubmittedSnap.hasData && hasSubmittedSnap.data!.docs.isNotEmpty;

                    if (alreadySubmitted) {
                      String suggestionDocId = hasSubmittedSnap.data!.docs.first.id;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "تم إرسال اقتراحك بنجاح ✅",
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                              ),
                              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                              label: const Text("تعديل / إلغاء", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => _deleteSupervisorSuggestion(suggestionDocId),
                            )
                          ],
                        ),
                      );
                    }

                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGold,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black, size: 18),
                        label: const Text(
                          "تقديم الاقتراحات ✨",
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        onPressed: () => _showSubmitSuggestionDialog(reqId, maxStudents, isDark),
                      ),
                    );
                  },
                )
              else
                const Center(
                  child: Text(
                    "انتهت مهلة إرسال الاقتراحات لهذا الطلب 🔒",
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.redAccent),
                  ),
                ),
            ] else ...[
              const Divider(height: 24),
              _buildManagerViewSuggestions(reqId, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSupervisorSuggestion(String docId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد التعديل والإلغاء", style: TextStyle(fontFamily: 'Cairo')),
        content: const Text("هل ترغب في إلغاء اقتراحك وإتاحة إمكانية الاختيار مجدداً؟", style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("نعم، احذف وحرر", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('honor_suggestions').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إلغاء الاقتراح، يمكنك تقديم اقتراح جديد الآن ✨", style: TextStyle(fontFamily: 'Cairo'))));
    }
  }

  Future<void> _confirmDeleteRequest(String reqId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف طلب التكريم", style: TextStyle(fontFamily: 'Cairo')),
        content: const Text("هل أنت تأكد من حذف هذا الطلب؟ سيتم حذف جميع الاقتراحات الواردة بخصوصه أيضاً.", style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("حذف النهائي", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('honor_suggestion_requests').doc(reqId).delete();
      var batch = FirebaseFirestore.instance.batch();
      var suggestions = await FirebaseFirestore.instance.collection('honor_suggestions').where('requestId', isEqualTo: reqId).get();
      for (var doc in suggestions.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حذف الطلب وجميع الاقتراحات المترتبة عليه 🗑️", style: TextStyle(fontFamily: 'Cairo'))));
    }
  }

  // ----------------------------------------------------
  // 1. إنشاء طلب جديد مع الإشعار الفوري للمشرفين
  // ----------------------------------------------------
  void _showCreateRequestDialog(bool isDark) {
    TextEditingController titleController = TextEditingController();
    TextEditingController maxStudentsController = TextEditingController(text: "1");
    DateTime selectedDeadline = DateTime.now().add(const Duration(days: 2));
    List<String> selectedSupervisors = ['all'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff0f172a) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          "طلب اقتراح أسماء للتكريم 💡",
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : primaryNavy),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: "عنوان الطلب / التكريم",
                          labelStyle: const TextStyle(fontFamily: 'Cairo'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: maxStudentsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "العدد المسموح اقتراحه لكل مشرف",
                          labelStyle: const TextStyle(fontFamily: 'Cairo'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          "تاريخ قفل الطلب: ${intl.DateFormat('yyyy/MM/dd hh:mm a').format(selectedDeadline)}",
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white : primaryNavy),
                        ),
                        trailing: const Icon(Icons.event_rounded, color: Colors.amber),
                        onTap: () async {
                          DateTime? date = await showDatePicker(
                            context: context,
                            initialDate: selectedDeadline,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            if (!context.mounted) return;
                            TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                            if (time != null) {
                              setModalState(() {
                                selectedDeadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                              });
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text("تحديد المشرفين الموجه لهم الطلب:", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('supervisors').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();
                          var sups = snapshot.data!.docs;

                          return Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: const Text("جميع المشرفين ✨", style: TextStyle(fontFamily: 'Cairo')),
                                selected: selectedSupervisors.contains('all'),
                                onSelected: (val) {
                                  setModalState(() {
                                    selectedSupervisors.clear();
                                    if (val) selectedSupervisors.add('all');
                                  });
                                },
                              ),
                              ...sups.map((s) {
                                String sId = s.id;
                                String sName = s['name'] ?? 'مشرف';
                                bool isSel = selectedSupervisors.contains(sId);
                                return FilterChip(
                                  label: Text(sName, style: const TextStyle(fontFamily: 'Cairo')),
                                  selected: isSel,
                                  onSelected: (val) {
                                    setModalState(() {
                                      selectedSupervisors.remove('all');
                                      if (val) {
                                        selectedSupervisors.add(sId);
                                      } else {
                                        selectedSupervisors.remove(sId);
                                      }
                                      if (selectedSupervisors.isEmpty) selectedSupervisors.add('all');
                                    });
                                  },
                                );
                              }).toList()
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGold,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            String reqTitle = titleController.text.trim();
                            if (reqTitle.isEmpty) return;

                            await FirebaseFirestore.instance.collection('honor_suggestion_requests').add({
                              'cycleId': widget.cycle.id,
                              'title': reqTitle,
                              'maxStudents': int.tryParse(maxStudentsController.text) ?? 1,
                              'deadline': Timestamp.fromDate(selectedDeadline),
                              'targetSupervisors': selectedSupervisors,
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            // 🔔 إرسال الإشعارات للمشرفين المستهدفين
                            _sendNotificationToSupervisors(
                              targetSupervisors: selectedSupervisors,
                              requestTitle: reqTitle,
                            );

                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                          child: const Text("إرسال الطلب للمشرفين 🚀", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // 2. تقديم الاقتراحات (عند المشرف)
  // ----------------------------------------------------
  void _showSubmitSuggestionDialog(String reqId, int maxStudents, bool isDark) {
    List<Map<String, String>> selectedStudentsWithReason = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff0f172a) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text("اختر طلابك المرشحين ⭐", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : primaryNavy)),
                  ),
                  Text("المسموح باختيارهم: أقصاه $maxStudents طلاب", style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.amber)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('students')
                          .where('cycleId', isEqualTo: widget.cycle.id)
                          .where('supervisorId', isEqualTo: widget.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        var students = snapshot.data!.docs;

                        if (students.isEmpty) {
                          return const Center(child: Text("لا يوجد طلاب مسجلون تحت إشرافك في هذه الدورة", style: TextStyle(fontFamily: 'Cairo')));
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: students.length,
                          itemBuilder: (context, idx) {
                            var stData = students[idx].data() as Map<String, dynamic>;
                            String stName = stData['name'] ?? 'طالب';
                            String stId = students[idx].id;

                            bool isSelected = selectedStudentsWithReason.any((element) => element['id'] == stId);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                title: Text(stName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                trailing: Icon(isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: isSelected ? Colors.green : Colors.grey),
                                onTap: () {
                                  if (isSelected) {
                                    setModalState(() => selectedStudentsWithReason.removeWhere((e) => e['id'] == stId));
                                  } else {
                                    if (selectedStudentsWithReason.length >= maxStudents) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تجاوزت العدد المسموح به ($maxStudents)", style: const TextStyle(fontFamily: 'Cairo'))));
                                      return;
                                    }
                                    _promptReasonDialog(stName, (reason) {
                                      setModalState(() {
                                        selectedStudentsWithReason.add({
                                          'id': stId,
                                          'name': stName,
                                          'reason': reason,
                                        });
                                      });
                                    });
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        if (selectedStudentsWithReason.isEmpty) return;

                        String actualSupName = await _getActualSupervisorName(widget.uid);

                        await FirebaseFirestore.instance.collection('honor_suggestions').add({
                          'requestId': reqId,
                          'supervisorId': widget.uid,
                          'supervisorName': actualSupName,
                          'students': selectedStudentsWithReason,
                          'submittedAt': FieldValue.serverTimestamp(),
                        });

                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                      child: const Text("إرسال الاقتراحات للمدير 📩", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _promptReasonDialog(String studentName, Function(String) onConfirm) {
    TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("سبب اختيار ($studentName)", style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: "مثال: متميز في الحفظ والتزام تام بالأخلاق"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm(reasonController.text.trim());
            },
            child: const Text("تأكيد", style: TextStyle(fontFamily: 'Cairo')),
          )
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // 3. عرض نتائج الاقتراحات للمدير
  // ----------------------------------------------------
  Widget _buildManagerViewSuggestions(String reqId, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('honor_suggestions').where('requestId', isEqualTo: reqId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        var docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_empty_rounded, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text("لم يتم إرسال أي اقتراحات من المشرفين بعد ⏳", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.orange)),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mark_email_read_rounded, color: accentGold, size: 18),
                const SizedBox(width: 6),
                Text(
                  "الاقتراحات الواردة (${docs.length}):",
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : primaryNavy),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              List students = data['students'] ?? [];
              String supUid = data['supervisorId'] ?? '';
              String storedSupName = data['supervisorName'] ?? '';

              return FutureBuilder<String>(
                future: (storedSupName.isNotEmpty && storedSupName != 'مشرف')
                    ? Future.value(storedSupName)
                    : _getActualSupervisorName(supUid),
                builder: (context, nameSnap) {
                  String displaySupName = nameSnap.data ?? "جاري التحميل...";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff0f172a).withValues(alpha: 0.6) : const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: accentGold.withValues(alpha: 0.2),
                              child: Icon(Icons.person, size: 14, color: accentGold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "المشرف: $displaySupName",
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? accentGold : primaryNavy),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...students.map((st) => Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("🌟 ", style: TextStyle(fontSize: 12)),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                                        children: [
                                          TextSpan(text: "${st['name']}: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                          TextSpan(text: "${st['reason']}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }
}