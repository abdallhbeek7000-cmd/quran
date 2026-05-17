import 'dart:io';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; 
import 'package:provider/provider.dart';
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

  File? _selectedImage; 
  XFile? _pickerFile; 
  final ImagePicker _picker = ImagePicker();

  final Color primaryColor = const Color(0xff425c75);

  // دالة فتح المعرض واختيار الصورة المحدثة الشاملة
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

  // 🔥 دالة الرفع المباشر بالبايتات المربوطة بسيرفر Cloudinary الخاص بك
  Future<String> _uploadStudentImageToCloudinary() async {
    if (_pickerFile == null) return '';
    try {
      var url = Uri.parse('https://api.cloudinary.com/v1_1/dqsrrej2b/image/upload');
      
      // قراءة بايتات الصورة لضمان استقرار الرفع وسرعته على الموبايل
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
      final serial = await studentService.generateStudentSerial(
        year: widget.cycle.year,
        cycleNumber: widget.cycle.cycleNumber,
      );

      // استدعاء دالة الرفع الجديدة واستلام رابط الويب المباشر لتخزينه في فايربوست
      String finalImageUrl = '';
      if (_pickerFile != null) {
        finalImageUrl = await _uploadStudentImageToCloudinary();
      }

      final student = StudentModel(
        id: '',
        serial: serial,
        name: name.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? primaryColor,
        title: const Text("إضافة طالب جديد", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // معاينة الصورة العلوية
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                    backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                    child: _selectedImage == null
                        ? Icon(Icons.account_circle, size: 110, color: Colors.grey[400])
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: CircleAvatar(
                      backgroundColor: isDarkMode ? Colors.orange : primaryColor,
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
            const SizedBox(height: 25),

            // معلومات التسجيل
            _buildSectionCard(
              title: "معلومات التسجيل",
              icon: Icons.app_registration,
              isDarkMode: isDarkMode,
              child: DropdownButtonFormField<String>(
                value: studentType,
                dropdownColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: _inputDecoration("نوع الطالب", Icons.category_outlined, isDarkMode),
                items: const [
                  DropdownMenuItem(value: "new", child: Text("طالب جديد")),
                  DropdownMenuItem(value: "old", child: Text("طالب قديم")),
                  DropdownMenuItem(value: "completed", child: Text("خاتم")),
                ],
                onChanged: (v) => setState(() => studentType = v!),
              ),
            ),

            const SizedBox(height: 15),

            // المعلومات الشخصية
            _buildSectionCard(
              title: "المعلومات الشخصية",
              icon: Icons.person_outline,
              isDarkMode: isDarkMode,
              child: Column(
                children: [
                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: name, decoration: _inputDecoration("اسم الطالب الكامل", Icons.person, isDarkMode)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: fatherName, decoration: _inputDecoration("اسم الأب", Icons.man, isDarkMode))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: motherName, decoration: _inputDecoration("اسم الأم", Icons.woman, isDarkMode))),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: phone, keyboardType: TextInputType.phone, decoration: _inputDecoration("رقم الهاتف", Icons.phone, isDarkMode)),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // تفاصيل إضافية
            _buildSectionCard(
              title: "تفاصيل إضافية",
              icon: Icons.info_outline,
              isDarkMode: isDarkMode,
              child: Column(
                children: [
                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: address, decoration: _inputDecoration("مكان السكن", Icons.location_on_outlined, isDarkMode)),
                  const SizedBox(height: 15),
                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: schoolGrade, decoration: _inputDecoration("الصف الدراسي", Icons.school_outlined, isDarkMode)),
                  const SizedBox(height: 15),
                  TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: fatherJob, decoration: _inputDecoration("عمل الأب", Icons.work_outline, isDarkMode)),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // التواريخ والحفظ
            _buildSectionCard(
              title: "التواريخ والحفظ",
              icon: Icons.history_edu,
              isDarkMode: isDarkMode,
              child: Column(
                children: [
                  if (studentType != "new") ...[
                    TextField(
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      controller: memorizedPages,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration("عدد الصفحات المحفوظة", Icons.auto_stories_outlined, isDarkMode),
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

            const SizedBox(height: 30),

            // زر الحفظ
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : addStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.orange : primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("حفظ بيانات الطالب", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
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
        boxShadow: [BoxShadow(color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
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

  Widget _buildDatePicker({required String label, required IconData icon, required bool isDarkMode, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xff2b2b2b) : Colors.white,
          border: Border.all(color: isDarkMode ? Colors.transparent : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDarkMode ? Colors.orange : primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis)),
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
              primary: isDarkMode ? Colors.orange : primaryColor,
              onPrimary: Colors.white,
              surface: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black,
            ),
            dialogBackgroundColor: isDarkMode ? const Color(0xff1e1e1e) : Colors.white,
          ),
          child: child!,
        );
      },
    );
  }
}