import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cycle_model.dart';
import '../services/student_service.dart';

class AssignStudentsPage extends StatefulWidget {
  final CycleModel cycle;

  const AssignStudentsPage({
    super.key,
    required this.cycle,
  });

  @override
  State<AssignStudentsPage> createState() => _AssignStudentsPageState();
}

class _AssignStudentsPageState extends State<AssignStudentsPage> {
  final firestore = FirebaseFirestore.instance;
  final studentService = StudentService();
  final Color primaryColor = const Color(0xff425c75);

  // متغيرات التوزيع السريع من الأعلى (اختياري)
  String? globalSupervisorId;
  String? globalSupervisorName;

  assignStudent(String studentId, String supId, String supName) async {
    if (supId.isEmpty) return;

    await studentService.assignSupervisor(
      studentId: studentId,
      supervisorId: supId,
      supervisorName: supName,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primaryColor,
        content: Text("تم تعيين $supName بنجاح"),
        duration: const Duration(seconds: 1),
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
        title: const Text("توزيع الطلاب على المشرفين", 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // لوحة التحكم العلوية (التوزيع السريع)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("التوزيع السريع لمشرف محدد:", 
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                StreamBuilder(
                  stream: firestore.collection('supervisors').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final supervisors = snapshot.data!.docs;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: globalSupervisorId,
                          decoration: const InputDecoration(border: InputBorder.none),
                          hint: const Text("اختر مشرفاً للكل"),
                          items: supervisors.map((s) {
                            return DropdownMenuItem(
                              value: s.id,
                              child: Text(s['name'] ?? s['email']), // عرض الاسم وإذا مو موجود الإيميل
                            );
                          }).toList(),
                          onChanged: (v) {
                            final sup = supervisors.firstWhere((e) => e.id == v);
                            setState(() {
                              globalSupervisorId = sup.id;
                              globalSupervisorName = sup['name'] ?? sup['email'];
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder(
              stream: firestore
                  .collection('students')
                  .where('cycleId', isEqualTo: widget.cycle.id)
                  .where('archived', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;

                if (docs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final student = docs[index];
                    final data = student.data();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.1),
                          child: Text(data['name'].toString().substring(0, 1),
                              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          data['supervisorName'] == '' ? 'غير موزع' : "المشرف: ${data['supervisorName']}",
                          style: TextStyle(color: data['supervisorName'] == '' ? Colors.orange : Colors.green),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: globalSupervisorId == null ? Colors.grey : primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: globalSupervisorId == null 
                            ? null 
                            : () => assignStudent(student.id, globalSupervisorId!, globalSupervisorName!),
                          child: const Text("توزيع", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text("لا يوجد طلاب حالياً في هذه الدورة"),
        ],
      ),
    );
  }
}