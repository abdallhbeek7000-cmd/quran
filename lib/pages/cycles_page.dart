import 'dart:ui'; // 🎯 لتأثير الزجاج والـ Blur
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // 🎯 لقراءة المظهر
import '../services/cycle_service.dart';
import '../models/cycle_model.dart'; 
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider
import 'students_page.dart'; 

class CyclesPage extends StatefulWidget {
  const CyclesPage({super.key});

  @override
  State<CyclesPage> createState() => _CyclesPageState();
}

class _CyclesPageState extends State<CyclesPage> {
  final firestore = FirebaseFirestore.instance;
  final cycleService = CycleService();
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // لون الإنعكاس الزجاجي

  archiveCycle(String id) async {
    await cycleService.archiveCycle(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.orange,
        content: Text("تمت أرشفة الدورة بنجاح"),
      ),
    );
  }

  Future<void> _editEndDate(BuildContext context, String cycleId, String currentEndDateStr, bool isDarkMode) async {
    DateTime initialDate = DateTime.now();
    try {
      initialDate = DateTime.parse(currentEndDateStr);
    } catch (_) {}

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: isDarkMode ? accentGold : primaryColor,
              onPrimary: Colors.white,
              surface: isDarkMode ? const Color(0xff1e293b) : Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black87,
            ),
            dialogBackgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      await firestore.collection('cycles').doc(cycleId).update({
        'endDate': pickedDate.toString(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("تم تحديث تاريخ انتهاء الدورة بنجاح 🎉"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // قراءة المظهر
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف
        title: Text("إدارة الدورات", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية المتدرجة الانسيابية مع الدوائر العائمة
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
            right: -40,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          // 🏢 2. المحتوى الأساسي للواجهة
          SafeArea(
            child: StreamBuilder(
              stream: firestore.collection('cycles').orderBy('startDate', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return _buildEmptyState(isDarkMode);
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final cycle = docs[index];
                    final data = cycle.data();
                    bool isArchived = data['archived'] ?? false;
                    String endDateStr = data['endDate']?.toString() ?? DateTime.now().toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: _buildGlassContainer(
                        isDarkMode: isDarkMode,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: isArchived ? (isDarkMode ? Colors.white10 : Colors.grey[300]) : (isDarkMode ? accentGold.withOpacity(0.2) : primaryColor.withOpacity(0.1)),
                              child: Icon(
                                isArchived ? Icons.archive_outlined : Icons.calendar_today_rounded,
                                color: isArchived ? Colors.grey : (isDarkMode ? accentGold : primaryColor),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              data['name'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isArchived ? Colors.grey : (isDarkMode ? Colors.white : Colors.black87),
                                decoration: isArchived ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text(
                              "رقم الدورة: ${data['cycleNumber'] ?? ''}",
                              style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey[600]),
                            ),
                            
                            // زر الإجراء في اليمين
                            trailing: isArchived 
                              ? IconButton(
                                  icon: Icon(Icons.visibility_outlined, size: 22, color: isDarkMode ? Colors.blueGrey.shade300 : Colors.blueGrey),
                                  tooltip: "استعراض أرشيف طلاب الدورة",
                                  onPressed: () {
                                    final dynamic outputModel = CycleModel;
                                    Navigator.push(
                                      context, 
                                      MaterialPageRoute(
                                        builder: (_) => StudentsPage(
                                          cycle: (outputModel is CycleModel) ? (cycle as dynamic) : (cycle as dynamic),
                                          role: "manager",
                                          uid: "",
                                          isArchivedFromHistory: true, // وضع التصفح التام والآمن 🔒
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Icon(Icons.arrow_drop_down_circle_outlined, color: isDarkMode ? accentGold : primaryColor, size: 20),
                              
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                child: Column(
                                  children: [
                                    Divider(color: isDarkMode ? Colors.white24 : Colors.black12),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildDateInfo("تاريخ البدء", data['startDate'].toString().split(' ')[0], Icons.login_rounded, Colors.green, isDarkMode),
                                        InkWell(
                                          onTap: isArchived ? null : () => _editEndDate(context, cycle.id, endDateStr, isDarkMode),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            child: Row(
                                              children: [
                                                _buildDateInfo("تاريخ الانتهاء", endDateStr.split(' ')[0], Icons.logout_rounded, Colors.redAccent, isDarkMode),
                                                if (!isArchived) ...[
                                                  const SizedBox(width: 6),
                                                  Icon(Icons.edit_calendar_rounded, size: 16, color: isDarkMode ? accentGold : primaryColor),
                                                ]
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (!isArchived) ...[
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: OutlinedButton.icon(
                                          onPressed: () => archiveCycle(cycle.id),
                                          icon: const Icon(Icons.archive, size: 18),
                                          label: const Text("نقل إلى الأرشيف", style: TextStyle(fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                            side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                                            backgroundColor: isDarkMode ? Colors.redAccent.withOpacity(0.1) : Colors.red.shade50,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                          ),
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              )
                            ],
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
    );
  }

  // 🧊 أداة مساعدة لتغليف العناصر وتأثير الزجاج (Glassmorphism)
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

  // 🧊 أداة عرض بيانات التواريخ بستايل متناسق مع المظهر
  Widget _buildDateInfo(String label, String date, IconData icon, Color color, bool isDarkMode) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white60 : Colors.grey)),
          ],
        ),
        const SizedBox(height: 5),
        Text(date, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkMode ? Colors.white : Colors.black87)),
      ],
    );
  }

  // 🧊 واجهة الحالة الفارغة بستايل زجاجي
  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_outlined, size: 80, color: isDarkMode ? accentGold.withOpacity(0.6) : primaryColor.withOpacity(0.4)),
            const SizedBox(height: 15),
            Text(
              "لا توجد دورات مسجلة حالياً",
              style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white60 : primaryColor.withOpacity(0.7), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}