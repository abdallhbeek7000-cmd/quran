import 'dart:ui'; // 🎯 ضرورية لتأثير الزجاج والـ Blur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../services/session_service.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart';

class EditSessionPage extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> data;

  const EditSessionPage({
    super.key,
    required this.sessionId,
    required this.data,
  });

  @override
  State<EditSessionPage> createState() => _EditSessionPageState();
}

class _EditSessionPageState extends State<EditSessionPage> {
  final sessionService = SessionService();
  late TextEditingController newMemorization;
  late TextEditingController newReview; 
  late TextEditingController oldReview; 
  late TextEditingController homework;
  late TextEditingController readingBySight; 
  late TextEditingController religiousActivities;
  late TextEditingController notes;
  
  late TextEditingController totalMemorizedPagesController;

  bool absent = false;
  
  String memorizationRating = "جيد";
  String reviewRating = "جيد";
  
  String studentStatus = "مهذب";
  bool loading = false;

  bool isCompletedStudent = false;
  bool checkingStudentType = true;

  String? selectedSupervisorId;
  String? selectedSupervisorName;

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // 🎯 لون الزجاج المكمل

  @override
  void initState() {
    super.initState();
    final data = widget.data;

    absent = data['absent'] ?? false;
    
    memorizationRating = data['memorizationRating'] ?? data['rating'] ?? "جيد";
    if (memorizationRating.isEmpty) memorizationRating = "جيد";
    
    reviewRating = data['reviewRating'] ?? data['rating'] ?? "جيد";
    if (reviewRating.isEmpty) reviewRating = "جيد";

    studentStatus = (data['studentStatus'] == null || data['studentStatus'] == '') ? "مهذب" : data['studentStatus'];

    newMemorization = TextEditingController(text: data['newMemorization']);
    
    String fullReview = data['review'] ?? '';
    if (fullReview.contains('|')) {
      var parts = fullReview.split('|');
      newReview = TextEditingController(text: parts[0].trim());
      oldReview = TextEditingController(text: parts[1].trim());
    } else {
      newReview = TextEditingController(text: fullReview);
      oldReview = TextEditingController();
    }

    homework = TextEditingController(text: data['homework']);
    readingBySight = TextEditingController(text: data['readingBySight'] ?? ''); 
    religiousActivities = TextEditingController(text: data['religiousActivities']);
    notes = TextEditingController(text: data['notes']);
    
    var initialPages = data['total_memorized_pages']?.toString() ?? '';
    totalMemorizedPagesController = TextEditingController(text: initialPages);

    selectedSupervisorId = data['supervisorId'] ?? '';
    selectedSupervisorName = data['supervisorName'] ?? '';

    _checkIfStudentIsCompleted();
  }

  Future<void> _checkIfStudentIsCompleted() async {
    try {
      String studentId = widget.data['studentId'] ?? '';
      if (studentId.isNotEmpty) {
        DocumentSnapshot studentDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .get();
            
        if (studentDoc.exists && studentDoc.data() != null) {
          Map<String, dynamic> sData = studentDoc.data() as Map<String, dynamic>;
          if (sData['studentType'] == 'completed') {
            setState(() {
              isCompletedStudent = true;
            });
          }
        }
      }
    } catch (e) {
      print("Error checking student type in edit page: $e");
    } finally {
      setState(() {
        checkingStudentType = false;
      });
    }
  }

  @override
  void dispose() {
    newMemorization.dispose();
    newReview.dispose();
    oldReview.dispose();
    homework.dispose();
    readingBySight.dispose();
    religiousActivities.dispose();
    notes.dispose();
    totalMemorizedPagesController.dispose(); 
    super.dispose();
  }

