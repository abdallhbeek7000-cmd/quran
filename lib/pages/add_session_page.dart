import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart'; 

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
  final religiousActivities = TextEditingController();
  final notes = TextEditingController();
  final absenceReasonController = TextEditingController(); 

  bool loading = false;
  bool absent = false;
  String absenceType = "بدون عذر"; 
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

    String finalNearReview = absent ? '' : newReview.text.trim();
    String finalFarReview = absent ? '' : oldReview.text.trim();

    final session = SessionModel(
      id: '',
      studentId: widget.studentId,
      studentName: widget.studentName,
      supervisorId: widget.supervisorId,
      supervisorName: widget.supervisorName,
      date: date,
      absent: absent,
      newMemorization: absent ? '' : newMemorization.text.trim(),
      review: absent ? '' : "$finalNearReview | $finalFarReview",
      homework: absent ? '' : homework.text.trim(),
      rating: absent ? '' : rating,
      studentStatus: absent ? '' : studentStatus,
      religiousActivities: absent ? '' : religiousActivities.text.trim(),
      notes: notes.text.trim(),
    );

    final Map<String, dynamic> sessionData = {
      'studentId': session.studentId,
      'studentName': session.studentName,
      'supervisorId': session.supervisorId,
      'supervisorName': session.supervisorName,
      'date': session.date,
      'absent': session.absent,
      'newMemorization': session.newMemorization,
      'nearReview': finalNearReview, 
      'farReview': finalFarReview,   
      'homework': session.homework,
      'rating': session.rating,
      'studentStatus': session.studentStatus,
      'religiousActivities': session.religiousActivities,
      'notes': session.notes,
      'absenceType': absent ? absenceType : '', 
      'absenceReason': absent ? absenceReasonController.text.trim() : '', 
    };

    await FirebaseFirestore.instance.collection('sessions').add(sessionData);

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
                      isDarkMode: isDarkMode,
                      child: Column(
                        children: [
                          TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: newMemorization, decoration: _inputDecoration("الحفظ الجديد", Icons.star_border, isDarkMode)),
                          const SizedBox(height: 15),
                          TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: newReview, decoration: _inputDecoration("مراجعة جديد", Icons.auto_stories_outlined, isDarkMode)),
                          const SizedBox(height: 15),
                          TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: oldReview, decoration: _inputDecoration("مراجعة قديم", Icons.history_outlined, isDarkMode)),
                          const SizedBox(height: 15),
                          TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: homework, decoration: _inputDecoration("الواجب", Icons.edit_note, isDarkMode)),
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
                          DropdownButtonFormField<String>(
                            value: rating,
                            dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            decoration: _inputDecoration("التقييم", Icons.grade, isDarkMode),
                            items: ["ممتاز", "جيد", "سيء"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                            onChanged: (v) => setState(() => rating = v!),
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
                        backgroundColor: absent ? Colors.orange : (isDarkMode ? Colors.orange : primaryColor),
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