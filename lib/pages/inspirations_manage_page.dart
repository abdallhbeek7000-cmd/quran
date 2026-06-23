import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class InspirationsManagePage extends StatefulWidget {
  const InspirationsManagePage({super.key});

  @override
  State<InspirationsManagePage> createState() => _InspirationsManagePageState();
}

class _InspirationsManagePageState extends State<InspirationsManagePage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();

  // تغيير حالة التفعيل
  void _toggleInspirationStatus(bool val) async {
    await FirebaseFirestore.instance.collection('settings').doc('general').set({
      'is_inspiration_active': val,
    }, SetOptions(merge: true));
  }

  // إضافة إشراقة جديدة
  void _addInspiration() async {
    if (_textController.text.trim().isEmpty) return;
    
    await FirebaseFirestore.instance.collection('inspirations').add({
      'text': _textController.text.trim(),
      'source': _sourceController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    _textController.clear();
    _sourceController.clear();
    if(mounted) Navigator.pop(context);
  }

  // 🚀 تحديث/تعديل إشراقة موجودة سابقاً
  void _updateInspiration(String docId) async {
    if (_textController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('inspirations').doc(docId).update({
      'text': _textController.text.trim(),
      'source': _sourceController.text.trim(),
    });

    _textController.clear();
    _sourceController.clear();
    if(mounted) Navigator.pop(context);
  }

  // حذف إشراقة
  void _deleteInspiration(String docId) async {
    await FirebaseFirestore.instance.collection('inspirations').doc(docId).delete();
  }

  // 🚀 منبثق الإضافة والتعديل الموحد
  void _showInspirationDialog({required bool isDark, String? docId, String? initialText, String? initialSource}) {
    // إذا كان هناك بيانات سابقة، نعبئها بضمير لتعديلها
    _textController.text = initialText ?? '';
    _sourceController.text = initialSource ?? '';
    bool isEdit = docId != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff1e293b) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 15),
                Text(
                  isEdit ? "تعديل الإشراقة الحالية ✏️" : "إضافة إشراقة جديدة ✨", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _textController,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "نص الإشراقة (آية، حديث، أو حكمة)",
                    labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _sourceController,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "المصدر (مثال: سورة البقرة، رواه مسلم)",
                    labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 2,
                  ),
                  onPressed: () => isEdit ? _updateInspiration(docId) : _addInspiration(),
                  child: Text(
                    isEdit ? "حفظ التعديلات الأنيقة" : "حفظ الإشراقة الجديدة", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo')
                  ),
                )
              ],
            ),
          ),
        );
      },
    ).then((_) {
      // تنظيف الحقول بعد إغلاق الديالوج دوماً لمنع التشابك
      _textController.clear();
      _sourceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
        title: Text("إدارة إشراقة اليوم", style: TextStyle(color: isDark ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: goldColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showInspirationDialog(isDark: isDark),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [const Color(0xff0f172a), const Color(0xff1e293b)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 🎛️ زر التحكم العام بالتفعيل
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('settings').doc('general').snapshots(),
                  builder: (context, snapshot) {
                    bool isActive = true;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      isActive = (snapshot.data!.data() as Map<String, dynamic>)['is_inspiration_active'] ?? true;
                    }
                    return Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isActive ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5), width: 1.2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 10)
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("حالة ظهور الإشراقة للأهالي", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 14)),
                              Text(isActive ? "مفعلة وتظهر يومياً" : "متوقفة حالياً", style: TextStyle(fontSize: 12, color: isActive ? Colors.green : Colors.redAccent, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Switch(
                            value: isActive,
                            activeColor: Colors.green,
                            onChanged: _toggleInspirationStatus,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                // 📜 قائمة الإشراقات المضافة مع خياري التعديل والحذف
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('inspirations').orderBy('createdAt', descending: false).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return Center(child: Text("لم يتم إضافة أي إشراقات بعد 📭", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : primaryColor)));

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          String docId = docs[index].id;
                          String text = data['text'] ?? '';
                          String source = data['source'] ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.7), width: 1.2),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: goldColor.withOpacity(0.15),
                                child: Text("${index + 1}", style: TextStyle(color: isDark ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              ),
                              title: Text(text, style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(source, style: TextStyle(fontSize: 12, color: goldColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 🚀 زر التعديل الجديد والمطور
                                  IconButton(
                                    icon: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent, size: 24),
                                    tooltip: "تعديل الإشراقة",
                                    onPressed: () => _showInspirationDialog(
                                      isDark: isDark,
                                      docId: docId,
                                      initialText: text,
                                      initialSource: source,
                                    ),
                                  ),
                                  // زر الحذف
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                    tooltip: "حذف الإشراقة",
                                    onPressed: () => _deleteInspiration(docId),
                                  ),
                                ],
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
          )
        ],
      ),
    );
  }
}