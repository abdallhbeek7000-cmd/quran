import 'dart:io';
import 'dart:convert'; 
import 'dart:ui'; // 🎯 ضرورية جداً لتأثير الزجاج
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; 
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../services/theme_provider.dart';
import '../models/cycle_model.dart';
import '../models/student_model.dart';
import '../services/student_service.dart';

class AddStudentPage extends StatefulWidget {
  final CycleModel cycle;

  const AddStudentPage({
    super.key,
    required this.cycle,
  });

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final studentService = StudentService();
  final name = TextEditingController();
  final fatherName = TextEditingController();
  final motherName = TextEditingController();
  final phone = TextEditingController();
  final fatherJob = TextEditingController();
  final address = TextEditingController();
  final schoolGrade = TextEditingController();
  final memorizedPages = TextEditingController();

  DateTime? birthDate;
  DateTime? startDate;
  bool loading = false;
  String studentType = "new";
  
  // 🎯 المتغيرات الخاصة بالجنسية
  String selectedNationality = "سوري";
  final List<Map<String, dynamic>> nationalities = [
    {'name': 'سوري', 'flag': 'custom'}, 
    {'name': 'فلسطيني', 'flag': '🇵🇸'},
    {'name': 'أردني', 'flag': '🇯🇴'},
    {'name': 'لبناني', 'flag': '🇱🇧'},
    {'name': 'عراقي', 'flag': '🇮🇶'},
    {'name': 'مصري', 'flag': '🇪🇬'},
    {'name': 'سعودي', 'flag': '🇸🇦'},
    {'name': 'يمني', 'flag': '🇾🇪'},
    {'name': 'سوداني', 'flag': '🇸🇩'},
    {'name': 'تركي', 'flag': '🇹🇷'},
    {'name': 'جنسية أخرى', 'flag': '🌍'},
  ];

