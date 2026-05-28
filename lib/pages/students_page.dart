import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_lib; 
import 'package:path_provider/path_provider.dart'; 
import 'package:share_plus/share_plus.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 
import '../models/cycle_model.dart';
import 'add_student_page.dart';
import 'edit_student_page.dart';
import 'add_session_page.dart';
import 'student_sessions_page.dart';

class StudentsPage extends StatefulWidget {
  final CycleModel cycle;
  final String role;
  final String uid;
  final bool isArchivedFromHistory;

  const StudentsPage({
    super.key,
    required this.cycle,
    required this.role,
    required this.uid,
    this.isArchivedFromHistory = false,
  });

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  String search = '';
  String selectedSupervisor = '';
  final Color primaryColor = const Color(0xff425c75);

  void _showDeleteStudentDialog(BuildContext context, String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text(
                "حذف ملف الطالب",
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
              ),
            ],
          ),
          content: Text(
            "هل أنت متأكد من حذف الطالب ($studentName) نهائياً من هذه الدورة؟\n\n🚨 تنبيه: سيتم مسح بيانات الطالب وسجل التسميع الخاص به تماماً ولا يمكن التراجع عن هذا الإجراء.",
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.4, color: Colors.black87),
          ),
          actions: [
            TextButton(
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text(
                "حذف نهائي", 
                style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext); 
                
                await FirebaseFirestore.instance
                    .collection('students')
                    .doc(studentId)
                    .delete();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red.shade900,
                      content: Text("تم حذف ملف الطالب ($studentName) بنجاح 🗑️", style: const TextStyle(fontFamily: 'Cairo')),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> exportToExcel() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("جاري تجهيز ملف الإكسل...")),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('cycleId', isEqualTo: widget.cycle.id)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("لا يوجد طلاب لتصديرهم")),
        );
        return;
      }

      var excel = excel_lib.Excel.createExcel();
      excel_lib.Sheet sheetObject = excel['الطلاب'];
      excel.delete('Sheet1'); 

      sheetObject.appendRow([
        excel_lib.TextCellValue('التسلسلي'),
        excel_lib.TextCellValue('اسم الطالب'),
        excel_lib.TextCellValue('اسم الأب'),
        excel_lib.TextCellValue('اسم الأم'),
        excel_lib.TextCellValue('المشرف'),
      ]);

      for (var doc in snapshot.docs) {
        var data = doc.data();
        sheetObject.appendRow([
          excel_lib.TextCellValue(data['serial']?.toString() ?? ''),
          excel_lib.TextCellValue(data['name']?.toString() ?? ''),
          excel_lib.TextCellValue(data['fatherName']?.toString() ?? ''),
          excel_lib.TextCellValue(data['motherName']?.toString() ?? ''),
          excel_lib.TextCellValue(data['supervisorName'] ?? 'غير موزع'),
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    try {
      await Share.share("رقم هاتف ولي الأمر للمتابعة: $phoneNumber");
    } catch (e) {
      print("Error opening dialer: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('students')
        .where('cycleId', isEqualTo: widget.cycle.id);

    if (!widget.isArchivedFromHistory) {
      query = query.where('archived', isEqualTo: false);
    }

    if (widget.role == "supervisor") {
      query = query.where('supervisorId', isEqualTo: widget.uid);
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: Text(
          widget.isArchivedFromHistory ? "أرشيف: ${widget.cycle.name}" : "قائمة الطلاب", 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo', fontSize: 16)
        ),
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
      floatingActionButton: (widget.role == "manager" && !widget.isArchivedFromHistory)
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
                  style: const TextStyle(color: Colors.black, fontFamily: 'Cairo', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن اسم الطالب...',
                    hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
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

          if (widget.role == "manager" && !widget.isArchivedFromHistory)
            _buildAbsentAlertSection(),

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
                  physics: const BouncingScrollPhysics(),
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

  Widget _buildAbsentAlertSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('students')
          .where('cycleId', isEqualTo: widget.cycle.id)
          .where('archived', isEqualTo: false)
          .where('consecutiveAbsences', isGreaterThanOrEqualTo: 3) 
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();

        final alertStudents = snapshot.data!.docs;

        return Container(
          margin: const EdgeInsets.fromLTRB(15, 15, 15, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.red.shade200, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gpp_maybe_rounded, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    "تنبيه غياب متكرر (🚨 يحتاج متابعة إدارية)",
                    style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 65,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: alertStudents.length,
                  itemBuilder: (context, idx) {
                    final sData = alertStudents[idx].data() as Map<String, dynamic>;
                    final String sName = sData['name'] ?? 'طالب';
                    final int count = sData['consecutiveAbsences'] ?? 3;
                    final String pPhone = sData['parentPhone'] ?? ''; 

                    return Container(
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(sName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87, fontFamily: 'Cairo')),
                              // 🎯 إصلاح السطر 332: تعديل size إلى fontSize داخل الـ TextStyle وتنسيق السطور المتداخلة
                              Text("منقطع لـ $count أيام ⚠️", style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                            ],
                          ),
                          if (pPhone.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.green.shade50,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.phone_forwarded_rounded, size: 16, color: Colors.green),
                                tooltip: "اتصال بولي الأمر",
                                onPressed: () => _makePhoneCall(pPhone),
                              ),
                            ),
                          ]
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
        border: Border.all(color: Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(15),
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
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Cairo'),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          firstLetter,
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Cairo'),
                        ),
                      ),
              ),
            ),
            title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo')),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                Text("الرقم: ${data['serial'] ?? '---'}", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'Cairo')),
                Text("المشرف: ${data['supervisorName'] ?? 'غير موزع'}", style: TextStyle(color: primaryColor, fontSize: 12, fontFamily: 'Cairo')),
              ],
            ),
            trailing: widget.isArchivedFromHistory 
                ? const Icon(Icons.archive_outlined, color: Colors.grey, size: 20)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_note_rounded, color: primaryColor, size: 24),
                        tooltip: "تعديل بيانات الطالب",
                        onPressed: () => _nav(EditStudentPage(student: doc)),
                      ),
                      if (widget.role == "manager") 
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                          tooltip: "حذف الطالب",
                          onPressed: () => _showDeleteStudentDialog(context, doc.id, studentName),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (!widget.isArchivedFromHistory)
                  _buildActionButton(Icons.add_task, "جلسة جديد", Colors.green, () {
                    _nav(AddSessionPage(
                      studentId: doc.id,
                      studentName: data['name'] ?? '',
                      supervisorId: data['supervisorId'] ?? '',
                      supervisorName: data['supervisorName'] ?? '',
                    ));
                  }),
                  
                _buildActionButton(
                  widget.isArchivedFromHistory ? Icons.folder_open_rounded : Icons.history, 
                  widget.isArchivedFromHistory ? "استعراض السجل القديم" : "السجل", 
                  Colors.blue, 
                  () {
                    _nav(StudentSessionsPage(
                      studentId: doc.id, 
                      studentName: data['name'] ?? '', 
                      role: widget.isArchivedFromHistory ? "readonly" : widget.role
                    ));
                  }
                ),
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
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo')),
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
              hint: const Text("فلترة بالمشرف", style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Cairo')),
              dropdownColor: primaryColor,
              icon: const Icon(Icons.filter_list, color: Colors.white),
              items: [
                const DropdownMenuItem(value: '', child: Text("كل المشرفين", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 13))),
                ...supervisors.map((sup) => DropdownMenuItem(
                  value: sup['name'].toString(), 
                  child: Text(sup['name'], style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 13)),
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
          Text("لم نجد أي طلاب بهذا الاسم", style: TextStyle(color: Colors.grey[600], fontFamily: 'Cairo', fontSize: 14)),
        ],
      ),
    );
  }

  void _nav(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}