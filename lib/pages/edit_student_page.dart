import 'dart:io';
import 'dart:convert'; 
import 'dart:ui'; // 🎯 ضرورية لتأثير الزجاج (Blur)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; 
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
  final Color accentGold = const Color(0xffd4af37); // لون الإنعكاس الزجاجي
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

  // 🔥 دالة الرفع المباشر المدمجة ببيانات السيرفر الخاص بك dqsrrej2b
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
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف بالكامل
        title: Text('تعديل بيانات الطالب', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
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
            top: -20,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          // 🏢 2. المحتوى الأساسي للواجهة
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  // 🧊 3. قسم الصورة الشخصية والهيدر الزجاجي
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1), blurRadius: 15, offset: const Offset(0, 5)),
                                ]
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                backgroundImage: _newSelectedImage != null 
                                    ? FileImage(_newSelectedImage!) 
                                    : (currentImageUrl != null && currentImageUrl!.isNotEmpty 
                                        ? NetworkImage(currentImageUrl!) as ImageProvider
                                        : null),
                                child: (_newSelectedImage == null && (currentImageUrl == null || currentImageUrl!.isEmpty))
                                    ? Icon(Icons.person, size: 55, color: isDarkMode ? Colors.white54 : Colors.grey[400])
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                backgroundColor: isDarkMode ? accentGold : primaryColor,
                                radius: 16,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                  onPressed: _pickImage,
                                  tooltip: "تغيير صورة الطالب",
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          nameController.text.isEmpty ? "اسم الطالب" : nameController.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "الرقم التسلسلي: ${serialController.text}",
                          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🧊 4. قسم البيانات الأساسية الزجاجي
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nameController,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          decoration: _glassInputDecoration("اسم الطالب الكامل", Icons.badge_outlined, isDarkMode),
                        ),
                        const SizedBox(height: 15),

                        TextField(
                          controller: serialController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          decoration: _glassInputDecoration("الرقم التسلسلي", Icons.format_list_numbered_rtl, isDarkMode),
                        ),
                        const SizedBox(height: 15),

                        TextField(
                          controller: fatherNameController,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          decoration: _glassInputDecoration("اسم الأب", Icons.person_outline, isDarkMode),
                        ),
                        const SizedBox(height: 15),

                        TextField(
                          controller: motherNameController,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          decoration: _glassInputDecoration("اسم الأم", Icons.woman_outlined, isDarkMode),
                        ),
                        const SizedBox(height: 15),

                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          decoration: _glassInputDecoration("رقم هاتف ولي الأمر", Icons.phone_android, isDarkMode),
                        ),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          value: studentType,
                          dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          decoration: _glassInputDecoration("فئة الطالب", Icons.category_outlined, isDarkMode),
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
                              hint: Text("اختر المشرف / الحلقة", style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black45)),
                              dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                              decoration: _glassInputDecoration("المشرف المسؤول", Icons.gite_outlined, isDarkMode),
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
                        
                        const SizedBox(height: 35),

                        // 🚀 زر الحفظ الزجاجي الفخم
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : updateStudent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9),
                              foregroundColor: Colors.white,
                              elevation: 5,
                              shadowColor: Colors.black38,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    "حفظ التغييرات",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                          ),
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

  // 🧊 أداة تغليف الأقسام بتأثير الزجاج (Glassmorphism)
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

  // 🧊 أداة حقول الإدخال الزجاجية
  InputDecoration _glassInputDecoration(String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600, fontSize: 13),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
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
}