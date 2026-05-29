import 'dart:ui'; // 🎯 لتأثير الزجاج (Blur)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // 🎯 لقراءة المظهر
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final firestore = FirebaseFirestore.instance;

  final searchController = TextEditingController();

  final nameController = TextEditingController();
  final fatherController = TextEditingController();
  final motherController = TextEditingController();
  final ageController = TextEditingController();
  final addressController = TextEditingController();
  final fatherJobController = TextEditingController();
  final phoneController = TextEditingController();

  final supervisorEmail = TextEditingController();
  final supervisorPassword = TextEditingController();

  DateTime? birthDate;
  String searchText = '';

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // لون الانعكاس الزجاجي

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<String> generateStudentNumber() async {
    final settingsRef = firestore.collection('settings').doc('student_counter');
    final settingsDoc = await settingsRef.get();

    int current = 20260101;
    if (settingsDoc.exists) {
      current = settingsDoc['current'];
    }

    await settingsRef.set({
      'current': current + 1,
    });

    return current.toString();
  }

  Future<void> addSupervisor() async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: supervisorEmail.text.trim(),
        password: supervisorPassword.text.trim(),
      );

      await firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'role': 'supervisor',
        'email': supervisorEmail.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("تم إضافة المشرف بنجاح 🎉")),
      );

      supervisorEmail.clear();
      supervisorPassword.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("خطأ: $e")),
      );
    }
  }

  Future<void> addStudent() async {
    try {
      final studentNumber = await generateStudentNumber();

      await firestore.collection('students').add({
        'student_number': studentNumber,
        'name': nameController.text,
        'father_name': fatherController.text,
        'mother_name': motherController.text,
        'age': ageController.text,
        'address': addressController.text,
        'father_job': fatherJobController.text,
        'phone': phoneController.text,
        'birth_date': birthDate.toString(),
        'supervisor_id': '',
        'created_at': DateTime.now().toString(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("تم إضافة الطالب بنجاح 🎓")),
      );

      nameController.clear();
      fatherController.clear();
      motherController.clear();
      ageController.clear();
      addressController.clear();
      fatherJobController.clear();
      phoneController.clear();

      setState(() {
        birthDate = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("خطأ: $e")),
      );
    }
  }

  Future<void> deleteStudent(String id) async {
    await firestore.collection('students').doc(id).delete();
  }

  Future<void> editStudent(String id, Map<String, dynamic> data, bool isDarkMode) async {
    nameController.text = data['name'];
    fatherController.text = data['father_name'];
    motherController.text = data['mother_name'];
    ageController.text = data['age'];
    addressController.text = data['address'];
    fatherJobController.text = data['father_job'];
    phoneController.text = data['phone'];

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("تعديل بيانات الطالب", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildField("الاسم", nameController, Icons.person, isDarkMode),
                buildField("اسم الأب", fatherController, Icons.man, isDarkMode),
                buildField("اسم الأم", motherController, Icons.woman, isDarkMode),
                buildField("العمر", ageController, Icons.cake, isDarkMode),
                buildField("السكن", addressController, Icons.location_on, isDarkMode),
                buildField("عمل الأب", fatherJobController, Icons.work, isDarkMode),
                buildField("الهاتف", phoneController, Icons.phone, isDarkMode),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? accentGold : primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await firestore.collection('students').doc(id).update({
                  'name': nameController.text,
                  'father_name': fatherController.text,
                  'mother_name': motherController.text,
                  'age': ageController.text,
                  'address': addressController.text,
                  'father_job': fatherJobController.text,
                  'phone': phoneController.text,
                });
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("تم التعديل بنجاح")));
              },
              child: const Text("حفظ التعديلات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 🧊 أداة الحقول المحدثة بستايل الزجاج
  Widget buildField(String title, TextEditingController controller, IconData icon, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: title,
          labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
          prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
          filled: true,
          fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
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
        ),
      ),
    );
  }

  // 🧊 أداة الحاوية الزجاجية (Glassmorphism)
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = const EdgeInsets.all(20)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // قراءة حالة المظهر
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية وراء AppBar
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف
        title: Text("لوحة المدير 👑", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            tooltip: "تسجيل الخروج",
          ),
        ],
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية الانسيابية مع الدوائر العائمة (Blobs)
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
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 200,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          // 🏢 2. المحتوى الأساسي
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🧊 قسم: إضافة مشرف
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings, color: isDarkMode ? accentGold : primaryColor, size: 28),
                            const SizedBox(width: 10),
                            Text("إضافة مشرف جديد", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        buildField("البريد الإلكتروني للمشرف", supervisorEmail, Icons.email_outlined, isDarkMode),
                        buildField("كلمة المرور", supervisorPassword, Icons.lock_outline, isDarkMode),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: addSupervisor,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 5,
                            ),
                            child: const Text("إضافة مشرف", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🧊 قسم: إضافة طالب سريع
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_add_alt_1, color: isDarkMode ? accentGold : primaryColor, size: 28),
                            const SizedBox(width: 10),
                            Text("إضافة طالب جديد", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        buildField("اسم الطالب الكامل", nameController, Icons.person, isDarkMode),
                        buildField("اسم الأب", fatherController, Icons.man, isDarkMode),
                        buildField("اسم الأم", motherController, Icons.woman, isDarkMode),
                        
                        Row(
                          children: [
                            Expanded(child: buildField("العمر", ageController, Icons.cake, isDarkMode)),
                            const SizedBox(width: 10),
                            Expanded(child: buildField("رقم الهاتف", phoneController, Icons.phone, isDarkMode)),
                          ],
                        ),
                        
                        buildField("مكان السكن", addressController, Icons.location_on, isDarkMode),
                        buildField("عمل الأب", fatherJobController, Icons.work, isDarkMode),

                        // زر اختيار التاريخ
                        InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              firstDate: DateTime(1990),
                              lastDate: DateTime.now(),
                              initialDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: isDarkMode ? accentGold : primaryColor,
                                      onPrimary: Colors.white,
                                      surface: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                      onSurface: isDarkMode ? Colors.white : Colors.black,
                                    ),
                                    dialogBackgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (pickedDate != null) {
                              setState(() => birthDate = pickedDate);
                            }
                          },
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                              border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: isDarkMode ? accentGold : primaryColor, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  birthDate == null ? "اختر تاريخ الميلاد" : birthDate.toString().split(' ')[0],
                                  style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 25),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: addStudent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 5,
                            ),
                            child: const Text("حفظ بيانات الطالب", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🧊 قسم: البحث وقائمة الطلاب
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.group, color: isDarkMode ? accentGold : primaryColor, size: 28),
                            const SizedBox(width: 10),
                            Text("قائمة الطلاب", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // حقل البحث
                        TextField(
                          controller: searchController,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: "البحث عن طالب...",
                            labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
                            prefixIcon: Icon(Icons.search, color: isDarkMode ? accentGold : primaryColor, size: 22),
                            filled: true,
                            fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDarkMode ? accentGold : primaryColor, width: 1.5)),
                          ),
                          onChanged: (value) {
                            setState(() {
                              searchText = value.toLowerCase();
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // قائمة الطلاب
                        StreamBuilder(
                          stream: firestore.collection('students').orderBy('student_number').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final students = snapshot.data!.docs.where((student) {
                              final name = student['name'].toString().toLowerCase();
                              return name.contains(searchText);
                            }).toList();

                            if (students.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text("لا يوجد طلاب مسجلين", style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54)),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final student = students[index];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                                    title: Text(student['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontSize: 16)),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _infoRow(Icons.tag, "الرقم: ${student['student_number']}", isDarkMode),
                                          const SizedBox(height: 4),
                                          _infoRow(Icons.phone, "الهاتف: ${student['phone']}", isDarkMode),
                                          const SizedBox(height: 4),
                                          _infoRow(Icons.cake, "العمر: ${student['age']}", isDarkMode),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () => editStudent(student.id, student.data(), isDarkMode),
                                          icon: CircleAvatar(
                                            backgroundColor: Colors.orange.withOpacity(0.15),
                                            radius: 16,
                                            child: const Icon(Icons.edit, color: Colors.orange, size: 16),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => deleteStudent(student.id),
                                          icon: CircleAvatar(
                                            backgroundColor: Colors.red.withOpacity(0.15),
                                            radius: 16,
                                            child: const Icon(Icons.delete, color: Colors.red, size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
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

  // 🧊 أداة صغيرة لترتيب النصوص بجانب أيقونات في قائمة الطلاب
  Widget _infoRow(IconData icon, String text, bool isDarkMode) {
    return Row(
      children: [
        Icon(icon, size: 14, color: isDarkMode ? Colors.white54 : Colors.black45),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87)),
      ],
    );
  }
}