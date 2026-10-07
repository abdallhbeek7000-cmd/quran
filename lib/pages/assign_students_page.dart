import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:provider/provider.dart';
import '../models/cycle_model.dart';
import '../services/student_service.dart';
import '../services/theme_provider.dart';

class AssignStudentsPage extends StatefulWidget {
  final CycleModel cycle;

  const AssignStudentsPage({
    super.key,
    required this.cycle,
  });

  @override
  State<AssignStudentsPage> createState() => _AssignStudentsPageState();
}

class _AssignStudentsPageState extends State<AssignStudentsPage> {
  final firestore = FirebaseFirestore.instance;
  final studentService = StudentService();
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  String? globalSupervisorId;
  String? globalSupervisorName;
  bool isResetting = false;

  // 🔍 تحكم بالبحث والصف الدراسي
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  String selectedGrade = 'الكل'; // 👈 الصف المحدد حالياً للفلترة

  // 🎓 القائمة الثابتة للصفوف الدراسية مثل صفحة الطالب
  final List<String> allGradesList = [
    "الكل",
    "الأول",
    "الثاني",
    "الثالث",
    "الرابع",
    "الخامس",
    "السادس",
    "السابع",
    "الثامن",
    "التاسع",
    "العاشر",
    "الحادي عشر",
    "البكالوريا",
    "جامعي"
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  assignStudent(String studentId, String supId, String supName) async {
    if (supId.isEmpty) return;

    await studentService.assignSupervisor(
      studentId: studentId,
      supervisorId: supId,
      supervisorName: supName,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primaryColor,
        content: Text("تم تعيين $supName بنجاح", style: const TextStyle(fontFamily: 'Cairo')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // 🚀 🔄 دالة سحب وإعادة ضبط كافة الطلاب بالدورة النشطة
  Future<void> _resetAllSupervisors(String activeCycleId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد إزالة التوزيع ⚠️", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text(
          "هل أنت أصلًا متاكد من سحب كافة الطلاب من جميع المشرفين في هذه الدورة لإعادة توزيعهم من جديد؟",
          style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("تأكيد السحب", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => isResetting = true);

    try {
      final snapshot = await firestore
          .collection('students')
          .where('cycleId', isEqualTo: activeCycleId)
          .where('archived', isEqualTo: false)
          .get();

      WriteBatch batch = firestore.batch();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'supervisorId': '',
          'supervisorName': '',
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("✅ تم سحب وإعادة ضبط توزيع كافة الطلاب بنجاح!", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("❌ حدث خطأ أثناء السحب: $e", style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) setState(() => isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('cycles')
          .where('active', isEqualTo: true)
          .where('archived', isEqualTo: false)
          .limit(1)
          .snapshots(),
      builder: (context, cycleSnap) {
        if (cycleSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
            appBar: AppBar(
              title: Text(
                "توزيع الطلاب على المشرفين 👥",
                style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo'),
              ),
              iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
              centerTitle: true,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        bool isCycleActive = cycleSnap.hasData && cycleSnap.data!.docs.isNotEmpty;
        final String activeCycleId = isCycleActive ? cycleSnap.data!.docs.first.id : widget.cycle.id;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Text(
              "توزيع الطلاب على المشرفين 👥", 
              style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo'),
            ),
            iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
            centerTitle: true,
            actions: [
              if (isCycleActive)
                IconButton(
                  tooltip: "إلغاء توزيع جميع الطلاب",
                  icon: isResetting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                      : const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                  onPressed: isResetting ? null : () => _resetAllSupervisors(activeCycleId),
                ),
            ],
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
              Positioned(
                top: -40,
                left: -50,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withValues(alpha: 0.07) : accentGold.withValues(alpha: 0.12)),
                ),
              ),
              Positioned(
                bottom: 60,
                right: -60,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withValues(alpha: 0.15) : primaryColor.withValues(alpha: 0.2)),
                ),
              ),

              SafeArea(
                child: !isCycleActive
                    ? Center(
                        child: _buildGlassContainer(
                          isDarkMode: isDarkMode,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event_busy_rounded, size: 70, color: Colors.orangeAccent),
                              const SizedBox(height: 15),
                              Text(
                                "لا توجد دورة نشطة حالياً 🚫",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "تم إغلاق الدورة. يرجى تفعيل أو فتح دورة جديدة للبدء بتوزيع الطلاب.",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: isDarkMode ? Colors.white60 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Column(
                              children: [
                                // 🔍 مربع البحث
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white.withValues(alpha: 0.7)),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (val) {
                                      setState(() {
                                        searchQuery = val.trim().toLowerCase();
                                      });
                                    },
                                    style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white : Colors.black87),
                                    decoration: InputDecoration(
                                      hintText: "ابحث باسم الطالب أو رقمه التسلسلي...",
                                      hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDarkMode ? Colors.white54 : Colors.black45),
                                      prefixIcon: Icon(Icons.search_rounded, color: isDarkMode ? accentGold : primaryColor),
                                      suffixIcon: searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(Icons.clear, color: isDarkMode ? Colors.white54 : Colors.black54),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() => searchQuery = '');
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // 👔 القائمة المنسدلة لتعيين المشرف
                                _buildGlassContainer(
                                  isDarkMode: isDarkMode,
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "التوزيع السريع لمشرف محدد:", 
                                        style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white70 : primaryColor.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 10),
                                      StreamBuilder<QuerySnapshot>(
                                        stream: firestore.collection('supervisors').snapshots(),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) return const SizedBox();
                                          final supervisors = snapshot.data!.docs;

                                          if (supervisors.isEmpty) {
                                            return const Padding(
                                              padding: EdgeInsets.symmetric(vertical: 8.0),
                                              child: Text("لا يوجد مشرفون مسجلون في النظام", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.orange)),
                                            );
                                          }

                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 15),
                                            decoration: BoxDecoration(
                                              color: isDarkMode ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.4),
                                              borderRadius: BorderRadius.circular(15),
                                              border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButtonFormField<String>(
                                                value: globalSupervisorId,
                                                dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                                style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                                decoration: const InputDecoration(border: InputBorder.none),
                                                hint: Text("اختر مشرفاً لتعيينه للكل...", style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white60 : Colors.black45, fontSize: 12)),
                                                items: supervisors.map((s) {
                                                  final map = s.data() as Map<String, dynamic>;
                                                  String displayName = map['name'] ?? map['email'] ?? 'مشرف';
                                                  return DropdownMenuItem(
                                                    value: s.id,
                                                    child: Text(displayName), 
                                                  );
                                                }).toList(),
                                                onChanged: (v) {
                                                  final sup = supervisors.firstWhere((e) => e.id == v);
                                                  final supData = sup.data() as Map<String, dynamic>;
                                                  setState(() {
                                                    globalSupervisorId = sup.id;
                                                    globalSupervisorName = supData['name'] ?? supData['email'] ?? 'مشرف';
                                                  });
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 🎓 اختيار الصف الدراسي (مطابق لصفحة إضافة الطالب)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "اختر صفاً بشكل سريع للفرز:",
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white70 : primaryColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // 🏫 شريط أزرار خيارات الصفوف السريعة
                          SizedBox(
                            height: 38,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: allGradesList.length,
                              itemBuilder: (context, index) {
                                String grade = allGradesList[index];
                                bool isSelected = selectedGrade == grade;

                                return Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() => selectedGrade = grade);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (isDarkMode ? accentGold : primaryColor)
                                            : (isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.6)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? (isDarkMode ? accentGold : primaryColor)
                                              : (isDarkMode ? Colors.white12 : Colors.black12),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          grade,
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected
                                                ? Colors.white
                                                : (isDarkMode ? Colors.white.withValues(alpha: 0.64) : primaryColor),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 📜 جلب وعرض قائمة الطلاب وفق الفرز
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: firestore
                                  .collection('students')
                                  .where('cycleId', isEqualTo: activeCycleId)
                                  .where('archived', isEqualTo: false)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                var allDocs = snapshot.data!.docs.toList();

                                if (allDocs.isEmpty) return _buildEmptyState(isDarkMode);

                                // 🔍 تطبيق الفلترة بالبحث والصف الدراسي المقترن
                                var filteredDocs = allDocs.where((doc) {
                                  var data = doc.data() as Map<String, dynamic>;
                                  String name = (data['name'] ?? '').toString().toLowerCase();
                                  String serial = (data['serial'] ?? '').toString().toLowerCase();
                                  String studentGrade = (data['grade'] ?? data['class'] ?? 'غير محدد').toString().trim();

                                  bool matchesSearch = searchQuery.isEmpty || name.contains(searchQuery) || serial.contains(searchQuery);
                                  bool matchesGrade = selectedGrade == 'الكل' || studentGrade == selectedGrade;

                                  return matchesSearch && matchesGrade;
                                }).toList();

                                // 🔢 ترتيب الطلاب حسب السيريال
                                filteredDocs.sort((a, b) {
                                  var dataA = a.data() as Map<String, dynamic>;
                                  var dataB = b.data() as Map<String, dynamic>;
                                  int serialA = int.tryParse(dataA['serial']?.toString() ?? '') ?? 99999999;
                                  int serialB = int.tryParse(dataB['serial']?.toString() ?? '') ?? 99999999;
                                  return serialA.compareTo(serialB);
                                });

                                return filteredDocs.isEmpty
                                    ? Center(
                                        child: Text(
                                          "لا يوجد طلاب في $selectedGrade 🔍",
                                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white60 : primaryColor),
                                        ),
                                      )
                                    : ListView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.only(left: 20, right: 20, top: 5, bottom: 25),
                                        itemCount: filteredDocs.length,
                                        itemBuilder: (context, index) {
                                          final student = filteredDocs[index];
                                          final data = student.data() as Map<String, dynamic>;
                                          final String imageUrl = data['imageUrl'] ?? '';
                                          final String studentName = data['name'] ?? 'بدون اسم';
                                          final String serial = data['serial']?.toString() ?? '---';
                                          final String studentGrade = data['grade'] ?? data['class'] ?? '';
                                          final String firstLetter = studentName.isNotEmpty ? studentName.trim().substring(0, 1) : "?";

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            child: _buildGlassContainer(
                                              isDarkMode: isDarkMode,
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: ListTile(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                                leading: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      margin: const EdgeInsets.only(left: 8),
                                                      decoration: BoxDecoration(
                                                        color: primaryColor.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        "#$serial",
                                                        style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: isDarkMode ? accentGold : primaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 46,
                                                      height: 46,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isDarkMode ? Colors.white10 : primaryColor.withValues(alpha: 0.08),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(23),
                                                        child: imageUrl.isNotEmpty
                                                            ? CachedNetworkImage(
                                                                imageUrl: imageUrl,
                                                                fit: BoxFit.cover,
                                                                placeholder: (context, url) => const Center(
                                                                  child: SizedBox(
                                                                    width: 18,
                                                                    height: 18,
                                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                                  ),
                                                                ),
                                                                errorWidget: (context, url, error) => Center(
                                                                  child: Text(
                                                                    firstLetter,
                                                                    style: TextStyle(color: isDarkMode ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
                                                                  ),
                                                                ),
                                                              )
                                                            : Center(
                                                                child: Text(
                                                                  firstLetter,
                                                                  style: TextStyle(color: isDarkMode ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
                                                                ),
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                title: Text(
                                                  studentName, 
                                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontSize: 14, fontFamily: 'Cairo'),
                                                ),
                                                subtitle: Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        data['supervisorName'] == '' || data['supervisorName'] == null 
                                                            ? '⚠️ غير موزع' 
                                                            : "🔹 المشرف: ${data['supervisorName']}",
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                          fontFamily: 'Cairo',
                                                          color: data['supervisorName'] == '' || data['supervisorName'] == null ? Colors.orange : Colors.green,
                                                        ),
                                                      ),
                                                      if (studentGrade.isNotEmpty) ...[
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          "• $studentGrade",
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            fontFamily: 'Cairo',
                                                            color: isDarkMode ? Colors.white54 : Colors.black45,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                trailing: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: globalSupervisorId == null 
                                                        ? (isDarkMode ? Colors.white12 : Colors.grey.shade300) 
                                                        : (isDarkMode ? accentGold : primaryColor),
                                                    elevation: globalSupervisorId == null ? 0 : 3,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  ),
                                                  onPressed: globalSupervisorId == null 
                                                      ? null 
                                                      : () => assignStudent(student.id, globalSupervisorId!, globalSupervisorName!),
                                                  child: Text(
                                                    "توزيع", 
                                                    style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontWeight: FontWeight.bold, 
                                                      fontSize: 12,
                                                      color: globalSupervisorId == null ? Colors.grey : Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 70, color: isDarkMode ? accentGold.withValues(alpha: 0.6) : primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 15),
            Text(
              "لا يوجد طلاب حالياً في هذه الدورة",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white60 : primaryColor.withValues(alpha: 0.7), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}