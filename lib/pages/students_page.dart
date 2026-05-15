import 'dart:io'; // ضروري للتعامل مع الملفات
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart'; // مكتبة الإكسل
import 'package:path_provider/path_provider.dart'; // لتحديد مكان الحفظ
import 'package:share_plus/share_plus.dart'; // للمشاركة عبر الواتساب
import '../models/cycle_model.dart';
import 'add_student_page.dart';
import 'edit_student_page.dart';
import 'add_session_page.dart';
import 'student_sessions_page.dart';

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
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  String search = '';
  String selectedSupervisor = '';
  final Color primaryColor = const Color(0xff425c75);

  // دالة تصدير ملف الإكسل
  Future<void> exportToExcel() async {
    try {
      // 1. جلب بيانات الطلاب من فايربيز لهذه الدورة حصراً
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('cycleId', isEqualTo: widget.cycle.id)
          .where('archived', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("لا يوجد طلاب لتصديرهم")),
        );
        return;
      }

      // 2. إنشاء ملف الإكسل وتجهيز الصفحة
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['الطلاب'];
      excel.delete('Sheet1'); 

      // 3. إضافة العناوين (Headers)
      sheetObject.appendRow([
        TextCellValue('التسلسلي'),
        TextCellValue('اسم الطالب'),
        TextCellValue('اسم الأب'),
        TextCellValue('اسم الأم'),
        TextCellValue('المشرف'),
      ]);

      // 4. تعبئة البيانات من الداتابيز
      for (var doc in snapshot.docs) {
        var data = doc.data();
        sheetObject.appendRow([
          TextCellValue(data['serial']?.toString() ?? ''),
          TextCellValue(data['name']?.toString() ?? ''),
          TextCellValue(data['fatherName']?.toString() ?? ''),
          TextCellValue(data['motherName']?.toString() ?? ''),
          TextCellValue(data['supervisorName'] ?? 'غير موزع'),
        ]);
      }

      // 5. حفظ الملف في الذاكرة المؤقتة للهاتف
      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/طلاب_${widget.cycle.name}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      // 6. فتح قائمة المشاركة (واتساب، إيميل...)
      await Share.shareXFiles([XFile(filePath)], text: 'قائمة طلاب: ${widget.cycle.name}');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ أثناء التصدير: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('students')
        .where('cycleId', isEqualTo: widget.cycle.id)
        .where('archived', isEqualTo: false);

    if (widget.role == "supervisor") {
      query = query.where('supervisorId', isEqualTo: widget.uid);
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text("قائمة الطلاب", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // إضافة زر التصدير في الـ AppBar
          if (widget.role == "manager") // نظهره للمدير فقط
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: "تصدير Excel",
              onPressed: exportToExcel,
            ),
        ],
      ),
      floatingActionButton: widget.role == "manager"
          ? FloatingActionButton(
              backgroundColor: primaryColor,
              onPressed: () => _nav(AddStudentPage(cycle: widget.cycle)),
              child: const Icon(Icons.person_add_alt_1, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          // قسم البحث والفلترة
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن اسم الطالب...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xff425c75)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => search = v.toLowerCase()),
                ),
                if (widget.role == "manager") ...[
                  const SizedBox(height: 10),
                  _buildSupervisorFilter(),
                ],
              ],
            ),
          ),

          // قائمة الطلاب
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nameMatches = data['name'].toString().toLowerCase().contains(search);
                  final supervisorMatches = selectedSupervisor.isEmpty || data['supervisorName'] == selectedSupervisor;
                  return nameMatches && supervisorMatches;
                }).toList();

                if (docs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildStudentCard(docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ... (باقي الودجتات _buildStudentCard و _buildSupervisorFilter كما هي في كودك الأصلي) ...
  // ملاحظة: تأكد من إبقاء الدوال الأخرى موجودة في ملفك.
  
  Widget _buildStudentCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: primaryColor.withOpacity(0.1),
              child: Text(
                data['name'].toString().isNotEmpty ? data['name'].toString().substring(0, 1) : "?",
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            title: Text(data['name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                Text("الرقم: ${data['serial'] ?? '---'}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                Text("المشرف: ${data['supervisorName'] ?? 'غير موزع'}", style: TextStyle(color: primaryColor, fontSize: 13)),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.edit_note, color: primaryColor),
              onPressed: () => _nav(EditStudentPage(student: doc)),
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(Icons.add_task, "جلسة جديد", Colors.green, () {
                  _nav(AddSessionPage(
                    studentId: doc.id,
                    studentName: data['name'],
                    supervisorId: data['supervisorId'] ?? '',
                    supervisorName: data['supervisorName'] ?? '',
                  ));
                }),
                _buildActionButton(Icons.history, "السجل", Colors.blue, () {
                  _nav(StudentSessionsPage(studentId: doc.id, studentName: data['name'], role: widget.role));
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildSupervisorFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('supervisors').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final supervisors = snapshot.data!.docs;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(15)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedSupervisor.isEmpty ? null : selectedSupervisor,
              hint: const Text("فلترة بالمشرف", style: TextStyle(color: Colors.white70, fontSize: 14)),
              dropdownColor: primaryColor,
              icon: const Icon(Icons.filter_list, color: Colors.white),
              items: [
                const DropdownMenuItem(value: '', child: Text("كل المشرفين", style: TextStyle(color: Colors.white))),
                ...supervisors.map((sup) => DropdownMenuItem(
                  value: sup['name'],
                  child: Text(sup['name'], style: const TextStyle(color: Colors.white)),
                )),
              ],
              onChanged: (v) => setState(() => selectedSupervisor = v!),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text("لم نجد أي طلاب بهذا الاسم", style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _nav(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}