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
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
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

  final Color primaryColor = const Color(0xff425c75);

  addStudent() async {
    if (name.text.isEmpty || phone.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال اسم الطالب ورقم الهاتف على الأقل")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final serial = await studentService.generateStudentSerial(
        year: widget.cycle.year,
        cycleNumber: widget.cycle.cycleNumber,
      );

      final student = StudentModel(
        id: '',
        serial: serial,
        name: name.text.trim(),
        fatherName: fatherName.text.trim(),
        motherName: motherName.text.trim(),
        phone: phone.text.trim(),
        fatherJob: fatherJob.text.trim(),
        address: address.text.trim(),
        schoolGrade: schoolGrade.text.trim(),
        birthDate: birthDate?.toString() ?? '',
        studentType: studentType,
        supervisorId: '',
        supervisorName: '',
        cycleId: widget.cycle.id,
        cycleName: widget.cycle.name,
        startMemorization: startDate?.toString() ?? '',
        memorizedPages: double.tryParse(memorizedPages.text) ?? 0,
        imageUrl: '',
        archived: false,
        createdAt: DateTime.now().toString(),
      );

      await studentService.addStudent(student);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("تمت إضافة الطالب بنجاح")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("خطأ: $e")),
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
        title: const Text("إضافة طالب جديد", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // قسم نوع الطالب
            _buildSectionCard(
              title: "معلومات التسجيل",
              icon: Icons.app_registration,
              child: DropdownButtonFormField<String>(
                value: studentType,
                decoration: _inputDecoration("نوع الطالب", Icons.category_outlined),
                items: const [
                  DropdownMenuItem(value: "new", child: Text("طالب جديد")),
                  DropdownMenuItem(value: "old", child: Text("طالب قديم")),
                  DropdownMenuItem(value: "completed", child: Text("خاتم")),
                ],
                onChanged: (v) => setState(() => studentType = v!),
              ),
            ),

            const SizedBox(height: 15),

            // قسم المعلومات الشخصية
            _buildSectionCard(
              title: "المعلومات الشخصية",
              icon: Icons.person_outline,
              child: Column(
                children: [
                  TextField(controller: name, decoration: _inputDecoration("اسم الطالب الكامل", Icons.person)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: fatherName, decoration: _inputDecoration("اسم الأب", Icons.man))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: motherName, decoration: _inputDecoration("اسم الأم", Icons.woman))),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(controller: phone, keyboardType: TextInputType.phone, decoration: _inputDecoration("رقم الهاتف", Icons.phone)),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // قسم الدراسة والسكن
            _buildSectionCard(
              title: "تفاصيل إضافية",
              icon: Icons.info_outline,
              child: Column(
                children: [
                  TextField(controller: address, decoration: _inputDecoration("مكان السكن", Icons.location_on_outlined)),
                  const SizedBox(height: 15),
                  TextField(controller: schoolGrade, decoration: _inputDecoration("الصف الدراسي", Icons.school_outlined)),
                  const SizedBox(height: 15),
                  TextField(controller: fatherJob, decoration: _inputDecoration("عمل الأب", Icons.work_outline)),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // قسم التواريخ والحفظ
            _buildSectionCard(
              title: "التواريخ والحفظ",
              icon: Icons.history_edu,
              child: Column(
                children: [
                  if (studentType != "new") ...[
                    TextField(
                      controller: memorizedPages,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration("عدد الصفحات المحفوظة", Icons.auto_stories_outlined),
                    ),
                    const SizedBox(height: 15),
                  ],
                  Row(
                    children: [
                      Expanded(child: _buildDatePicker(
                        label: birthDate == null ? "تاريخ الميلاد" : birthDate.toString().split(" ")[0],
                        icon: Icons.cake_outlined,
                        onTap: () async {
                          final picked = await _selectDate(context, DateTime(2000));
                          if (picked != null) setState(() => birthDate = picked);
                        },
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDatePicker(
                        label: startDate == null ? "بدء الحفظ" : startDate.toString().split(" ")[0],
                        icon: Icons.play_arrow_outlined,
                        onTap: () async {
                          final picked = await _selectDate(context, DateTime(2000));
                          if (picked != null) setState(() => startDate = picked);
                        },
                      )),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // زر الإضافة
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : addStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("حفظ بيانات الطالب", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // مساعد لتنسيق الحقول
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    );
  }

  // كرت لتنظيم الأقسام
  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 25),
          child,
        ],
      ),
    );
  }

  // تصميم زر اختيار التاريخ
  Widget _buildDatePicker({required String label, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _selectDate(BuildContext context, DateTime initial) async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: initial,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryColor),
          ),
          child: child!,
        );
      },
    );
  }
}