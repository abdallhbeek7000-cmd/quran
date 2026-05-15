import 'package:flutter/material.dart';
import '../services/cycle_service.dart';

class CreateCyclePage extends StatefulWidget {
  const CreateCyclePage({super.key});

  @override
  State<CreateCyclePage> createState() => _CreateCyclePageState();
}

class _CreateCyclePageState extends State<CreateCyclePage> {
  final cycleService = CycleService();
  final Color primaryColor = const Color(0xff425c75);

  String type = "صيف";
  final year = TextEditingController();
  final cycleNumber = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  bool loading = false;

  // دالة لاختيار التاريخ بشكل أنيق
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor, // لون الرأس
              onPrimary: Colors.white, // لون النص في الرأس
              onSurface: primaryColor, // لون الأيام
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  createCycle() async {
    if (startDate == null || endDate == null || year.text.isEmpty || cycleNumber.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى ملء جميع الحقول واختيار التواريخ")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await cycleService.createCycle(
        type: type,
        year: int.parse(year.text),
        cycleNumber: int.parse(cycleNumber.text),
        startDate: startDate.toString(),
        endDate: endDate.toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("تم إنشاء الدورة بنجاح")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("حدث خطأ: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text("إنشاء دورة جديدة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  // نوع الدورة
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: _inputDecoration("نوع الدورة", Icons.wb_sunny_outlined),
                    items: const [
                      DropdownMenuItem(value: "صيف", child: Text("دورة صيفية")),
                      DropdownMenuItem(value: "شتاء", child: Text("دورة شتوية")),
                    ],
                    onChanged: (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: 15),

                  // السنة ورقم الدورة في صف واحد
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: year,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration("السنة", Icons.calendar_today),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: cycleNumber,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration("رقم الدورة", Icons.numbers),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // تاريخ البداية
                  InkWell(
                    onTap: () => _selectDate(context, true),
                    child: IgnorePointer(
                      child: TextField(
                        decoration: _inputDecoration(
                          startDate == null ? "تاريخ البداية" : startDate.toString().split(" ")[0],
                          Icons.date_range,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // تاريخ النهاية
                  InkWell(
                    onTap: () => _selectDate(context, false),
                    child: IgnorePointer(
                      child: TextField(
                        decoration: _inputDecoration(
                          endDate == null ? "تاريخ النهاية" : endDate.toString().split(" ")[0],
                          Icons.event_available,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // زر الإنشاء
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : createCycle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("تأكيد إنشاء الدورة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
    );
  }
}