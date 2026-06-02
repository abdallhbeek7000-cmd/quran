import 'dart:ui'; 
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
  
  // 🚀 فصل حقول الواجب في التعديل (3 حقول)
  late TextEditingController newHomeworkController;
  late TextEditingController newReviewHomeworkController; // واجب مراجعة جديد
  late TextEditingController oldReviewHomeworkController; // واجب مراجعة قديم

  late TextEditingController readingBySight; 
  late TextEditingController religiousActivities;
  late TextEditingController notes;
  
  late TextEditingController totalMemorizedPagesController;

  bool absent = false;
  
  // 🚀 المفاتيح الذكية للتحكم بالظهور
  bool hasNewMemorization = true;
  bool hasReview = true;

  String memorizationRating = "جيد";
  String reviewRating = "جيد";
  
  String studentStatus = "مهذب";
  bool loading = false;

  bool isCompletedStudent = false;
  bool checkingStudentType = true;

  String? selectedSupervisorId;
  String? selectedSupervisorName;

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); 

  @override
  void initState() {
    super.initState();
    final data = widget.data;

    absent = data['absent'] ?? false;
    
    // 🎯 ذكاء تحديد المفاتيح بناءً على البيانات القديمة
    hasNewMemorization = (data['newMemorization'] ?? '').toString().trim().isNotEmpty;
    hasReview = (data['nearReview'] ?? '').toString().trim().isNotEmpty || 
                (data['farReview'] ?? '').toString().trim().isNotEmpty || 
                (data['review'] ?? '').toString().trim().isNotEmpty;

    if (!hasNewMemorization && !hasReview && !absent) {
      hasNewMemorization = true;
      hasReview = true;
    }

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
      newReview = TextEditingController(text: data['nearReview'] ?? fullReview);
      oldReview = TextEditingController(text: data['farReview'] ?? '');
    }

    // 🎯 ذكاء التوافق الرجعي لفصل الواجب القديم والجديد والمراجعات
    String oldHw = data['homework'] ?? '';
    String nHw = data['newHomework'] ?? '';
    String nRevHw = data['newReviewHomework'] ?? '';
    String oRevHw = data['oldReviewHomework'] ?? '';

    // إذا لم تكن الحقول الجديدة موجودة، نحاول استخراجها من النسخ الأقدم
    if (nHw.isEmpty && nRevHw.isEmpty && oRevHw.isEmpty && oldHw.isNotEmpty) {
      String rHwLegacy = data['reviewHomework'] ?? ''; // من التعديل السابق
      if (rHwLegacy.isNotEmpty) {
        oRevHw = rHwLegacy; // نضع المراجعة القديمة في حقل المراجعة القديم كافتراضي
      } else {
        if (oldHw.contains('جديد:') || oldHw.contains('مراجعة:')) {
          var parts = oldHw.split(RegExp(r'\n|\|'));
          for (var p in parts) {
            if (p.contains('حفظ:') || p.contains('جديد:')) nHw = p.replaceAll(RegExp(r'حفظ:|جديد:'), '').trim();
            if (p.contains('مراجعة:')) oRevHw = p.replaceAll('مراجعة:', '').trim();
          }
        } else {
          oRevHw = oldHw; 
        }
      }
    }
    
    newHomeworkController = TextEditingController(text: nHw);
    newReviewHomeworkController = TextEditingController(text: nRevHw);
    oldReviewHomeworkController = TextEditingController(text: oRevHw);

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
    newHomeworkController.dispose();
    newReviewHomeworkController.dispose();
    oldReviewHomeworkController.dispose();
    readingBySight.dispose();
    religiousActivities.dispose();
    notes.dispose();
    totalMemorizedPagesController.dispose(); 
    super.dispose();
  }

  save() async {
    if (!absent && !hasNewMemorization && !hasReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text("يجب تفعيل خيار الحفظ أو المراجعة على الأقل")),
      );
      return;
    }

    setState(() => loading = true);

    double totalPages = isCompletedStudent ? 604.0 : (double.tryParse(totalMemorizedPagesController.text.trim()) ?? 0.0);
    String studentId = widget.data['studentId'] ?? '';

    // 🎯 تنظيف البيانات بناءً على المفاتيح الذكية
    String finalNewMemo = (!hasNewMemorization || absent || isCompletedStudent) ? '' : newMemorization.text.trim();
    String finalNearReview = (!hasReview || absent || isCompletedStudent) ? '' : newReview.text.trim();
    String finalFarReview = (!hasReview || absent) ? '' : oldReview.text.trim();
    
    String finalMemoRating = (!hasNewMemorization || absent || isCompletedStudent) ? '' : memorizationRating;
    String finalRevRating = (!hasReview || absent) ? '' : reviewRating;

    // 🚀 دمج الواجبات للعرض القديم وحفظهم كحقول منفصلة للجديد
    String finalNewHW = (absent || isCompletedStudent) ? '' : newHomeworkController.text.trim();
    String finalNewRevHW = (absent || isCompletedStudent) ? '' : newReviewHomeworkController.text.trim();
    String finalOldRevHW = absent ? '' : oldReviewHomeworkController.text.trim();
    
    String combinedHW = "";
    
    if (isCompletedStudent) {
      combinedHW = finalOldRevHW; 
    } else {
      if (finalNewHW.isNotEmpty) combinedHW += "حفظ: $finalNewHW";
      
      List<String> revParts = [];
      if (finalNewRevHW.isNotEmpty) revParts.add(finalNewRevHW);
      if (finalOldRevHW.isNotEmpty) revParts.add(finalOldRevHW);
      String combinedRev = revParts.join(" | ");

      if (combinedRev.isNotEmpty) {
        combinedHW += (combinedHW.isNotEmpty ? " \n " : "") + "مراجعة: $combinedRev";
      }
    }

    // 1️⃣ تحديث مستند الجلسة الحالي
    await sessionService.updateSession(
      sessionId: widget.sessionId,
      data: {
        'absent': absent,
        'supervisorId': selectedSupervisorId, 
        'supervisorName': selectedSupervisorName, 
        'newMemorization': finalNewMemo,
        'review': absent || !hasReview ? '' : (isCompletedStudent ? finalFarReview : "$finalNearReview | $finalFarReview"),
        'nearReview': finalNearReview, 
        'farReview': finalFarReview,   
        'homework': combinedHW,
        'newHomework': finalNewHW,
        'newReviewHomework': finalNewRevHW,
        'oldReviewHomework': finalOldRevHW,
        'readingBySight': absent ? '' : readingBySight.text.trim(), 
        'memorizationRating': finalMemoRating,
        'reviewRating': finalRevRating,
        'rating': absent ? '' : (isCompletedStudent ? finalRevRating : (hasNewMemorization ? finalMemoRating : finalRevRating)), 
        'studentStatus': absent ? '' : studentStatus,
        'religiousActivities': absent ? '' : religiousActivities.text.trim(),
        'notes': notes.text.trim(),
        if (!absent) 'total_memorized_pages': totalPages,
      },
    );

    // 2️⃣ المزامنة الفورية: تحديث مستند الطالب الرئيسي
    if (!absent && studentId.isNotEmpty && !isCompletedStudent && totalMemorizedPagesController.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('students').doc(studentId).update({
        'memorizedPages': totalPages,
      });
    }

    // 🎯 3️⃣ شحن التحديث كإشعار
    if (studentId.isNotEmpty) {
      String notifyTitle = "✏️ تعديل في بيانات الحلقة";
      String notifyBody = "";
      String notifyType = "regular";

      if (absent) {
        notifyTitle = "🚨 تعديل: تسجيل غياب طالب";
        notifyBody = "تم تعديل الجلسة وتوثيق غياب الطالب اليوم بـ السجل الإداري.";
        notifyType = "absent";
      } else {
        String bodyText = isCompletedStudent
            ? "تم تحديث وتعديل سجل مراجعة الختمة الشاملة بنجاح"
            : "تم تعديل بيانات الإنجاز اليومي بنجاح";
            
        if (hasNewMemorization && finalMemoRating.isNotEmpty) {
          bodyText += "، الحفظ: ($finalMemoRating)";
        }
        if (hasReview && finalRevRating.isNotEmpty) {
          bodyText += "، المراجعة: ($finalRevRating)";
        }
        
        notifyBody = bodyText;
        notifyType = "regular";
      }

      await NotificationService.sendAndSaveNotification(
        studentId: studentId,
        title: notifyTitle,
        body: notifyBody,
        type: notifyType,
        context: context, 
      );
    }

    if (!mounted) return;
    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث الجلسة بنجاح", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, 
        title: Text("تعديل بيانات الجلسة", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 18)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: checkingStudentType
          ? const Center(child: CircularProgressIndicator()) 
          : Stack(
              children: [
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

                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
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

                        if (!absent) ...[
                          _buildSectionCard(
                            title: isCompletedStudent ? "تعديل مراجعة الختمة الشاملة 👑" : "تعديل الإنجاز القرآني",
                            icon: Icons.edit_calendar,
                            isDarkMode: isDarkMode,
                            child: Column(
                              children: [
                                if (!isCompletedStudent) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(15)),
                                          child: CheckboxListTile(
                                            activeColor: Colors.blueAccent,
                                            title: Text("حفظ جديد", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
                                            value: hasNewMemorization,
                                            onChanged: (v) => setState(() => hasNewMemorization = v!),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(15)),
                                          child: CheckboxListTile(
                                            activeColor: Colors.green,
                                            title: Text("مراجعة", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
                                            value: hasReview,
                                            onChanged: (v) => setState(() => hasReview = v!),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                if (!isCompletedStudent && hasNewMemorization) ...[
                                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: newMemorization, decoration: _glassInputDecoration("الحفظ الجديد", Icons.star_border, isDarkMode)),
                                  const SizedBox(height: 15),
                                ],
                                
                                if (hasReview) ...[
                                  if (!isCompletedStudent) ...[
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
                                ],

                                TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: readingBySight, decoration: _glassInputDecoration("قراءة نظراً من المصحف (اختياري)", Icons.menu_book_outlined, isDarkMode)),
                                const SizedBox(height: 15),
                                
                                // 🚀 عرض حقول الواجب المفصولة لـ 3 أقسام
                                if (isCompletedStudent) ...[
                                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: oldReviewHomeworkController, decoration: _glassInputDecoration("المقدار المطلوب للمرة القادمة", Icons.edit_note, isDarkMode)),
                                ] else ...[
                                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: newHomeworkController, decoration: _glassInputDecoration("واجب الحفظ الجديد القادم", Icons.edit_document, isDarkMode)),
                                  const SizedBox(height: 15),
                                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: newReviewHomeworkController, decoration: _glassInputDecoration("واجب المراجعة الجديد القادم", Icons.menu_book_rounded, isDarkMode)),
                                  const SizedBox(height: 15),
                                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: oldReviewHomeworkController, decoration: _glassInputDecoration("واجب المراجعة القديم القادم", Icons.history_edu_rounded, isDarkMode)),
                                ],
                                
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
                                if (!isCompletedStudent && hasNewMemorization) ...[
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
                                
                                if (hasReview) ...[
                                  DropdownButtonFormField<String>(
                                    value: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].contains(reviewRating) ? reviewRating : "جيد",
                                    dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                    decoration: _glassInputDecoration(isCompletedStudent ? "تقييم مراجعة الختمة" : "تقييم المراجعة", Icons.rate_review_outlined, isDarkMode),
                                    items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                    onChanged: (v) => setState(() => reviewRating = v!),
                                  ),
                                  const SizedBox(height: 15),
                                ],

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