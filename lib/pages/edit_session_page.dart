import 'package:flutter/material.dart';

import '../services/session_service.dart';

class EditSessionPage extends StatefulWidget {
  final String sessionId;

  final Map<String, dynamic> data;

  const EditSessionPage({
    super.key,
    required this.sessionId,
    required this.data,
  });

  @override
  State<EditSessionPage> createState() =>
      _EditSessionPageState();
}

class _EditSessionPageState
    extends State<EditSessionPage> {
  final sessionService = SessionService();

  late TextEditingController
      newMemorization;

  late TextEditingController review;

  late TextEditingController homework;

  late TextEditingController
      religiousActivities;

  late TextEditingController notes;

  bool absent = false;

  String rating = "جيد";

  String studentStatus = "مهذب";

  bool loading = false;

  @override
  void initState() {
    super.initState();

    final data = widget.data;

    absent = data['absent'];

    rating = data['rating'];

    studentStatus =
        data['studentStatus'];

    newMemorization =
        TextEditingController(
      text: data['newMemorization'],
    );

    review = TextEditingController(
      text: data['review'],
    );

    homework =
        TextEditingController(
      text: data['homework'],
    );

    religiousActivities =
        TextEditingController(
      text:
          data['religiousActivities'],
    );

    notes = TextEditingController(
      text: data['notes'],
    );
  }

  save() async {
    setState(() {
      loading = true;
    });

    await sessionService.updateSession(
      sessionId: widget.sessionId,
      data: {
        'absent': absent,
        'newMemorization':
            absent
                ? ''
                : newMemorization.text,
        'review':
            absent ? '' : review.text,
        'homework':
            absent
                ? ''
                : homework.text,
        'rating':
            absent ? '' : rating,
        'studentStatus':
            absent
                ? ''
                : studentStatus,
        'religiousActivities':
            absent
                ? ''
                : religiousActivities
                    .text,
        'notes': notes.text,
      },
    );

    setState(() {
      loading = false;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "تم تعديل الجلسة",
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
            const Text("تعديل الجلسة"),
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
                    loading ? null : save,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        "حفظ التعديلات",
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }
}