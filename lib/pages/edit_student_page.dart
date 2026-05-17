import 'dart:io';
import 'dart:convert'; // استيراد مكتبة تحويل البيانات لمعالجة رد السيرفر
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // استبدال الفايربيز ستورج بـ http للرفع المباشر
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
  String? currentImageUrl; 

  File? _newSelectedImage; 
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
    currentImageUrl = data['imageUrl']; 

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

  // 🔥 دالة الرفع المباشر الجديدة المدمجة ببيانات السيرفر الخاص بك dqsrrej2b
  Future<String> _uploadNewImageToCloudinary() async {
    if (_newSelectedImage == null) return currentImageUrl ?? '';
    try {
      var url = Uri.parse('https://api.cloudinary.com/v1_1/dqsrrej2b/image/upload');
      
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'rhjrrtqz'
        ..files.add(await http.MultipartFile.fromPath('file', _newSelectedImage!.path));

      var response = await request.send();
      
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        var jsonMap = jsonDecode(responseString);
        
        return jsonMap['secure_url'] ?? currentImageUrl ?? '';
      } else {
        debugPrint("فشل الرفع إلى سيرفر الصور. كود الخطأ: ${response.statusCode}");
        return currentImageUrl ?? '';
      }
    } catch (e) {
      debugPrint("خطأ أثناء رفع الصورة الجديدة إلى Cloudinary: $e");
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
      // رفع الصورة الجديدة إلى Cloudinary إذا تم اختيارها، وإلا الحفاظ على الرابط القديم
      String finalImageUrl = currentImageUrl ?? '';
      if (_newSelectedImage != null) {
        finalImageUrl = await _uploadNewImageToCloudinary();
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
        'imageUrl': finalImageUrl, 
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
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: _inputDecoration("اسم الطالب الكامل", Icons.badge_outlined, isDarkMode),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: serialController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: _inputDecoration("الرقم التسلسلي", Icons.format_list_numbered_rtl, isDarkMode),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: fatherNameController,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: _inputDecoration("اسم الأب", Icons.person_outline, isDarkMode),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: motherNameController,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: _inputDecoration("اسم الأم", Icons.woman_outlined, isDarkMode),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: _inputDecoration("رقم هاتف ولي الأمر", Icons.phone_android, isDarkMode),
                    ),
                    const SizedBox(height: 15),

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