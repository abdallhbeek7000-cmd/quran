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
                            Text("الطلاب الأكثر تميزاً وإنجازاً باختيار الإدارة", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
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
                child: Text("لم يتم اختيار فرسان هذه الفئة بعد.", style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              );
            }

            var data = snapshot.data!.data() as Map<String, dynamic>;
            
            // 🚀 الدعم المزدوج للنظام القديم (3 فرسان) والجديد (قائمة مفتوحة)
            List<dynamic> knights = data.containsKey('knights') ? data['knights'] : [];
            if (knights.isEmpty && data.containsKey('first')) {
              knights = [data['first'], data['second'], data['third']];
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: knights.length,
              itemBuilder: (context, index) {
                var student = knights[index];
                if (student == null || student['name'] == "لم يحدد") return const SizedBox();

                Color medalColor = index == 0 ? goldColor : (index == 1 ? silverColor : (index == 2 ? bronzeColor : primaryColor.withOpacity(0.6)));

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
                        customColor: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.4),
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
                                        errorWidget: (c, u, e) => Center(child: Text(firstLetter, style: TextStyle(color: medalColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Cairo'))),
                                      )
                                    : Center(child: Text(firstLetter, style: TextStyle(color: medalColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Cairo'))),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
                                  const SizedBox(height: 4),
                                  Text("الرقم التسلسلي: $serialNumber", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey[700], fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                );
              },
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
// 🚀 شاشة توليد البوستر التسويقي الديناميكي الشبكي (The Grid Engine) 🚀
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

  // قائمة موحدة لجميع النجوم
  List<Map<String, dynamic>> allWinners = [];

  final Color royalNavy = const Color(0xff1A2A3A);
  final Color pureGold = const Color(0xffD4AF37);

  @override
  void initState() {
    super.initState();
    _loadAllCategoryWinners();
  }

  Future<void> _loadAllCategoryWinners() async {
    List<Map<String, dynamic>> newS = await _fetchCategoryKnights('new_students');
    List<Map<String, dynamic>> oldS = await _fetchCategoryKnights('old_students');
    List<Map<String, dynamic>> compS = await _fetchCategoryKnights('completed_students');
    
    if (mounted) {
      setState(() {
        allWinners = [...newS, ...oldS, ...compS];
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCategoryKnights(String docId) async {
    var doc = await FirebaseFirestore.instance.collection('honor_board').doc(docId).get();
    if (!doc.exists) return [];
    var data = doc.data()!;
    
    List<dynamic> knights = data.containsKey('knights') ? data['knights'] : [];
    if (knights.isEmpty && data.containsKey('first')) {
      knights = [data['first'], data['second'], data['third']];
    }

    List<Map<String, dynamic>> list = [];
    for (int i = 0; i < knights.length; i++) {
      var k = knights[i];
      if (k == null || k['name'] == 'لم يحدد') continue;

      dynamic rawSerial = k['serial'];
      int serialNumber = rawSerial is int ? rawSerial : (int.tryParse(rawSerial?.toString() ?? '') ?? 0);
      
      String imageUrl = '';
      var sSnap = await FirebaseFirestore.instance.collection('students').where('serial', whereIn: [serialNumber, serialNumber.toString()]).limit(1).get();
      if (sSnap.docs.isNotEmpty) {
        imageUrl = (sSnap.docs.first.data() as Map<String, dynamic>)['imageUrl'] ?? '';
      }

      list.add({
        'name': k['name'],
        'imageUrl': imageUrl,
        'index': i, // للاحتفاظ بلون الميدالية بناءً على ترتيبه في فئته
      });
    }
    return list;
  }

  Future<void> _captureAndSharePng() async {
    setState(() { _isCapturing = true; });
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); 
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/honor_poster.png').create();
      await imagePath.writeAsBytes(pngBytes);

      setState(() { _isCapturing = false; });
      await Share.shareXFiles([XFile(imagePath.path)], text: '🌟 نجوم وفرسان المعهد المتميزين، بارك الله فيهم وزادهم علماً وتفوقاً 🌟');
    } catch (e) {
      setState(() { _isCapturing = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("حدث خطأ أثناء حفظ الصورة", style: TextStyle(fontFamily: 'Cairo'))));
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
              onPressed: _isLoading || allWinners.isEmpty ? null : _captureAndSharePng,
              backgroundColor: pureGold,
              icon: const Icon(Icons.share, color: Colors.black),
              label: const Text("مشاركة الصورة", style: TextStyle(color: Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.amber))
        : allWinners.isEmpty 
            ? const Center(child: Text("لا يوجد نجوم لعرضهم بالبوستر حالياً", style: TextStyle(color: Colors.white, fontFamily: 'Cairo')))
            : Center(
                child: InteractiveViewer(
                  child: RepaintBoundary(
                    key: _globalKey,
                    child: Container(
                      width: 1080 / 2.5, 
                      height: 1920 / 2.5,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xff1A2A3A), Color(0xff090d16)],
                          begin: Alignment.topCenter, 
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(top: 60, right: -30, child: Icon(Icons.workspace_premium, size: 180, color: pureGold.withValues(alpha: 0.04))),
                          Positioned(bottom: 120, left: -40, child: Icon(Icons.auto_awesome, size: 220, color: pureGold.withValues(alpha: 0.04))),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 35),
                            child: Column(
                              children: [
                                Icon(Icons.stars_rounded, color: pureGold, size: 55),
                                const SizedBox(height: 8),
                                Text("نجوم التميز الشرفية", style: TextStyle(color: pureGold, fontSize: 26, fontWeight: FontWeight.w900, fontFamily: 'Cairo', shadows: [Shadow(color: pureGold.withValues(alpha: 0.6), blurRadius: 12)])),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  decoration: BoxDecoration(color: pureGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: pureGold.withValues(alpha: 0.4))),
                                  child: Text("تاريخ الإعلان: $todayDate", style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                ),
                                
                                const SizedBox(height: 30),
                                
                                // 🚀 التوزيع الشبكي الديناميكي الذكي للطلاب
                                Expanded(
                                  child: Center(
                                    child: GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: allWinners.length,
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: allWinners.length <= 3 ? 1 : (allWinners.length <= 8 ? 2 : 3), 
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: allWinners.length <= 3 ? 2.5 : 0.85, 
                                      ),
                                      itemBuilder: (context, idx) {
                                        var winner = allWinners[idx];
                                        String wName = winner['name'];
                                        String firstL = wName.isNotEmpty ? wName.trim().substring(0, 1) : "?";
                                        int rankIdx = winner['index'];
                                        
                                        Color medalC = rankIdx == 0 ? pureGold : (rankIdx == 1 ? const Color(0xffC0C0C0) : (rankIdx == 2 ? const Color(0xffCD7F32) : Colors.white38));

                                        return Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.03),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: medalC.withValues(alpha: 0.3), width: 1.2),
                                          ),
                                          child: allWinners.length <= 3 
                                              ? Row( 
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    _buildAvatarCircle(winner['imageUrl'], firstL, medalC),
                                                    const SizedBox(width: 15),
                                                    Expanded(child: Text(wName, style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Cairo', fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                                  ],
                                                )
                                              : Column( 
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    _buildAvatarCircle(winner['imageUrl'], firstL, medalC),
                                                    const SizedBox(height: 10),
                                                    Text(wName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold, height: 1.2)),
                                                  ],
                                                ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                const Divider(color: Colors.white12),
                                Text("نسأل الله لهم الثبات والمزيد من الفتوحات والتميز", style: TextStyle(color: pureGold.withValues(alpha: 0.7), fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(border: Border.all(color: pureGold.withValues(alpha: 0.4), width: 2.5)),
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

  Widget _buildAvatarCircle(String url, String firstLetter, Color medalC) {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: medalC, width: 2),
        boxShadow: [BoxShadow(color: medalC.withOpacity(0.3), blurRadius: 8)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: url.isNotEmpty
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : Container(color: Colors.white10, child: Center(child: Text(firstLetter, style: TextStyle(color: medalC, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')))),
      ),
    );
  }
}