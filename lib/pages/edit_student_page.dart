import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class EditStudentPage extends StatefulWidget {
  final DocumentSnapshot student;

  const EditStudentPage({
    super.key,
    required this.student,
  });

  @override
  State<EditStudentPage> createState() => _EditStudentPageState();
}

class _EditStudentPageState extends State<EditStudentPage> {
  late TextEditingController nameController;
  late TextEditingController serialController;
  late TextEditingController fatherNameController;
  late TextEditingController motherNameController;
  late TextEditingController phoneController;
  
  String? selectedSupervisorId;
  String? selectedSupervisorName;
  String? studentType;
  String? currentImageUrl; // لتخزين رابط الصورة الحالي القادم من الفايربيز

  File? _newSelectedImage; // لتخزين ملف الصورة الجديد في حال اختار المدير تغييرها
  final ImagePicker _picker = ImagePicker();

  final Color primaryColor = const Color(0xff425c75);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.student.data() as Map<String, dynamic>;
    
    nameController = TextEditingController(text: data['name'] ?? '');
    serialController = TextEditingController(text: (data['serial'] ?? '').toString());
    fatherNameController = TextEditingController(text: data['fatherName'] ?? '');
    motherNameController = TextEditingController(text: data['motherName'] ?? '');
    phoneController = TextEditingController(text: data['phone'] ?? '');
    
    selectedSupervisorId = data['supervisorId'];
    selectedSupervisorName = data['supervisorName'];
    studentType = data['studentType'] ?? 'new';
    currentImageUrl = data['imageUrl']; // قراءة رابط الصورة الحالي

