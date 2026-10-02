import 'dart:io';
import 'dart:convert'; 
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _AddStudentPageState extends State<AddStudentPage> with SingleTickerProviderStateMixin {
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

  final List<String> quickGradeSuggestions = const [
    'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس',
    'السابع', 'الثامن', 'التاسع', 'العاشر', 'الحادي عشر', 'البكالوريا', 'جامعي'
  ];

  File? _selectedImage; 
  XFile? _pickerFile; 
  final ImagePicker _picker = ImagePicker();

  final Color primaryColor = const Color(0xff2d3748);
  final Color accentGold = const Color(0xffd4af37); 
  final Color accentGlow = const Color(0xfff59e0b);

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    name.dispose();
    fatherName.dispose();
    motherName.dispose();
    phone.dispose();
    fatherJob.dispose();
    address.dispose();
    schoolGrade.dispose();
    memorizedPages.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.mediumImpact();
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, 
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
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: _pickerFile!.name));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        var jsonMap = jsonDecode(responseString);
        return jsonMap['secure_url'] ?? '';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  addStudent(String targetCycleId, String targetCycleName) async {
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 10,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: Colors.amber.shade900,
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text("يرجى إدخال اسم الطالب ورقم الهاتف كحد أدنى", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      String serial = '';
      String prefix = "${widget.cycle.year}${widget.cycle.cycleNumber.toString().padLeft(2, '0')}"; 

      var studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('cycleId', isEqualTo: targetCycleId)
          .get(const GetOptions(source: Source.server));

      if (studentsSnapshot.docs.isEmpty) {
        serial = "${prefix}01"; 
      } else {
        int maxSerial = 0;
        for (var doc in studentsSnapshot.docs) {
          String currentSerial = doc.data()['serial']?.toString() ?? "";
          if (currentSerial.startsWith(prefix)) {
            int parsed = int.tryParse(currentSerial) ?? 0;
            if (parsed > maxSerial) maxSerial = parsed;
          }
        }
        serial = maxSerial == 0 ? "${prefix}01" : (maxSerial + 1).toString();
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
        cycleId: targetCycleId,
        cycleName: targetCycleName,
        startMemorization: startDate?.toString() ?? '',
        memorizedPages: double.tryParse(memorizedPages.text) ?? 0,
        imageUrl: finalImageUrl, 
        archived: false,
        createdAt: DateTime.now().toString(),
      );

      await studentService.addStudent(student);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 10,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: Colors.green.shade700,
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text("تمت إضافة الطالب بنجاح ✨", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("خطأ أثناء الإضافة: $e", style: const TextStyle(fontFamily: 'Cairo'))),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _buildSyrianRevolutionFlag() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 26,
        height: 18,
        decoration: BoxDecoration(border: Border.all(color: Colors.white60, width: 0.5)),
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cycles')
          .where('isCurrent', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .snapshots(),
      builder: (context, cycleSnap) {
        if (cycleSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        bool isCycleActive = cycleSnap.hasData && cycleSnap.data!.docs.isNotEmpty;
        final currentCycleDoc = isCycleActive ? cycleSnap.data!.docs.first : null;
        final String activeCycleId = currentCycleDoc?.id ?? widget.cycle.id;
        final String activeCycleName = (currentCycleDoc?.data() as Map<String, dynamic>?)?['name'] ?? widget.cycle.name;

        return Scaffold(
          extendBodyBehindAppBar: true, 
          backgroundColor: isDarkMode ? const Color(0xff0a0f1d) : const Color(0xfff8fafc),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent, 
            title: Text("إضافة طالب جديد", style: TextStyle(fontWeight: FontWeight.w800, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 19)),
            iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
            centerTitle: true,
          ),
          body: Stack(
            children: [
              // 🎨 1. خلفية متدرجة حديثة
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode
                        ? [const Color(0xff0a0f1d), const Color(0xff151f32), const Color(0xff0a0f1d)]
                        : [const Color(0xfff1f5f9), const Color(0xffe2e8f0), const Color(0xffcbd5e1)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              
              // ✨ 2. هالات ضوئية عائمة خلف الكروت
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Positioned(
                        top: -50 + (_glowController.value * 25),
                        right: -50,
                        child: Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentGlow.withOpacity(isDarkMode ? 0.15 : 0.2),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 100 - (_glowController.value * 25),
                        left: -60,
                        child: Container(
                          width: 320,
                          height: 320,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentGold.withOpacity(isDarkMode ? 0.12 : 0.18),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              // 🏢 3. المحتوى الفعلي المنسق بكروت عالية الاحترافية
              SafeArea(
                child: !isCycleActive
                    ? Center(
                        child: _buildCreativeCard(
                          isDarkMode: isDarkMode,
                          padding: const EdgeInsets.all(25),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy_rounded, size: 70, color: Colors.orangeAccent),
                              const SizedBox(height: 15),
                              Text("لا توجد دورة نشطة حالياً 🚫", style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
                              const SizedBox(height: 8),
                              Text("تم إغلاق الدورة، لا يمكنك إضافة طلاب جدد حتى فتح دورة جديدة.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: isDarkMode ? Colors.white60 : Colors.black54)),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        child: Column(
                          children: [
                            // 🌟 1. هيدر اختيار الصورة الملكي (Glow Avatar Header)
                            _buildCreativeCard(
                              isDarkMode: isDarkMode,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                              child: Center(
                                child: Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 125,
                                          height: 125,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: SweepGradient(
                                              colors: [accentGold, accentGlow, Colors.amberAccent, accentGold],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: accentGlow.withOpacity(0.4),
                                                blurRadius: 25,
                                                spreadRadius: 2,
                                              )
                                            ],
                                          ),
                                        ),
                                        CircleAvatar(
                                          radius: 58,
                                          backgroundColor: isDarkMode ? const Color(0xff151f32) : Colors.white,
                                          backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                                          child: _selectedImage == null
                                              ? Icon(Icons.person_add_alt_1_rounded, size: 50, color: isDarkMode ? Colors.white38 : Colors.grey[400])
                                              : null,
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _pickImage,
                                              borderRadius: BorderRadius.circular(30),
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: LinearGradient(colors: [accentGlow, accentGold]),
                                                  border: Border.all(color: Colors.white, width: 2.5),
                                                  boxShadow: [
                                                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)
                                                  ],
                                                ),
                                                child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      name.text.isEmpty ? "اسم الطالب الجديد" : name.text,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: isDarkMode ? Colors.white : primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 📝 2. بطاقة نوع التسجيل
                            _buildSectionHeader(
                              title: "فئة التسجيل",
                              icon: Icons.category_rounded,
                              isDarkMode: isDarkMode,
                              child: DropdownButtonFormField<String>(
                                value: studentType,
                                dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13.5),
                                decoration: _buildInputDecoration("نوع الطالب بالحلقة", Icons.badge_outlined, isDarkMode),
                                items: const [
                                  DropdownMenuItem(value: "new", child: Text("طالب جديد")),
                                  DropdownMenuItem(value: "old", child: Text("طالب قديم")),
                                  DropdownMenuItem(value: "completed", child: Text("طالب خاتم لكتاب الله 👑")),
                                ],
                                onChanged: (v) => setState(() => studentType = v!),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 👤 3. البيانات الشخصية
                            _buildSectionHeader(
                              title: "المعلومات الشخصية",
                              icon: Icons.person_rounded,
                              isDarkMode: isDarkMode,
                              child: Column(
                                children: [
                                  TextField(
                                    controller: name,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    decoration: _buildInputDecoration("اسم الطالب الكامل", Icons.account_circle_outlined, isDarkMode),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 14),

                                  DropdownButtonFormField<String>(
                                    value: selectedNationality,
                                    dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                    decoration: _buildInputDecoration("الجنسية", Icons.flag_outlined, isDarkMode),
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
                                  const SizedBox(height: 14),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: fatherName,
                                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                          decoration: _buildInputDecoration("اسم الأب", Icons.face_rounded, isDarkMode),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: motherName,
                                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                          decoration: _buildInputDecoration("اسم الأم", Icons.face_3_rounded, isDarkMode),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  TextField(
                                    controller: phone,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    decoration: _buildInputDecoration("رقم هاتف ولي الأمر", Icons.phone_android_rounded, isDarkMode),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 🏫 4. قسم الدراسة والصف (schoolGrade) مع الشارات الجذابة
                            _buildSectionHeader(
                              title: "الدراسة والسكن (schoolGrade)",
                              icon: Icons.school_rounded,
                              isDarkMode: isDarkMode,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: schoolGrade,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    decoration: _buildInputDecoration("الصف الدراسي (كتابة حرّة)", Icons.edit_note_rounded, isDarkMode),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 12),

                                  Text("اختيار سريع للصف:", style: TextStyle(fontSize: 11.5, color: isDarkMode ? Colors.white60 : Colors.black54, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),

                                  SizedBox(
                                    height: 42,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: quickGradeSuggestions.length,
                                      itemBuilder: (context, index) {
                                        final suggestion = quickGradeSuggestions[index];
                                        final isSelected = schoolGrade.text.trim() == suggestion;
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: ChoiceChip(
                                            label: Text(suggestion, style: TextStyle(fontSize: 12, fontFamily: 'Cairo', color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
                                            selected: isSelected,
                                            selectedColor: accentGlow,
                                            backgroundColor: isDarkMode ? const Color(0xff1e293b) : const Color(0xffe2e8f0),
                                            elevation: isSelected ? 4 : 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            onSelected: (bool selected) {
                                              if (selected) {
                                                setState(() {
                                                  schoolGrade.text = suggestion;
                                                });
                                              }
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  TextField(
                                    controller: address,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    decoration: _buildInputDecoration("مكان السكن / العنوان", Icons.location_on_rounded, isDarkMode),
                                  ),
                                  const SizedBox(height: 14),

                                  TextField(
                                    controller: fatherJob,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    decoration: _buildInputDecoration("عمل الأب", Icons.work_rounded, isDarkMode),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 📅 5. قسم التواريخ والحفظ
                            _buildSectionHeader(
                              title: "التواريخ ومستوى الحفظ",
                              icon: Icons.history_edu_rounded,
                              isDarkMode: isDarkMode,
                              child: Column(
                                children: [
                                  if (studentType != "new") ...[
                                    TextField(
                                      controller: memorizedPages,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                      decoration: _buildInputDecoration("عدد الصفحات المحفوظة مسبقاً", Icons.menu_book_rounded, isDarkMode),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  Row(
                                    children: [
                                      Expanded(child: _buildDatePickerCard(
                                        label: birthDate == null ? "تاريخ الميلاد" : birthDate.toString().split(" ")[0],
                                        icon: Icons.cake_rounded,
                                        isDarkMode: isDarkMode,
                                        onTap: () async {
                                          final picked = await _selectDate(context, DateTime(1990), isDarkMode);
                                          if (picked != null) setState(() => birthDate = picked);
                                        },
                                      )),
                                      const SizedBox(width: 10),
                                      Expanded(child: _buildDatePickerCard(
                                        label: startDate == null ? "بدء الحفظ" : startDate.toString().split(" ")[0],
                                        icon: Icons.play_arrow_rounded,
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

                            const SizedBox(height: 28),

                            // 🚀 6. زر الحفظ الفخم المصمم بظل ثلاثي الأبعاد (Glowing Submit Button)
                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: ElevatedButton(
                                onPressed: loading ? null : () => addStudent(activeCycleId, activeCycleName),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isDarkMode 
                                          ? [accentGlow, accentGold]
                                          : [const Color(0xff3b82f6), const Color(0xff1d4ed8)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isDarkMode ? accentGlow : Colors.blue).withOpacity(0.4),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      )
                                    ],
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: loading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 22),
                                              SizedBox(width: 10),
                                              Text(
                                                "حفظ وإضافة الطالب",
                                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
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
      },
    );
  }

  // 🧊 أداة بناء الكروت الإبداعية (Neumorphic Glass Card)
  Widget _buildCreativeCard({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDarkMode ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon, required Widget child, required bool isDarkMode}) {
    return _buildCreativeCard(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDarkMode ? accentGold : primaryColor).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo')),
            ],
          ),
          Divider(height: 24, color: isDarkMode ? Colors.white12 : Colors.black12),
          child,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600, fontSize: 12.5, fontFamily: 'Cairo'),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode ? Colors.black.withOpacity(0.25) : Colors.white.withOpacity(0.5), 
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: isDarkMode ? accentGold : primaryColor, width: 1.8),
      ),
    );
  }

  Widget _buildDatePickerCard({required String label, required IconData icon, required bool isDarkMode, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black.withOpacity(0.25) : Colors.white.withOpacity(0.5),
          border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDarkMode ? accentGold : primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.black87, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis)),
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