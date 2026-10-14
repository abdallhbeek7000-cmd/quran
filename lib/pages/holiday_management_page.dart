import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  List<DocumentSnapshot> _allStudents = [];
  bool _isLoadingStudents = true;

  final Color primaryNavy = const Color(0xff1e293b);
  final Color accentGold = const Color(0xffD4AF37);

  @override
  void initState() {
    super.initState();
    _fetchStudentsOnce();
  }

  Future<void> _fetchStudentsOnce() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('cycleId', isEqualTo: widget.cycle.id)
          .where('archived', isEqualTo: false)
          .get();

      if (mounted) {
        setState(() {
          _allStudents = snap.docs;
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

    setState(() => _isSaving = true);

    try {
      final todayStr = DateTime.now().toString().split(' ')[0];
      final nowTimestamp = FieldValue.serverTimestamp();

      final targetStudents = _applyToAll
          ? _allStudents
          : _allStudents.where((doc) => _selectedStudentIds.contains(doc.id)).toList();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // حفظ العطلة في كولكشن sessions مباشرة لكل طالب لضمان ظهورها باستعلام الطالب المباشر
      for (var studentDoc in targetStudents) {
        final studentData = studentDoc.data() as Map<String, dynamic>;
        final sessionRef = FirebaseFirestore.instance.collection('sessions').doc();

        batch.set(sessionRef, {
          'studentId': studentDoc.id,
          'studentName': studentData['name'] ?? '',
          'cycleId': widget.cycle.id,
          'date': todayStr,
          'createdAt': nowTimestamp,
          'actualCreatedAt': todayStr,
          'isHoliday': true,
          'sessionType': 'holiday',
          'status': 'عطلة',
          'title': 'عطلة: ${_reasonController.text.trim()}',
          'note': _reasonController.text.trim(),
          'notes': _reasonController.text.trim(),
          'sessionNumber': null, // لا يحسب ضمن الترقيم
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text("تم تسجيل العطلة لـ ${targetStudents.length} طالب بنجاح 🎉", style: const TextStyle(fontFamily: 'Cairo')),
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
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDark ? const Color(0xff0b1120) : const Color(0xfff8fafc),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            "إدارة وتسجيل العطلات 🌴",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : primaryNavy,
              fontFamily: 'Cairo',
              fontSize: 18,
            ),
          ),
          iconTheme: IconThemeData(color: isDark ? Colors.white : primaryNavy),
        ),
        body: Stack(
          children: [
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
                                _buildGlassCard(
                                  isDark: isDark,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.event_note_rounded, color: isDark ? accentGold : primaryNavy, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            "الدورة الفعالة: ${widget.cycle.name}",
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : primaryNavy,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 15),
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
                                          hintText: "مثال: عطلة رسمية / رحلة المعهد...",
                                          hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
                                          filled: true,
                                          fillColor: isDark ? Colors.black26 : Colors.white60,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

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
                                        title: const Text("جميع الطلاب في الدورة", style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                                        value: true,
                                        groupValue: _applyToAll,
                                        activeColor: Colors.amber,
                                        onChanged: (val) => setState(() => _applyToAll = val!),
                                      ),
                                      RadioListTile<bool>(
                                        title: const Text("تحديد طلاب محددين فقط", style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                                        value: false,
                                        groupValue: _applyToAll,
                                        activeColor: Colors.amber,
                                        onChanged: (val) => setState(() => _applyToAll = val!),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

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
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.amber),
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
                                            hintText: "ابحث بالاسم...",
                                            prefixIcon: const Icon(Icons.search, size: 18),
                                            filled: true,
                                            fillColor: isDark ? Colors.black26 : Colors.white60,
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
                                            final isSelected = _selectedStudentIds.contains(sId);

                                            return CheckboxListTile(
                                              title: Text(sName, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                                              value: isSelected,
                                              activeColor: Colors.amber,
                                              onChanged: (check) {
                                                setState(() {
                                                  if (check == true) {
                                                    _selectedStudentIds.add(sId);
                                                  } else {
                                                    _selectedStudentIds.remove(sId);
                                                  }
                                                });
                                              },
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

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xff1e293b) : Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -3))
                            ],
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.check_circle_rounded, color: Colors.white),
                              label: Text(
                                _isSaving ? "جاري الحفظ..." : "تسجيل وتأكيد العطلة",
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
        color: isDark ? const Color(0xff1e293b).withOpacity(0.5) : Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: child,
    );
  }
}