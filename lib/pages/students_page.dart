import 'dart:io'; 
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_lib; 
import 'package:path_provider/path_provider.dart'; 
import 'package:share_plus/share_plus.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:provider/provider.dart'; 
import '../models/cycle_model.dart';
import 'add_student_page.dart';
import 'edit_student_page.dart';
import 'add_session_page.dart';
import 'student_sessions_page.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart';
import '../widgets/animated_glass_background.dart'; 
import '../widgets/glass_toast.dart'; 

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
  final Color accentGold = const Color(0xffd4af37); 

  final Map<String, String> _flags = {
    'فلسطيني': '🇵🇸', 'أردني': '🇯🇴', 'لبناني': '🇱🇧', 'عراقي': '🇮🇶',
    'مصري': '🇪🇬', 'سعودي': '🇸🇦', 'يمني': '🇾🇪', 'سوداني': '🇸🇩',
    'تركي': '🇹🇷', 'جنسية أخرى': '🌍',
  };

  void _updateStudentLiveStatus(String studentId, String newStatus, String studentName) async {
    await FirebaseFirestore.instance.collection('students').doc(studentId).update({
      'livePulse': newStatus,
    });

    String statusText = "";
    switch (newStatus) {
      case 'green': statusText = "🟢 جاري التسميع الآن"; break;
      case 'yellow': statusText = "🟡 يراجع بانتظار التسميع"; break;
      case 'blue': statusText = "🔵 أتم التسميع بانتظار الانصراف"; break;
      default: return; 
    }

    if (mounted) {
      await NotificationService.sendAndSaveNotification(
        studentId: studentId,
        title: "تحديث مباشر: $studentName",
        body: "حالة الطالب اللحظية في المعهد: $statusText",
        type: "live_status", 
        context: context, 
      );
      
      GlassToast.show(
        context, 
        title: "تحديث مباشر", 
        message: 'تم تحديث حالة ($studentName) اللحظية بنجاح 🟢', 
        icon: Icons.wifi_tethering_rounded, 
        color: Colors.greenAccent.shade400,
      );
    }
  }

  void _showDeleteStudentDialog(BuildContext context, String studentId, String studentName, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 10),
              Text("حذف ملف الطالب", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87)),
            ],
          ),
          content: Text(
            "هل أنت متأكد من حذف الطالب ($studentName) نهائياً من هذه الدورة؟\n\n🚨 تنبيه: سيتم مسح بيانات الطالب وسجل التسميع الخاص به تماماً ولا يمكن التراجع عن هذا الإجراء.",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.4, color: isDarkMode ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text("حذف نهائي", style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(dialogContext); 
                await FirebaseFirestore.instance.collection('students').doc(studentId).delete();
                if (context.mounted) {
                  GlassToast.show(
                    context, 
                    title: "تم الحذف", 
                    message: "تم حذف ملف الطالب ($studentName) بنجاح نهائياً", 
                    icon: Icons.delete_outline_rounded, 
                    color: Colors.redAccent,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("جاري تجهيز ملف الإكسل...", style: TextStyle(fontFamily: 'Cairo'))));

      final snapshot = await FirebaseFirestore.instance.collection('students').where('cycleId', isEqualTo: widget.cycle.id).get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد طلاب لتصديرهم", style: TextStyle(fontFamily: 'Cairo'))));
        return;
      }

      var excel = excel_lib.Excel.createExcel();
      excel_lib.Sheet sheetObject = excel['الطلاب'];
      excel.delete('Sheet1'); 

      sheetObject.appendRow([
        excel_lib.TextCellValue('التسلسلي'),
        excel_lib.TextCellValue('اسم الطالب'),
        excel_lib.TextCellValue('الجنسية'), 
        excel_lib.TextCellValue('الرقم'),
        excel_lib.TextCellValue('الصف'),
        excel_lib.TextCellValue('اسم الأب'),
        excel_lib.TextCellValue('اسم الأم'),
        excel_lib.TextCellValue('المشرف'),
      ]);

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String grade = data['grade'] ?? data['schoolGrade'] ?? data['classLevel'] ?? data['studyLevel'] ?? 'غير مسجل';

        sheetObject.appendRow([
          excel_lib.TextCellValue(data['serial']?.toString() ?? ''),
          excel_lib.TextCellValue(data['name']?.toString() ?? ''),
          excel_lib.TextCellValue(data['nationality']?.toString() ?? 'سوري'), 
          excel_lib.TextCellValue(data['serial']?.toString() ?? ''),
          excel_lib.TextCellValue(grade),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ أثناء التصدير: $e", style: const TextStyle(fontFamily: 'Cairo'))));
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

  Widget _buildSyrianRevolutionFlag() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: 24, height: 16,
        decoration: BoxDecoration(border: Border.all(color: Colors.white54, width: 0.5)),
        child: Column(
          children: [
            Expanded(child: Container(color: const Color(0xff007A3D))), 
            Expanded(
              child: Container(
                color: Colors.white,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.star, color: Color(0xffCE1126), size: 4.5),
                    Icon(Icons.star, color: Color(0xffCE1126), size: 4.5),
                    Icon(Icons.star, color: Color(0xffCE1126), size: 4.5),
                  ],
                ),
              )
            ), 
            Expanded(child: Container(color: Colors.black)), 
          ],
        ),
      ),
    );
  }

  Widget _getNationalityFlag(String? nationality) {
    String nat = nationality ?? 'سوري';
    if (nat == 'سوري') return _buildSyrianRevolutionFlag();
    return Text(_flags[nat] ?? '🌍', style: const TextStyle(fontSize: 16));
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

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
      extendBodyBehindAppBar: true, 
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, 
        title: Text(
          widget.isArchivedFromHistory ? "أرشيف: ${widget.cycle.name}" : "قائمة الطلاب", 
          style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 18)
        ),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
        actions: [
          if (widget.role == "manager") 
            IconButton(icon: Icon(Icons.file_download, color: isDarkMode ? accentGold : primaryColor), tooltip: "تصدير Excel", onPressed: exportToExcel),
        ],
      ),
      floatingActionButton: (widget.role == "manager" && !widget.isArchivedFromHistory)
          ? FloatingActionButton(
              backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9),
              onPressed: () => _nav(AddStudentPage(cycle: widget.cycle)),
              child: const Icon(Icons.person_add_alt_1, color: Colors.white),
            )
          : null,
          
      body: AnimatedGlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: _buildGlassContainer(
                  isDarkMode: isDarkMode,
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      TextField(
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        decoration: _glassInputDecoration("ابحث عن اسم الطالب...", Icons.search, isDarkMode),
                        onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
                      ),
                      if (widget.role == "manager") ...[
                        const SizedBox(height: 12),
                        _buildSupervisorFilter(isDarkMode),
                      ],
                    ],
                  ),
                ),
              ),

              if (widget.role == "manager" && !widget.isArchivedFromHistory)
                _buildAbsentAlertSection(isDarkMode),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: query.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text("حدث خطأ في تحميل البيانات"));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    var docs = snapshot.data!.docs.where((doc) {
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

                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      int sA = int.tryParse(aData['serial']?.toString() ?? '0') ?? 0;
                      int sB = int.tryParse(bData['serial']?.toString() ?? '0') ?? 0;
                      return sA.compareTo(sB);
                    });

                    if (docs.isEmpty) return _buildEmptyState(isDarkMode);

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(left: 15, right: 15, top: 10, bottom: 80),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        return _buildStudentCard(docs[index], isDarkMode);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero, Color? customColor, Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ?? (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: customBorderColor ?? (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6)), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.02), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _glassInputDecoration(String hint, IconData icon, bool isDarkMode) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontFamily: 'Cairo', fontSize: 13),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), 
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDarkMode ? accentGold : primaryColor, width: 1.5)),
    );
  }

  Widget _buildAbsentAlertSection(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').where('cycleId', isEqualTo: widget.cycle.id).where('archived', isEqualTo: false).where('consecutiveAbsences', isGreaterThanOrEqualTo: 3).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
        final alertStudents = snapshot.data!.docs;
        return Container(
          margin: const EdgeInsets.fromLTRB(15, 5, 15, 10),
          child: _buildGlassContainer(
            isDarkMode: isDarkMode,
            padding: const EdgeInsets.all(12),
            customColor: Colors.redAccent.withOpacity(isDarkMode ? 0.15 : 0.1),
            customBorderColor: Colors.redAccent.withOpacity(0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gpp_maybe_rounded, color: Colors.redAccent.shade200, size: 20),
                    const SizedBox(width: 8),
                    Text("تنبيه غياب متكرر (🚨 يحتاج متابعة إدارية)", style: TextStyle(color: isDarkMode ? Colors.red.shade300 : Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 65,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: alertStudents.length,
                    itemBuilder: (context, idx) {
                      final sData = alertStudents[idx].data() as Map<String, dynamic>;
                      final String sName = sData['name'] ?? 'طالب';
                      final int count = sData['consecutiveAbsences'] ?? 3;
                      final String pPhone = sData['parentPhone'] ?? ''; 
                      return Container(
                        margin: const EdgeInsets.only(left: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.2))),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(sName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo')),
                                Text("منقطع لـ $count أيام ⚠️", style: TextStyle(color: Colors.redAccent.shade400, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                              ],
                            ),
                            if (pPhone.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              CircleAvatar(
                                radius: 16, backgroundColor: Colors.green.withOpacity(0.15),
                                child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.phone_forwarded_rounded, size: 16, color: Colors.green), tooltip: "اتصال بولي الأمر", onPressed: () => _makePhoneCall(pPhone)),
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
          ),
        );
      },
    );
  }

  Widget _buildStudentCard(DocumentSnapshot doc, bool isDarkMode) {
    final data = doc.data() as Map<String, dynamic>;
    final String imageUrl = data['imageUrl'] ?? '';
    final String studentName = data['name'] ?? 'بدون اسم';
    final String nationality = data['nationality'] ?? 'سوري'; 
    final String livePulse = data['livePulse'] ?? 'none'; 
    
    // سحب بيانات الصف
    final String grade = data['grade'] ?? data['schoolGrade'] ?? data['classLevel'] ?? data['studyLevel'] ?? 'غير مسجل';
    
    final String firstLetter = studentName.isNotEmpty ? studentName.trim().substring(0, 1) : "?";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              leading: GestureDetector(
                onTap: () {
                  if (imageUrl.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: Colors.black.withOpacity(0.9),
                        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
                        body: Center(
                          child: Hero(
                            tag: 'avatar_${doc.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: CachedNetworkImage(imageUrl: imageUrl, width: MediaQuery.of(context).size.width, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ));
                  }
                },
                child: Hero(
                  tag: 'avatar_${doc.id}', 
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? Colors.white10 : primaryColor.withOpacity(0.1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (c, u) => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))), errorWidget: (c, u, e) => Center(child: Text(firstLetter, style: TextStyle(color: isDarkMode ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Cairo'))))
                          : Center(child: Text(firstLetter, style: TextStyle(color: isDarkMode ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Cairo'))),
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  _getNationalityFlag(nationality),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      studentName, 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo'),
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis, 
                    ),
                  ),
                ],
              ),
              // 🚀 هنا السحر: استخدام Wrap والشارات الذكية
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Wrap(
                  spacing: 6, // المسافة الأفقية بين الشارات
                  runSpacing: 6, // المسافة العمودية إذا الشاشة ضيقة ونزلوا لسطر جديد
                  children: [
                    _buildInfoBadge("رقم: ${data['serial'] ?? '---'}", isDarkMode ? Colors.white70 : Colors.grey.shade700, isDarkMode),
                    _buildInfoBadge("الصف: $grade", isDarkMode ? Colors.lightBlueAccent : Colors.blue.shade700, isDarkMode),
                    _buildInfoBadge("المشرف: ${data['supervisorName'] ?? 'غير موزع'}", isDarkMode ? accentGold : primaryColor, isDarkMode, isBold: true),
                  ],
                ),
              ),
              trailing: widget.isArchivedFromHistory 
                  ? Icon(Icons.archive_outlined, color: isDarkMode ? Colors.white54 : Colors.grey, size: 22)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!widget.isArchivedFromHistory)
                          _buildPulseDot(livePulse, doc.id, studentName, isDarkMode),
                        IconButton(icon: Icon(Icons.edit_note_rounded, color: isDarkMode ? accentGold : primaryColor, size: 26), tooltip: "تعديل بيانات الطالب", onPressed: () => _nav(EditStudentPage(student: doc))),
                        if (widget.role == "manager") 
                          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24), tooltip: "حذف الطالب", onPressed: () => _showDeleteStudentDialog(context, doc.id, studentName, isDarkMode)),
                      ],
                    ),
            ),
            Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!widget.isArchivedFromHistory)
                    _buildActionButton(Icons.add_task, "جلسة جديدة", Colors.greenAccent.shade400, isDarkMode, () {
                      _nav(AddSessionPage(studentId: doc.id, studentName: data['name'] ?? '', supervisorId: data['supervisorId'] ?? '', supervisorName: data['supervisorName'] ?? ''));
                    }),
                  _buildActionButton(widget.isArchivedFromHistory ? Icons.folder_open_rounded : Icons.history, widget.isArchivedFromHistory ? "استعراض السجل القديم" : "السجل", isDarkMode ? Colors.lightBlueAccent : Colors.blue, isDarkMode, () {
                    _nav(StudentSessionsPage(studentId: doc.id, studentName: data['name'] ?? '', role: widget.isArchivedFromHistory ? "readonly" : widget.role));
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 دالة الشارات الذكية لترتيب المعلومات بخاصية Wrap
  Widget _buildInfoBadge(String text, Color color, bool isDarkMode, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDarkMode ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontFamily: 'Cairo',
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPulseDot(String currentPulse, String studentId, String studentName, bool isDarkMode) {
    Color dotColor;
    switch (currentPulse) {
      case 'green': dotColor = Colors.greenAccent.shade400; break;
      case 'yellow': dotColor = Colors.amber; break;
      case 'blue': dotColor = Colors.lightBlueAccent; break;
      default: dotColor = isDarkMode ? Colors.white24 : Colors.black26;
    }

    return PopupMenuButton<String>(
      tooltip: 'تغيير الحالة المباشرة',
      color: isDarkMode ? const Color(0xff1e293b) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: dotColor.withOpacity(0.2),
          shape: BoxShape.circle,
          boxShadow: currentPulse != 'none' ? [BoxShadow(color: dotColor.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)] : [],
        ),
        child: Icon(Icons.circle, color: dotColor, size: 14),
      ),
      onSelected: (String newValue) {
        _updateStudentLiveStatus(studentId, newValue, studentName);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'green', child: _buildPulseOption(Icons.circle, Colors.greenAccent.shade400, "جاري التسميع الآن")),
        PopupMenuItem<String>(value: 'yellow', child: _buildPulseOption(Icons.circle, Colors.amber, "يراجع بانتظار التسميع")),
        PopupMenuItem<String>(value: 'blue', child: _buildPulseOption(Icons.circle, Colors.lightBlueAccent, "أتم التسميع (انصراف)")),
        const PopupMenuDivider(),
        PopupMenuItem<String>(value: 'none', child: _buildPulseOption(Icons.cancel, Colors.grey, "غير متواجد / إطفاء الحالة")),
      ],
    );
  }

  Widget _buildPulseOption(IconData icon, Color color, String label) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, bool isDarkMode, VoidCallback onTap) {
    return TextButton.icon(
      style: TextButton.styleFrom(backgroundColor: color.withOpacity(isDarkMode ? 0.1 : 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
    );
  }

  Widget _buildSupervisorFilter(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('supervisors').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final supervisors = snapshot.data!.docs;
        return DropdownButtonFormField<String>(
          value: selectedSupervisor.isEmpty ? null : selectedSupervisor,
          hint: Text("فلترة بحسب المشرف...", style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontSize: 13, fontFamily: 'Cairo')),
          dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          decoration: _glassInputDecoration("", Icons.filter_list_rounded, isDarkMode),
          items: [
            const DropdownMenuItem(value: '', child: Text("كل المشرفين")),
            ...supervisors.map((sup) => DropdownMenuItem(value: sup['name'].toString(), child: Text(sup['name']))),
          ],
          onChanged: (v) => setState(() => selectedSupervisor = v ?? ''),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 80, color: isDarkMode ? accentGold.withOpacity(0.6) : primaryColor.withOpacity(0.4)),
            const SizedBox(height: 15),
            Text("لم نجد أي طلاب يطابقون بحثك", style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey[700], fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _nav(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}