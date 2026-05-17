import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:share_plus/share_plus.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; // استيراد حزمة الكاش الذكية للصور
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

  Future<void> exportToExcel() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("جاري تجهيز ملف الإكسل...")),
      );

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

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['الطلاب'];
      excel.delete('Sheet1'); 

      sheetObject.appendRow([
        TextCellValue('التسلسلي'),
        TextCellValue('اسم الطالب'),
        TextCellValue('اسم الأب'),
        TextCellValue('اسم الأم'),
        TextCellValue('المشرف'),
      ]);

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

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/طلاب_${widget.cycle.name}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

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
          if (widget.role == "manager") 
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
                  onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
                ),
                if (widget.role == "manager") ...[
                  const SizedBox(height: 10),
                  _buildSupervisorFilter(),
                ],
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  final studentName = (data['name'] ?? '').toString().trim().toLowerCase();
                  final nameMatches = studentName.contains(search);
                  
                  bool supervisorMatches = true;
                  
                  if (selectedSupervisor.isNotEmpty) {
                    final currentStudentSupervisor = (data['supervisorName'] ?? '').toString().trim().toLowerCase();
                    final selectedSupervisorClean = selectedSupervisor.trim().toLowerCase();
                    
                    supervisorMatches = (currentStudentSupervisor == selectedSupervisorClean);
                  }
                  
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

  // 🔥 دالة بناء كرت الطالب المحدثة لعرض الصور من الكلاوديناري بكفاءة عالية
  Widget _buildStudentCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String imageUrl = data['imageUrl'] ?? '';
    final String studentName = data['name'] ?? 'بدون اسم';
    final String firstLetter = studentName.isNotEmpty ? studentName.trim().substring(0, 1) : "?";

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
            // 🔥 تعديل قسم الـ leading ليعرض الصورة المرفوعة بكاش ذكي أو يعود للحرف الافتراضي
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Text(
                            firstLetter,
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          firstLetter,
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
              ),
            ),
            title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  value: sup['name'].toString(), 
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