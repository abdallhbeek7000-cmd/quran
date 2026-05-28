import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../services/session_service.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart'; // 🎯 استيراد سيرفيس الإشعارات والتوثيق المحدث

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

  // 🎯 متغير الفحص الذكي: هل الطالب خاتم؟
  bool isCompletedStudent = false;
  bool checkingStudentType = true;

  // متغيرات المشرف المختار للتعديل
  String? selectedSupervisorId;
  String? selectedSupervisorName;

  final Color primaryColor = const Color(0xff425c75);

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

      // إرسال وتوثيق لايف
      await NotificationService.sendAndSaveNotification(
        studentId: studentId,
        title: notifyTitle,
        body: notifyBody,
        type: notifyType,
      );
    }

    if (!mounted) return;
    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث الجلسة وإخطار الأهل بالتعديل بنجاح", style: TextStyle(fontFamily: 'Cairo'))),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
        title: const Text("تعديل بيانات الجلسة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo', fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: checkingStudentType
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                    ),
                    child: Card(
                      elevation: 0,
                      color: Colors.white.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: SwitchListTile(
                        activeColor: Colors.orange,
                        value: absent,
                        title: const Text("تسجيل غياب في هذا اليوم", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                        onChanged: (v) => setState(() => absent = v),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (!absent) ...[
                          _buildSectionCard(
                            title: isCompletedStudent ? "تعديل مراجعة الختمة الشاملة 👑" : "تعديل الإنجاز القرآني",
                            icon: Icons.edit_calendar,
                            isDarkMode: isDarkMode,
                            child: Column(
                              children: [
                                if (!isCompletedStudent) ...[
                                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo'), controller: newMemorization, decoration: _inputDecoration("الحفظ الجديد", Icons.star_border, isDarkMode)),
                                  const SizedBox(height: 15),
                                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo'), controller: newReview, decoration: _inputDecoration("مراجعة جديد", Icons.auto_stories_outlined, isDarkMode)),
                                  const SizedBox(height: 15),
                                ],
                                
                                TextField(
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo'), 
                                  controller: oldReview, 
                                  decoration: _inputDecoration(
                                    isCompletedStudent ? "المقدار المسموع من مراجعة الختمة الشاملة" : "مراجعة قديم", 
                                    isCompletedStudent ? Icons.verified_user_rounded : Icons.history_outlined, 
                                    isDarkMode
                                  )
                                ),
                                const SizedBox(height: 15),
                                TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo'), controller: readingBySight, decoration: _inputDecoration("قراءة نظراً من المصحف (اختياري)", Icons.menu_book_outlined, isDarkMode)),
                                const SizedBox(height: 15),
                                TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo'), controller: homework, decoration: _inputDecoration(isCompletedStudent ? "المقدار المطلوب للمرة القادمة" : "الواجب", Icons.edit_note, isDarkMode)),
                                
                                if (!isCompletedStudent) ...[
                                  const SizedBox(height: 20), 
                                  const Divider(),
                                  const SizedBox(height: 10),
                                  TextField(
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), 
                                    controller: totalMemorizedPagesController, 
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"^\d+\.?\d*"))],
                                    decoration: _inputDecoration("إجمالي عدد الصفحات المحفوظة حتى الآن", Icons.analytics_outlined, isDarkMode)
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
                                    dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo'),
                                    decoration: _inputDecoration("تقييم الحفظ الجديد", Icons.stars, isDarkMode),
                                    items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                    onChanged: (v) => setState(() => memorizationRating = v!),
                                  ),
                                  const SizedBox(height: 15),
                                ],
                                
                                DropdownButtonFormField<String>(
                                  value: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].contains(reviewRating) ? reviewRating : "جيد",
                                  dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo'),
                                  decoration: _inputDecoration(isCompletedStudent ? "تقييم مراجعة الختمة" : "تقييم المراجعة (الماضى)", Icons.rate_review_outlined, isDarkMode),
                                  items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (v) => setState(() => reviewRating = v!),
                                ),
                                const SizedBox(height: 15),
                                DropdownButtonFormField<String>(
                                  value: studentStatus,
                                  dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo'),
                                  decoration: _inputDecoration("حالة الطالب", Icons.mood, isDarkMode),
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
                            child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo'), controller: religiousActivities, decoration: _inputDecoration("نشاطات دينية", Icons.volunteer_activism, isDarkMode)),
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
                                dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
                                decoration: _inputDecoration("اسم المشرف الحالي / البديل", Icons.person_search_rounded, isDarkMode),
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
                              if (absent) const SizedBox(height: 15),
                              TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo'), controller: notes, maxLines: 3, decoration: _inputDecoration("الملاحظات العامة", Icons.comment, isDarkMode)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: loading ? null : save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: absent ? Colors.orange : (isDarkMode ? Colors.orange : primaryColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("تحديث البيانات", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontFamily: 'Cairo', fontSize: 12),
      prefixIcon: Icon(icon, color: isDarkMode ? Colors.orange : primaryColor, size: 18),
      filled: true,
      fillColor: isDarkMode ? const Color(0xff2b2b2b) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.transparent : Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.transparent : Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.orange : primaryColor, width: 1.5)),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child, required bool isDarkMode}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isDarkMode ? Colors.orange : primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: isDarkMode ? Colors.orange : primaryColor, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo')),
            ],
          ),
          Divider(height: 25, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
          child,
        ],
      ),
    );
  }
}