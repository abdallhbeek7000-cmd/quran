import 'package:flutter/material.dart';

import '../models/cycle_model.dart';
import '../models/student_model.dart';

import '../services/student_service.dart';

class AddStudentPage extends StatefulWidget {
  final CycleModel cycle;

  const AddStudentPage({
    super.key,
    required this.cycle,
  });

  @override
  State<AddStudentPage> createState() =>
      _AddStudentPageState();
}

class _AddStudentPageState
    extends State<AddStudentPage> {
  final studentService = StudentService();

  final name = TextEditingController();

  final fatherName = TextEditingController();

  final motherName = TextEditingController();

  final phone = TextEditingController();

  final fatherJob = TextEditingController();

  final address = TextEditingController();

  final schoolGrade = TextEditingController();

  final memorizedPages = TextEditingController();

  DateTime? birthDate;

  DateTime? startDate;

  bool loading = false;

  String studentType = "new";

  addStudent() async {
    setState(() {
      loading = true;
    });

    final serial =
        await studentService.generateStudentSerial(
      year: widget.cycle.year,
      cycleNumber: widget.cycle.cycleNumber,
    );

    final student = StudentModel(
      id: '',
      serial: serial,
      name: name.text,
      fatherName: fatherName.text,
      motherName: motherName.text,
      phone: phone.text,
      fatherJob: fatherJob.text,
      address: address.text,
      schoolGrade: schoolGrade.text,
      birthDate: birthDate.toString(),
      studentType: studentType,
      supervisorId: '',
      supervisorName: '',
      cycleId: widget.cycle.id,
      cycleName: widget.cycle.name,
      startMemorization:
          startDate.toString(),
      memorizedPages:
          double.tryParse(
                memorizedPages.text,
              ) ??
              0,
      imageUrl: '',
      archived: false,
      createdAt:
          DateTime.now().toString(),
    );

    await studentService.addStudent(student);

    setState(() {
      loading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("تمت إضافة الطالب"),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إضافة طالب"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField(
              value: studentType,
              items: const [
                DropdownMenuItem(
                  value: "new",
                  child: Text("طالب جديد"),
                ),
                DropdownMenuItem(
                  value: "old",
                  child: Text("طالب قديم"),
                ),
                DropdownMenuItem(
                  value: "completed",
                  child: Text("خاتم"),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  studentType = v!;
                });
              },
              decoration: const InputDecoration(
                labelText: "نوع الطالب",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: "اسم الطالب",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: fatherName,
              decoration: const InputDecoration(
                labelText: "اسم الأب",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: motherName,
              decoration: const InputDecoration(
                labelText: "اسم الأم",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: phone,
              decoration: const InputDecoration(
                labelText: "رقم الهاتف",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: fatherJob,
              decoration: const InputDecoration(
                labelText: "عمل الأب",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: address,
              decoration: const InputDecoration(
                labelText: "مكان السكن",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: schoolGrade,
              decoration: const InputDecoration(
                labelText: "الصف الدراسي",
              ),
            ),

            const SizedBox(height: 15),

            if (studentType != "new")
              TextField(
                controller: memorizedPages,
                keyboardType:
                    TextInputType.number,
                decoration:
                    const InputDecoration(
                  labelText:
                      "عدد الصفحات المحفوظة",
                ),
              ),

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: () async {
                birthDate =
                    await showDatePicker(
                  context: context,
                  firstDate:
                      DateTime(2000),
                  lastDate:
                      DateTime.now(),
                  initialDate:
                      DateTime.now(),
                );

                setState(() {});
              },
              child: Text(
                birthDate == null
                    ? "تاريخ الميلاد"
                    : birthDate
                        .toString()
                        .split(" ")[0],
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () async {
                startDate =
                    await showDatePicker(
                  context: context,
                  firstDate:
                      DateTime(2000),
                  lastDate:
                      DateTime.now(),
                  initialDate:
                      DateTime.now(),
                );

                setState(() {});
              },
              child: Text(
                startDate == null
                    ? "تاريخ بدء الحفظ"
                    : startDate
                        .toString()
                        .split(" ")[0],
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    loading ? null : addStudent,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        "إضافة الطالب",
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }
}