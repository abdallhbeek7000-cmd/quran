import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_session_page.dart';
import '../models/cycle_model.dart';
import 'student_sessions_page.dart';
import '../utils/app_colors.dart';
import 'add_student_page.dart';
import 'edit_student_page.dart';

class StudentsPage extends StatefulWidget {
  final CycleModel cycle;

  final String role;

  final String uid;

  const StudentsPage({
    super.key,
    required this.cycle,
    required this.role,
    required this.uid,
  });

  @override
State<StudentsPage> createState() =>
    _StudentsPageState();
}

class _StudentsPageState
    extends State<StudentsPage> {

String search = '';
String selectedSupervisor = '';

  @override
  Widget build(BuildContext context) {
    final cycle = widget.cycle;
final role = widget.role;
final uid = widget.uid;
    Query query = FirebaseFirestore.instance
        .collection('students')
        .where('cycleId', isEqualTo: cycle.id)
        .where('archived', isEqualTo: false);

    if (role == "supervisor") {
      query = query.where(
        'supervisorId',
        isEqualTo: uid,
      );
    }

    return Scaffold(
      floatingActionButton:

    role == "manager"

        ? FloatingActionButton(

            onPressed: () {

              Navigator.push(
                context,

                MaterialPageRoute(
                  builder: (_) =>
                      AddStudentPage(
                    cycle: cycle,
                  ),
                ),
              );
            },

            child: const Icon(
              Icons.add,
            ),
          )

        : null,
      appBar: AppBar(
        title: const Text("الطلاب"),
      ),


      
body: Column(
  children: [

    Padding(
      padding: const EdgeInsets.all(10),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'ابحث عن طالب',
          prefixIcon:
              const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(15),
          ),
        ),
        onChanged: (value) {
          setState(() {
            search =
                value.toLowerCase();
          });
        },
      ),
    ),

    Padding(
  padding:
      const EdgeInsets.symmetric(
    horizontal: 10,
  ),

  child: StreamBuilder(

    stream:
        FirebaseFirestore.instance
            .collection(
              'supervisors',
            )
            .snapshots(),

    builder: (context, snapshot) {

      if (!snapshot.hasData) {
        return const SizedBox();
      }

      final supervisors =
          snapshot.data!.docs;

      return DropdownButtonFormField(

        value:
            selectedSupervisor.isEmpty
                ? null
                : selectedSupervisor,

        decoration:
            const InputDecoration(
          labelText:
              'فلترة حسب المشرف',
        ),

        items: [

          const DropdownMenuItem(
            value: '',
            child: Text(
              'كل المشرفين',
            ),
          ),

          ...supervisors.map((sup) {

            final data =
                sup.data();

            return DropdownMenuItem(

              value: data['name'],

              child: Text(
                data['name'],
              ),
            );
          }).toList(),
        ],

        onChanged: (value) {

          setState(() {
            selectedSupervisor =
                value.toString();
          });
        },
      );
    },
  ),
),

    Flexible(
      child: StreamBuilder(        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "لا يوجد طلاب",
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final student = docs[index];

              final data =
                  student.data()
                      as Map<String, dynamic>;
                      final name =
    data['name']
        .toString()
        .toLowerCase();

final supervisor =
    data['supervisorName'] ?? '';

final matchesSearch =
    name.contains(search);

final matchesSupervisor =

    selectedSupervisor.isEmpty ||

    supervisor ==
        selectedSupervisor;

if (!(matchesSearch &&
    matchesSupervisor)) {

  return const SizedBox();
}

              
              return Card(
                margin:
                    const EdgeInsets.all(10),
                child: ListTile(
                  isThreeLine: true,
                  leading: CircleAvatar(
  radius: 22,
  backgroundColor:
      AppColors.primary,
  child: Text(
    data['serial']
        .toString()
        .substring(
      data['serial']
              .length -
          2,
    ),
    style: const TextStyle(
      color: Colors.white,
      fontWeight:
          FontWeight.bold,
      fontSize: 18,
    ),
  ),
),
title: Text(
  data['name'],
  style: const TextStyle(
    fontSize: 18,
    fontWeight:
        FontWeight.bold,
  ),
),                  subtitle: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        "الرقم: ${data['serial']}",
                      ),
                      Text(
                        "المشرف: ${data['supervisorName'] == '' ? 'غير موزع' : data['supervisorName']}",
                      ),
                      const SizedBox(height: 6),

Container(
  padding:
      const EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 4,
  ),
  decoration: BoxDecoration(
    color: AppColors.gold
        .withOpacity(0.15),
    borderRadius:
        BorderRadius.circular(20),
  ),
  child: const Text(
    "طالب فعال",
    style: TextStyle(
      color: AppColors.gold,
      fontWeight:
          FontWeight.bold,
    ),
  ),
),
FutureBuilder(

  future:
      FirebaseFirestore.instance
          .collection('sessions')
          .where(
            'studentId',
            isEqualTo:
                student.id,
          )
          .get(),

  builder: (context, snapshot) {

    if (!snapshot.hasData) {

      return const Text(
        'الجلسات: ...',
      );
    }

    final count =
        snapshot.data!.docs.length;

    return Text(
      'عدد الجلسات: $count',
    );
  },
),
                    ],
                  ),

                  
                  trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddSessionPage(
              studentId: student.id,
              studentName: data['name'],
              supervisorId:
                  data['supervisorId'],
              supervisorName:
                  data['supervisorName'],
            ),
          ),
        );
      },
      child: const Text("جلسة"),
    ),

    const SizedBox(width: 5),

    ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StudentSessionsPage(
              studentId: student.id,
              studentName: data['name'],
              role: role,
            ),
          ),
        );
      },
      child: const Text("السجل"),
    ),

    IconButton(
  icon: const Icon(Icons.edit),

  onPressed: () {

    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) => EditStudentPage(
          student: student,
        ),
      ),
    );
  },
),

    IconButton(
  icon: const Icon(
    Icons.delete,
    color: Colors.red,
  ),
  onPressed: () async {
    final confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text(
            'هل أنت متأكد من حذف الطالب؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('إلغاء'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                'حذف',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(student.id)
          .delete();
    }
  },
),
  ],
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
}