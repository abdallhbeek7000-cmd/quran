import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../widgets/offline_wrapper.dart';

class AllCyclesStudentsPage extends StatefulWidget {
  const AllCyclesStudentsPage({super.key});

  @override
  State<AllCyclesStudentsPage> createState() => _AllCyclesStudentsPageState();
}

class _AllCyclesStudentsPageState extends State<AllCyclesStudentsPage> {
  final Color primaryNavy = const Color(0xff1e293b);
  final Color accentGold = const Color(0xffD4AF37);
  final Color softBlue = const Color(0xff3b82f6);

  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // 🎯 استخراج ذكي للرقم التسلسلي مع مراعاة كافة مسميات الفايربيس
  String _getStudentSerialNumber(Map<String, dynamic> data) {
    var rawValue = data['serialNumber'] ?? 
                   data['serial'] ?? 
                   data['studentId'] ?? 
                   data['sequenceNumber'] ?? 
                   data['idNumber'] ?? 
                   data['number'];

    if (rawValue != null && rawValue.toString().trim().isNotEmpty) {
      return rawValue.toString().trim();
    }
    return '';
  }

  // 🚀 نافذة النقل المستقبلية الفاخرة
  void _showTransferDialog(BuildContext context, Map<String, dynamic> studentData, String studentDocId, bool isDark) {
    String serial = _getStudentSerialNumber(studentData);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff0f172a).withOpacity(0.92) : Colors.white.withOpacity(0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                border: Border.all(color: accentGold.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: accentGold.withOpacity(0.15), blurRadius: 30, spreadRadius: 5)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50, height: 5,
                      decoration: BoxDecoration(color: accentGold.withOpacity(0.6), borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: accentGold.withOpacity(0.2), shape: BoxShape.circle),
                        child: Icon(Icons.published_with_changes_rounded, color: accentGold, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "نقل الطالب لدورة جديدة",
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : primaryNavy),
                            ),
                            Text(
                              "${studentData['name'] ?? ''} • #${serial.isNotEmpty ? serial : 'بدون رقم'}",
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: accentGold, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Text("اختر الدورة المستهدفة:", style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 14),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('cycles').snapshots(),
                    builder: (context, cycleSnap) {
                      if (cycleSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      }
                      if (!cycleSnap.hasData || cycleSnap.data!.docs.isEmpty) {
                        return const Text("لا توجد دورات متاحة حالياً.", style: TextStyle(fontFamily: 'Cairo'));
                      }

                      final cycles = cycleSnap.data!.docs;

                      return Column(
                        children: cycles.map((cDoc) {
                          final cData = cDoc.data() as Map<String, dynamic>;
                          final String cycleId = cDoc.id;
                          final String cycleName = "${cData['name'] ?? 'دورة'} (${cData['cycleNumber'] ?? 1})";
                          final bool isCurrent = studentData['cycleId'] == cycleId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isCurrent 
                                  ? Colors.orange.withOpacity(0.08) 
                                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isCurrent ? Colors.orange.shade400 : accentGold.withOpacity(0.3), width: 1.2),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              title: Text(cycleName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : primaryNavy)),
                              subtitle: Text(
                                isCurrent ? "الدورة الحالية للطالب 📌" : "جاهزة للنقل إليها ⚡",
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isCurrent ? Colors.orange : Colors.green.shade400, fontWeight: FontWeight.bold),
                              ),
                              trailing: isCurrent
                                  ? const Icon(Icons.check_circle_rounded, color: Colors.orange)
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [accentGold, const Color(0xffb8860b)]),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: accentGold.withOpacity(0.3), blurRadius: 8)],
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                                        onPressed: () => _executeTransfer(studentDocId, cycleId, cycleName),
                                        child: const Text("نقل ➔", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ⚡ تنفيذ نقل الطالب مع الاحتفاظ بكافة بياناته المرتكزة على رقمه
  Future<void> _executeTransfer(String studentDocId, String newCycleId, String newCycleName) async {
    try {
      await FirebaseFirestore.instance.collection('students').doc(studentDocId).update({
        'cycleId': newCycleId,
        'cycleName': newCycleName,
        'transferredAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xff10b981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            content: Text("تم نقل الطالب بنجاح إلى $newCycleName 🎉", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.redAccent, content: Text("فشلت عملية النقل، حاول مجدداً", style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDark ? const Color(0xff0b1120) : const Color(0xfff8fafc),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2)),
            ),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(color: isDark ? Colors.white : primaryNavy),
          title: Text("جميع طلاب الدورات 🎒", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryNavy, fontFamily: 'Cairo', fontSize: 18)),
        ),
        body: Stack(
          children: [
            // 🌌 خلفية حيوية متدرجة ذات دوائر نيون سحرية
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                      ? [const Color(0xff0b1120), const Color(0xff1e293b), const Color(0xff0f172a)] 
                      : [const Color(0xfff1f5f9), const Color(0xffe2e8f0), const Color(0xffcbd5e1)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -60, right: -60,
              child: Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, color: accentGold.withOpacity(isDark ? 0.08 : 0.15))),
            ),
            Positioned(
              bottom: 100, left: -80,
              child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: softBlue.withOpacity(isDark ? 0.08 : 0.12))),
            ),

            SafeArea(
              child: Column(
                children: [
                  // 🔍 شريط البحث الكريستالي
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.white.withOpacity(0.8), width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                            style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: "ابحث باسم الطالب أو الرقم التسلسلي...",
                              hintStyle: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                              border: InputBorder.none,
                              icon: Icon(Icons.search_rounded, color: accentGold, size: 22),
                              suffixIcon: _searchQuery.isNotEmpty 
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18), 
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = "");
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 📊 لوحة الإحصائيات السريعة للسيستم
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('students').snapshots(),
                    builder: (context, snapshot) {
                      int totalStudents = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.white.withOpacity(0.6)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.groups_rounded, color: accentGold, size: 20),
                                  const SizedBox(width: 8),
                                  Text("إجمالي الطلاب المسجلين:", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(color: accentGold.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                child: Text("$totalStudents طالب", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: accentGold)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // 📜 قائمة الطلاب المنسقة ببراعة وبأعلى ترتّب تسلسلي
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('students').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text("لا يوجد طلاب مسجلين بالسيستم حالياً", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54)),
                          );
                        }

                        var docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);

                        // 🔢 ترتيب رياضي دقيق وتصاعدي حسب الرقم التسلسلي
                        docs.sort((a, b) {
                          var dataA = a.data() as Map<String, dynamic>;
                          var dataB = b.data() as Map<String, dynamic>;

                          String strA = _getStudentSerialNumber(dataA);
                          String strB = _getStudentSerialNumber(dataB);

                          int numA = int.tryParse(strA) ?? 999999;
                          int numB = int.tryParse(strB) ?? 999999;

                          return numA.compareTo(numB);
                        });

                        // 🔍 تصفية نتائج البحث
                        if (_searchQuery.isNotEmpty) {
                          docs = docs.where((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            String name = (data['name'] ?? '').toString().toLowerCase();
                            String serial = _getStudentSerialNumber(data).toLowerCase();
                            return name.contains(_searchQuery) || serial.contains(_searchQuery);
                          }).toList();
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final studentDoc = docs[index];
                            final data = studentDoc.data() as Map<String, dynamic>;

                            final String name = data['name'] ?? 'بدون اسم';
                            final String serial = _getStudentSerialNumber(data);
                            final String? imageUrl = data['imageUrl'];
                            final String currentCycle = data['cycleName'] ?? 'دورة غير محددة';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.white.withOpacity(0.8), width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // 🖼️ الصورة الشخصية مع إطار متوهج
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: 52, height: 52,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(colors: [accentGold, softBlue]),
                                              ),
                                            ),
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
                                              backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                                              child: (imageUrl == null || imageUrl.isEmpty) ? Icon(Icons.person, color: accentGold, size: 26) : null,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),

                                        // 👤 تفاصيل الطالب
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: isDark ? Colors.white : primaryNavy,
                                                      ),
                                                    ),
                                                  ),
                                                  // 🏷️ وسام الرقم التسلسلي الأنيق
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: accentGold.withOpacity(0.18),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(color: accentGold.withOpacity(0.4), width: 1),
                                                    ),
                                                    child: Text(
                                                      serial.isNotEmpty ? "#$serial" : "بدون رقم",
                                                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: accentGold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(Icons.workspace_premium_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      "الدورة الحالية: $currentCycle",
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        // 🔁 زر النقل الكريستالي الجذاب
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _showTransferDialog(context, data, studentDoc.id, isDark),
                                            borderRadius: BorderRadius.circular(14),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: isDark ? primaryNavy.withOpacity(0.8) : primaryNavy,
                                                borderRadius: BorderRadius.circular(14),
                                                boxShadow: [BoxShadow(color: primaryNavy.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.white),
                                                  SizedBox(width: 4),
                                                  Text("نقل", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
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
      ),
    );
  }
}