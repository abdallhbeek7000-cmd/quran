import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cycle_service.dart';
import '../services/theme_provider.dart';

class CreateCyclePage extends StatefulWidget {
  const CreateCyclePage({super.key});

  @override
  State<CreateCyclePage> createState() => _CreateCyclePageState();
}

class _CreateCyclePageState extends State<CreateCyclePage> {
  final cycleService = CycleService();
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  String type = "صيف";
  final year = TextEditingController();
  final cycleNumber = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  bool loading = false;

  // خيارات نقل الطلاب المحددين
  bool copyStudentsFromPrevious = false;
  String? selectedPreviousCycleId;
  List<Map<String, dynamic>> previousCyclesList = [];
  
  // قائمة الطلاب المحددين للنقل
  List<Map<String, dynamic>> availableStudents = [];
  List<String> selectedStudentIds = [];
  bool isLoadingStudents = false;

  @override
  void initState() {
    super.initState();
    _loadPreviousCycles();
  }

  Future<void> _loadPreviousCycles() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('cycles').get();
      if (snap.docs.isNotEmpty) {
        setState(() {
          previousCyclesList = snap.docs.map((d) {
            var data = d.data();
            return {
              'id': d.id,
              'name': "${data['name'] ?? 'دورة'} (${data['cycleNumber'] ?? '1'})",
            };
          }).toList();
        });
      }
    } catch (e) {
      print("خطأ في جلب الدورات السابقة: $e");
    }
  }

  // جلب طلاب الدورة المحددة فقط
  Future<void> _fetchStudentsForCycle(String cycleId) async {
    setState(() => isLoadingStudents = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('cycleId', isEqualTo: cycleId)
          .get();

      setState(() {
        availableStudents = snap.docs.map((d) {
          var data = d.data();
          return {
            'docId': d.id,
            'name': data['name'] ?? 'بدون اسم',
            'groupName': data['groupName'] ?? '',
            'data': data,
          };
        }).toList();
        selectedStudentIds = availableStudents.map((s) => s['docId'] as String).toList(); // تحديد الكل افتراضياً
      });
    } catch (e) {
      print("خطأ في جلب الطلاب: $e");
    } finally {
      setState(() => isLoadingStudents = false);
    }
  }

  // نافذة اختيار الطلاب المطلوب نقلهم
  void _showStudentSelectionDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                "حدد الطلاب المستمرين معكم 👥",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : primaryColor,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: isLoadingStudents
                    ? const Center(child: CircularProgressIndicator())
                    : availableStudents.isEmpty
                        ? const Center(child: Text("لا يوجد طلاب في هذه الدورة", style: TextStyle(fontFamily: 'Cairo')))
                        : Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        selectedStudentIds = availableStudents.map((s) => s['docId'] as String).toList();
                                      });
                                    },
                                    child: const Text("تحديد الكل", style: TextStyle(fontFamily: 'Cairo')),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        selectedStudentIds.clear();
                                      });
                                    },
                                    child: const Text("إلغاء الكل", style: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: availableStudents.length,
                                  itemBuilder: (context, index) {
                                    var student = availableStudents[index];
                                    bool isSelected = selectedStudentIds.contains(student['docId']);
                                    return CheckboxListTile(
                                      activeColor: accentGold,
                                      title: Text(
                                        student['name'],
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "الحلقة: ${student['groupName']}",
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11,
                                          color: isDarkMode ? Colors.white54 : Colors.black54,
                                        ),
                                      ),
                                      value: isSelected,
                                      onChanged: (bool? val) {
                                        setDialogState(() {
                                          if (val == true) {
                                            selectedStudentIds.add(student['docId']);
                                          } else {
                                            selectedStudentIds.remove(student['docId']);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentGold),
                  onPressed: () {
                    setState(() {}); // تحديث الواجهة الرئيسية
                    Navigator.pop(context);
                  },
                  child: const Text("تم", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart, bool isDarkMode) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  createCycle() async {
    if (startDate == null || endDate == null || year.text.trim().isEmpty || cycleNumber.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى ملء جميع الحقول واختيار التواريخ", style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final int inputYear = int.parse(year.text.trim());
      final int inputCycleNumber = int.parse(cycleNumber.text.trim());
      final String cycleName = "$type $inputYear";

      // 1. أرشفة وتثبيط كافة الدورات السابقة
      final previousDocs = await FirebaseFirestore.instance.collection('cycles').get();
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in previousDocs.docs) {
        batch.update(doc.reference, {
          'active': false,
          'isCurrent': false,
          'status': 'closed',
        });
      }
      await batch.commit();

      // 2. إنشاء الدورة الجديدة المفعّلة
      DocumentReference newCycleRef = await FirebaseFirestore.instance.collection('cycles').add({
        'name': cycleName,
        'type': type,
        'year': inputYear,
        'cycleNumber': inputCycleNumber,
        'startDate': startDate.toString().split(" ")[0],
        'endDate': endDate.toString().split(" ")[0],
        'active': true,
        'isCurrent': true,
        'status': 'active',
        'archived': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. نقل الطلاب المحددين مع الحفاظ الكامل على رقمهم التسلسلي الأصلي (serial)
      if (copyStudentsFromPrevious && selectedStudentIds.isNotEmpty) {
        WriteBatch copyBatch = FirebaseFirestore.instance.batch();

        for (var studentMap in availableStudents) {
          if (selectedStudentIds.contains(studentMap['docId'])) {
            var data = studentMap['data'] as Map<String, dynamic>;
            DocumentReference newStudentRef = FirebaseFirestore.instance.collection('students').doc();

            copyBatch.set(newStudentRef, {
              ...data,
              // نحتفظ بـ serial الأصلي للطالب كما هو بدون أي تغيير!
              'cycleId': newCycleRef.id,
              'cycleName': cycleName,
              'points': 0, // تصفير النقاط للدورة الجديدة
              'attendanceCount': 0, // تصفير سجلات الحضور
              'archived': false,
              'isArchived': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
        await copyBatch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("تم إنشاء الدورة وتفعيلها بنجاح 🎉", style: TextStyle(fontFamily: 'Cairo'))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("حدث خطأ: $e", style: const TextStyle(fontFamily: 'Cairo'))),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
        title: Text("إنشاء دورة جديدة", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
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
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: type,
                          dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          decoration: _glassInputDecoration("نوع الدورة", Icons.wb_sunny_outlined, isDarkMode),
                          items: const [
                            DropdownMenuItem(value: "صيف", child: Text("دورة صيفية")),
                            DropdownMenuItem(value: "شتاء", child: Text("دورة شتوية")),
                          ],
                          onChanged: (v) => setState(() => type = v!),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: year,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                decoration: _glassInputDecoration("السنة", Icons.calendar_today, isDarkMode),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: cycleNumber,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                decoration: _glassInputDecoration("رقم الدورة", Icons.numbers, isDarkMode),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDatePicker(
                          label: startDate == null ? "تاريخ البداية" : startDate.toString().split(" ")[0],
                          icon: Icons.date_range,
                          isDarkMode: isDarkMode,
                          onTap: () => _selectDate(context, true, isDarkMode),
                        ),
                        const SizedBox(height: 16),
                        _buildDatePicker(
                          label: endDate == null ? "تاريخ النهاية" : endDate.toString().split(" ")[0],
                          icon: Icons.event_available,
                          isDarkMode: isDarkMode,
                          onTap: () => _selectDate(context, false, isDarkMode),
                        ),
                        const SizedBox(height: 20),

                        if (previousCyclesList.isNotEmpty) ...[
                          Divider(color: isDarkMode ? Colors.white24 : Colors.black12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: accentGold,
                            title: Text(
                              "نقل طلاب محددين من دورة سابقة 👥",
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : primaryColor,
                              ),
                            ),
                            value: copyStudentsFromPrevious,
                            onChanged: (val) {
                              setState(() {
                                copyStudentsFromPrevious = val;
                                if (val && previousCyclesList.isNotEmpty) {
                                  selectedPreviousCycleId = previousCyclesList.first['id'];
                                  _fetchStudentsForCycle(selectedPreviousCycleId!);
                                }
                              });
                            },
                          ),
                          if (copyStudentsFromPrevious) ...[
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: selectedPreviousCycleId,
                              dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                              decoration: _glassInputDecoration("اختر الدورة السابقة", Icons.unarchive_rounded, isDarkMode),
                              items: previousCyclesList.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c['id'],
                                  child: Text(c['name']),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setState(() => selectedPreviousCycleId = v);
                                if (v != null) _fetchStudentsForCycle(v);
                              },
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _showStudentSelectionDialog(isDarkMode),
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: accentGold.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: accentGold.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "تم تحديد (${selectedStudentIds.length}) طالب من أصل (${availableStudents.length})",
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isDarkMode ? Colors.white : primaryColor,
                                      ),
                                    ),
                                    const Icon(Icons.edit_note_rounded, color: Colors.amber),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: loading ? null : createCycle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9),
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("تأكيد إنشاء الدورة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _glassInputDecoration(String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Cairo'),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
    );
  }

  Widget _buildDatePicker({required String label, required IconData icon, required bool isDarkMode, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDarkMode ? accentGold : primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white70 : Colors.black87, fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}