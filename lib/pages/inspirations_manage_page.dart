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

  // حذف إشراقة
  void _deleteInspiration(String docId) async {
    await FirebaseFirestore.instance.collection('inspirations').doc(docId).delete();
  }

  void _showAddDialog(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1e293b).withOpacity(0.9) : Colors.white.withOpacity(0.95),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("إضافة إشراقة جديدة ✨", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _textController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "نص الإشراقة (آية، حديث، أو حكمة)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _sourceController,
                      decoration: InputDecoration(
                        labelText: "المصدر (مثال: سورة البقرة، رواه مسلم)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldColor,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _addInspiration,
                      child: const Text("حفظ الإشراقة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
        title: Text("إدارة إشراقة اليوم", style: TextStyle(color: isDark ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: goldColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddDialog(isDark),
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
                        color: isDark ? Colors.black26 : Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isActive ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("حالة ظهور الإشراقة للأهالي", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor)),
                              Text(isActive ? "مفعلة وتظهر يومياً" : "متوقفة حالياً", style: TextStyle(fontSize: 12, color: isActive ? Colors.green : Colors.redAccent)),
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
                
                // 📜 قائمة الإشراقات المضافة
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('inspirations').orderBy('createdAt', descending: false).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return const Center(child: Text("لم يتم إضافة أي إشراقات بعد."));

                      return ListView.builder(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          return Card(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            margin: const EdgeInsets.only(bottom: 15),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: goldColor.withOpacity(0.2),
                                child: Text("${index + 1}", style: TextStyle(color: isDark ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(data['text'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
                              subtitle: Text(data['source'] ?? '', style: TextStyle(fontSize: 11, color: goldColor)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _deleteInspiration(docs[index].id),
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