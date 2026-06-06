import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/theme_provider.dart';
import 'manage_honor_board_page.dart'; 

class HonorBoardPage extends StatelessWidget {
  final String role; 

  const HonorBoardPage({super.key, required this.role}); 

  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37); 
  final Color silverColor = const Color(0xffC0C0C0); 
  final Color bronzeColor = const Color(0xffCD7F32); 

  Stream<DocumentSnapshot> getHonorCategory(String categoryId) {
    return FirebaseFirestore.instance.collection('honor_board').doc(categoryId).snapshots();
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
        title: Text("لوحة الشرف والتميز", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
        actions: [
          // 🚀 زر مشاركة البوستر الجديد
          IconButton(
            icon: Icon(Icons.ios_share_rounded, color: isDarkMode ? goldColor : primaryColor),
            tooltip: "مشاركة البوستر كصورة",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HonorBoardPosterScreen())),
          ),
          if (role == "manager")
            IconButton(
              icon: Icon(Icons.edit_calendar, color: isDarkMode ? goldColor : primaryColor),
              tooltip: "إدارة لوحة الشرف",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageHonorBoardPage())),
            )
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
            top: -20, left: -50,
            child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? goldColor.withOpacity(0.08) : goldColor.withOpacity(0.12))),
          ),
          Positioned(
            bottom: 100, right: -60,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2))),
          ),

          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _buildGlassContainer(
                  isDarkMode: isDarkMode,
                  padding: const EdgeInsets.all(20),
                  customColor: isDarkMode ? goldColor.withOpacity(0.15) : goldColor.withOpacity(0.2),
                  customBorderColor: goldColor.withOpacity(0.5),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 55),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("فرسان الحلقة", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            const SizedBox(height: 5),
                            Text("الطلاب الأكثر تميزاً وإنجازاً باختيار الإدارة", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 25),
                _buildCategorySection("الطلاب الجدد", "new_students", isDarkMode ? Colors.lightBlueAccent : Colors.blue, Icons.auto_awesome, isDarkMode),
                const SizedBox(height: 25),
                _buildCategorySection("الطلاب القدماء", "old_students", Colors.orange, Icons.history_edu, isDarkMode),
                const SizedBox(height: 25),
                _buildCategorySection("الطلاب الخاتمين", "completed_students", Colors.green, Icons.verified, isDarkMode),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String title, String categoryId, Color accentColor, IconData icon, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
            ],
          ),
        ),
        StreamBuilder<DocumentSnapshot>(
          stream: getHonorCategory(categoryId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            if (!snapshot.data!.exists) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text("لم يتم اختيار فرسان هذه الفئة بعد.", style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              );
            }

            var data = snapshot.data!.data() as Map<String, dynamic>;
            List<dynamic> positions = [data['first'], data['second'], data['third']];

            return Column(
              children: List.generate(3, (index) {
                var student = positions[index];
                if (student == null || student['name'] == "لم يحدد") return const SizedBox();

                Color medalColor = index == 0 ? goldColor : (index == 1 ? silverColor : bronzeColor);
                bool isFirst = index == 0;

                final dynamic rawSerial = student['serial'];
                final int serialNumber = rawSerial is int ? rawSerial : (int.tryParse(rawSerial?.toString() ?? '') ?? 0);

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance.collection('students').where('serial', whereIn: [serialNumber, serialNumber.toString()]).limit(1).get(),
                  builder: (context, studentSnapshot) {
                    String imageUrl = '';
                    if (studentSnapshot.hasData && studentSnapshot.data!.docs.isNotEmpty) {
                      imageUrl = (studentSnapshot.data!.docs.first.data() as Map<String, dynamic>)['imageUrl'] ?? '';
                    }

                    final String studentName = student['name'] ?? '';
                    final String firstLetter = studentName.isNotEmpty ? studentName.trim().substring(0, 1) : "?";

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: _buildGlassContainer(
                        isDarkMode: isDarkMode,
                        padding: const EdgeInsets.all(12),
                        customColor: isDarkMode ? Colors.white.withOpacity(0.05) : (isFirst ? goldColor.withOpacity(0.08) : Colors.white.withOpacity(0.4)),
                        customBorderColor: medalColor.withOpacity(isDarkMode ? 0.6 : 0.8), 
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(Icons.workspace_premium, color: medalColor, size: 50),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 15),
                            Container(
                              width: 55, height: 55,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: medalColor.withOpacity(0.8), width: 2),
                                boxShadow: [BoxShadow(color: medalColor.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl, fit: BoxFit.cover,
                                        placeholder: (c, u) => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                                        errorWidget: (c, u, e) => Center(child: Text(firstLetter, style: TextStyle(color: medalColor, fontWeight: FontWeight.bold, fontSize: 20))),
                                      )
                                    : Center(child: Text(firstLetter, style: TextStyle(color: medalColor, fontWeight: FontWeight.bold, fontSize: 20))),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
                                  const SizedBox(height: 4),
                                  Text("الرقم التسلسلي: $serialNumber", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey[700], fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                );
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero, Color? customColor, Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ?? (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: customBorderColor ?? (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6)), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.02), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: child,
        ),
      ),
    );
  }
}

