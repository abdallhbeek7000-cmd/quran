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
  final Color silverColor = const Color(0xff9E9E9E); 
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
// 🚀 البوستر بالمقاس المثالي للموبايل والواتساب بدقة ناصعة بدون نقص 🚀
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

  List<Map<String, dynamic>> allStars = [];

  final Color primaryNavy = const Color(0xff1E293B);
  final Color royalGold = const Color(0xffD4AF37);

  @override
  void initState() {
    super.initState();
    _loadAllStars();
  }

  Future<void> _loadAllStars() async {
    List<Map<String, dynamic>> newS = await _fetchCategoryKnights('new_students');
    List<Map<String, dynamic>> oldS = await _fetchCategoryKnights('old_students');
    List<Map<String, dynamic>> compS = await _fetchCategoryKnights('completed_students');
    
    if (mounted) {
      setState(() {
        allStars = [...newS, ...oldS, ...compS];
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
      });
    }
    return list;
  }

  // 📸 الالتقاط بمعامل بكسل عالي جداً لإخراج صورة بدقة جبارة للموبايل
  Future<void> _captureAndSharePng() async {
    setState(() { _isCapturing = true; });
    try {
      await Future.delayed(const Duration(milliseconds: 350));
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      // 🚀 معامل مضاعفة البكسلات لإعطاء دقة فائقة جداً عند الحفظ
      ui.Image image = await boundary.toImage(pixelRatio: 3.5); 
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/honor_poster_mobile.png').create();
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
    String todayDate = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";

    return Scaffold(
      backgroundColor: const Color(0xff0F172A),
      appBar: _isCapturing 
          ? null 
          : AppBar(
              backgroundColor: primaryNavy,
              title: const Text("معاينة البوستر", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
      floatingActionButton: _isCapturing 
          ? null 
          : FloatingActionButton.extended(
              onPressed: _isLoading || allStars.isEmpty ? null : _captureAndSharePng,
              backgroundColor: royalGold,
              icon: const Icon(Icons.share, color: Colors.black),
              label: const Text("مشاركة الصورة", style: TextStyle(color: Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.amber))
        : allStars.isEmpty 
            ? const Center(child: Text("لا يوجد نجوم لعرضهم بالبوستر حالياً", style: TextStyle(color: Colors.white, fontFamily: 'Cairo')))
            : Center(
                child: InteractiveViewer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: RepaintBoundary(
                      key: _globalKey,
                      child: Container(
                        width: 410, // 🎯 مقاس الشاشة المثالي للهواتف والواتساب لمنع أي نقص
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xffFFFFFF), Color(0xffF8FAFC), Color(0xffE2E8F0)],
                            begin: Alignment.topCenter, 
                            end: Alignment.bottomCenter,
                          ),
                          border: Border.all(color: royalGold, width: 2.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min, // يتمدد رأسياً حسب عدد الطلاب بدون أي نقص
                          children: [
                            // 👑 الهيدر
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              decoration: BoxDecoration(
                                color: primaryNavy,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(color: primaryNavy.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.stars_rounded, color: royalGold, size: 26),
                                      const SizedBox(width: 8),
                                      Text("نجوم وفرسان الحلقة", style: TextStyle(color: royalGold, fontSize: 19, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text("معهد الشيخ سعيد العبدالله 🕌", style: TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 10),
                            
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: royalGold.withOpacity(0.15), 
                                borderRadius: BorderRadius.circular(18), 
                                border: Border.all(color: royalGold, width: 0.8)
                              ),
                              child: Text("🗓️ تاريخ الإعلان: $todayDate", style: TextStyle(color: primaryNavy, fontSize: 10.5, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            ),

                            const SizedBox(height: 22),

                            // 🌟 كروت الطلاب مقاس الموبايل المتناسق
                            Wrap(
                              spacing: 10,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: allStars.map((star) {
                                String name = star['name'];
                                String url = star['imageUrl'];
                                String firstL = name.isNotEmpty ? name.trim().substring(0, 1) : "?";

                                return Container(
                                  width: 115, // 🎯 عرض مناسب جداً لثلاثة كروت بالصف مع الحفاظ على الأبعاد
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: royalGold.withOpacity(0.55), width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 🌟 صورة واضحة جداً بحجم 68px
                                      Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Container(
                                            width: 68,
                                            height: 68,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: royalGold, width: 2.2),
                                              boxShadow: [BoxShadow(color: royalGold.withOpacity(0.25), blurRadius: 6)],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(40),
                                              child: url.isNotEmpty
                                                  ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                                                  : Container(
                                                      color: const Color(0xffF1F5F9), 
                                                      child: Center(
                                                        child: Text(firstL, style: TextStyle(color: royalGold, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))
                                                      )
                                                    ),
                                            ),
                                          ),
                                          // 🌟 النجمة الموحدة
                                          Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                            child: const Icon(Icons.star_rounded, color: Color(0xffD4AF37), size: 18),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        name,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: primaryNavy, fontSize: 10.5, fontFamily: 'Cairo', fontWeight: FontWeight.bold, height: 1.2),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 22),
                            const Divider(color: Colors.black12, height: 15),
                            Text("دعواتنا لهم بالدوام والتألق وأن ينفع الله بهم الأمة 🌸", style: TextStyle(color: primaryNavy.withOpacity(0.8), fontSize: 10.5, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}