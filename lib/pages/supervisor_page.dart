import 'dart:ui'; // 🎯 ضرورية لتأثير الزجاج والـ Blur
import 'package:flutter/material.dart';
import 'package:quran_habal/services/cloudinary_helper.dart';
import 'add_supervisor_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // 🎯 لقراءة المظهر
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider

class SupervisorPage extends StatelessWidget {
  const SupervisorPage({super.key});

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // لون الإنعكاس الزجاجي

  // 🎯 نافذة التأكيد والتحذير قبل حذف المشرف نهائياً (متوافقة مع المظهر)
  void _showDeleteConfirmationDialog(BuildContext context, String docId, String supervisorName, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 10),
              Text(
                "تأكيد حذف المشرف",
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87),
              ),
            ],
          ),
          content: Text(
            "هل أنت متأكد من رغبتك في حذف حساب المشرف ($supervisorName) نهائياً من المنظومة؟\n\n⚠️ تنبيه: هذا الإجراء لا يمكن التراجع عنه.",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.4, color: isDarkMode ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text(
                "حذف نهائي", 
                style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext); // إغلاق الدايلوج أولاً
                
                await FirebaseFirestore.instance
                    .collection('supervisors')
                    .doc(docId)
                    .delete();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red.shade900,
                      content: Text("تم حذف المشرف ($supervisorName) بنجاح 🗑️", style: const TextStyle(fontFamily: 'Cairo')),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 🎯 نافذة التعديل (BottomSheet) بستايل زجاجي وألوان متناسقة
  void _showEditBottomSheet(BuildContext context, String docId, Map<String, dynamic> currentData, bool isDarkMode) {
    final TextEditingController nameEditController = TextEditingController(text: currentData['name']);
    String? currentImgUrl = currentData['imageUrl'];
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, // لجعل الحواف شفافة وتطبيق الزجاج
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setModalState) {
            return Container(
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xff121212).withOpacity(0.9) : Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 50, height: 5, decoration: BoxDecoration(color: isDarkMode ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(5))),
                          const SizedBox(height: 25),
                          Text("تعديل بيانات المشرف", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
                          const SizedBox(height: 25),
                          
                          GestureDetector(
                            onTap: isUploading ? null : () async {
                              setModalState(() => isUploading = true);
                              String? newUrl = await CloudinaryHelper.pickAndUploadProfileImage();
                              if (newUrl != null) {
                                setModalState(() {
                                  currentImgUrl = newUrl;
                                });
                              }
                              setModalState(() => isUploading = false);
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.grey[200],
                                    backgroundImage: currentImgUrl != null && currentImgUrl!.isNotEmpty
                                        ? NetworkImage(currentImgUrl!)
                                        : null,
                                    child: currentImgUrl == null || currentImgUrl!.isEmpty
                                        ? Icon(Icons.camera_alt_outlined, color: isDarkMode ? accentGold : primaryColor, size: 35)
                                        : null,
                                  ),
                                ),
                                if (isUploading)
                                  const Positioned.fill(child: CircularProgressIndicator(color: Colors.white)),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    backgroundColor: isDarkMode ? accentGold : primaryColor,
                                    radius: 16,
                                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text("اضغط على الصورة لتغييرها", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          const SizedBox(height: 25),
                          
                          TextField(
                            controller: nameEditController,
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
                            decoration: _glassInputDecoration("اسم المشرف الكامل", Icons.person, isDarkMode),
                          ),
                          const SizedBox(height: 30),
                          
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDarkMode ? accentGold : primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    elevation: 2,
                                  ),
                                  onPressed: () async {
                                    if (nameEditController.text.trim().isEmpty) return;
                                    
                                    await FirebaseFirestore.instance
                                        .collection('supervisors')
                                        .doc(docId)
                                        .update({
                                      'name': nameEditController.text.trim(),
                                      'imageUrl': currentImgUrl ?? '',
                                    });
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث البيانات بنجاح", style: TextStyle(fontFamily: 'Cairo'))),
                                      );
                                    }
                                  },
                                  child: const Text("حفظ التعديلات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.grey.shade400),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  child: Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف
        title: Text("قائمة المشرفين", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddSupervisorPage(),
            ),
          );
        },
        child: const Icon(Icons.person_add_alt_1, color: Colors.white),
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية الانسيابية مع الدوائر العائمة (Blobs)
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
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          // 🏢 2. المحتوى الأساسي للواجهة
          SafeArea(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('supervisors').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final supervisors = snapshot.data!.docs;

                if (supervisors.isEmpty) {
                  return _buildEmptyState(isDarkMode);
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: supervisors.length,
                  itemBuilder: (context, index) {
                    final supervisor = supervisors[index];
                    final data = supervisor.data() as Map<String, dynamic>;
                    String? imageUrl = data['imageUrl'];
                    String sName = data['name'] ?? 'بدون اسم';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: _buildGlassContainer(
                        isDarkMode: isDarkMode,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          onTap: () => _showEditBottomSheet(context, supervisor.id, data, isDarkMode), 
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDarkMode ? Colors.white10 : primaryColor.withOpacity(0.08),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: imageUrl != null && imageUrl.isNotEmpty 
                                  ? Image.network(imageUrl, fit: BoxFit.cover)
                                  : Icon(Icons.person, color: isDarkMode ? accentGold : primaryColor, size: 28),
                            ),
                          ),
                          title: Text(
                            sName,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.email_outlined, size: 13, color: isDarkMode ? Colors.white54 : Colors.grey[600]),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    data['email'] ?? '',
                                    style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey[700], fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 26),
                            tooltip: "حذف المشرف",
                            onPressed: () => _showDeleteConfirmationDialog(context, supervisor.id, sName, isDarkMode),
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
    );
  }

  // 🧊 أداة مساعدة لتغليف العناصر وتأثير الزجاج (Glassmorphism)
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
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

  // 🧊 تنسيق حقول الإدخال داخل الـ BottomSheet
  InputDecoration _glassInputDecoration(String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Cairo'),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05), 
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15), 
        borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.black12, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15), 
        borderSide: BorderSide(color: isDarkMode ? accentGold : primaryColor, width: 1.5),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_rounded, size: 80, color: isDarkMode ? accentGold.withOpacity(0.6) : primaryColor.withOpacity(0.4)),
            const SizedBox(height: 15),
            Text(
              "لا يوجد مشرفين مضافين بعد",
              style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[700], fontSize: 15, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}