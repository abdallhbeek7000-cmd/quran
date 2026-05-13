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
  State<AssignStudentsPage> createState() =>
      _AssignStudentsPageState();
}

class _AssignStudentsPageState
    extends State<AssignStudentsPage> {
  final firestore = FirebaseFirestore.instance;

  final studentService = StudentService();

  String? selectedSupervisorId;

  String? selectedSupervisorName;

  assignStudent(String studentId) async {
    if (selectedSupervisorId == null) {
      return;
    }

    await studentService.assignSupervisor(
      studentId: studentId,
      supervisorId: selectedSupervisorId!,
      supervisorName:
          selectedSupervisorName ?? '',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("تم توزيع الطالب"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("توزيع الطلاب"),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(15),
            child: StreamBuilder(
              stream: firestore
                  .collection('supervisors')
                  .snapshots(),
              builder:
                  (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                final supervisors =
                    snapshot.data!.docs;

                return DropdownButtonFormField(
                  value:
                      selectedSupervisorId,
                  items:
                      supervisors.map((s) {
                    final data = s.data();

                    return DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        data['email'],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    final sup =
                        supervisors.firstWhere(
                      (e) => e.id == v,
                    );

                    selectedSupervisorId =
                        sup.id;

                    selectedSupervisorName =
                        sup['email'];

                    setState(() {});
                  },
                  decoration:
                      const InputDecoration(
                    labelText:
                        "اختر المشرف",
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: StreamBuilder(
              stream: firestore
                  .collection(
                    'students',
                  )
                  .where(
                    'cycleId',
                    isEqualTo:
                        widget.cycle.id,
                  )
                  .where(
                    'archived',
                    isEqualTo: false,
                  )
                  .snapshots(),
              builder:
                  (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final docs =
                    snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "لا يوجد طلاب",
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder:
                      (context, index) {
                    final student =
                        docs[index];

                    final data =
                        student.data();

                    return Card(
                      margin:
                          const EdgeInsets
                              .all(10),
                      child: ListTile(
                        title: Text(
                          data['name'],
                        ),
                        subtitle: Text(
                          data['supervisorName'] ==
                                  ''
                              ? 'غير موزع'
                              : data[
                                  'supervisorName'],
                        ),
                        trailing:
                            ElevatedButton(
                          onPressed: () {
                            assignStudent(
                              student.id,
                            );
                          },
                          child: const Text(
                            "توزيع",
                          ),
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
}