  File? _selectedImage; 
  XFile? _pickerFile; 
  final ImagePicker _picker = ImagePicker();

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // 🎯 لون الزجاج المكمل

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, 
    );
    if (pickedFile != null) {
      setState(() {
        _pickerFile = pickedFile; 
        _selectedImage = File(pickedFile.path); 
      });
    }
  }

  Future<String> _uploadStudentImageToCloudinary() async {
    if (_pickerFile == null) return '';
    try {
      var url = Uri.parse('https://api.cloudinary.com/v1_1/dqsrrej2b/image/upload');
      final bytes = await _pickerFile!.readAsBytes();
      
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'rhjrrtqz'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: _pickerFile!.name,
        ));

      var response = await request.send();
      
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        var jsonMap = jsonDecode(responseString);
        
        return jsonMap['secure_url'] ?? '';
      } else {
        debugPrint("فشل الرفع إلى سيرفر الصور. كود الخطأ: ${response.statusCode}");
        return '';
      }
    } catch (e) {
      debugPrint("خطأ أثناء رفع الصورة إلى Cloudinary: $e");
      return '';
    }
  }

  addStudent() async {
    if (name.text.isEmpty || phone.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال اسم الطالب ورقم الهاتف على الأقل")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      String serial = '';
      String prefix = "${widget.cycle.year}${widget.cycle.cycleNumber.toString().padLeft(2, '0')}"; 

      var studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('cycleId', isEqualTo: widget.cycle.id)
          .get(const GetOptions(source: Source.server));

      if (studentsSnapshot.docs.isEmpty) {
        serial = "${prefix}01"; 
      } else {
        int maxSerial = 0;
        for (var doc in studentsSnapshot.docs) {
          String currentSerial = doc.data()['serial'] ?? "";
          if (currentSerial.startsWith(prefix)) {
            int parsed = int.tryParse(currentSerial) ?? 0;
            if (parsed > maxSerial) maxSerial = parsed;
          }
        }
        
        if (maxSerial == 0) {
          serial = "${prefix}01";
        } else {
          serial = (maxSerial + 1).toString();
        }
      }

      String finalImageUrl = '';
      if (_pickerFile != null) {
        finalImageUrl = await _uploadStudentImageToCloudinary();
      }

      final student = StudentModel(
        id: '',
        serial: serial, 
        name: name.text.trim(),
        nationality: selectedNationality, 
        fatherName: fatherName.text.trim(),
        motherName: motherName.text.trim(),
        phone: phone.text.trim(),
        fatherJob: fatherJob.text.trim(),
        address: address.text.trim(),
        schoolGrade: schoolGrade.text.trim(),
        birthDate: birthDate?.toString() ?? '',
        studentType: studentType,
        supervisorId: '',
        supervisorName: '',
        cycleId: widget.cycle.id,
        cycleName: widget.cycle.name,
        startMemorization: startDate?.toString() ?? '',
        memorizedPages: double.tryParse(memorizedPages.text) ?? 0,
        imageUrl: finalImageUrl, 
        archived: false,
        createdAt: DateTime.now().toString(),
      );

      await studentService.addStudent(student);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("تمت إضافة الطالب بنجاح")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("خطأ: $e")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // 🎯 برمجة علم الثورة السورية باستخدام Flutter Containers
  Widget _buildSyrianRevolutionFlag() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 26,
        height: 18,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white60, width: 0.5), // تعديل لون الإطار ليناسب الزجاج
        ),
        child: Column(
          children: [
            Expanded(child: Container(color: const Color(0xff007A3D))), 
            Expanded(
              child: Container(
                color: Colors.white,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.star, color: Color(0xffCE1126), size: 5.5),
                    Icon(Icons.star, color: Color(0xffCE1126), size: 5.5),
                    Icon(Icons.star, color: Color(0xffCE1126), size: 5.5),
                  ],
                ),
              )
            ), 
            Expanded(child: Container(color: Colors.black)), 
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية للزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف
        title: Text("إضافة طالب جديد", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية الانسيابية مع الدوائر العائمة
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
            top: 20,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 150,
            right: -80,
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
                  // 🧊 3. قسم الصورة الشخصية (بتأثير زجاجي خفيف خلفها)
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1), blurRadius: 15, offset: const Offset(0, 5)),
                              ]
                            ),
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                              backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                              child: _selectedImage == null
                                  ? Icon(Icons.add_a_photo_outlined, size: 45, color: isDarkMode ? Colors.white54 : Colors.grey[400])
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: isDarkMode ? accentGold : primaryColor,
                              radius: 18,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                onPressed: _pickImage,
                                tooltip: "اختيار صورة للطالب",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🧊 4. الأقسام الزجاجية
                  _buildSectionCard(
                    title: "معلومات التسجيل",
                    icon: Icons.app_registration,
                    isDarkMode: isDarkMode,
                    child: DropdownButtonFormField<String>(
                      value: studentType,
                      dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                      decoration: _glassInputDecoration("نوع الطالب", Icons.category_outlined, isDarkMode),
                      items: const [
                        DropdownMenuItem(value: "new", child: Text("طالب جديد")),
                        DropdownMenuItem(value: "old", child: Text("طالب قديم")),
                        DropdownMenuItem(value: "completed", child: Text("خاتم")),
                      ],
                      onChanged: (v) => setState(() => studentType = v!),
                    ),
                  ),

                  const SizedBox(height: 15),

                  _buildSectionCard(
                    title: "المعلومات الشخصية",
                    icon: Icons.person_outline,
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold), controller: name, decoration: _glassInputDecoration("اسم الطالب الكامل", Icons.person, isDarkMode)),
                        
                        const SizedBox(height: 15),
                        
                        DropdownButtonFormField<String>(
                          value: selectedNationality,
                          dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                          decoration: _glassInputDecoration("الجنسية", Icons.flag_outlined, isDarkMode),
                          items: nationalities.map((nat) {
                            return DropdownMenuItem<String>(
                              value: nat['name'],
                              child: Row(
                                children: [
                                  nat['flag'] == 'custom' 
                                      ? _buildSyrianRevolutionFlag() 
                                      : Text(nat['flag'], style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                  Text(nat['name']),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => selectedNationality = v!),
                        ),

                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: fatherName, decoration: _glassInputDecoration("اسم الأب", Icons.man, isDarkMode))),
                            const SizedBox(width: 10),
                            Expanded(child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: motherName, decoration: _glassInputDecoration("اسم الأم", Icons.woman, isDarkMode))),
                          ],
                        ),
                        const SizedBox(height: 15),
                        TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: phone, keyboardType: TextInputType.phone, decoration: _glassInputDecoration("رقم الهاتف", Icons.phone, isDarkMode)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  _buildSectionCard(
                    title: "تفاصيل إضافية",
                    icon: Icons.info_outline,
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: address, decoration: _glassInputDecoration("مكان السكن", Icons.location_on_outlined, isDarkMode)),
                        const SizedBox(height: 15),
                        TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: schoolGrade, decoration: _glassInputDecoration("الصف الدراسي", Icons.school_outlined, isDarkMode)),
                        const SizedBox(height: 15),
                        TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: fatherJob, decoration: _glassInputDecoration("عمل الأب", Icons.work_outline, isDarkMode)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  _buildSectionCard(
                    title: "التواريخ والحفظ",
                    icon: Icons.history_edu,
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        if (studentType != "new") ...[
                          TextField(
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                            controller: memorizedPages,
                            keyboardType: TextInputType.number,
                            decoration: _glassInputDecoration("عدد الصفحات المحفوظة مسبقاً", Icons.auto_stories_outlined, isDarkMode),
                          ),
                          const SizedBox(height: 15),
                        ],
                        Row(
                          children: [
                            Expanded(child: _buildDatePicker(
                              label: birthDate == null ? "تاريخ الميلاد" : birthDate.toString().split(" ")[0],
                              icon: Icons.cake_outlined,
                              isDarkMode: isDarkMode,
                              onTap: () async {
                                final picked = await _selectDate(context, DateTime(1990), isDarkMode);
                                if (picked != null) setState(() => birthDate = picked);
                              },
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _buildDatePicker(
                              label: startDate == null ? "بدء الحفظ" : startDate.toString().split(" ")[0],
                              icon: Icons.play_arrow_outlined,
                              isDarkMode: isDarkMode,
                              onTap: () async {
                                final picked = await _selectDate(context, DateTime(2010), isDarkMode);
                                if (picked != null) setState(() => startDate = picked);
                              },
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),

                  // 🚀 زر الحفظ الزجاجي الفخم
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: loading ? null : addStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9),
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shadowColor: Colors.black38,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("حفظ بيانات الطالب", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
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

  // 🧊 أداة بطاقة القسم (تستخدم التغليف الزجاجي)
  Widget _buildSectionCard({required String title, required IconData icon, required Widget child, required bool isDarkMode}) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Divider(height: 25, color: isDarkMode ? Colors.white24 : Colors.black12),
          child,
        ],
      ),
    );
  }

  // 🧊 أداة حقول الإدخال الزجاجية
  InputDecoration _glassInputDecoration(String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600),
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
    );
  }

  // 🧊 أداة اختيار التاريخ (بستايل زجاجي)
  Widget _buildDatePicker({required String label, required IconData icon, required bool isDarkMode, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
          border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDarkMode ? accentGold : primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _selectDate(BuildContext context, DateTime initial, bool isDarkMode) async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: initial,
      lastDate: DateTime.now(),
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
  }
}