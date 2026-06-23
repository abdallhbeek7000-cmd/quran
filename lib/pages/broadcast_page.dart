import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart';

class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  
  bool _isLoading = false;
  double _progress = 0.0;
  int _totalTarget = 0;
  int _sentCount = 0;

  // 🚀 متغيرات مخصصة لتحديد نوع الإرسال والطلاب المستهدفين
  bool _sendToAll = true; 
  List<String> _selectedStudentIds = [];

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: -10, end: 20).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  // 🚀 دالة الإرسال الذكية (للجميع أو للمحددين)
  Future<void> _sendBroadcast() async {
    final String title = _titleController.text.trim();
    final String body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text("يرجى كتابة عنوان وتفاصيل الإعلان", style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    if (!_sendToAll && _selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text("يرجى اختيار طالب واحد على الأقل للإرسال له", style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _sentCount = 0;
    });

    try {
      List<String> targets = [];

      if (_sendToAll) {
        // 1. جلب جميع الطلاب من قاعدة البيانات
        final QuerySnapshot studentsSnapshot = await FirebaseFirestore.instance.collection('students').get();
        targets = studentsSnapshot.docs.map((doc) => doc.id).toList();
      } else {
        // الاعتماد على قائمة الطلاب المحددة يدوياً
        targets = List.from(_selectedStudentIds);
      }

      _totalTarget = targets.length;

      if (_totalTarget == 0) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. حلقة إرسال الإشعارات للطلاب المستهدفين
      for (String studentId in targets) {
        await NotificationService.sendAndSaveNotification(
          studentId: studentId,
          title: title,
          body: body,
          type: 'broadcast',
        );

        _sentCount++;
        setState(() {
          _progress = _sentCount / _totalTarget;
        });
      }

      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        setState(() {
          _selectedStudentIds.clear();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green, 
            content: Text("✅ تم إرسال الإعلان بنجاح!", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("❌ حدث خطأ: $e", style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        title: Text("الإعلانات العامة", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
        centerTitle: true,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
      ),
      body: Stack(
        children: [
          // الخلفية التراكمية الأصلية
          Container(
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // الدوائر العائمة المتحركة كما هي
          AnimatedBuilder(
            animation: _bgAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: 50 + _bgAnimation.value,
                    left: -50 - (_bgAnimation.value / 2),
                    child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12))),
                  ),
                  Positioned(
                    bottom: 100 - _bgAnimation.value,
                    right: -60 + _bgAnimation.value,
                    child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2))),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _buildGlassContainer(
                  isDarkMode: isDarkMode,
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_rounded, size: 60, color: isDarkMode ? accentGold : primaryColor),
                      const SizedBox(height: 15),
                      Text("إرسال إعلان مخصص", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                      const SizedBox(height: 5),
                      Text("سيصل كإشعار منبثق ويوثق في سجلات أولياء الأمور المستهدفين.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.black54, fontFamily: 'Cairo')),
                      const SizedBox(height: 25),

                      // 🚀 الراديو بوتون لاختيار الفئة المستهدفة (الكل أو مخصص)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.black12 : Colors.white24,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<bool>(
                              activeColor: isDarkMode ? accentGold : primaryColor,
                              title: const Text("إرسال للجميع (كل الطلاب) 🌍", style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                              value: true,
                              groupValue: _sendToAll,
                              onChanged: (val) => setState(() => _sendToAll = val!),
                            ),
                            RadioListTile<bool>(
                              activeColor: isDarkMode ? accentGold : primaryColor,
                              title: const Text("تحديد طلاب معينين 🎯", style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                              value: false,
                              groupValue: _sendToAll,
                              onChanged: (val) => setState(() => _sendToAll = val!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🚀 قائمة اختيار الطلاب المنبثقة الذكية عند الرغبة بالإرسال المخصص
                      if (!_sendToAll) ...[
                        _buildStudentSelectorSection(isDarkMode),
                        const SizedBox(height: 20),
                      ],

                      // حقل العنوان
                      TextField(
                        controller: _titleController,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        decoration: _glassInputDecoration("عنوان الإعلان (مثال: عطلة رسمية)", Icons.title, isDarkMode),
                      ),
                      const SizedBox(height: 15),

                      // حقل التفاصيل
                      TextField(
                        controller: _bodyController,
                        maxLines: 4,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        decoration: _glassInputDecoration("تفاصيل الإعلان أو التذكير...", Icons.message_rounded, isDarkMode),
                      ),
                      const SizedBox(height: 25),

                      // شريط التقدم أثناء الإرسال التراكمي
                      if (_isLoading) ...[
                        Column(
                          children: [
                            LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: isDarkMode ? Colors.white12 : Colors.black12,
                              color: accentGold,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            const SizedBox(height: 10),
                            Text("جاري الإرسال: $_sentCount / $_totalTarget", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.black87)),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ],

                      // زر الإرسال النهائي مدمج بالحالة اللحظية
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _sendBroadcast,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9),
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          icon: _isLoading ? const SizedBox() : const Icon(Icons.send_rounded),
                          label: _isLoading 
                              ? const SizedBox(width: 24, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text(_sendToAll ? "إرسال الإعلان للجميع" : "إرسال للمختارين (${_selectedStudentIds.length})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 ويدجت ذكي يعرض الطلاب يتيح لك انتقاء أعداد مخصصة للإرسال الفوري
  Widget _buildStudentSelectorSection(bool isDarkMode) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200), // تثبيت الطول لمنع زحف الشاشة
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('students').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(15), child: Text("لا يوجد طلاب مسجلين بالمعهد حالياً", style: TextStyle(fontFamily: 'Cairo', fontSize: 13)));

          return ListView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var sData = docs[index].data() as Map<String, dynamic>;
              String studentId = docs[index].id;
              String name = sData['name'] ?? 'طالب';
              String serial = sData['serial']?.toString() ?? '---';
              bool isChecked = _selectedStudentIds.contains(studentId);

              return CheckboxListTile(
                activeColor: isDarkMode ? accentGold : primaryColor,
                title: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text("الرقم التسلسلي: $serial", style: const TextStyle(fontSize: 11)),
                value: isChecked,
                onChanged: (bool? checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedStudentIds.add(studentId);
                    } else {
                      _selectedStudentIds.remove(studentId);
                    }
                  });
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _glassInputDecoration(String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600, fontFamily: 'Cairo', fontSize: 13),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.6), 
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDarkMode ? accentGold : primaryColor, width: 1.5)),
    );
  }
}