// 🚀=============================================================🚀
// 🚀 شاشة توليد البوستر التسويقي الأوتوماتيكي (The Marketing Engine) 🚀
// 🚀=============================================================🚀
class HonorBoardPosterScreen extends StatefulWidget {
  const HonorBoardPosterScreen({super.key});

  @override
  State<HonorBoardPosterScreen> createState() => _HonorBoardPosterScreenState();
}

class _HonorBoardPosterScreenState extends State<HonorBoardPosterScreen> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isCapturing = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> newStudents = [];
  List<Map<String, dynamic>> oldStudents = [];
  List<Map<String, dynamic>> completedStudents = [];

  final Color royalNavy = const Color(0xff1A2A3A);
  final Color pureGold = const Color(0xffD4AF37);

  @override
  void initState() {
    super.initState();
    _fetchAllWinners();
  }

  // 🚀 دالة سحب بيانات الفرسان لتجهيز البوستر
  Future<void> _fetchAllWinners() async {
    newStudents = await _fetchCategoryData('new_students');
    oldStudents = await _fetchCategoryData('old_students');
    completedStudents = await _fetchCategoryData('completed_students');
    setState(() { _isLoading = false; });
  }

  Future<List<Map<String, dynamic>>> _fetchCategoryData(String docId) async {
    var doc = await FirebaseFirestore.instance.collection('honor_board').doc(docId).get();
    if (!doc.exists) return [];
    var data = doc.data()!;
    List<dynamic> positions = [data['first'], data['second'], data['third']];
    List<Map<String, dynamic>> validStudents = [];

    for (int i = 0; i < positions.length; i++) {
      var pos = positions[i];
      if (pos == null || pos['name'] == 'لم يحدد') continue;

      dynamic rawSerial = pos['serial'];
      int serialNumber = rawSerial is int ? rawSerial : (int.tryParse(rawSerial?.toString() ?? '') ?? 0);
      
      String imageUrl = '';
      var sSnap = await FirebaseFirestore.instance.collection('students').where('serial', whereIn: [serialNumber, serialNumber.toString()]).limit(1).get();
      if (sSnap.docs.isNotEmpty) {
        imageUrl = (sSnap.docs.first.data() as Map<String, dynamic>)['imageUrl'] ?? '';
      }

      validStudents.add({
        'name': pos['name'],
        'imageUrl': imageUrl,
        'rank': i + 1,
      });
    }
    return validStudents;
  }

  // 🚀 دالة التقاط الصورة والمشاركة (السحر الحقيقي)
  Future<void> _captureAndSharePng() async {
    setState(() { _isCapturing = true; });
    try {
      // إعطاء وقت قصير للفلاتر ليرسم الواجهة بدون أزرار
      await Future.delayed(const Duration(milliseconds: 300));
      
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); // جودة عالية جداً 4K
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/honor_stars.png').create();
      await imagePath.writeAsBytes(pngBytes);

      setState(() { _isCapturing = false; });
      await Share.shareXFiles([XFile(imagePath.path)], text: '🌟 نجوم وفرسان الحلقة لهذا الأسبوع، بارك الله فيهم وزادهم علماً 🌟');
    } catch (e) {
      setState(() { _isCapturing = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("حدث خطأ أثناء حفظ الصورة")));
    }
  }

  @override
  Widget build(BuildContext context) {
    String todayDate = "${DateTime.now().year} / ${DateTime.now().month} / ${DateTime.now().day}";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isCapturing 
          ? null 
          : AppBar(
              backgroundColor: royalNavy,
              title: const Text("معاينة البوستر", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
      floatingActionButton: _isCapturing 
          ? null 
          : FloatingActionButton.extended(
              onPressed: _isLoading ? null : _captureAndSharePng,
              backgroundColor: pureGold,
              icon: const Icon(Icons.share, color: Colors.black),
              label: const Text("مشاركة الصورة", style: TextStyle(color: Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.amber))
        : Center(
            child: InteractiveViewer( // مشان يقدر يقرّب الصورة ويعاينها قبل النشر
              child: RepaintBoundary(
                key: _globalKey,
                child: Container(
                  width: 1080 / 2.5, // نسبة وتناسب ستوري الانستغرام وحالات الواتس
                  height: 1920 / 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [royalNavy, const Color(0xff0f172a)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // ديكور النجوم بالخلفية
                      Positioned(top: 50, right: -20, child: Icon(Icons.star, size: 150, color: pureGold.withOpacity(0.05))),
                      Positioned(bottom: 100, left: -30, child: Icon(Icons.auto_awesome, size: 200, color: pureGold.withOpacity(0.05))),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                        child: Column(
                          children: [
                            // 🎩 ترويسة البوستر
                            Icon(Icons.workspace_premium, color: pureGold, size: 60),
                            const SizedBox(height: 10),
                            Text("نجـوم الحلقـة", style: TextStyle(color: pureGold, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'Cairo', shadows: [Shadow(color: pureGold.withOpacity(0.5), blurRadius: 15)])),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                              decoration: BoxDecoration(color: pureGold.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: pureGold.withOpacity(0.5))),
                              child: Text("تاريخ الإعلان: $todayDate", style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // 👥 عرض الفرسان
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (newStudents.isNotEmpty) _buildPosterSection("الطلاب الجدد", newStudents),
                                  if (oldStudents.isNotEmpty) _buildPosterSection("الطلاب القدماء", oldStudents),
                                  if (completedStudents.isNotEmpty) _buildPosterSection("الخاتمين المتميزين", completedStudents),
                                ],
                              ),
                            ),
                            
                            // 📜 تذييل البوستر
                            const Divider(color: Colors.white24),
                            Text("نسأل الله لهم الثبات والمزيد من التفوق", style: TextStyle(color: pureGold.withOpacity(0.8), fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      
                      // إطار ذهبي محيط بالبوستر
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(border: Border.all(color: pureGold.withOpacity(0.5), width: 3)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildPosterSection(String title, List<Map<String, dynamic>> students) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: students.map((student) {
            String firstLetter = student['name'].isNotEmpty ? student['name'].trim().substring(0, 1) : "?";
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  Container(
                    width: 65, height: 65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: pureGold, width: 2.5),
                      boxShadow: [BoxShadow(color: pureGold.withOpacity(0.4), blurRadius: 10)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: student['imageUrl'].isNotEmpty
                          ? CachedNetworkImage(imageUrl: student['imageUrl'], fit: BoxFit.cover)
                          : Container(color: Colors.white10, child: Center(child: Text(firstLetter, style: TextStyle(color: pureGold, fontSize: 24, fontWeight: FontWeight.bold)))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 80,
                    child: Text(
                      student['name'],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.w600, height: 1.2),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}