import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../services/session_service.dart';
import '../services/theme_provider.dart';

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
  
  // 🎯 التعديل الملوكي: فصل متغيرات التقييم داخل شاشة التعديل
  String memorizationRating = "جيد";
  String reviewRating = "جيد";
  
  String studentStatus = "مهذب";
  bool loading = false;

  final Color primaryColor = const Color(0xff425c75);

  @override
  void initState() {
    super.initState();
    final data = widget.data;

    absent = data['absent'] ?? false;
    
    // 🎯 قراءة ذكية للتقييمات المفصولة مع حقل احتياطي للبيانات القديمة منعاً للـ Crash
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

    double totalPages = double.tryParse(totalMemorizedPagesController.text.trim()) ?? 0.0;
    String studentId = widget.data['studentId'] ?? '';

    // 1️⃣ تحديث مستند الجلسة الحالي في مجموعة sessions مع فصل التقييمات
    await sessionService.updateSession(
      sessionId: widget.sessionId,
      data: {
        'absent': absent,
        'newMemorization': absent ? '' : newMemorization.text.trim(),
        'review': absent ? '' : "${newReview.text.trim()} | ${oldReview.text.trim()}",
        'nearReview': absent ? '' : newReview.text.trim(), 
        'farReview': absent ? '' : oldReview.text.trim(),   
        'homework': absent ? '' : homework.text.trim(),
        'readingBySight': absent ? '' : readingBySight.text.trim(), 
        
        // 🎯 حفظ التقييمات الجديدة بعد الفصل في قاعدة البيانات
        'memorizationRating': absent ? '' : memorizationRating,
        'reviewRating': absent ? '' : reviewRating,
        'rating': absent ? '' : memorizationRating, // للحفاظ على توافق السيستم القديم
        
        'studentStatus': absent ? '' : studentStatus,
        'religiousActivities': absent ? '' : religiousActivities.text.trim(),
        'notes': notes.text.trim(),
        
        if (!absent) 'total_memorized_pages': totalPages,
      },
    );

    // 2️⃣ المزامنة الفورية: تحديث مستند الطالب الرئيسي
    if (!absent && studentId.isNotEmpty && totalMemorizedPagesController.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('students').doc(studentId).update({
        'memorizedPages': totalPages,
      });
    }

    if (!mounted) return;
    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث الجلسة بنجاح")),
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
        title: const Text("تعديل بيانات الجلسة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
              child: Card(
                elevation: 0,
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: SwitchListTile(
                  activeColor: Colors.orange,
                  value: absent,
                  title: const Text("تسجيل غياب في هذا اليوم", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      title: "تعديل الإنجاز القرآني",
                      icon: Icons.edit_calendar,
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
                          TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: homework, decoration: _inputDecoration("الواجب", Icons.edit_note, isDarkMode)),
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
                      title: "تعديل السلوك والتقييم",
                      icon: Icons.thumbs_up_down_outlined,
                      isDarkMode: isDarkMode,
                      child: Column(
                        children: [
                          // 🎯 التعديل الملوكي: Dropdown منفصل لتعديل تقييم الحفظ الجديد
                          DropdownButtonFormField<String>(
                            value: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].contains(memorizationRating) ? memorizationRating : "جيد",
                            dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            decoration: _inputDecoration("تقييم الحفظ الجديد", Icons.stars, isDarkMode),
                            items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                            onChanged: (v) => setState(() => memorizationRating = v!),
                          ),
                          const SizedBox(height: 15),
                          
                          // 🎯 التعديل الملوكي: Dropdown منفصل لتعديل تقييم المراجعات
                          DropdownButtonFormField<String>(
                            value: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].contains(reviewRating) ? reviewRating : "جيد",
                            dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            decoration: _inputDecoration("تقييم المراجعة (الماضى)", Icons.g_translate, isDarkMode),
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
                  ],
                  const SizedBox(height: 15),
                  _buildSectionCard(
                    title: "ملاحظات إضافية",
                    icon: Icons.comment_bank_outlined,
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        if (!absent) TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: religiousActivities, decoration: _inputDecoration("نشاطات دينية", Icons.mosque_outlined, isDarkMode)),
                        if (!absent) const SizedBox(height: 15),
                        TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: notes, maxLines: 3, decoration: _inputDecoration("الملاحظات العامة", Icons.comment, isDarkMode)),
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
                          : const Text("تحديث البيانات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
              Icon(icon, color: isDarkMode ? Colors.orange : primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: isDarkMode ? Colors.orange : primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Divider(height: 25, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
          child,
        ],
      ),
    );
  }
}