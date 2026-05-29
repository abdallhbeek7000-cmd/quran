import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui'; // 🎯 ضرورية لتأثير الزجاج
import '../models/session_model.dart';
import '../services/session_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart'; 
import '../services/notification_service.dart'; 

class AddSessionPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String supervisorId;
  final String supervisorName;

  const AddSessionPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<AddSessionPage> createState() => _AddSessionPageState();
}

class _AddSessionPageState extends State<AddSessionPage> {
  final sessionService = SessionService();
  
  final newMemorization = TextEditingController();
  final newReview = TextEditingController(); 
  final oldReview = TextEditingController(); 
  final homework = TextEditingController();
  final readingBySight = TextEditingController(); 
  final religiousActivities = TextEditingController();
  final notes = TextEditingController();
  final absenceReasonController = TextEditingController(); 
  final examScoreController = TextEditingController(); 
  
  final totalMemorizedPagesController = TextEditingController();

  bool loading = false;
  bool absent = false;
  bool isExam = false; 
  String absenceType = "بدون عذر"; 
  
  String memorizationRating = "جيد"; 
  String reviewRating = "جيد";       
  
  String studentStatus = "مهذب";

  bool isCompletedStudent = false;
  bool checkingStudentType = true;

  String? selectedSupervisorId;
  String? selectedSupervisorName;

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // لون مكمل للانعكاسات الزجاجية

  @override
  void initState() {
    super.initState();
    selectedSupervisorId = widget.supervisorId;
    selectedSupervisorName = widget.supervisorName;
    _checkIfStudentIsCompleted();
  }

