import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../models/cycle_model.dart';
import '../services/theme_provider.dart';
import '../widgets/offline_wrapper.dart';

class HolidayManagementPage extends StatefulWidget {
  final CycleModel cycle;
  final String role;

  const HolidayManagementPage({
    super.key,
    required this.cycle,
    required this.role,
  });

  @override
  State<HolidayManagementPage> createState() => _HolidayManagementPageState();
}

class _HolidayManagementPageState extends State<HolidayManagementPage> {
  final TextEditingController _reasonController = TextEditingController(text: "عطلة رسمية");
  final TextEditingController _searchController = TextEditingController();

  bool _applyToAll = true;
  final List<String> _selectedStudentIds = [];
  bool _isSaving = false;
  String _searchQuery = "";

  // ميزات العطلة الطويلة والأيام المتعددة
  bool _isLongHoliday = false;
  final List<DateTime> _selectedDates = [];

  List<DocumentSnapshot> _allStudents = [];
  bool _isLoadingStudents = true;

  final Color primaryNavy = const Color(0xff1e293b);
  final Color accentGold = const Color(0xffD4AF37);
  final Color softBlue = const Color(0xff3b82f6);

  @override
  void initState() {
    super.initState();
    _fetchStudentsOnce();
  }

  /// جلب الطلاب وترتيبهم تسلسلياً برمجياً بحسب الرقم التسلسلي (serial) عدديًا
  Future<void> _fetchStudentsOnce() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('cycleId', isEqualTo: widget.cycle.id)
          .where('archived', isEqualTo: false)
          .get();

      List<DocumentSnapshot> students = snap.docs;

      // فرز الطلاب حسب الرقم التسلسلي عدديًا بطريقة دقيقة جداً
      students.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;

        String serialStrA = dataA['serial']?.toString() ?? dataA['serialNumber']?.toString() ?? '999999';
        String serialStrB = dataB['serial']?.toString() ?? dataB['serialNumber']?.toString() ?? '999999';

        // استخراج الأرقام فقط من السلسلة في حال احتوت على حروف
        num numA = num.tryParse(serialStrA.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
        num numB = num.tryParse(serialStrB.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;

        return numA.compareTo(numB);
      });

      if (mounted) {
        setState(() {
          _allStudents = students;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في تحميل الطلاب: $e");
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// اختيار تاريخ جديد وإضافته لقائمة العطل
  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: accentGold,
              onPrimary: Colors.black,
              onSurface: primaryNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      DateTime cleanDate = DateTime(picked.year, picked.month, picked.day);
      if (!_selectedDates.any((d) => d.year == cleanDate.year && d.month == cleanDate.month && d.day == cleanDate.day)) {
        setState(() {
          _selectedDates.add(cleanDate);
          _selectedDates.sort((a, b) => a.compareTo(b));
        });
      }
    }
  }

  Future<void> _submitHoliday() async {
    if (!_applyToAll && _selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text("يرجى اختيار طالب واحد على الأقل لتسجيل العطلة له", style: TextStyle(fontFamily: 'Cairo')),
        ),
      );
      return;
    }

