import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _EditStudentPageState extends State<EditStudentPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController nameController;
  late TextEditingController serialController;
  late TextEditingController fatherNameController;
  late TextEditingController motherNameController;
  late TextEditingController phoneController;
  late TextEditingController schoolGradeController;

  String? selectedSupervisorId;
  String? selectedSupervisorName;
  String? studentType;
  String? currentImageUrl;

  // 🗓️ تخصيص كل يوم على حدة: {اليوم: الفترة}
  final List<String> _weekDays = const [
    'السبت',
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  final List<String> _periodsList = const [
    'عصراً',
    'عالمغرب',
    'عصراً وعالمغرب',
  ];

  final Map<String, String> _daySchedules = {};
  String _bulkPeriod = "عصراً";

  List<String> get _orderedSelectedDays {
    final days = _daySchedules.keys.toList();
    days.sort((a, b) => _weekDays.indexOf(a).compareTo(_weekDays.indexOf(b)));
    return days;
  }

  // 🎯 الحفاظ على معرف الدورة واسمها لمنع الخربطة بين الدورات
  String? cycleId;
  String? cycleName;

  File? _newSelectedImage;
  final ImagePicker _picker = ImagePicker();

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);
  bool _isLoading = false;

  late AnimationController _glowController;

  final List<String> quickGradeSuggestions = const [
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'السابع',
    'الثامن',
    'التاسع',
    'العاشر',
    'الحادي عشر',
    'البكالوريا',
    'جامعي'
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.student.data() as Map<String, dynamic>;

    nameController = TextEditingController(text: data['name'] ?? '');
    serialController =
        TextEditingController(text: (data['serial'] ?? '').toString());
    fatherNameController =
        TextEditingController(text: data['fatherName'] ?? '');
    motherNameController =
        TextEditingController(text: data['motherName'] ?? '');
    phoneController = TextEditingController(text: data['phone'] ?? '');
    schoolGradeController =
        TextEditingController(text: data['schoolGrade']?.toString() ?? '');

    selectedSupervisorId = data['supervisorId'];
    selectedSupervisorName = data['supervisorName'];
    studentType = data['studentType'] ?? 'new';
    currentImageUrl = data['imageUrl'];

    // تحميل جدول الأيام المخصص إن وجد، وإلا التوافق مع النظام القديم
    final fallbackPeriodRaw = data['attendancePeriod']?.toString();
    final fallbackPeriod = (_periodsList.contains(fallbackPeriodRaw))
        ? fallbackPeriodRaw!
        : 'عصراً';
    _bulkPeriod = fallbackPeriod;

    if (data['scheduleByDay'] is Map) {
      final rawSchedule = Map<String, dynamic>.from(data['scheduleByDay'] as Map);
      rawSchedule.forEach((dayKey, periodVal) {
        final dayStr = dayKey.toString();
        if (_weekDays.contains(dayStr)) {
          final pStr = periodVal?.toString() ?? fallbackPeriod;
          _daySchedules[dayStr] =
              _periodsList.contains(pStr) ? pStr : fallbackPeriod;
        }
      });
    } else if (data['attendanceDays'] is List) {
      for (final rawDay in (data['attendanceDays'] as List)) {
        final dayStr = rawDay.toString();
        if (_weekDays.contains(dayStr)) {
          _daySchedules[dayStr] = fallbackPeriod;
        }
      }
    }

    // جلب قيم الدورة المربوطة بالطالب
    cycleId = data['cycleId'];
    cycleName = data['cycleName'];

    nameController.addListener(() => setState(() {}));
    serialController.addListener(() => setState(() {}));
    schoolGradeController.addListener(() => setState(() {}));

    _glowController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    nameController.dispose();
    serialController.dispose();
    fatherNameController.dispose();
    motherNameController.dispose();
    phoneController.dispose();
    schoolGradeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ⚡ اختيار سريع لنظام الأيام
  void _applyQuickDaysPreset(String preset) {
    HapticFeedback.selectionClick();
    setState(() {
      _daySchedules.clear();
      if (preset == 'all') {
        for (final day in _weekDays) {
          _daySchedules[day] = _bulkPeriod;
        }
      } else if (preset == 'three') {
        for (final day in const ['السبت', 'الإثنين', 'الأربعاء']) {
          _daySchedules[day] = _bulkPeriod;
        }
      } else if (preset == 'clear') {
        _daySchedules.clear();
      }
    });
  }

  void _toggleDay(String day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_daySchedules.containsKey(day)) {
        _daySchedules.remove(day);
      } else {
        _daySchedules[day] = _bulkPeriod;
      }
    });
  }

  void _setDayPeriod(String day, String period) {
    HapticFeedback.selectionClick();
    setState(() {
      _daySchedules[day] = period;
    });
  }

  void _cycleDayPeriod(String day) {
    HapticFeedback.selectionClick();
    final current = _daySchedules[day] ?? 'عصراً';
    final nextIndex = (_periodsList.indexOf(current) + 1) % _periodsList.length;
    setState(() {
      _daySchedules[day] = _periodsList[nextIndex];
    });
  }

  void _applyBulkPeriodToSelected() {
    HapticFeedback.selectionClick();
    if (_daySchedules.isEmpty) return;
    setState(() {
      for (final day in _daySchedules.keys.toList()) {
        _daySchedules[day] = _bulkPeriod;
      }
    });
  }

  String _buildScheduleSummaryText() {
    final days = _orderedSelectedDays;
    if (days.isEmpty) return "الدوام: غير محدد";
    final distinctPeriods = days.map((d) => _daySchedules[d] ?? 'عصراً').toSet();
    if (distinctPeriods.length == 1) {
      return "${days.length} أيام • ${distinctPeriods.first}";
    }
    return "${days.length} أيام • فترات مخصصة";
  }

  Future<void> _pickImage() async {
    HapticFeedback.mediumImpact();
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (pickedFile != null) {
      setState(() {
        _newSelectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadNewImageToCloudinary() async {
    if (_newSelectedImage == null) return currentImageUrl ?? '';
    try {
      var url =
          Uri.parse('https://api.cloudinary.com/v1_1/dqsrrej2b/image/upload');

      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'rhjrrtqz'
        ..files.add(
            await http.MultipartFile.fromPath('file', _newSelectedImage!.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        var jsonMap = jsonDecode(responseString);

        return jsonMap['secure_url'] ?? currentImageUrl ?? '';
      } else {
        return currentImageUrl ?? '';
      }
    } catch (e) {
      debugPrint("خطأ أثناء رفع الصورة: $e");
      return currentImageUrl ?? '';
    }
  }

  Future<void> _toggleCompletionStatus(bool isDarkMode) async {
    HapticFeedback.selectionClick();
    bool isCurrentlyCompleted = studentType == 'completed';

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.transparent,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xff1e293b).withOpacity(0.9)
                    : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: accentGold, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: accentGold.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrentlyCompleted
                          ? Colors.red.withOpacity(0.15)
                          : accentGold.withOpacity(0.15),
                    ),
                    child: Text(
                      isCurrentlyCompleted ? "⚠" : "👑",
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    isCurrentlyCompleted
                        ? "إلغاء صفة الخاتم"
                        : "ترقية الطالب لـ خاتم لكتاب الله 👑",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : primaryColor,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isCurrentlyCompleted
                        ? "هل ترغب في إعادة حساب الطالب للنظام العادي وإلغاء صفة الختمة؟"
                        : "هل ترغب في اعتماد الطالب (${nameController.text}) كخاتم لكتاب الله كاملاً (604 صفحة)؟",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      fontFamily: 'Cairo',
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text("إلغاء",
                              style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.grey[700],
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCurrentlyCompleted
                                ? Colors.redAccent
                                : accentGold,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            isCurrentlyCompleted
                                ? "تأكيد الإلغاء"
                                : "تأكيد الختم 👑",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                                fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      setState(() {
        studentType = isCurrentlyCompleted ? 'old' : 'completed';
      });
    }
  }

  Future<void> updateStudent() async {
    if (nameController.text.trim().isEmpty ||
        serialController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.orange,
            content: Text("يرجى ملء الاسم والرقم التسلسلي كحد أدنى",
                style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String finalImageUrl = currentImageUrl ?? '';
      if (_newSelectedImage != null) {
        finalImageUrl = await _uploadNewImageToCloudinary();
      }

      final orderedDays = _orderedSelectedDays;
      final Map<String, String> orderedScheduleMap = {
        for (final day in orderedDays) day: _daySchedules[day] ?? 'عصراً',
      };

      // 🛡 خريطة بيانات الحفظ مع الحفاظ الصريح والكامل على معرف واسم الدورة وجدول الدوام المخصص
      Map<String, dynamic> updateData = {
        'name': nameController.text.trim(),
        'serial': serialController.text.trim(),
        'fatherName': fatherNameController.text.trim(),
        'motherName': motherNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'supervisorId': selectedSupervisorId ?? '',
        'supervisorName': selectedSupervisorName ?? '',
        'studentType': studentType,
        'schoolGrade': schoolGradeController.text.trim(),
        'imageUrl': finalImageUrl,
        'attendanceDays': orderedDays,
        'scheduleByDay': orderedScheduleMap,
      };

      if (orderedDays.isNotEmpty) {
        final distinctPeriods = orderedScheduleMap.values.toSet();
        updateData['attendancePeriod'] = distinctPeriods.length == 1
            ? distinctPeriods.first
            : 'مخصص حسب اليوم';
      }

      // ربط وحفظ cycleId و cycleName بشكل دقيق
      if (cycleId != null && cycleId!.isNotEmpty) {
        updateData['cycleId'] = cycleId;
      }
      if (cycleName != null && cycleName!.isNotEmpty) {
        updateData['cycleName'] = cycleName;
      }

      if (studentType == 'completed') {
        updateData['memorizedPages'] = 604.0;
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.student.id)
          .update(updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.green,
            content: Text("تم تحديث بيانات الطالب بنجاح ✨",
                style: TextStyle(fontFamily: 'Cairo'))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: Colors.red,
            content: Text("خطأ أثناء التحديث: $e",
                style: const TextStyle(fontFamily: 'Cairo'))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDarkMode ? const Color(0xff0f172a) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text('تعديل ملف الطالب',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : primaryColor,
                fontFamily: 'Cairo',
                fontSize: 18)),
        iconTheme:
            IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [
                        const Color(0xff0f172a),
                        const Color(0xff1e293b),
                        const Color(0xff0f172a)
                      ]
                    : [
                        const Color(0xffe2e8f0),
                        const Color(0xffcfdef3),
                        const Color(0xffe0eafc)
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -40 + (_glowController.value * 20),
                    left: -60,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (studentType == 'completed'
                                ? accentGold
                                : primaryColor)
                            .withOpacity(isDarkMode ? 0.15 : 0.2),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80 - (_glowController.value * 20),
                    right: -70,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            accentGold.withOpacity(isDarkMode ? 0.12 : 0.15),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  _buildGlassCard(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.symmetric(
                        vertical: 22, horizontal: 20),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: studentType == 'completed'
                                      ? [
                                          accentGold,
                                          Colors.amberAccent,
                                          accentGold
                                        ]
                                      : [
                                          primaryColor,
                                          isDarkMode
                                              ? accentGold
                                              : Colors.blueAccent
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (studentType == 'completed'
                                            ? accentGold
                                            : primaryColor)
                                        .withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 3,
                                  )
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: isDarkMode
                                    ? const Color(0xff1e293b)
                                    : Colors.white,
                                backgroundImage: _newSelectedImage != null
                                    ? FileImage(_newSelectedImage!)
                                    : (currentImageUrl != null &&
                                            currentImageUrl!.isNotEmpty
                                        ? NetworkImage(currentImageUrl!)
                                            as ImageProvider
                                        : null),
                                child: (_newSelectedImage == null &&
                                        (currentImageUrl == null ||
                                            currentImageUrl!.isEmpty))
                                    ? Icon(Icons.person_rounded,
                                        size: 55,
                                        color: isDarkMode
                                            ? Colors.white38
                                            : Colors.grey[400])
                                    : null,
                              ),
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
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDarkMode
                                          ? accentGold
                                          : primaryColor,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.3),
                                            blurRadius: 8)
                                      ],
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        size: 15, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          nameController.text.isEmpty
                              ? "اسم الطالب"
                              : nameController.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo'),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.black26
                                    : Colors.white60,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isDarkMode
                                        ? Colors.white12
                                        : Colors.black12),
                              ),
                              child: Text(
                                "الكود: #${serialController.text}",
                                style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo'),
                              ),
                            ),
                            if (schoolGradeController.text.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentGold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: accentGold.withOpacity(0.5)),
                                ),
                                child: Text(
                                  "الصف: ${schoolGradeController.text}",
                                  style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.amberAccent
                                          : primaryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo'),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isDarkMode ? accentGold : primaryColor)
                                    .withOpacity(0.14),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color:
                                        (isDarkMode ? accentGold : primaryColor)
                                            .withOpacity(0.35)),
                              ),
                              child: Text(
                                _buildScheduleSummaryText(),
                                style: TextStyle(
                                    color: isDarkMode
                                        ? accentGold
                                        : primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildGlassCard(
                    isDarkMode: isDarkMode,
                    borderColor: studentType == 'completed' ? accentGold : null,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: studentType == 'completed'
                                ? accentGold.withOpacity(0.2)
                                : (isDarkMode
                                    ? Colors.white10
                                    : Colors.black.withOpacity(0.05)),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                              studentType == 'completed' ? "👑" : "📖",
                              style: const TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                studentType == 'completed'
                                    ? "حساب خاتم لكتاب الله"
                                    : "طالب غير خاتم حالياً",
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  color: studentType == 'completed'
                                      ? accentGold
                                      : (isDarkMode
                                          ? Colors.white
                                          : primaryColor),
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                studentType == 'completed'
                                    ? "604 صفحة (مراجعة شاملة)"
                                    : "نظام التسميع العادي",
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: isDarkMode
                                        ? Colors.white60
                                        : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: studentType == 'completed'
                                ? Colors.redAccent.withOpacity(0.85)
                                : accentGold,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          onPressed: () => _toggleCompletionStatus(isDarkMode),
                          child: Text(
                            studentType == 'completed'
                                ? "إلغاء الخاتم"
                                : "ترقية لخاتم 👑",
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🗓️ قسم تخصيص أيام الدوام وفترة كل يوم
                  _buildGlassCard(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.all(18),
                    child: _buildAttendanceScheduleSection(isDarkMode),
                  ),

                  const SizedBox(height: 16),

                  _buildGlassCard(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.school_rounded,
                                color: isDarkMode ? accentGold : primaryColor,
                                size: 22),
                            const SizedBox(width: 8),
                            Text(
                              "الصف الدراسي",
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: isDarkMode ? Colors.white : primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: schoolGradeController,
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo'),
                          decoration: _glassInputDecoration(
                              "أدخل أو عدّل الصف الدراسي",
                              Icons.edit_note_rounded,
                              isDarkMode),
                        ),
                        const SizedBox(height: 12),
                        Text("أو اختر صفاً بشكل سريع:",
                            style: TextStyle(
                                fontSize: 11,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.black54,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 38,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: quickGradeSuggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = quickGradeSuggestions[index];
                              final isSelected =
                                  schoolGradeController.text.trim() ==
                                      suggestion;
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  label: Text(suggestion,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'Cairo',
                                          color: isSelected
                                              ? Colors.white
                                              : (isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black87),
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal)),
                                  selected: isSelected,
                                  selectedColor:
                                      isDarkMode ? accentGold : primaryColor,
                                  backgroundColor: isDarkMode
                                      ? Colors.black26
                                      : Colors.white60,
                                  onSelected: (bool selected) {
                                    if (selected) {
                                      setState(() {
                                        schoolGradeController.text =
                                            suggestion;
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildGlassCard(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("البيانات الشخصية والإدارية",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                color:
                                    isDarkMode ? accentGold : primaryColor)),
                        const SizedBox(height: 15),
                        TextField(
                          controller: nameController,
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo'),
                          decoration: _glassInputDecoration(
                              "اسم الطالب الكامل",
                              Icons.badge_outlined,
                              isDarkMode),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: serialController,
                          keyboardType: TextInputType.text,
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo'),
                          decoration: _glassInputDecoration(
                              "الرقم التسلسلي (كود الطالب)",
                              Icons.format_list_numbered_rtl_rounded,
                              isDarkMode),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: fatherNameController,
                                style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo'),
                                decoration: _glassInputDecoration(
                                    "اسم الأب",
                                    Icons.person_outline_rounded,
                                    isDarkMode),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: motherNameController,
                                style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo'),
                                decoration: _glassInputDecoration(
                                    "اسم الأم",
                                    Icons.woman_outlined,
                                    isDarkMode),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo'),
                          decoration: _glassInputDecoration(
                              "رقم هاتف ولي الأمر",
                              Icons.phone_android_rounded,
                              isDarkMode),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: studentType,
                          dropdownColor: isDarkMode
                              ? const Color(0xff1e293b)
                              : Colors.white,
                          style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo'),
                          decoration: _glassInputDecoration(
                              "فئة الطالب في الحلقة",
                              Icons.category_rounded,
                              isDarkMode),
                          items: const [
                            DropdownMenuItem(
                                value: "new", child: Text("طالب جديد")),
                            DropdownMenuItem(
                                value: "old", child: Text("طالب قديم")),
                            DropdownMenuItem(
                                value: "completed",
                                child: Text("طالب خاتم 👑")),
                          ],
                          onChanged: (v) => setState(() => studentType = v),
                        ),
                        const SizedBox(height: 14),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('supervisors')
                              .snapshots(),
                          builder: (context, snapshot) {
                            List<DropdownMenuItem<String>> supervisorItems = [];

                            if (snapshot.hasData) {
                              for (var doc in snapshot.data!.docs) {
                                var sData = doc.data() as Map<String, dynamic>;
                                String supName = sData['name'] ??
                                    sData['email'] ??
                                    'مشرف';
                                supervisorItems.add(DropdownMenuItem(
                                  value: doc.id,
                                  child: Text(supName,
                                      style:
                                          const TextStyle(fontFamily: 'Cairo')),
                                ));
                              }
                            }

                            String? currentSelection = selectedSupervisorId;
                            if (currentSelection != null &&
                                !supervisorItems.any(
                                    (item) => item.value == currentSelection)) {
                              currentSelection = null;
                            }

                            return DropdownButtonFormField<String>(
                              value: currentSelection,
                              hint: Text("اختر المشرف المسؤول",
                                  style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white60
                                          : Colors.black45,
                                      fontFamily: 'Cairo')),
                              dropdownColor: isDarkMode
                                  ? const Color(0xff1e293b)
                                  : Colors.white,
                              style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo'),
                              decoration: _glassInputDecoration(
                                  "المشرف / الحلقة",
                                  Icons.gite_rounded,
                                  isDarkMode),
                              items: supervisorItems,
                              onChanged: (v) {
                                if (v != null && snapshot.hasData) {
                                  var chosenDoc = snapshot.data!.docs
                                      .firstWhere((doc) => doc.id == v);
                                  var chosenData =
                                      chosenDoc.data() as Map<String, dynamic>;
                                  setState(() {
                                    selectedSupervisorId = v;
                                    selectedSupervisorName =
                                        chosenData['name'] ??
                                            chosenData['email'];
                                  });
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : updateStudent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? accentGold.withOpacity(0.9)
                                  : primaryColor.withOpacity(0.95),
                              foregroundColor: Colors.white,
                              elevation: 6,
                              shadowColor:
                                  (isDarkMode ? accentGold : primaryColor)
                                      .withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        "حفظ وتحديث التغييرات",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                            fontFamily: 'Cairo'),
                                      ),
                                    ],
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

  Widget _buildAttendanceScheduleSection(bool isDarkMode) {
    final selectedDays = _orderedSelectedDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                color: isDarkMode ? accentGold : primaryColor, size: 22),
            const SizedBox(width: 8),
            Text(
              "جدول الدوام وتخصيص كل يوم",
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
                color: isDarkMode ? Colors.white : primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              "اختيار سريع للأيام:",
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: isDarkMode ? Colors.white60 : Colors.black54,
              ),
            ),
            const Spacer(),
            _buildPresetChip(
              label: "3 أيام",
              isDarkMode: isDarkMode,
              onTap: () => _applyQuickDaysPreset('three'),
            ),
            const SizedBox(width: 6),
            _buildPresetChip(
              label: "كل الأسبوع",
              isDarkMode: isDarkMode,
              onTap: () => _applyQuickDaysPreset('all'),
            ),
            const SizedBox(width: 6),
            _buildPresetChip(
              label: "مسح",
              isDarkMode: isDarkMode,
              onTap: () => _applyQuickDaysPreset('clear'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _weekDays.map((day) {
            final bool isSelected = _daySchedules.containsKey(day);
            return InkWell(
              onTap: () => _toggleDay(day),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDarkMode ? accentGold : primaryColor)
                      : (isDarkMode
                          ? Colors.black.withOpacity(0.22)
                          : Colors.white.withOpacity(0.55)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? (isDarkMode ? accentGold : primaryColor)
                        : (isDarkMode ? Colors.white12 : Colors.white70),
                    width: 1.3,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_rounded,
                          size: 15, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      day,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDarkMode ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.white10 : Colors.white70,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "فترة للأيام الجديدة / السريعة:",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (selectedDays.isNotEmpty)
                    InkWell(
                      onTap: _applyBulkPeriodToSelected,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        child: Text(
                          "تطبيق على المحددة",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                            color: isDarkMode ? accentGold : primaryColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: _periodsList.map((period) {
                  final bool isSelected = _bulkPeriod == period;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: period == 'عصراً وعالمغرب' ? 0 : 6),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _bulkPeriod = period);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDarkMode ? accentGold : primaryColor)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? (isDarkMode ? accentGold : primaryColor)
                                  : (isDarkMode
                                      ? Colors.white12
                                      : Colors.black12),
                            ),
                          ),
                          child: Text(
                            period,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isDarkMode
                                      ? Colors.white70
                                      : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (selectedDays.isEmpty)
          Text(
            "اختر يوماً أو أكثر لتخصيص فترته (عصراً، عالمغرب، أو عصراً وعالمغرب).",
            style: TextStyle(
              fontSize: 11.5,
              fontFamily: 'Cairo',
              color: isDarkMode ? Colors.white54 : Colors.black54,
            ),
          )
        else ...[
          Text(
            "تخصيص فترة كل يوم لحاله:",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              color: isDarkMode ? accentGold : primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          ...selectedDays.map((day) {
            final currentPeriod = _daySchedules[day] ?? 'عصراً';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.22)
                    : Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode ? Colors.white12 : Colors.white70,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 68,
                    child: Text(
                      day,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : primaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _periodsList.map((period) {
                          final active = currentPeriod == period;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: InkWell(
                              onTap: () => _setDayPeriod(day, period),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: active
                                      ? (isDarkMode ? accentGold : primaryColor)
                                      : (isDarkMode
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.white.withOpacity(0.5)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: active
                                        ? (isDarkMode ? accentGold : primaryColor)
                                        : (isDarkMode
                                            ? Colors.white12
                                            : Colors.black12),
                                  ),
                                ),
                                child: Text(
                                  period,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    fontWeight: active
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: active
                                        ? Colors.white
                                        : (isDarkMode
                                            ? Colors.white70
                                            : Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: "تبديل الفترة",
                    icon: Icon(
                      Icons.sync_rounded,
                      size: 18,
                      color: isDarkMode ? accentGold : primaryColor,
                    ),
                    onPressed: () => _cycleDayPeriod(day),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: "إزالة اليوم",
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _toggleDay(day),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (isDarkMode ? accentGold : primaryColor).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (isDarkMode ? accentGold : primaryColor).withOpacity(0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? accentGold : primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(
      {required Widget child,
      required bool isDarkMode,
      EdgeInsetsGeometry padding = EdgeInsets.zero,
      Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: borderColor ??
                  (isDarkMode
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.7)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.03),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _glassInputDecoration(
      String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: isDarkMode ? Colors.white60 : Colors.black54,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
          fontFamily: 'Cairo'),
      prefixIcon:
          Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode
          ? Colors.black.withOpacity(0.2)
          : Colors.white.withOpacity(0.4),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: isDarkMode ? accentGold : primaryColor, width: 1.5),
      ),
    );
  }
}