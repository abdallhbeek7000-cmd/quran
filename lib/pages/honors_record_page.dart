import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../models/cycle_model.dart';
import '../services/theme_provider.dart';
import '../services/cloudinary_helper.dart';

class HonorsRecordPage extends StatefulWidget {
  final CycleModel cycle;
  final String role; // 👈 استقبال دور المستخدم

  const HonorsRecordPage({
    super.key,
    required this.cycle,
    this.role = 'supervisor', // افتراضياً مشرف في حال عدم التمرير
  });

  @override
  State<HonorsRecordPage> createState() => _HonorsRecordPageState();
}

class _HonorsRecordPageState extends State<HonorsRecordPage> {
  final Color primaryNavy = const Color(0xff1e293b);
  final Color accentGold = const Color(0xffD4AF37);
  final Color softBlue = const Color(0xff3b82f6);

  // التحقق هل المستخدم مدير
  bool get isManager => widget.role == 'manager';

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
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
          "سجل التكريمات 🏅",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : primaryNavy,
          ),
        ),
      ),
      // 👈 يظهر زر إضافة تكريم جديد فقط إذا كان المستخدم مديراً
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              backgroundColor: accentGold,
              elevation: 6,
              icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.black),
              label: const Text(
                "إضافة تكريم جديد",
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black),
              ),
              onPressed: () => _showAddHonorDialog(isDark),
            )
          : null,
      body: Stack(
        children: [
          Positioned(
            top: -50, right: -50,
            child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: accentGold.withValues(alpha: isDark ? 0.08 : 0.12))),
          ),
          Positioned(
            bottom: 100, left: -60,
            child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: softBlue.withValues(alpha: isDark ? 0.08 : 0.12))),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1e293b).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? accentGold.withValues(alpha: 0.3) : primaryNavy.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: accentGold.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: Icon(Icons.workspace_premium_rounded, color: accentGold, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("تكريمات الدورة الفعالة 🎖️", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                              Text(
                                widget.cycle.name,
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : primaryNavy),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('honors_records')
                        .where('cycleId', isEqualTo: widget.cycle.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text("حدث خطأ في تحميل البيانات ⚠️", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : primaryNavy)),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.stars_rounded, size: 70, color: accentGold.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                "لا يوجد سجل تكريمات لهذه الدورة بعد ✨",
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
                              ),
                            ],
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs.toList();
                      docs.sort((a, b) {
                        var dataA = a.data() as Map<String, dynamic>;
                        var dataB = b.data() as Map<String, dynamic>;
                        Timestamp? tA = dataA['date'] as Timestamp?;
                        Timestamp? tB = dataB['date'] as Timestamp?;
                        if (tA == null || tB == null) return 0;
                        return tB.compareTo(tA);
                      });

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                        physics: const BouncingScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          String docId = docs[index].id;
                          return _buildHonorCard(docId, data, isDark);
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
  }

  Widget _buildHonorCard(String docId, Map<String, dynamic> data, bool isDark) {
    String weekTitle = data['weekTitle'] ?? 'تكريم أسبوعي';
    List names = data['names'] ?? [];
    String imageUrl = data['imageUrl'] ?? '';
    Timestamp? ts = data['date'] as Timestamp?;
    String dateStr = ts != null ? intl.DateFormat('yyyy/MM/dd').format(ts.toDate()) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1e293b).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              GestureDetector(
                onTap: () => _showImageDialog(imageUrl),
                child: Stack(
                  children: [
                    Image.network(
                      imageUrl,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 190,
                          color: isDark ? Colors.black26 : Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text("تكبير", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 10)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.stars_rounded, color: accentGold, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            weekTitle,
                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : primaryNavy),
                          ),
                        ],
                      ),
                      // 👈 يظهر زر الحذف فقط إذا كان المستخدم مديراً
                      if (isManager)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => _confirmDelete(docId),
                        )
                    ],
                  ),
                  if (dateStr.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? Colors.white54 : Colors.black45),
                        const SizedBox(width: 6),
                        Text(
                          "تاريخ التكريم: $dateStr",
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text("الطلاب المكرمون 🌟:", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12, color: isDark ? accentGold : primaryNavy)),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: names.map((name) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? accentGold.withValues(alpha: 0.15) : softBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? accentGold.withValues(alpha: 0.3) : softBlue.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          name.toString(),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : primaryNavy,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHonorDialog(bool isDark) {
    TextEditingController weekController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    List<String> addedNames = [];
    String? uploadedImageUrl;
    DateTime selectedDate = DateTime.now();
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff0f172a) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(10))),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          "تسجيل تكريم جديد 🏅",
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : primaryNavy),
                        ),
                      ),
                      const SizedBox(height: 18),

                      TextField(
                        controller: weekController,
                        decoration: InputDecoration(
                          labelText: "اسم الأسبوع / الفعالية (مثال: الأسبوع الأول)",
                          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                          prefixIcon: const Icon(Icons.stars_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      InkWell(
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "تاريخ التكريم: ${intl.DateFormat('yyyy/MM/dd').format(selectedDate)}",
                                style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : primaryNavy),
                              ),
                              const Icon(Icons.calendar_month_rounded, color: Colors.amber),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: "اسم الطالب المكرم",
                                labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                                prefixIcon: const Icon(Icons.person_add_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  setModalState(() {
                                    addedNames.add(val.trim());
                                    nameController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: accentGold),
                            icon: const Icon(Icons.add, color: Colors.black),
                            onPressed: () {
                              if (nameController.text.trim().isNotEmpty) {
                                setModalState(() {
                                  addedNames.add(nameController.text.trim());
                                  nameController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: addedNames.map((name) {
                          return Chip(
                            label: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setModalState(() => addedNames.remove(name));
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: () async {
                          setModalState(() => isUploading = true);
                          String? url = await CloudinaryHelper.pickAndUploadProfileImage();
                          setModalState(() {
                            uploadedImageUrl = url;
                            isUploading = false;
                          });
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accentGold.withValues(alpha: 0.5), style: BorderStyle.solid),
                          ),
                          child: isUploading
                              ? const Center(child: CircularProgressIndicator())
                              : uploadedImageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(uploadedImageUrl!, fit: BoxFit.cover),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo_rounded, color: accentGold, size: 30),
                                        const SizedBox(height: 6),
                                        Text(
                                          "اضغط هنا لرفع الصورة الجماعية 📸",
                                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                                        )
                                      ],
                                    ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGold,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            if (weekController.text.isEmpty || addedNames.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("يرجى إدخال اسم الأسبوع واسم طالب واحد على الأقل", style: TextStyle(fontFamily: 'Cairo'))),
                              );
                              return;
                            }

                            await FirebaseFirestore.instance.collection('honors_records').add({
                              'cycleId': widget.cycle.id,
                              'weekTitle': weekController.text.trim(),
                              'date': Timestamp.fromDate(selectedDate),
                              'names': addedNames,
                              'imageUrl': uploadedImageUrl ?? '',
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                          child: const Text("حفظ سجل التكريم ✨", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف التكريم", style: TextStyle(fontFamily: 'Cairo')),
        content: const Text("هل أنت تأكد من حذف هذا التكريم؟", style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('honors_records').doc(docId).delete();
              if (!mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
          ),
        ],
      ),
    );
  }
}