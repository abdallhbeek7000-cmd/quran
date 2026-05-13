import 'package:flutter/material.dart';

import '../services/exam_service.dart';

class AddExamPage
    extends StatefulWidget {
  final String studentId;

  final String studentName;

  final String supervisorId;

  final String supervisorName;

  const AddExamPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<AddExamPage> createState() =>
      _AddExamPageState();
}

class _AddExamPageState
    extends State<AddExamPage> {
  final examService = ExamService();

  final titleController =
      TextEditingController();

  final notesController =
      TextEditingController();

  final scoreController =
      TextEditingController();

  String type = "شفوي";

  bool passed = true;

  bool loading = false;

  saveExam() async {
    setState(() {
      loading = true;
    });

    await examService.addExam(
      studentId: widget.studentId,
      studentName:
          widget.studentName,
      supervisorId:
          widget.supervisorId,
      supervisorName:
          widget.supervisorName,
      title: titleController.text,
      type: type,
      score:
          int.tryParse(
            scoreController.text,
          ) ??
          0,
      passed: passed,
      notes: notesController.text,
    );

    setState(() {
      loading = false;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "تم إضافة الاختبار",
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          "إضافة اختبار",
        ),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller:
                  titleController,
              decoration:
                  const InputDecoration(
                labelText:
                    "عنوان الاختبار",
              ),
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField(
              value: type,
              items: const [
                DropdownMenuItem(
                  value: "شفوي",
                  child: Text(
                    "شفوي",
                  ),
                ),
                DropdownMenuItem(
                  value: "كتابي",
                  child: Text(
                    "كتابي",
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  type = v!;
                });
              },
              decoration:
                  const InputDecoration(
                labelText:
                    "نوع الاختبار",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller:
                  scoreController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText:
                    "الدرجة",
              ),
            ),

            const SizedBox(height: 15),

            SwitchListTile(
              value: passed,
              title: const Text(
                "ناجح",
              ),
              onChanged: (v) {
                setState(() {
                  passed = v;
                });
              },
            ),

            const SizedBox(height: 15),

            TextField(
              controller:
                  notesController,
              maxLines: 4,
              decoration:
                  const InputDecoration(
                labelText:
                    "ملاحظات",
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    loading
                        ? null
                        : saveExam,
                child:
                    loading
                        ? const CircularProgressIndicator()
                        : const Text(
                            "حفظ الاختبار",
                          ),
              ),
            )
          ],
        ),
      ),
    );
  }
}