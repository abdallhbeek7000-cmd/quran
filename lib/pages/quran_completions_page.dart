import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/theme_provider.dart';
import '../widgets/offline_wrapper.dart';

class QuranCompletionsPage extends StatefulWidget {
  const QuranCompletionsPage({super.key});

  @override
  State<QuranCompletionsPage> createState() => _QuranCompletionsPageState();
}

class _QuranCompletionsPageState extends State<QuranCompletionsPage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  String searchQuery = "";
  final TextEditingController searchCtrl = TextEditingController();

  // 📖 دالة تحديث عدد الختمات في الفايربيز (الحد الأدنى 0)
  Future<void> _updateCompletionsCount(String studentId, int currentCount, int delta) async {
    int newCount = currentCount + delta;
    if (newCount < 0) newCount = 0;

    await FirebaseFirestore.instance.collection('students').doc(studentId).update({
      'completionsCount': newCount,
      'lastCompletionDate': FieldValue.serverTimestamp(),
    });
  }

  // ✍️ نافذة تعديل عدد الختمات والملاحظات يدويًا
  void _showEditCompletionDialog(String studentId, String studentName, int currentCount, String currentNote, bool isDark) {
    final countCtrl = TextEditingController(text: currentCount.toString());
    final noteCtrl = TextEditingController(text: currentNote);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Icons.auto_stories_rounded, color: accentGold, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "تعديل ختمات: $studentName",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: "عدد الختمات في المعهد",
                      labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      prefixIcon: Icon(Icons.format_list_numbered_rounded, color: accentGold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: "ملاحظات (مثال: خاتم بمعهد آخر / يبدأ ختمته الأولى)",
                      labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      prefixIcon: Icon(Icons.edit_note_rounded, color: primaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? accentGold : primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        int? parsedCount = int.tryParse(countCtrl.text.trim());
                        if (parsedCount == null || parsedCount < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("يرجى إدخال عدد ختمات صحيح (0 أو أكثر)", style: TextStyle(fontFamily: 'Cairo'))),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        await FirebaseFirestore.instance.collection('students').doc(studentId).update({
                          'completionsCount': parsedCount,
                          'completionNotes': noteCtrl.text.trim(),
                          'lastCompletionDate': FieldValue.serverTimestamp(),
                        });

                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.green,
                            content: Text("تم حفظ سجل الختمة بنجاح 📖✨", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                icon: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                label: Text(isSaving ? "حفظ..." : "حفظ التعديل", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            "سجل الختمات القرآنية 📖✨",
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 18),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
        ),
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                      : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -30,
              left: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.15),
                ),
              ),
            ),

            SafeArea(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('students').where('archived', isEqualTo: false).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  final allDocs = snapshot.data!.docs;
                  final completedStudents = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    bool isCompletedType = data['studentType'] == 'completed';
                    bool hasCompletions = data.containsKey('completionsCount') && (data['completionsCount'] ?? 0) >= 0;
                    return isCompletedType || hasCompletions;
                  }).toList();

                  final filteredDocs = completedStudents.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    String name = data['name']?.toString() ?? '';
                    String serial = data['serial']?.toString() ?? '';
                    return name.contains(searchQuery) || serial.contains(searchQuery);
                  }).toList();

                  int totalCompletionsAll = 0;
                  for (var doc in completedStudents) {
                    var d = doc.data() as Map<String, dynamic>;
                    totalCompletionsAll += ((d['completionsCount'] as int?) ?? 0);
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: _buildGlassStatsHeader(completedStudents.length, totalCompletionsAll, isDark),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: _buildSearchBar(isDark),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filteredDocs.isEmpty
                            ? Center(
                                child: Text(
                                  "لا توجد نتائج تطابق البحث 🔍",
                                  style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white60 : Colors.black54),
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                itemCount: filteredDocs.length,
                                itemBuilder: (context, index) {
                                  var studentData = filteredDocs[index].data() as Map<String, dynamic>;
                                  String studentId = filteredDocs[index].id;
                                  return _buildStudentCompletionCard(studentId, studentData, isDark);
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassStatsHeader(int totalStudents, int totalCompletions, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.7), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 12, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentGold.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentGold, width: 1.5),
                ),
                child: Icon(Icons.auto_stories_rounded, color: accentGold, size: 32),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("سجل ختمات القرآن الكريم", style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor)),
                    const SizedBox(height: 4),
                    Text("معهد الشيخ سعيد العبدالله 🕌", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: isDark ? accentGold.withOpacity(0.9) : primaryColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      "$totalCompletions ختمة 📖",
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("الطلاب: $totalStudents خاتم", style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.25) : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : Colors.white70),
      ),
      child: TextField(
        controller: searchCtrl,
        onChanged: (val) => setState(() => searchQuery = val.trim()),
        style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: "ابحث باسم الطالب أو الرقم التسلسلي...",
          hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade500),
          prefixIcon: Icon(Icons.search_rounded, color: isDark ? accentGold : primaryColor),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    searchCtrl.clear();
                    setState(() => searchQuery = "");
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildStudentCompletionCard(String studentId, Map<String, dynamic> data, bool isDark) {
    String name = data['name'] ?? 'طالب خاتم';
    String serial = data['serial']?.toString() ?? '---';
    String imageUrl = data['imageUrl'] ?? '';
    int completionsCount = (data['completionsCount'] as int?) ?? 0;
    String note = data['completionNotes'] ?? '';
    String firstLetter = name.isNotEmpty ? name.trim().substring(0, 1) : "?";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accentGold, width: 2),
                        boxShadow: [BoxShadow(color: accentGold.withOpacity(0.2), blurRadius: 8)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (c, u) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                errorWidget: (c, u, e) => Center(child: Text(firstLetter, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 22, color: accentGold))),
                              )
                            : Center(child: Text(firstLetter, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 22, color: accentGold))),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.workspace_premium_rounded, color: accentGold, size: 18),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("الرقم التسلسلي: $serial", style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600)),
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text("💡 $note", style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? accentGold.withOpacity(0.9) : primaryColor, fontWeight: FontWeight.bold)),
                          ]
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.amber, size: 26),
                      onPressed: () => _showEditCompletionDialog(studentId, name, completionsCount, note, isDark),
                      tooltip: "تعديل بيانات الختمة",
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "الختمات في هذا المعهد:",
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: completionsCount > 0 ? () => _updateCompletionsCount(studentId, completionsCount, -1) : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: completionsCount > 0 ? Colors.redAccent.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: completionsCount > 0 ? Colors.redAccent.withOpacity(0.5) : Colors.grey.withOpacity(0.3)),
                            ),
                            child: Icon(Icons.remove_rounded, size: 18, color: completionsCount > 0 ? Colors.redAccent : Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accentGold, width: 1.2),
                          ),
                          child: Text(
                            "$completionsCount ختمة 🌟",
                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? accentGold : primaryColor),
                          ),
                        ),
                        const SizedBox(width: 12),

                        InkWell(
                          onTap: () => _updateCompletionsCount(studentId, completionsCount, 1),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.withOpacity(0.5)),
                            ),
                            child: const Icon(Icons.add_rounded, size: 18, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 80, color: isDark ? accentGold.withOpacity(0.4) : primaryColor.withOpacity(0.3)),
          const SizedBox(height: 15),
          Text(
            "لا يوجد طلاب خاتمون مسجلون حالياً",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : primaryColor),
          ),
          const SizedBox(height: 6),
          Text(
            "عند تغيير نوع الطالب إلى (طالب خاتم) سيظهر في هذا السجل تلقائياً",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}