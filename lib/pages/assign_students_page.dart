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

  // 🔍 تحكم بالبحث
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

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
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية المتدرجة الانسيابية
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
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.07) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 60,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          // 🏢 2. المحتوى الأساسي للواجهة
          SafeArea(
            child: Column(
              children: [
                // 🧊 لوحة التحكم العلوية والبحث التفاعلي
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      // 🔍 شريط البحث المصمم بزجاجية أنيقة
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                              filled: true,
                              fillColor: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.white),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.white.withOpacity(0.7)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: isDarkMode ? accentGold : primaryColor, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // التوزيع السريع لمشرف محدد
                      _buildGlassContainer(
                        isDarkMode: isDarkMode,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "التوزيع السريع لمشرف محدد:", 
                              style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white70 : primaryColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            StreamBuilder(
                              stream: firestore.collection('supervisors').snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox();
                                final supervisors = snapshot.data!.docs;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 15),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
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
                                        return DropdownMenuItem(
                                          value: s.id,
                                          child: Text(s['name'] ?? s['email']), 
                                        );
                                      }).toList(),
                                      onChanged: (v) {
                                        final sup = supervisors.firstWhere((e) => e.id == v);
                                        setState(() {
                                          globalSupervisorId = sup.id;
                                          globalSupervisorName = sup['name'] ?? sup['email'];
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

                // 🧊 قائمة الطلاب الزجاجية
                Expanded(
                  child: StreamBuilder(
                    stream: firestore
                        .collection('students')
                        .where('cycleId', isEqualTo: widget.cycle.id)
                        .where('archived', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      var docs = snapshot.data!.docs.toList();

                      if (docs.isEmpty) return _buildEmptyState(isDarkMode);

                      // 🔢 🚀 الترتيب التلقائي التنازلي/التصاعدي حسب الرقم التسلسلي المعتمد (serial)
                      docs.sort((a, b) {
                        var dataA = a.data();
                        var dataB = b.data();

                        int serialA = int.tryParse(dataA['serial']?.toString() ?? '') ?? 99999999;
                        int serialB = int.tryParse(dataB['serial']?.toString() ?? '') ?? 99999999;

                        return serialA.compareTo(serialB);
                      });

                      // 🔍 تصفية القائمة بالبحث
                      if (searchQuery.isNotEmpty) {
                        docs = docs.where((doc) {
                          var data = doc.data();
                          String name = (data['name'] ?? '').toString().toLowerCase();
                          String serial = (data['serial'] ?? '').toString().toLowerCase();
                          return name.contains(searchQuery) || serial.contains(searchQuery);
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Text("لا توجد نتائج تطابق بحثك 🔍", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white60 : primaryColor)),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 25),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final student = docs[index];
                          final data = student.data();
                          final String imageUrl = data['imageUrl'] ?? '';
                          final String studentName = data['name'] ?? 'بدون اسم';
                          final String serial = data['serial']?.toString() ?? '---';
                          final String firstLetter = studentName.isNotEmpty ? studentName.trim().substring(0, 1) : "?";

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: _buildGlassContainer(
                              isDarkMode: isDarkMode,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 🔢 شارة الرقم التسلسلي المعتمد
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      margin: const EdgeInsets.only(left: 8),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.15),
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
                                        color: isDarkMode ? Colors.white10 : primaryColor.withOpacity(0.08),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
                                        ]
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
                                title: Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontSize: 14, fontFamily: 'Cairo')),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    data['supervisorName'] == '' || data['supervisorName'] == null ? '⚠️ غير موزع' : "🔹 المشرف: ${data['supervisorName']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      fontFamily: 'Cairo',
                                      color: data['supervisorName'] == '' || data['supervisorName'] == null ? Colors.orange : Colors.green,
                                    ),
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
                                      color: globalSupervisorId == null ? Colors.grey : Colors.white
                                    )
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🧊 أداة مساعدة لتغليف العناصر وتأثير الزجاج (Glassmorphism)
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.02),
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

  // 🧊 واجهة الحالة الفارغة
  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 70, color: isDarkMode ? accentGold.withOpacity(0.6) : primaryColor.withOpacity(0.4)),
            const SizedBox(height: 15),
            Text(
              "لا يوجد طلاب حالياً في هذه الدورة",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white60 : primaryColor.withOpacity(0.7), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}