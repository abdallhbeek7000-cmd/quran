import 'package:flutter/material.dart';

import '../models/session_model.dart';

import '../services/session_service.dart';

class AddSessionPage extends StatefulWidget {
  final String studentId;

  final String studentName;

  final String supervisorId;

  final String supervisorName;

  const AddSessionPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<AddSessionPage> createState() =>
      _AddSessionPageState();
}

class _AddSessionPageState
    extends State<AddSessionPage> {
  final sessionService = SessionService();

  final newMemorization =
      TextEditingController();

  final review = TextEditingController();

  final homework = TextEditingController();

  final religiousActivities =
      TextEditingController();

  final notes = TextEditingController();

  bool loading = false;

  bool absent = false;

  String rating = "جيد";

  String studentStatus = "مهذب";

  addSession() async {
    final hasToday =
        await sessionService.hasSessionToday(
      widget.studentId,
    );

    if (hasToday) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "تم تسجيل جلسة اليوم مسبقًا",
          ),
        ),
      );

      return;
    }

    setState(() {
      loading = true;
    });

    final now = DateTime.now();

    final date =
        "${now.year}-${now.month}-${now.day}";

    final session = SessionModel(
      id: '',
      studentId: widget.studentId,
      studentName: widget.studentName,
      supervisorId: widget.supervisorId,
      supervisorName:
          widget.supervisorName,
      date: date,
      absent: absent,
      newMemorization:
          absent ? '' : newMemorization.text,
      review: absent ? '' : review.text,
      homework:
          absent ? '' : homework.text,
      rating: absent ? '' : rating,
      studentStatus:
          absent ? '' : studentStatus,
      religiousActivities:
          absent
              ? ''
              : religiousActivities.text,
      notes: notes.text,
    );

    await sessionService.addSession(
      session,
    );

    setState(() {
      loading = false;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "تمت إضافة الجلسة",
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.studentName,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SwitchListTile(
              value: absent,
              title: const Text(
                "الطالب غائب",
              ),
              onChanged: (v) {
                setState(() {
                  absent = v;
                });
              },
            ),

            if (!absent) ...[
              TextField(
                controller:
                    newMemorization,
                decoration:
                    const InputDecoration(
                  labelText:
                      "الحفظ الجديد",
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: review,
                decoration:
                    const InputDecoration(
                  labelText:
                      "المراجعة",
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: homework,
                decoration:
                    const InputDecoration(
                  labelText:
                      "الواجب",
                ),
              ),

              const SizedBox(height: 15),

              DropdownButtonFormField(
                value: rating,
                items: const [
                  DropdownMenuItem(
                    value: "ممتاز",
                    child: Text(
                      "ممتاز",
                    ),
                  ),
                  DropdownMenuItem(
                    value: "جيد",
                    child: Text(
                      "جيد",
                    ),
                  ),
                  DropdownMenuItem(
                    value: "سيء",
                    child: Text(
                      "سيء",
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    rating = v!;
                  });
                },
                decoration:
                    const InputDecoration(
                  labelText:
                      "التقييم",
                ),
              ),

              const SizedBox(height: 15),

              DropdownButtonFormField(
                value: studentStatus,
                items: const [
                  DropdownMenuItem(
                    value: "مهذب",
                    child: Text(
                      "مهذب",
                    ),
                  ),
                  DropdownMenuItem(
                    value: "منضبط",
                    child: Text(
                      "منضبط",
                    ),
                  ),
                  DropdownMenuItem(
                    value: "مشاغب",
                    child: Text(
                      "مشاغب",
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        "كثير الحركة",
                    child: Text(
                      "كثير الحركة",
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    studentStatus = v!;
                  });
                },
                decoration:
                    const InputDecoration(
                  labelText:
                      "حالة الطالب",
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller:
                    religiousActivities,
                decoration:
                    const InputDecoration(
                  labelText:
                      "نشاطات دينية",
                ),
              ),
            ],

            const SizedBox(height: 15),

            TextField(
              controller: notes,
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
                    loading ? null : addSession,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        "حفظ الجلسة",
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }
}