  Future<void> _checkIfStudentIsCompleted() async {
    try {
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId)
          .get();
          
      if (studentDoc.exists && studentDoc.data() != null) {
        Map<String, dynamic> data = studentDoc.data() as Map<String, dynamic>;
        if (data['studentType'] == 'completed') {
          setState(() {
            isCompletedStudent = true;
          });
        }
      }
    } catch (e) {
      print("Error checking student type: $e");
    } finally {
      setState(() {
        checkingStudentType = false;
      });
    }
  }

  addSession() async {
    final hasToday = await sessionService.hasSessionToday(widget.studentId);
    if (hasToday) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text("تم تسجيل جلسة اليوم مسبقًا")),
      );
      return;
    }

    if (isExam && !absent && examScoreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text("يرجى إدخال علامة الاختبار أولاً")),
      );
      return;
    }

    setState(() => loading = true);
    final now = DateTime.now();
    final date = "${now.year}-${now.month}-${now.day}";

    String finalNearReview = (absent || isExam || isCompletedStudent) ? '' : newReview.text.trim();
    String finalFarReview = (absent || isExam) ? '' : oldReview.text.trim();

    final session = SessionModel(
      id: '',
      studentId: widget.studentId,
      studentName: widget.studentName,
      supervisorId: selectedSupervisorId ?? widget.supervisorId, 
      supervisorName: selectedSupervisorName ?? widget.supervisorName, 
      date: date,
      absent: absent,
      newMemorization: (absent || isExam || isCompletedStudent) ? '' : newMemorization.text.trim(),
      review: (absent || isExam) ? '' : (isCompletedStudent ? finalFarReview : "$finalNearReview | $finalFarReview"),
      homework: (absent || isExam) ? '' : homework.text.trim(),
      rating: (absent || isExam) ? '' : (isCompletedStudent ? reviewRating : memorizationRating),
      studentStatus: (absent || isExam) ? '' : studentStatus,
      religiousActivities: (absent || isExam) ? '' : religiousActivities.text.trim(),
      notes: notes.text.trim(),
    );

    double totalPages = isCompletedStudent ? 604.0 : (double.tryParse(totalMemorizedPagesController.text.trim()) ?? 0.0);

    final Map<String, dynamic> sessionData = {
      'studentId': session.studentId,
      'studentName': session.studentName,
      'supervisorId': session.supervisorId,
      'supervisorName': session.supervisorName,
      'date': session.date,
      'absent': session.absent,
      'isExam': isExam, 
      'examScore': isExam && !absent ? examScoreController.text.trim() : '', 
      'newMemorization': session.newMemorization,
      'nearReview': finalNearReview, 
      'farReview': finalFarReview,   
      'homework': session.homework,
      'readingBySight': (absent || isExam) ? '' : readingBySight.text.trim(), 
      'memorizationRating': (absent || isExam || isCompletedStudent) ? '' : memorizationRating,
      'reviewRating': (absent || isExam) ? '' : reviewRating,
      'rating': (absent || isExam) ? '' : (isCompletedStudent ? reviewRating : memorizationRating), 
      'studentStatus': session.studentStatus,
      'religiousActivities': session.religiousActivities,
      'notes': session.notes,
      'absenceType': absent ? absenceType : '', 
      'absenceReason': absent ? absenceReasonController.text.trim() : '', 
      if (!absent && !isExam) 'total_memorized_pages': totalPages,
    };

    await FirebaseFirestore.instance.collection('sessions').add(sessionData);

    final studentRef = FirebaseFirestore.instance.collection('students').doc(widget.studentId);
    
    if (absent) {
      await studentRef.update({
        'consecutiveAbsences': FieldValue.increment(1),
      });
    } else {
      final Map<String, dynamic> updateData = {
        'consecutiveAbsences': 0,
      };
      
      if (!isExam && !isCompletedStudent && totalMemorizedPagesController.text.trim().isNotEmpty) {
        updateData['memorizedPages'] = totalPages;
      }
      
      await studentRef.update(updateData);
    }

    // 🎯 الإشعارات المزدوجة الملوكية
    String notifyTitle = "";
    String notifyBody = "";
    String notifyType = "regular";

    if (absent) {
      notifyTitle = "🚨 تنبيه غياب الطالب";
      notifyBody = "تم تسجيل غياب لـ ${widget.studentName} في حلقة اليوم، نوع الغياب: ($absenceType)";
      notifyType = "absent";
    } else if (isExam) {
      notifyTitle = "📝 نتيجة اختبار جديدة";
      notifyBody = "تم توثيق نتيجة اختبار لـ ${widget.studentName} بعلامة (${examScoreController.text.trim()} من 100)";
      notifyType = "exam";
    } else {
      notifyTitle = "📢 تحديث يومي من الحلقة";
      notifyBody = isCompletedStudent 
          ? "تم تحديث سجل مراجعة الختمة الشاملة لـ ${widget.studentName} بنجاح، التقييم: ($reviewRating)"
          : "تم تسجيل يومية جديدة لـ ${widget.studentName} الحفظ: ($memorizationRating) والمراجعة: ($reviewRating)";
      notifyType = "regular";
    }

    await NotificationService.sendAndSaveNotification(
      studentId: widget.studentId,
      title: notifyTitle,
      body: notifyBody,
      type: notifyType,
      context: context, 
    );

    if (!mounted) return;
    setState(() => loading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.green, content: Text("تمت إضافة الجلسة بنجاح")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية وراء AppBar
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف
        title: Text(widget.studentName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: checkingStudentType 
          ? const Center(child: CircularProgressIndicator()) 
          : Stack(
              children: [
                // 🎨 1. الخلفية الانسيابية مع الدوائر العائمة
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
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  left: -80,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
                  ),
                ),

                // 🏢 2. المحتوى الأساسي (نماذج الجلسة)
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        // 🧊 قسم خيارات الغياب والاختبار (زجاجي)
                        _buildGlassContainer(
                          isDarkMode: isDarkMode,
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: SwitchListTile(
                                  activeColor: Colors.orange,
                                  value: absent,
                                  title: Text("تسجيل الطالب غائب؟", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
                                  secondary: Icon(absent ? Icons.person_off : Icons.person, color: isDarkMode ? Colors.white70 : primaryColor),
                                  onChanged: (v) {
                                    setState(() {
                                      absent = v;
                                      if (absent) isExam = false; 
                                    });
                                  },
                                ),
                              ),
                              if (!absent) ...[
                                const SizedBox(height: 10),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: SwitchListTile(
                                    activeColor: Colors.teal,
                                    value: isExam,
                                    title: Text("تسجيل كـ (جلسة اختبار) ؟", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
                                    secondary: Icon(Icons.assignment_turned_in, color: isExam ? Colors.teal : (isDarkMode ? Colors.white70 : primaryColor)),
                                    onChanged: (v) {
                                      setState(() {
                                        isExam = v;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 🧊 أقسام الإدخال الرئيسية
                        if (!absent && !isExam) ...[
                          _buildSectionCard(
                            title: isCompletedStudent ? "منظومة مراجعة الختمة الشاملة 👑" : "الإنجاز القرآني اليومي",
                            icon: Icons.menu_book,
                            isDarkMode: isDarkMode,
                            child: Column(
                              children: [
                                if (!isCompletedStudent) ...[
                                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: newMemorization, decoration: _glassInputDecoration("الحفظ الجديد", Icons.star_border, isDarkMode)),
                                  const SizedBox(height: 15),
                                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: newReview, decoration: _glassInputDecoration("مراجعة جديد", Icons.auto_stories_outlined, isDarkMode)),
                                  const SizedBox(height: 15),
                                ],
                                TextField(
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), 
                                  controller: oldReview, 
                                  decoration: _glassInputDecoration(
                                    isCompletedStudent ? "المقدار المسموع من مراجعة الختمة الشاملة" : "مراجعة قديم", 
                                    isCompletedStudent ? Icons.verified_user_rounded : Icons.history_outlined, 
                                    isDarkMode
                                  )
                                ),
                                const SizedBox(height: 15),
                                TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: readingBySight, decoration: _glassInputDecoration("قراءة نظراً من المصحف (اختياري)", Icons.menu_book_outlined, isDarkMode)),
                                const SizedBox(height: 15),
                                TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: homework, decoration: _glassInputDecoration(isCompletedStudent ? "المقدار المطلوب للمرة القادمة" : "الواجب القادم", Icons.edit_note, isDarkMode)),
                                
                                if (!isCompletedStudent) ...[
                                  const SizedBox(height: 20),
                                  Divider(color: isDarkMode ? Colors.white24 : Colors.black12),
                                  const SizedBox(height: 10),
                                  TextField(
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold), 
                                    controller: totalMemorizedPagesController, 
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                                    decoration: _glassInputDecoration("إجمالي عدد الصفحات المحفوظة حتى الآن", Icons.analytics_outlined, isDarkMode)
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildSectionCard(
                            title: "التقييم والسلوك",
                            icon: Icons.thumbs_up_down_outlined,
                            isDarkMode: isDarkMode,
                            child: Column(
                              children: [
                                if (!isCompletedStudent) ...[
                                  DropdownButtonFormField<String>(
                                    value: memorizationRating,
                                    dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                    decoration: _glassInputDecoration("تقييم الحفظ الجديد", Icons.stars, isDarkMode),
                                    items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                    onChanged: (v) => setState(() => memorizationRating = v!),
                                  ),
                                  const SizedBox(height: 15),
                                ],
                                DropdownButtonFormField<String>(
                                  value: reviewRating,
                                  dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                  decoration: _glassInputDecoration(isCompletedStudent ? "تقييم مراجعة الختمة" : "تقييم المراجعة", Icons.rate_review_outlined, isDarkMode),
                                  items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (v) => setState(() => reviewRating = v!),
                                ),
                                const SizedBox(height: 15),
                                DropdownButtonFormField<String>(
                                  value: studentStatus,
                                  dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                  decoration: _glassInputDecoration("حالة الطالب", Icons.mood, isDarkMode),
                                  items: ["مهذب", "منضبط", "مشاغب", "كثير الحركة"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                  onChanged: (v) => setState(() => studentStatus = v!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildSectionCard(
                            title: "نشاطات إضافية",
                            icon: Icons.mosque_outlined,
                            isDarkMode: isDarkMode,
                            child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: religiousActivities, decoration: _glassInputDecoration("نشاطات دينية", Icons.volunteer_activism, isDarkMode)),
                          ),
                        ],

                        const SizedBox(height: 20),
                        _buildSectionCard(
                          title: "المشرف المسجِّل للجلسة",
                          icon: Icons.assignment_ind_outlined,
                          isDarkMode: isDarkMode,
                          child: FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance.collection('supervisors').get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                  return Text("لم يتم العثور على مشرفين", style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54));
                              }

                              List<DropdownMenuItem<String>> items = snapshot.data!.docs.map((doc) {
                                String id = doc.id;
                                String name = doc['name'] ?? 'مشرف غير معروف';
                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(name),
                                );
                              }).toList();

                              bool hasValue = snapshot.data!.docs.any((doc) => doc.id == selectedSupervisorId);
                              if (!hasValue && items.isNotEmpty) {
                                selectedSupervisorId = items.first.value;
                              }

                              return DropdownButtonFormField<String>(
                                value: selectedSupervisorId,
                                dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
                                decoration: _glassInputDecoration("اسم المشرف الحالي / البديل", Icons.person_search_rounded, isDarkMode),
                                items: items,
                                onChanged: (v) {
                                  setState(() {
                                    selectedSupervisorId = v;
                                    final selectedDoc = snapshot.data!.docs.firstWhere((doc) => doc.id == v);
                                    selectedSupervisorName = selectedDoc['name'] ?? 'مشرف غير معروف';
                                  });
                                },
                              );
                            },
                          ),
                        ),

                        if (isExam && !absent) ...[
                          const SizedBox(height: 20),
                          _buildSectionCard(
                            title: "نتائج اختبار الطالب",
                            icon: Icons.quiz,
                            isDarkMode: isDarkMode,
                            child: TextField(
                              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                              controller: examScoreController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: _glassInputDecoration("علامة الطالب من 100", Icons.percent, isDarkMode),
                            ),
                          ),
                        ],

                        if (absent) ...[
                          const SizedBox(height: 20),
                          _buildSectionCard(
                            title: "تفاصيل الغياب",
                            icon: Icons.person_off_outlined,
                            isDarkMode: isDarkMode,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("نوع الغياب:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkMode ? Colors.white : primaryColor)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    ChoiceChip(
                                      label: const Text("بدون عذر"),
                                      selected: absenceType == "بدون عذر",
                                      selectedColor: Colors.red.shade400,
                                      backgroundColor: isDarkMode ? Colors.black26 : Colors.white54,
                                      labelStyle: TextStyle(color: absenceType == "بدون عذر" ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87)),
                                      onSelected: (val) => setState(() => absenceType = "بدون عذر"),
                                    ),
                                    const SizedBox(width: 15),
                                    ChoiceChip(
                                      label: const Text("بعذر"),
                                      selected: absenceType == "بعذر",
                                      selectedColor: Colors.green.shade400,
                                      backgroundColor: isDarkMode ? Colors.black26 : Colors.white54,
                                      labelStyle: TextStyle(color: absenceType == "بعذر" ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87)),
                                      onSelected: (val) => setState(() => absenceType = "بعذر"),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                TextField(
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                  controller: absenceReasonController,
                                  decoration: _glassInputDecoration("سبب الغياب (اختياري مثل: مرض، سفر...)", Icons.help_outline, isDarkMode),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        _buildSectionCard(
                          title: "ملاحظات المشرف",
                          icon: Icons.note_alt_outlined,
                          isDarkMode: isDarkMode,
                          child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: notes, maxLines: 3, decoration: _glassInputDecoration("اكتب ملاحظاتك هنا...", Icons.comment, isDarkMode)),
                        ),
                        
                        const SizedBox(height: 35),
                        // 🚀 زر الحفظ الزجاجي
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: loading ? null : addSession,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: absent ? Colors.orange.withOpacity(0.9) : (isExam ? Colors.teal.withOpacity(0.9) : (isDarkMode ? Colors.orange.withOpacity(0.9) : primaryColor.withOpacity(0.9))),
                              foregroundColor: Colors.white,
                              elevation: 5,
                              shadowColor: Colors.black38,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("حفظ الجلسة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // 🧊 أداة تغليف الأقسام بتأثير الزجاج
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
              Text(title, style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
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
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), // خلفية نصف شفافة للحقل
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
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