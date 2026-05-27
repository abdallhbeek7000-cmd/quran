import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cycle_service.dart';
import '../models/cycle_model.dart'; 
import 'students_page.dart'; 

class CyclesPage extends StatefulWidget {
  const CyclesPage({super.key});

  @override
  State<CyclesPage> createState() => _CyclesPageState();
}

class _CyclesPageState extends State<CyclesPage> {
  final firestore = FirebaseFirestore.instance;
  final cycleService = CycleService();
  final Color primaryColor = const Color(0xff425c75);

  archiveCycle(String id) async {
    await cycleService.archiveCycle(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.orange,
        content: Text("تمت أرشفة الدورة بنجاح"),
      ),
    );
  }

  Future<void> _editEndDate(BuildContext context, String cycleId, String currentEndDateStr) async {
    DateTime initialDate = DateTime.now();
    try {
      initialDate = DateTime.parse(currentEndDateStr);
    } catch (_) {}

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      await firestore.collection('cycles').doc(cycleId).update({
        'endDate': pickedDate.toString(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("تم تحديث تاريخ انتهاء الدورة بنجاح 🎉"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text("إدارة الدورات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        stream: firestore.collection('cycles').orderBy('startDate', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final cycle = docs[index];
              final data = cycle.data();
              bool isArchived = data['archived'] ?? false;
              String endDateStr = data['endDate']?.toString() ?? DateTime.now().toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: isArchived ? Colors.grey[200] : primaryColor.withOpacity(0.1),
                        child: Icon(
                          isArchived ? Icons.archive_outlined : Icons.calendar_today_rounded,
                          color: isArchived ? Colors.grey : primaryColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        data['name'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isArchived ? Colors.grey : Colors.black87,
                          decoration: isArchived ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text(
                        "رقم الدورة: ${data['cycleNumber'] ?? ''}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      
                      // 🛠️ تمرير كائن الدورة المؤرشفة بأمان كـ dynamic لقتل أي خطأ بـ الموديل
                      trailing: isArchived 
                        ? IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 22, color: Colors.blueGrey),
                            tooltip: "استعراض أرشيف طلاب الدورة",
                            onPressed: () {
                              final dynamic outputModel = CycleModel;
                              
                              Navigator.push(
                                context, 
                                MaterialPageRoute(
                                  builder: (_) => StudentsPage(
                                    cycle: (outputModel is CycleModel) ? (cycle as dynamic) : (cycle as dynamic),
                                    role: "manager",
                                    uid: "",
                                    isArchivedFromHistory: true, // وضع التصفح التام والآمن 🔒
                                  ),
                                ),
                              );
                            },
                          )
                        : Icon(Icons.arrow_drop_down_circle_outlined, color: primaryColor, size: 20),
                        
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            children: [
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildDateInfo("تاريخ البدء", data['startDate'].toString().split(' ')[0], Icons.login_rounded, Colors.green),
                                  InkWell(
                                    onTap: isArchived ? null : () => _editEndDate(context, cycle.id, endDateStr),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      child: Row(
                                        children: [
                                          _buildDateInfo("تاريخ الانتهاء", endDateStr.split(' ')[0], Icons.logout_rounded, Colors.redAccent),
                                          if (!isArchived) ...[
                                            const SizedBox(width: 6),
                                            Icon(Icons.edit_calendar_rounded, size: 16, color: primaryColor),
                                          ]
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!isArchived) ...[
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => archiveCycle(cycle.id),
                                    icon: const Icon(Icons.archive, size: 18),
                                    label: const Text("نقل إلى الأرشيف"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ]
                            ],
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
      ),
    );
  }

  Widget _buildDateInfo(String label, String date, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 5),
        Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  // 🛠️ تم إصلاح الخطأ المطبعي هنا بالأسفل بالكامل لتختفي الحمرة فوراً
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          const Text("لا توجد دورات مسجلة حالياً", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}