  save() async {
    setState(() => loading = true);

    double totalPages = isCompletedStudent ? 604.0 : (double.tryParse(totalMemorizedPagesController.text.trim()) ?? 0.0);
    String studentId = widget.data['studentId'] ?? '';

    // 1️⃣ تحديث مستند الجلسة الحالي في مجموعة sessions
    await sessionService.updateSession(
      sessionId: widget.sessionId,
      data: {
        'absent': absent,
        'supervisorId': selectedSupervisorId, 
        'supervisorName': selectedSupervisorName, 
        'newMemorization': (absent || isCompletedStudent) ? '' : newMemorization.text.trim(),
        'review': absent ? '' : (isCompletedStudent ? oldReview.text.trim() : "${newReview.text.trim()} | ${oldReview.text.trim()}"),
        'nearReview': (absent || isCompletedStudent) ? '' : newReview.text.trim(), 
        'farReview': absent ? '' : oldReview.text.trim(),   
        'homework': absent ? '' : homework.text.trim(),
        'readingBySight': absent ? '' : readingBySight.text.trim(), 
        'memorizationRating': (absent || isCompletedStudent) ? '' : memorizationRating,
        'reviewRating': absent ? '' : reviewRating,
        'rating': absent ? '' : (isCompletedStudent ? reviewRating : memorizationRating), 
        'studentStatus': absent ? '' : studentStatus,
        'religiousActivities': absent ? '' : religiousActivities.text.trim(),
        'notes': notes.text.trim(),
        if (!absent) 'total_memorized_pages': totalPages,
      },
    );

    // 2️⃣ المزامنة الفورية: تحديث مستند الطالب الرئيسي (فقط لو لم يكن خاتماً)
    if (!absent && studentId.isNotEmpty && !isCompletedStudent && totalMemorizedPagesController.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('students').doc(studentId).update({
        'memorizedPages': totalPages,
      });
    }

    // 🎯 3️⃣ شحن التحديث السحري لمركز التنبيهات وإرساله كإشعار دفع خارجي معدل للأهل
    if (studentId.isNotEmpty) {
      String notifyTitle = "✏️ تعديل في بيانات الحلقة";
      String notifyBody = "";
      String notifyType = "regular";

      if (absent) {
        notifyTitle = "🚨 تعديل: تسجيل غياب طالب";
        notifyBody = "تم تعديل الجلسة وتوثيق غياب الطالب اليوم بـ السجل الإداري.";
        notifyType = "absent";
      } else {
        notifyBody = isCompletedStudent
            ? "تم تحديث وتعديل سجل مراجعة الختمة الشاملة بنجاح، التقييم الحالي: ($reviewRating)"
            : "تم تعديل بيانات الإنجاز اليومي بنجاح، الحفظ: ($memorizationRating) والمراجعة: ($reviewRating)";
        notifyType = "regular";
      }

      await NotificationService.sendAndSaveNotification(
        studentId: studentId,
        title: notifyTitle,
        body: notifyBody,
        type: notifyType,
        context: context, // 🎯 تمرير الـ context لعرض الشريط
      );
    }

    if (!mounted) return;
    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث الجلسة وإخطار الأهل بالتعديل بنجاح", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف
        title: Text("تعديل بيانات الجلسة", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 18)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: checkingStudentType
          ? const Center(child: CircularProgressIndicator()) 
          : Stack(
              children: [
                // 🎨 1. الخلفية الانسيابية مع الدوائر العائمة (Blobs)
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                          : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  top: -20,
                  left: -50,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  right: -60,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
                  ),
                ),

                // 🏢 2. المحتوى الأساسي للواجهة
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        // 🧊 قسم خيار الغياب (زجاجي)
                        _buildGlassContainer(
                          isDarkMode: isDarkMode,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: SwitchListTile(
                            activeColor: Colors.orangeAccent,
                            value: absent,
                            title: Text("تسجيل غياب في هذا اليوم", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15)),
                            secondary: Icon(absent ? Icons.person_off : Icons.person, color: isDarkMode ? Colors.white70 : primaryColor),
                            onChanged: (v) => setState(() => absent = v),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 🧊 أقسام التعديل الرئيسية
                        if (!absent) ...[
                          _buildSectionCard(
                            title: isCompletedStudent ? "تعديل مراجعة الختمة الشاملة 👑" : "تعديل الإنجاز القرآني",
                            icon: Icons.edit_calendar,
                            isDarkMode: isDarkMode,
                            child: Column(
                              children: [
                                if (!isCompletedStudent) ...[
                                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: newMemorization, decoration: _glassInputDecoration("الحفظ الجديد", Icons.star_border, isDarkMode)),
                                  const SizedBox(height: 15),
                                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: newReview, decoration: _glassInputDecoration("مراجعة جديد", Icons.auto_stories_outlined, isDarkMode)),
                                  const SizedBox(height: 15),
                                ],
                                
                                TextField(
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), 
                                  controller: oldReview, 
                                  decoration: _glassInputDecoration(
                                    isCompletedStudent ? "المقدار المسموع من مراجعة الختمة الشاملة" : "مراجعة قديم", 
                                    isCompletedStudent ? Icons.verified_user_rounded : Icons.history_outlined, 
                                    isDarkMode
                                  )
                                ),
                                const SizedBox(height: 15),
                                TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: readingBySight, decoration: _glassInputDecoration("قراءة نظراً من المصحف (اختياري)", Icons.menu_book_outlined, isDarkMode)),
                                const SizedBox(height: 15),
                                TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: homework, decoration: _glassInputDecoration(isCompletedStudent ? "المقدار المطلوب للمرة القادمة" : "الواجب", Icons.edit_note, isDarkMode)),
                                
                                if (!isCompletedStudent) ...[
                                  const SizedBox(height: 20), 
                                  Divider(color: isDarkMode ? Colors.white24 : Colors.black12),
                                  const SizedBox(height: 10),
                                  TextField(
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), 
                                    controller: totalMemorizedPagesController, 
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"^\d+\.?\d*"))],
                                    decoration: _glassInputDecoration("إجمالي عدد الصفحات المحفوظة حتى الآن", Icons.analytics_outlined, isDarkMode)
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          
                          _buildSectionCard(
                            title: "تعديل السلوك والتقييم",
                            icon: Icons.thumbs_up_down_outlined,
                            isDarkMode: isDarkMode,
                            child: Column(
                              children: [
                                if (!isCompletedStudent) ...[
                                  DropdownButtonFormField<String>(
                                    value: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].contains(memorizationRating) ? memorizationRating : "جيد",
                                    dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                    decoration: _glassInputDecoration("تقييم الحفظ الجديد", Icons.stars, isDarkMode),
                                    items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                    onChanged: (v) => setState(() => memorizationRating = v!),
                                  ),
                                  const SizedBox(height: 15),
                                ],
                                
                                DropdownButtonFormField<String>(
                                  value: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].contains(reviewRating) ? reviewRating : "جيد",
                                  dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                  decoration: _glassInputDecoration(isCompletedStudent ? "تقييم مراجعة الختمة" : "تقييم المراجعة (الماضي)", Icons.rate_review_outlined, isDarkMode),
                                  items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (v) => setState(() => reviewRating = v!),
                                ),
                                const SizedBox(height: 15),
                                DropdownButtonFormField<String>(
                                  value: studentStatus,
                                  dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                  decoration: _glassInputDecoration("حالة الطالب", Icons.mood, isDarkMode),
                                  items: ["مهذب", "منضبط", "مشاغب", "كثير الحركة"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (v) => setState(() => studentStatus = v!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),

                          _buildSectionCard(
                            title: "نشاطات إضافية",
                            icon: Icons.mosque_outlined,
                            isDarkMode: isDarkMode,
                            child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: religiousActivities, decoration: _glassInputDecoration("نشاطات دينية", Icons.volunteer_activism, isDarkMode)),
                          ),
                        ],

                        const SizedBox(height: 15),
                        _buildSectionCard(
                          title: "المشرف المسجِّل للجلسة",
                          icon: Icons.assignment_ind_outlined,
                          isDarkMode: isDarkMode,
                          child: FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance.collection("supervisors").get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return Text("لم يتم العثور على مشرفين", style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontFamily: 'Cairo'));
                              }

                              List<DropdownMenuItem<String>> items = snapshot.data!.docs.map((doc) {
                                String id = doc.id;
                                String name = doc["name"] ?? "مشرف غير معروف";
                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(name, style: const TextStyle(fontFamily: 'Cairo')),
                                );
                              }).toList();

                              bool hasValue = snapshot.data!.docs.any((doc) => doc.id == selectedSupervisorId);
                              if (!hasValue && items.isNotEmpty) {
                                selectedSupervisorId = items.first.value;
                              }

                              return DropdownButtonFormField<String>(
                                value: selectedSupervisorId,
                                dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                decoration: _glassInputDecoration("اسم المشرف الحالي / البديل", Icons.person_search_rounded, isDarkMode),
                                items: items,
                                onChanged: (v) {
                                  setState(() {
                                    selectedSupervisorId = v;
                                    final selectedDoc = snapshot.data!.docs.firstWhere((doc) => doc.id == v);
                                    selectedSupervisorName = selectedDoc["name"] ?? "مشرف غير معروف";
                                  });
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 15),
                        _buildSectionCard(
                          title: "ملاحظات إضافية",
                          icon: Icons.comment_bank_outlined,
                          isDarkMode: isDarkMode,
                          child: Column(
                            children: [
                              if (absent) const SizedBox(height: 5),
                              TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: notes, maxLines: 3, decoration: _glassInputDecoration("الملاحظات العامة", Icons.comment, isDarkMode)),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 35),
                        
                        // 🚀 زر الحفظ الزجاجي
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: loading ? null : save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: absent ? Colors.orange.withOpacity(0.9) : (isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9)),
                              foregroundColor: Colors.white,
                              elevation: 5,
                              shadowColor: Colors.black38,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("تحديث البيانات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', letterSpacing: 0.5)),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // 🧊 أداة تغليف الأقسام بتأثير الزجاج (Glassmorphism)
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // 🧊 أداة بطاقة القسم (تستخدم التغليف الزجاجي)
  Widget _buildSectionCard({required String title, required IconData icon, required Widget child, required bool isDarkMode}) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
            ],
          ),
          Divider(height: 25, color: isDarkMode ? Colors.white24 : Colors.black12),
          child,
        ],
      ),
    );
  }

  // 🧊 أداة حقول الإدخال الزجاجية
  InputDecoration _glassInputDecoration(String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600, fontFamily: 'Cairo', fontSize: 13),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), 
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15), 
        borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15), 
        borderSide: BorderSide(color: isDarkMode ? accentGold : primaryColor, width: 1.5),
      ),
    );
  }
}