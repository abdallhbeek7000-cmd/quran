import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageHonorBoardPage extends StatefulWidget {
  const ManageHonorBoardPage({super.key});

  @override
  State<ManageHonorBoardPage> createState() => _ManageHonorBoardPageState();
}

class _ManageHonorBoardPageState extends State<ManageHonorBoardPage> {
  String selectedCategory = "new_students"; // المعرف المستخدم لكولكشن لوحة الشرف
  String currentStudentType = "new"; // القيمة المقابلة لفلترة الطلاب بفايربيز (new, old, completed)
  
  Map<String, dynamic>? firstStudent;
  Map<String, dynamic>? secondStudent;
  Map<String, dynamic>? thirdStudent;
  
  bool isSaving = false;
  final Color primaryColor = const Color(0xff425c75);

  void loadCategoryData(String categoryId) async {
    var doc = await FirebaseFirestore.instance.collection('honor_board').doc(categoryId).get();
    if (doc.exists) {
      var data = doc.data()!;
      setState(() {
        firstStudent = data['first'];
        secondStudent = data['second'];
        thirdStudent = data['third'];
      });
    } else {
      setState(() {
        firstStudent = null;
        secondStudent = null;
        thirdStudent = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadCategoryData(selectedCategory);
  }

  void saveHonorBoard() async {
    setState(() => isSaving = true);
    
    await FirebaseFirestore.instance.collection('honor_board').doc(selectedCategory).set({
      'first': firstStudent ?? {'name': 'لم يحدد', 'serial': '---'},
      'second': secondStudent ?? {'name': 'لم يحدد', 'serial': '---'},
      'third': thirdStudent ?? {'name': 'لم يحدد', 'serial': '---'},
    });

    setState(() => isSaving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث الفرسان بنجاح!")),
    );
  }

  String? _getMatchedValue(Map<String, dynamic>? currentValue, List<Map<String, dynamic>> students) {
    if (currentValue == null) return null;
    for (var s in students) {
      if (s['name'] == currentValue['name'] && s['serial'] == currentValue['serial']) {
        return s['name'];
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تعديل فرسان لوحة الشرف", style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // الفلترة الذكية هنا: جلب الطلاب بناءً على الـ currentStudentType المختار فقط!
        stream: FirebaseFirestore.instance
            .collection('students')
            .where('archived', isEqualTo: false)
            .where('studentType', isEqualTo: currentStudentType)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          List<Map<String, dynamic>> allStudents = [];
          for (var doc in snapshot.data!.docs) {
            var d = doc.data() as Map<String, dynamic>;
            allStudents.add({
              'name': d['name']?.toString() ?? '',
              'serial': d['serial']?.toString() ?? '',
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("اختر الفئة المراد تعديلها:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    filled: true, 
                    fillColor: Colors.white, 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  items: const [
                    DropdownMenuItem(value: "new_students", child: Text("الطلاب الجدد")),
                    DropdownMenuItem(value: "old_students", child: Text("الطلاب القدماء")),
                    DropdownMenuItem(value: "completed_students", child: Text("الطلاب الخاتمين")),
                  ],
                  onChanged: (v) {
                    // تحديث فلتر الداتابيز بالتزامن مع تغيير القائمة
                    String type = "new";
                    if (v == "old_students") type = "old";
                    if (v == "completed_students") type = "completed";

                    setState(() {
                      selectedCategory = v!;
                      currentStudentType = type;
                    });
                    loadCategoryData(v!);
                  },
                ),
                const Divider(height: 40),
                
                _buildStudentDropdown("المركز الأول 🥇", firstStudent, allStudents, (val) => setState(() => firstStudent = val)),
                const SizedBox(height: 20),
                _buildStudentDropdown("المركز الثاني 🥈", secondStudent, allStudents, (val) => setState(() => secondStudent = val)),
                const SizedBox(height: 20),
                _buildStudentDropdown("المركز الثالث 🥉", thirdStudent, allStudents, (val) => setState(() => thirdStudent = val)),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: isSaving ? null : saveHonorBoard,
                    child: isSaving 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("حفظ الفرسان الحين", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudentDropdown(String label, Map<String, dynamic>? currentValue, List<Map<String, dynamic>> students, Function(Map<String, dynamic>) onSelected) {
    String? matchedValue = _getMatchedValue(currentValue, students);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: matchedValue,
          hint: const Text("اختر طالب من القائمة"),
          decoration: InputDecoration(
            filled: true, 
            fillColor: Colors.white, 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: students.map((s) {
            return DropdownMenuItem<String>(
              value: s['name'],
              child: Text("${s['name']} (${s['serial']})"),
            );
          }).toList(),
          onChanged: (v) {
            var selectedMap = students.firstWhere((s) => s['name'] == v);
            onSelected(selectedMap);
          },
        ),
      ],
    );
  }
}