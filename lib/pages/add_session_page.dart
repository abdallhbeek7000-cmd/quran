import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart'; 
import 'package:googleapis_auth/auth_io.dart'; 

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
  
  // 🎯 التعديل الملوكي: فصل متغيّرات التقييم لعدم الخلط
  String memorizationRating = "جيد"; // تقييم الحفظ الجديد
  String reviewRating = "جيد";       // تقييم المراجعات
  
  String studentStatus = "مهذب";

  final Color primaryColor = const Color(0xff425c75);

  Future<String?> getObtainAccessToken() async {
    try {
      final serviceAccountJson = await rootBundle.loadString('assets/service-account.json');
      final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      
      final client = await clientViaServiceAccount(accountCredentials, scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();
      return accessToken;
    } catch (e) {
      print("Error generating automatic Access Token: $e");
      return null;
    }
  }

  Future<void> sendNotificationToParent(String studentId, String memRating, String revRating, bool isAbsent, bool isExamSession, String examScore, String dateStr) async {
    try {
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
      if (!studentDoc.exists) return;
      Map<String, dynamic> data = studentDoc.data() as Map<String, dynamic>;
      String? parentToken = data['fcmToken'];
      String studentName = data['name'] ?? 'ابنكم';

      if (parentToken == null || parentToken.isEmpty) return;

      String accessToken = await getObtainAccessToken() ?? '';
      if (accessToken.isEmpty) return;

      String bodyText = "";
      if (isAbsent) {
        bodyText = "تم تسجيل غياب لـ $studentName في حلقة اليوم $dateStr";
      } else if (isExamSession) {
        bodyText = "🎯 تم تسجيل نتيجة اختبار لـ $studentName بعلامة ($examScore من 100) ليوم $dateStr";
      } else {
        // 🔔 تحديث نص الإشعار للأهل ليعكس الفصل الجديد
        bodyText = "تم تحديث يومية $studentName الحفظ: ($memRating) والمراجعة: ($revRating) ليوم $dateStr";
      }

      final String projectId = "quran-habal"; 
      
      await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken', 
        },
        body: jsonEncode(<String, dynamic>{
          'message': {
            'token': parentToken,
            'notification': {
              'title': isExamSession ? '📝 نتيجة اختبار جديدة' : '📢 تحديث يومي جديد من الحلقة',
              'body': bodyText,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'sound': 'default',
            }
          }
        }),
      );
    } catch (e) {
      print("Error sending notification: $e");
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

    String finalNearReview = (absent || isExam) ? '' : newReview.text.trim();
    String finalFarReview = (absent || isExam) ? '' : oldReview.text.trim();

    // نترك الموديل مؤقتاً يقرأ الـ memorizationRating كتقييم أساسي لحين تعديل ملف الـ Model بالخطوة الجاية
    final session = SessionModel(
      id: '',
      studentId: widget.studentId,
      studentName: widget.studentName,
      supervisorId: widget.supervisorId,
      supervisorName: widget.supervisorName,
      date: date,
      absent: absent,
      newMemorization: (absent || isExam) ? '' : newMemorization.text.trim(),
      review: (absent || isExam) ? '' : "$finalNearReview | $finalFarReview",
      homework: (absent || isExam) ? '' : homework.text.trim(),
      rating: (absent || isExam) ? '' : memorizationRating,
      studentStatus: (absent || isExam) ? '' : studentStatus,
      religiousActivities: (absent || isExam) ? '' : religiousActivities.text.trim(),
      notes: notes.text.trim(),
    );

    double totalPages = double.tryParse(totalMemorizedPagesController.text.trim()) ?? 0.0;

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
      
      // 🎯 رفع التقييمين منفصلين تماماً للـ Firestore لقفل اللخبطة عند الأهل
      'memorizationRating': (absent || isExam) ? '' : memorizationRating,
      'reviewRating': (absent || isExam) ? '' : reviewRating,
      'rating': (absent || isExam) ? '' : memorizationRating, // حقل احتياطي للتوافق القديم
      
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
      
      if (!isExam && totalMemorizedPagesController.text.trim().isNotEmpty) {
        updateData['memorizedPages'] = totalPages;
      }
      
      await studentRef.update(updateData);
    }

    await sendNotificationToParent(
      widget.studentId,
      absent ? '' : memorizationRating,
      absent ? '' : reviewRating,
      absent,
      isExam,
      examScoreController.text.trim(),
      date,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
        title: Text(widget.studentName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Card(
                    elevation: 0,
                    color: Colors.white.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: SwitchListTile(
                      activeColor: Colors.orange,
                      value: absent,
                      title: const Text("تسجيل الطالب غائب؟", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      secondary: Icon(absent ? Icons.person_off : Icons.person, color: Colors.white),
                      onChanged: (v) {
                        setState(() {
                          absent = v;
                          if (absent) isExam = false; 
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (!absent)
                    Card(
                      elevation: 0,
                      color: Colors.white.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: SwitchListTile(
                        activeColor: Colors.tealAccent,
                        value: isExam,
                        title: const Text("تسجيل كـ (جلسة اختبار) ؟", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        secondary: Icon(Icons.assignment_turned_in, color: isExam ? Colors.tealAccent : Colors.white),
                        onChanged: (v) {
                          setState(() {
                            isExam = v;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (!absent && !isExam) ...[
                    _buildSectionCard(
                      title: "الإنجاز القرآني اليومي",
                      icon: Icons.menu_book,
                      isDarkMode: isDarkMode,
                      child: Column(
                        children: [
                          TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: newMemorization, decoration: _inputDecoration("الحفظ الجديد", Icons.star_border, isDarkMode)),
                          const SizedBox(height: 15),
                          TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: newReview, decoration: _inputDecoration("مراجعة جديد", Icons.auto_stories_outlined, isDarkMode)),
                          const SizedBox(height: 15),
                          TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: oldReview, decoration: _inputDecoration("مراجعة قديم", Icons.history_outlined, isDarkMode)),
                          const SizedBox(height: 15),
                          TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: readingBySight, decoration: _inputDecoration("قراءة نظراً من المصحف (اختياري)", Icons.menu_book_outlined, isDarkMode)),
                          const SizedBox(height: 15),
                          TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: homework, decoration: _inputDecoration("الواجب القادم", Icons.edit_note, isDarkMode)),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 10),
                          TextField(
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold), 
                            controller: totalMemorizedPagesController, 
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                            decoration: _inputDecoration("إجمالي عدد الصفحات المحفوظة حتى الآن", Icons.analytics_outlined, isDarkMode)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildSectionCard(
                      title: "التقييم والسلوك",
                      icon: Icons.thumbs_up_down_outlined,
                      isDarkMode: isDarkMode,
                      child: Column(
                        children: [
                          // 🎯 التعديل الملوكي البصري: حقل تقييم الحفظ الجديد بشكل مستقل
                          DropdownButtonFormField<String>(
                            value: memorizationRating,
                            dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            decoration: _inputDecoration("تقييم الحفظ الجديد", Icons.stars, isDarkMode),
                            items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                            onChanged: (v) => setState(() => memorizationRating = v!),
                          ),
                          const SizedBox(height: 15),
                          
                          // 🎯 التعديل الملوكي البصري: حقل تقييم المراجعات بشكل مستقل
                          DropdownButtonFormField<String>(
                            value: reviewRating,
                            dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            decoration: _inputDecoration("تقييم المراجعة", Icons.g_translate, isDarkMode),
                            items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                            onChanged: (v) => setState(() => reviewRating = v!),
                          ),
                          const SizedBox(height: 15),
                          
                          DropdownButtonFormField<String>(
                            value: studentStatus,
                            dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
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
                      child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: religiousActivities, decoration: _inputDecoration("نشاطات دينية", Icons.volunteer_activism, isDarkMode)),
                    ),
                  ],

                  if (isExam && !absent) ...[
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
                        decoration: _inputDecoration("علامة الطالب من 100", Icons.percent, isDarkMode),
                      ),
                    ),
                  ],

                  if (absent) ...[
                    _buildSectionCard(
                      title: "تفاصيل الغياب",
                      icon: Icons.person_off_outlined,
                      isDarkMode: isDarkMode,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("نوع الغياب:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkMode ? Colors.white : Colors.black)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text("بدون عذر"),
                                selected: absenceType == "بدون عذر",
                                selectedColor: Colors.red.shade100,
                                labelStyle: TextStyle(color: absenceType == "بدون عذر" ? Colors.red.shade900 : (isDarkMode ? Colors.white70 : Colors.black)),
                                onSelected: (val) => setState(() => absenceType = "بدون عذر"),
                              ),
                              const SizedBox(width: 15),
                              ChoiceChip(
                                label: const Text("بعذر"),
                                selected: absenceType == "بعذر",
                                selectedColor: Colors.green.shade100,
                                labelStyle: TextStyle(color: absenceType == "بعذر" ? Colors.green.shade900 : (isDarkMode ? Colors.white70 : Colors.black)),
                                onSelected: (val) => setState(() => absenceType = "بعذر"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            controller: absenceReasonController,
                            decoration: _inputDecoration("سبب الغياب (اختياري مثل: مرض، سفر...)", Icons.help_outline, isDarkMode),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 15),
                  _buildSectionCard(
                    title: "ملاحظات المشرف",
                    icon: Icons.note_alt_outlined,
                    isDarkMode: isDarkMode,
                    child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: notes, maxLines: 3, decoration: _inputDecoration("اكتب ملاحظاتك هنا...", Icons.comment, isDarkMode)),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: loading ? null : addSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: absent ? Colors.orange : (isExam ? Colors.teal : (isDarkMode ? Colors.orange : primaryColor)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("حفظ الجلسة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
      labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
      prefixIcon: Icon(icon, color: isDarkMode ? Colors.orange : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode ? const Color(0xff2b2b2b) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.transparent : Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.transparent : Colors.grey.shade200)),
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
              Icon(icon, color: isDarkMode ? Colors.tealAccent : primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: isDarkMode ? Colors.tealAccent : primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Divider(height: 25, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
          child,
        ],
      ),
    );
  }
}