import 'dart:ui'; // 🎯 ضرورية لتأثير الزجاج والـ Blur
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // 🎯 لقراءة المظهر
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider

class ManageHonorBoardPage extends StatefulWidget {
  const ManageHonorBoardPage({super.key});

  @override
  State<ManageHonorBoardPage> createState() => _ManageHonorBoardPageState();
}

class _ManageHonorBoardPageState extends State<ManageHonorBoardPage> {
  String selectedCategory = "new_students"; 
  String currentStudentType = "new"; 
  
  Map<String, dynamic>? firstStudent;
  Map<String, dynamic>? secondStudent;
  Map<String, dynamic>? thirdStudent;
  
  bool isSaving = false;
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // لون الزجاج المكمل

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
      const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث الفرسان بنجاح! 🏆", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
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
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف
        title: Text("تعديل فرسان لوحة الشرف", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية المتدرجة الانسيابية مع الدوائر العائمة
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
            left: -40,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          // 🏢 2. المحتوى الأساسي للواجهة
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
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
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      // 🧊 3. كرت اختيار الفئة الزجاجي
                      _buildGlassContainer(
                        isDarkMode: isDarkMode,
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.category_outlined, color: isDarkMode ? accentGold : primaryColor),
                                const SizedBox(width: 10),
                                Text("اختر الفئة المراد تعديلها:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                              ],
                            ),
                            const SizedBox(height: 15),
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                              decoration: _glassInputDecoration(isDarkMode),
                              items: const [
                                DropdownMenuItem(value: "new_students", child: Text("الطلاب الجدد")),
                                DropdownMenuItem(value: "old_students", child: Text("الطلاب القدماء")),
                                DropdownMenuItem(value: "completed_students", child: Text("الطلاب الخاتمين")),
                              ],
                              onChanged: (v) {
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
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 25),

                      // 🧊 4. كرت اختيار الفرسان الثلاثة الزجاجي
                      _buildGlassContainer(
                        isDarkMode: isDarkMode,
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            _buildStudentDropdown("المركز الأول", "🥇", firstStudent, allStudents, (val) => setState(() => firstStudent = val), isDarkMode, accentGold),
                            const SizedBox(height: 20),
                            Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 1),
                            const SizedBox(height: 20),
                            _buildStudentDropdown("المركز الثاني", "🥈", secondStudent, allStudents, (val) => setState(() => secondStudent = val), isDarkMode, const Color(0xffC0C0C0)),
                            const SizedBox(height: 20),
                            Divider(color: isDarkMode ? Colors.white24 : Colors.black12, height: 1),
                            const SizedBox(height: 20),
                            _buildStudentDropdown("المركز الثالث", "🥉", thirdStudent, allStudents, (val) => setState(() => thirdStudent = val), isDarkMode, const Color(0xffCD7F32)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 35),
                      
                      // 🚀 زر الحفظ الزجاجي
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9), 
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: Colors.black38,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: isSaving ? null : saveHonorBoard,
                          child: isSaving 
                              ? const CircularProgressIndicator(color: Colors.white) 
                              : const Text("حفظ الفرسان الآن", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', letterSpacing: 0.5)),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🧊 أداة مساعدة لتغليف العناصر بتأثير الزجاج (Glassmorphism)
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
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

  // 🧊 تنسيق حقول اختيار الفئات الزجاجية
  InputDecoration _glassInputDecoration(bool isDarkMode) {
    return InputDecoration(
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

  // 🧊 واجهة اختيار الفرسان الأنيقة 
  Widget _buildStudentDropdown(String label, String emoji, Map<String, dynamic>? currentValue, List<Map<String, dynamic>> students, Function(Map<String, dynamic>) onSelected, bool isDarkMode, Color medalColor) {
    String? matchedValue = _getMatchedValue(currentValue, students);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: medalColor, fontFamily: 'Cairo')),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: matchedValue,
          hint: Text("اختر طالب من القائمة", style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black45, fontSize: 13, fontFamily: 'Cairo')),
          dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          decoration: _glassInputDecoration(isDarkMode).copyWith(
            prefixIcon: Icon(Icons.person_outline, color: medalColor),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15), 
              borderSide: BorderSide(color: medalColor, width: 1.5), // تغيير لون التحديد حسب الميدالية
            ),
          ),
          items: students.map((s) {
            return DropdownMenuItem<String>(
              value: s['name'],
              child: Text("${s['name']} (${s['serial']})"),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              var selectedMap = students.firstWhere((s) => s['name'] == v);
              onSelected(selectedMap);
            }
          },
        ),
      ],
    );
  }
}