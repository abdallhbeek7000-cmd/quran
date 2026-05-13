import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditStudentPage extends StatefulWidget {

  final DocumentSnapshot student;

  const EditStudentPage({
    super.key,
    required this.student,
  });

  @override
  State<EditStudentPage> createState() =>
      _EditStudentPageState();
}

class _EditStudentPageState
    extends State<EditStudentPage> {

  late TextEditingController nameController;
  late TextEditingController serialController;

  @override
  void initState() {
    super.initState();

    final data =
        widget.student.data()
            as Map<String, dynamic>;

    nameController =
        TextEditingController(
      text: data['name'],
    );

    serialController =
        TextEditingController(
      text:
          data['serial'].toString(),
    );
  }

  Future<void> updateStudent() async {

    await FirebaseFirestore.instance
        .collection('students')
        .doc(widget.student.id)
        .update({

      'name': nameController.text,

      'serial':
          int.tryParse(
                serialController.text,
              ) ??
              0,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('تعديل الطالب'),
      ),

      body: Padding(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          children: [

            TextField(
              controller:
                  nameController,
              decoration:
                  const InputDecoration(
                labelText:
                    'اسم الطالب',
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller:
                  serialController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText:
                    'الرقم',
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed:
                  updateStudent,
              child:
                  const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}