    if (_isLongHoliday && _selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text("يرجى اختيار تاريخ يوم واحد على الأقل للعطلة الطويلة", style: TextStyle(fontFamily: 'Cairo')),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final nowTimestamp = FieldValue.serverTimestamp();
      final targetStudents = _applyToAll
          ? _allStudents
          : _allStudents.where((doc) => _selectedStudentIds.contains(doc.id)).toList();

      List<String> datesToApply = [];
      if (_isLongHoliday) {
        datesToApply = _selectedDates.map((d) => intl.DateFormat('yyyy-MM-dd').format(d)).toList();
      } else {
        datesToApply = [intl.DateFormat('yyyy-MM-dd').format(DateTime.now())];
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int operationCount = 0;

      for (String dateStr in datesToApply) {
        for (var studentDoc in targetStudents) {
          final studentData = studentDoc.data() as Map<String, dynamic>;
          final sessionRef = FirebaseFirestore.instance.collection('sessions').doc();

          batch.set(sessionRef, {
            'studentId': studentDoc.id,
            'studentName': studentData['name'] ?? '',
            'cycleId': widget.cycle.id,
            'date': dateStr,
            'createdAt': nowTimestamp,
            'actualCreatedAt': dateStr,
            'isHoliday': true,
            'sessionType': 'holiday',
            'status': 'عطلة',
            'title': 'عطلة: ${_reasonController.text.trim()}',
            'note': _reasonController.text.trim(),
            'notes': _reasonController.text.trim(),
            'sessionNumber': null,
          });

          operationCount++;

          if (operationCount >= 450) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            operationCount = 0;
          }
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text("تم تسجيل العطلة بنجاح لـ ${targetStudents.length} طالب خلال ${datesToApply.length} يوم/أيام 🎉", style: const TextStyle(fontFamily: 'Cairo')),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("خطأ في حفظ العطلة: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("حدث خطأ أثناء حفظ العطلة: $e", style: const TextStyle(fontFamily: 'Cairo')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final filteredStudents = _allStudents.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final serial = (data['serial'] ?? data['serialNumber'] ?? '').toString();
      return name.contains(_searchQuery.toLowerCase()) || serial.contains(_searchQuery);
    }).toList();

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDark ? const Color(0xff0b1120) : const Color(0xfff8fafc),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : primaryNavy),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "إدارة وتسجيل العطلات 🌴",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : primaryNavy,
              fontFamily: 'Cairo',
              fontSize: 18,
            ),
          ),
        ),
        body: Stack(
          children: [
            // خلفية بصرية متدرجة بالدوائر الملونة الجذابة
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xff0b1120), const Color(0xff1e293b), const Color(0xff0f172a)]
                      : [const Color(0xfff1f5f9), const Color(0xffe2e8f0), const Color(0xffcbd5e1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentGold.withValues(alpha: isDark ? 0.08 : 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: softBlue.withValues(alpha: isDark ? 0.08 : 0.10),
                ),
              ),
            ),

            SafeArea(
              child: _isLoadingStudents
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1️⃣ كرت الدورة وسبب العطلة
                                _buildGlassCard(
                                  isDark: isDark,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: accentGold.withValues(alpha: 0.18),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.event_note_rounded, color: accentGold, size: 20),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            "الدورة الفعالة: ${widget.cycle.name}",
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: isDark ? Colors.white : primaryNavy,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "سبب العطلة / الإجازة:",
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _reasonController,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: "مثال: عطلة رسمية / فترة امتحانات...",
                                          hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
                                          filled: true,
                                          fillColor: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.8),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 2️⃣ كرت خيار العطلة الطويلة
                                _buildGlassCard(
                                  isDark: isDark,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SwitchListTile(
                                        activeColor: accentGold,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          "عطلة طويلة (تحديد عدة أيام مخصصة)",
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : primaryNavy,
                                          ),
                                        ),
                                        subtitle: Text(
                                          _isLongHoliday ? "يمكنك اختيار أيام منفصلة للدوام التبادلي أو الامتحانات" : "تسجيل العطلة لليوم فقط",
                                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                                        ),
                                        value: _isLongHoliday,
                                        onChanged: (val) {
                                          setState(() {
                                            _isLongHoliday = val;
                                            if (!_isLongHoliday) _selectedDates.clear();
                                          });
                                        },
                                      ),
                                      if (_isLongHoliday) ...[
                                        const Divider(height: 20),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accentGold,
                                            elevation: 2,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.black, size: 18),
                                          label: const Text("إضافة يوم عطلة 📅", style: TextStyle(fontFamily: 'Cairo', color: Colors.black, fontWeight: FontWeight.bold)),
                                          onPressed: _pickDate,
                                        ),
                                        const SizedBox(height: 12),
                                        if (_selectedDates.isEmpty)
                                          const Text("لم يتم اختيار أي أيام بعد، اضغط على الأزرار لاختيار التواريخ.", style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.orangeAccent))
                                        else
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: _selectedDates.map((date) {
                                              String dStr = intl.DateFormat('yyyy/MM/dd').format(date);
                                              return Chip(
                                                backgroundColor: isDark ? Colors.amber.withValues(alpha: 0.18) : Colors.amber.shade100,
                                                label: Text(dStr, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? accentGold : primaryNavy)),
                                                deleteIcon: const Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                                                onDeleted: () {
                                                  setState(() {
                                                    _selectedDates.remove(date);
                                                  });
                                                },
                                              );
                                            }).toList(),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 3️⃣ كرت اختيار الفئة المستهدفة
                                _buildGlassCard(
                                  isDark: isDark,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "تطبيق العطلة على:",
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : primaryNavy,
                                        ),
                                      ),
                                      RadioListTile<bool>(
                                        title: const Text("جميع الطلاب في الدورة", style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600)),
                                        value: true,
                                        groupValue: _applyToAll,
                                        activeColor: accentGold,
                                        onChanged: (val) => setState(() => _applyToAll = val!),
                                      ),
                                      RadioListTile<bool>(
                                        title: const Text("تحديد طلاب محددين فقط", style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600)),
                                        value: false,
                                        groupValue: _applyToAll,
                                        activeColor: accentGold,
                                        onChanged: (val) => setState(() => _applyToAll = val!),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 4️⃣ كرت قائمة الطلاب الممرتبين تسلسلياً
                                if (!_applyToAll) ...[
                                  _buildGlassCard(
                                    isDark: isDark,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "اختر الطلاب (${_selectedStudentIds.length} محدد)",
                                              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryNavy),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  if (_selectedStudentIds.length == _allStudents.length) {
                                                    _selectedStudentIds.clear();
                                                  } else {
                                                    _selectedStudentIds.clear();
                                                    _selectedStudentIds.addAll(_allStudents.map((e) => e.id));
                                                  }
                                                });
                                              },
                                              child: Text(
                                                _selectedStudentIds.length == _allStudents.length ? "إلغاء تحديد الكل" : "تحديد الكل",
                                                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: accentGold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: _searchController,
                                          onChanged: (val) => setState(() => _searchQuery = val),
                                          style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black),
                                          decoration: InputDecoration(
                                            hintText: "ابحث بالاسم أو الرقم التسلسلي...",
                                            prefixIcon: const Icon(Icons.search, size: 18),
                                            filled: true,
                                            fillColor: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.8),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: filteredStudents.length,
                                          itemBuilder: (context, index) {
                                            final sDoc = filteredStudents[index];
                                            final sData = sDoc.data() as Map<String, dynamic>;
                                            final sId = sDoc.id;
                                            final sName = sData['name'] ?? 'طالب';
                                            final serial = sData['serial']?.toString() ?? sData['serialNumber']?.toString() ?? '-';
                                            final isSelected = _selectedStudentIds.contains(sId);

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: isSelected ? accentGold.withValues(alpha: 0.5) : Colors.transparent,
                                                ),
                                              ),
                                              child: CheckboxListTile(
                                                dense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                                title: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: accentGold.withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        "#$serial",
                                                        style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: isDark ? accentGold : primaryNavy,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        sName,
                                                        style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
                                                          color: isDark ? Colors.white : Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                value: isSelected,
                                                activeColor: accentGold,
                                                checkColor: Colors.black,
                                                onChanged: (check) {
                                                  setState(() {
                                                    if (check == true) {
                                                      _selectedStudentIds.add(sId);
                                                    } else {
                                                      _selectedStudentIds.remove(sId);
                                                    }
                                                  });
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // زر حفظ وتأكيد العطلة
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xff0f172a) : Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -3))
                            ],
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentGold,
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                  : const Icon(Icons.check_circle_rounded, color: Colors.black),
                              label: Text(
                                _isSaving ? "جاري الحفظ..." : "تسجيل وتأكيد العطلة 🌴",
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              onPressed: _isSaving ? null : _submitHoliday,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1e293b).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: child,
    );
  }
}