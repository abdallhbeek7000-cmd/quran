import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';

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
  
  // تأكد أن هذه المتغيرات معرفة هنا بالضبط
  final newMemorization = TextEditingController();
  final newReview = TextEditingController(); // الحقل الجديد
  final oldReview = TextEditingController(); // الحقل الجديد (بدل review)
  final homework = TextEditingController();
  final religiousActivities = TextEditingController();
  final notes = TextEditingController();

  bool loading = false;
  bool absent = false;
  String rating = "جيد";
  String studentStatus = "مهذب";

  final Color primaryColor = const Color(0xff425c75);

  addSession() async {
    final hasToday = await sessionService.hasSessionToday(widget.studentId);
    if (hasToday) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text("تم تسجيل جلسة اليوم مسبقًا")),
      );
      return;
    }

    setState(() => loading = true);
    final now = DateTime.now();
    final date = "${now.year}-${now.month}-${now.day}";

    final session = SessionModel(
      id: '',
      studentId: widget.studentId,
      studentName: widget.studentName,
      supervisorId: widget.supervisorId,
      supervisorName: widget.supervisorName,
      date: date,
      absent: absent,
      newMemorization: absent ? '' : newMemorization.text.trim(),
      // هنا دمجنا الجديد والقديم في حقل واحد لكي لا نغير الموديل
      review: absent ? '' : "${newReview.text.trim()} | ${oldReview.text.trim()}",
      homework: absent ? '' : homework.text.trim(),
      rating: absent ? '' : rating,
      studentStatus: absent ? '' : studentStatus,
      religiousActivities: absent ? '' : religiousActivities.text.trim(),
      notes: notes.text.trim(),
    );

    await sessionService.addSession(session);
    if (!mounted) return;
    setState(() => loading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.green, content: Text("تمت إضافة الجلسة بنجاح")),
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
        title: Text(widget.studentName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
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
                  title: const Text("تسجيل الطالب غائب؟", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  secondary: Icon(absent ? Icons.person_off : Icons.person, color: Colors.white),
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
                      title: "الإنجاز القرآني",
                      icon: Icons.menu_book,
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
                      title: "التقييم والسلوك",
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
                    const SizedBox(height: 15),
                    _buildSectionCard(
                      title: "نشاطات إضافية",
                      icon: Icons.mosque_outlined,
                      child: TextField(controller: religiousActivities, decoration: _inputDecoration("نشاطات دينية", Icons.volunteer_activism)),
                    ),
                  ],
                  const SizedBox(height: 15),
                  _buildSectionCard(
                    title: "ملاحظات المشرف",
                    icon: Icons.note_alt_outlined,
                    child: TextField(controller: notes, maxLines: 3, decoration: _inputDecoration("اكتب ملاحظاتك هنا...", Icons.comment)),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: loading ? null : addSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: absent ? Colors.orange : primaryColor,
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