    nameController.addListener(() => setState(() {}));
    serialController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    nameController.dispose();
    serialController.dispose();
    fatherNameController.dispose();
    motherNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // دالة اختيار صورة جديدة من المعرض
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        _newSelectedImage = File(pickedFile.path);
      });
    }
  }

  // دالة رفع الصورة الجديدة لـ Firebase Storage
  Future<String> _uploadNewImage(String studentName) async {
    if (_newSelectedImage == null) return currentImageUrl ?? '';
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('students_images')
          .child('student_${studentName}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      final uploadTask = await storageRef.putFile(_newSelectedImage!);
      final String downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("خطأ أثناء رفع الصورة الجديدة: $e");
      return currentImageUrl ?? '';
    }
  }

  Future<void> updateStudent() async {
    if (nameController.text.trim().isEmpty || serialController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text("يرجى ملء الاسم والرقم التسلسلي كحد أدنى")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // رفع الصورة الجديدة أولاً إذا اختار المدير صورة جديدة، وإلا سيبقى الرابط القديم كما هو
      String finalImageUrl = currentImageUrl ?? '';
      if (_newSelectedImage != null) {
        finalImageUrl = await _uploadNewImage(nameController.text.trim());
      }

      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.student.id)
          .update({
        'name': nameController.text.trim(),
        'serial': int.tryParse(serialController.text.trim()) ?? 0,
        'fatherName': fatherNameController.text.trim(),
        'motherName': motherNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'supervisorId': selectedSupervisorId ?? '',
        'supervisorName': selectedSupervisorName ?? 'غير موزع',
        'studentType': studentType,
        'imageUrl': finalImageUrl, // تحديث حقل الصورة بفايربيز
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث بيانات الطالب بنجاح")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("خطأ أثناء التحديث: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
        title: const Text('تعديل بيانات الطالب', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // قسم المعاينة العلوية الفخم مع دعم عرض صورة الطالب الحالية أو الجديدة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        // تدرج العرض: إذا تم اختيار صورة جديدة محلياً يعرضها، وإذا كان لديه صورة قديمة بفايربيز يعرضها، وإلا يعرض الأيقونة الافتراضية
                        backgroundImage: _newSelectedImage != null 
                            ? FileImage(_newSelectedImage!) 
                            : (currentImageUrl != null && currentImageUrl!.isNotEmpty 
                                ? NetworkImage(currentImageUrl!) as ImageProvider
                                : null),
                        child: (_newSelectedImage == null && (currentImageUrl == null || currentImageUrl!.isEmpty))
                            ? const Icon(Icons.person, size: 50, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: isDarkMode ? Colors.orange : Colors.white,
                          radius: 16,
                          child: IconButton(
                            icon: Icon(Icons.camera_alt, size: 14, color: isDarkMode ? Colors.white : primaryColor),
                            onPressed: _pickImage,
                            tooltip: "تغيير صورة الطالب",
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    nameController.text.isEmpty ? "اسم الطالب" : nameController.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "الرقم التسلسلي: ${serialController.text}",
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05), 
                      blurRadius: 10, 
                      offset: const Offset(0, 5)
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // حقل الاسم
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: _inputDecoration("اسم الطالب الكامل", Icons.badge_outlined, isDarkMode),
                    ),
                    const SizedBox(height: 15),

                    // حقل الرقم التسلسلي
                    TextField(
                      controller: serialController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: _inputDecoration("الرقم التسلسلي", Icons.format_list_numbered_rtl, isDarkMode),
                    ),
                    const SizedBox(height: 15),

                    // حقل اسم الأب
                    TextField(
                      controller: fatherNameController,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: _inputDecoration("اسم الأب", Icons.person_outline, isDarkMode),
                    ),
                    const SizedBox(height: 15),

                    // حقل اسم الأم
                    TextField(
                      controller: motherNameController,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: _inputDecoration("اسم الأم", Icons.woman_outlined, isDarkMode),
                    ),
                    const SizedBox(height: 15),

                    // حقل رقم الهاتف
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: _inputDecoration("رقم هاتف ولي الأمر", Icons.phone_android, isDarkMode),
                    ),
                    const SizedBox(height: 15),

                    // فئة الطالب
                    DropdownButtonFormField<String>(
                      value: studentType,
                      dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: _inputDecoration("فئة الطالب", Icons.category_outlined, isDarkMode),
                      items: const [
                        DropdownMenuItem(value: "new", child: Text("طالب جديد")),
                        DropdownMenuItem(value: "old", child: Text("طالب قديم")),
                        DropdownMenuItem(value: "completed", child: Text("طالب خاتم")),
                      ],
                      onChanged: (v) => setState(() => studentType = v),
                    ),
                    const SizedBox(height: 15),

                    // قائمة المشرفين
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('supervisors').snapshots(),
                      builder: (context, snapshot) {
                        List<DropdownMenuItem<String>> supervisorItems = [];
                        
                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            var sData = doc.data() as Map<String, dynamic>;
                            supervisorItems.add(DropdownMenuItem(
                              value: doc.id,
                              child: Text(sData['name'] ?? ''),
                            ));
                          }
                        }

                        String? currentSelection = selectedSupervisorId;
                        if (currentSelection != null && !supervisorItems.any((item) => item.value == currentSelection)) {
                          currentSelection = null;
                        }

                        return DropdownButtonFormField<String>(
                          value: currentSelection,
                          hint: const Text("اختر المشرف / الحلقة"),
                          dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                          decoration: _inputDecoration("المشرف المسؤول", Icons.gite_outlined, isDarkMode),
                          items: supervisorItems,
                          onChanged: (v) {
                            if (v != null && snapshot.hasData) {
                              var chosenDoc = snapshot.data!.docs.firstWhere((doc) => doc.id == v);
                              var chosenData = chosenDoc.data() as Map<String, dynamic>;
                              setState(() {
                                selectedSupervisorId = v;
                                selectedSupervisorName = chosenData['name'];
                              });
                            }
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // زر الحفظ النهائي
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : updateStudent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? Colors.orange : primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "حفظ التغييرات",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
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
      prefixIcon: Icon(icon, color: isDarkMode ? Colors.orange : primaryColor),
      filled: true,
      fillColor: isDarkMode ? const Color(0xff2b2b2b) : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDarkMode ? Colors.transparent : Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDarkMode ? Colors.transparent : Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDarkMode ? Colors.orange : primaryColor, width: 2),
      ),
    );
  }
}