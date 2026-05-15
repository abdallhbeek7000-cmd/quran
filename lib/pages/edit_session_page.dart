import 'package:flutter/material.dart';
import '../services/session_service.dart';

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
  late TextEditingController newReview; // الحقل المطور
  late TextEditingController oldReview; // الحقل المطور
  late TextEditingController homework;
  late TextEditingController religiousActivities;
  late TextEditingController notes;

  bool absent = false;
  String rating = "جيد";
  String studentStatus = "مهذب";
  bool loading = false;

  final Color primaryColor = const Color(0xff425c75);

  @override
  void initState() {
    super.initState();
    final data = widget.data;

    absent = data['absent'] ?? false;
    rating = (data['rating'] == null || data['rating'] == '') ? "جيد" : data['rating'];
    studentStatus = (data['studentStatus'] == null || data['studentStatus'] == '') ? "مهذب" : data['studentStatus'];

    newMemorization = TextEditingController(text: data['newMemorization']);
    
    // فك دمج المراجعة (إذا كانت محفوظة بصيغة جديد | قديم)
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
    religiousActivities = TextEditingController(text: data['religiousActivities']);
    notes = TextEditingController(text: data['notes']);
  }

  save() async {
    setState(() => loading = true);

    await sessionService.updateSession(
      sessionId: widget.sessionId,
      data: {
        'absent': absent,
        'newMemorization': absent ? '' : newMemorization.text.trim(),
        'review': absent ? '' : "${newReview.text.trim()} | ${oldReview.text.trim()}",
        'homework': absent ? '' : homework.text.trim(),
        'rating': absent ? '' : rating,
        'studentStatus': absent ? '' : studentStatus,
        'religiousActivities': absent ? '' : religiousActivities.text.trim(),
        'notes': notes.text.trim(),
      },
    );

    if (!mounted) return;
    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث الجلسة بنجاح")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text("تعديل بيانات الجلسة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header التعديل
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: primaryColor,
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
                      title: "تعديل الإنجاز",
                      icon: Icons.edit_calendar,
                      child: Column(
                        children: [
                          TextField(controller: newMemorization, decoration: _inputDecoration("الحفظ الجديد", Icons.star_border)),
                          const SizedBox(height: 15),
                          TextField(controller: newReview, decoration: _inputDecoration("مراجعة جديد", Icons.auto_stories_outlined)),
                          const SizedBox(height: 15),
                          TextField(controller: oldReview, decoration: _inputDecoration("مراجعة قديم", Icons.history_outlined)),
                          const SizedBox(height: 15),
                          TextField(controller: homework, decoration: _inputDecoration("الواجب", Icons.edit_note)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildSectionCard(
                      title: "تعديل السلوك والتقييم",
                      icon: Icons.thumbs_up_down_outlined,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: rating,
                            decoration: _inputDecoration("التقييم", Icons.grade),
                            items: ["ممتاز", "جيد", "سيء"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                            onChanged: (v) => setState(() => rating = v!),
                          ),
                          const SizedBox(height: 15),
                          DropdownButtonFormField<String>(
                            value: studentStatus,
                            decoration: _inputDecoration("حالة الطالب", Icons.mood),
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
                    child: Column(
                      children: [
                        if (!absent) TextField(controller: religiousActivities, decoration: _inputDecoration("نشاطات دينية", Icons.mosque_outlined)),
                        const SizedBox(height: 15),
                        TextField(controller: notes, maxLines: 3, decoration: _inputDecoration("الملاحظات العامة", Icons.comment)),
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
                        backgroundColor: absent ? Colors.orange : primaryColor,
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 25),
          child,
        ],
      ),
    );
  }
}