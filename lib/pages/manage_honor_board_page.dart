import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; 
import '../services/theme_provider.dart'; 
import '../services/notification_service.dart'; // 🚀 استيراد خدمة الإشعارات

class ManageHonorBoardPage extends StatefulWidget {
  const ManageHonorBoardPage({super.key});

  @override
  State<ManageHonorBoardPage> createState() => _ManageHonorBoardPageState();
}

class _ManageHonorBoardPageState extends State<ManageHonorBoardPage> {
  String selectedCategory = "new_students"; 
  String currentStudentType = "new"; 
  
  List<Map<String, dynamic>> knightsList = [];
  
  bool isSaving = false;
  bool isClearing = false; // 🚀 حالة تحميل لزر الحذف

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); 

  void loadCategoryData(String categoryId) async {
    var doc = await FirebaseFirestore.instance.collection('honor_board').doc(categoryId).get();
    if (doc.exists && doc.data()!.containsKey('knights')) {
      var data = doc.data()!;
      setState(() {
        knightsList = List<Map<String, dynamic>>.from(data['knights']);
        // ضمان ألا يتجاوز العدد المخزن سابقاً 8 نجوم
        if (knightsList.length > 8) {
          knightsList = knightsList.sublist(0, 8);
        }
      });
    } else if (doc.exists && doc.data()!.containsKey('first')) {
      var data = doc.data()!;
      setState(() {
        knightsList = [
          if (data['first'] != null) Map<String, dynamic>.from(data['first']),
          if (data['second'] != null) Map<String, dynamic>.from(data['second']),
          if (data['third'] != null) Map<String, dynamic>.from(data['third']),
        ];
      });
    } else {
      setState(() {
        knightsList = [
          {'name': 'لم يحدد', 'serial': '---'} 
        ];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadCategoryData(selectedCategory);
  }

  // 🚀 دالة الحفظ مع البث الفوري للإشعارات لجميع الأهالي
  void saveHonorBoard() async {
    setState(() => isSaving = true);
    
    try {
      // 1. حفظ القائمة في Firestore
      await FirebaseFirestore.instance.collection('honor_board').doc(selectedCategory).set({
        'knights': knightsList.isEmpty ? [{'name': 'لم يحدد', 'serial': '---'}] : knightsList,
      });

      // 2. تحديد اسم الفئة بالإشعار
      String categoryName = "الطلاب الجدد";
      if (selectedCategory == "old_students") categoryName = "الطلاب القدماء";
      if (selectedCategory == "completed_students") categoryName = "الطلاب الخاتمين";

      // 3. 📣 جلب جميع الطلاب النشطين وإرسال إشعار لأولياء أمورهم
      var studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('archived', isEqualTo: false)
          .get();

      for (var studentDoc in studentsSnapshot.docs) {
        NotificationService.sendAndSaveNotification(
          studentId: studentDoc.id,
          title: "🏆 إعلان فرسان ولوحة الشرف!",
          body: "تم تحديث نجوم فرسان الحلقة لفئة ($categoryName). افتح التطبيق لمشاهدة المتميزين! 🌟",
          type: "honor_board_update",
          context: context,
        ).catchError((_) {});
      }

      setState(() => isSaving = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "تم تحديث لوحة الشرف وإرسال الإشعارات لجميع الأهالي بنجاح! 🏆🚀",
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
        ),
      );
    } catch (e) {
      setState(() => isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("حدث خطأ أثناء الحفظ: $e", style: const TextStyle(fontFamily: 'Cairo')),
        ),
      );
    }
  }

  // 🚀 دالة تصفير اللوحة وحذف النجوم مع رسالة تأكيد
  void clearHonorBoard(bool isDarkMode) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text("تصفير اللوحة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: isDarkMode ? Colors.white : Colors.black87)),
          ],
        ),
        content: Text("هل أنت متأكد أنك تريد حذف جميع النجوم من هذه الفئة وتصفير اللوحة بالكامل؟", style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("نعم، احذف", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isClearing = true);

    await FirebaseFirestore.instance.collection('honor_board').doc(selectedCategory).set({
      'knights': [],
    });

    setState(() {
      knightsList = [{'name': 'لم يحدد', 'serial': '---'}];
      isClearing = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.redAccent, content: Text("تم تصفير اللوحة وحذف النجوم بنجاح! 🗑️", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
    );
  }

  String? _getMatchedValue(Map<String, dynamic> currentValue, List<Map<String, dynamic>> students) {
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
      extendBodyBehindAppBar: true, 
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, 
        title: Text("تعديل نجوم لوحة الشرف", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -20, left: -40,
            child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12))),
          ),
          Positioned(
            bottom: 80, right: -60,
            child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2))),
          ),

          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
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
                      // كرت اختيار الفئة
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
                      
                      const SizedBox(height: 20),

                      // كرت اختيار الفرسان والنجوم
                      _buildGlassContainer(
                        isDarkMode: isDarkMode,
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            // 🌟 عداد الفرسان الحاليين والحد الأقصى
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "النجوم المحددة: (${knightsList.length}/8)",
                                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: isDarkMode ? accentGold : primaryColor),
                                ),
                                if (knightsList.length >= 8)
                                  const Text(
                                    "وصلت للحد الأقصى ✋",
                                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orangeAccent),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 15),

                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: knightsList.length,
                              itemBuilder: (context, idx) {
                                return Column(
                                  children: [
                                    if (idx > 0) const SizedBox(height: 20),
                                    _buildStudentDropdown(
                                      "النجم رقم #${idx + 1}", 
                                      knightsList[idx], 
                                      allStudents, 
                                      (val) => setState(() => knightsList[idx] = val), 
                                      isDarkMode, 
                                      idx == 0 ? accentGold : (idx == 1 ? const Color(0xffC0C0C0) : (idx == 2 ? const Color(0xffCD7F32) : primaryColor.withOpacity(0.7)))
                                    ),
                                    if (idx < knightsList.length - 1) ...[
                                      const SizedBox(height: 20),
                                      Divider(color: isDarkMode ? Colors.white10 : Colors.black12, height: 1),
                                    ]
                                  ],
                                );
                              },
                            ),
                            
                            const SizedBox(height: 25),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // ➕ زر إضافة نجم (مقيّد بـ 8)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    backgroundColor: knightsList.length < 8 ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                                  ),
                                  onPressed: knightsList.length < 8
                                      ? () {
                                          setState(() {
                                            knightsList.add({'name': 'لم يحدد', 'serial': '---'});
                                          });
                                        }
                                      : () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("الحد الأقصى للوحة الشرف هو 8 نجوم فقط ⭐️", style: TextStyle(fontFamily: 'Cairo')),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                  icon: Icon(Icons.add_circle_outline_rounded, color: knightsList.length < 8 ? Colors.green : Colors.grey),
                                  label: Text(
                                    "إضافة نجم ➕",
                                    style: TextStyle(
                                      color: knightsList.length < 8 ? Colors.green : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                                // ➖ زر حذف الأخير
                                if (knightsList.length > 1)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.15)),
                                    onPressed: () {
                                      setState(() {
                                        knightsList.removeLast();
                                      });
                                    },
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                                    label: const Text("حذف الأخير ➖", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 35),
                      
                      // 🚀 زر الحفظ الإيجابي مع الإشعارات
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9), 
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: isSaving ? null : saveHonorBoard,
                          child: isSaving 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
                              : const Text("حفظ اللوحة وبث الإشعار للأهالي 🚀", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo', letterSpacing: 0.5)),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // 🚀 زر تصفير اللوحة
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            backgroundColor: Colors.redAccent.withOpacity(0.05),
                          ),
                          onPressed: isClearing ? null : () => clearHonorBoard(isDarkMode),
                          icon: isClearing 
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2)) 
                              : const Icon(Icons.delete_sweep_rounded),
                          label: const Text("تصفير اللوحة وحذف النجوم", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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

  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.75), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }

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

  Widget _buildStudentDropdown(String label, Map<String, dynamic> currentValue, List<Map<String, dynamic>> students, Function(Map<String, dynamic>) onSelected, bool isDarkMode, Color medalColor) {
    String? matchedValue = _getMatchedValue(currentValue, students);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: medalColor, size: 22),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDarkMode ? Colors.white.withOpacity(0.9) : primaryColor, fontFamily: 'Cairo')),
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
              borderSide: BorderSide(color: medalColor, width: 1.5), 
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