import 'package:flutter/material.dart';

import '../services/cycle_service.dart';

class CreateCyclePage extends StatefulWidget {
  const CreateCyclePage({super.key});

  @override
  State<CreateCyclePage> createState() =>
      _CreateCyclePageState();
}

class _CreateCyclePageState
    extends State<CreateCyclePage> {
  final cycleService = CycleService();

  String type = "صيف";

  final year = TextEditingController();

  final cycleNumber = TextEditingController();

  DateTime? startDate;

  DateTime? endDate;

  bool loading = false;

  createCycle() async {
    if (startDate == null || endDate == null) {
      return;
    }

    setState(() {
      loading = true;
    });

    await cycleService.createCycle(
      type: type,
      year: int.parse(year.text),
      cycleNumber: int.parse(cycleNumber.text),
      startDate: startDate.toString(),
      endDate: endDate.toString(),
    );

    setState(() {
      loading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("تم إنشاء الدورة"),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إنشاء دورة"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField(
              value: type,
              items: const [
                DropdownMenuItem(
                  value: "صيف",
                  child: Text("صيف"),
                ),
                DropdownMenuItem(
                  value: "شتاء",
                  child: Text("شتاء"),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  type = v!;
                });
              },
              decoration: const InputDecoration(
                labelText: "نوع الدورة",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "السنة",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: cycleNumber,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "رقم الدورة",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                startDate = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: DateTime.now(),
                );

                setState(() {});
              },
              child: Text(
                startDate == null
                    ? "تاريخ البداية"
                    : startDate.toString().split(" ")[0],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                endDate = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: DateTime.now(),
                );

                setState(() {});
              },
              child: Text(
                endDate == null
                    ? "تاريخ النهاية"
                    : endDate.toString().split(" ")[0],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading ? null : createCycle,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("إنشاء الدورة"),
            )
          ],
        ),
      ),
    );
  }
}