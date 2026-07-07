import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/theme_provider.dart';
import '../services/cycle_service.dart';
import '../services/notification_service.dart';
import '../services/cloudinary_helper.dart'; 
import '../models/cycle_model.dart';
import '../widgets/offline_wrapper.dart';

class PointsBankPage extends StatefulWidget {
  const PointsBankPage({super.key});

  @override
  State<PointsBankPage> createState() => _PointsBankPageState();
}

class _PointsBankPageState extends State<PointsBankPage> with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  late TabController _tabController;
  CycleModel? currentCycle;
  bool isLoadingCycle = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCycle();
  }

  Future<void> _loadCycle() async {
    final cycle = await CycleService().getCurrentCycle();
    if (mounted) {
      setState(() {
        currentCycle = cycle;
        isLoadingCycle = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🔮 🚀 المحرك السحري لإشعار السائل الزجاجي الذي ينزلق بفخامة من الأعلى
  void _showTopPremiumToast({required String message, required IconData icon, required Color statusColor, required bool isDark}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 15, // النزول أسفل النوتش بالملي
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0), // الانزلاق السلس من الأعلى
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: Opacity(
                  opacity: (value + 100) / 100, // ظهور متدرج مع الانزلاق
                  child: child,
                ),
              );
            },
            child: Directionality(
              textDirection: TextDirection.rtl, // دعم محاذاة اللغة العربية الملكية
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // بلور زجاجي نقي خلف التنبيه
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1e293b).withOpacity(0.85) : Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.06), blurRadius: 15, offset: const Offset(0, 8))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), shape: BoxShape.circle),
                          child: Icon(icon, color: statusColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // إدخال التنبيه وحذفه التلقائي بعد 3 ثوانٍ
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  // 🚀 1. نافذة إضافة النقاط للطالب
  void _showAddPointsDialog(String studentId, String studentName, bool isDark) {
    final TextEditingController pointsController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    bool isAdding = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xff1e293b).withOpacity(0.9) : Colors.white.withOpacity(0.9),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isDark ? Colors.white24 : Colors.white, width: 1.5)
              ),
              title: Row(
                children: [
                  const Text("💎", style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text("إضافة نقاط لـ $studentName", style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pointsController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "عدد النقاط المكتسبة",
                      prefixIcon: Icon(Icons.add_circle_outline, color: accentGold),
                      filled: true, fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "سبب الحصول على النقاط",
                      hintText: "مثال: الإجابة على سؤال الدرس، الفوز بالمسابقة...",
                      filled: true, fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                if (isAdding)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: accentGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      int pts = int.tryParse(pointsController.text.trim()) ?? 0;
                      String reason = reasonController.text.trim();

                      if (pts <= 0 || reason.isEmpty) {
                        _showTopPremiumToast(message: "يرجى إدخال عدد النقاط والسبب الفعلي!", icon: Icons.warning_amber_rounded, statusColor: Colors.orangeAccent, isDark: isDark);
                        return;
                      }

                      setDialogState(() => isAdding = true);
                      try {
                        String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

                        await FirebaseFirestore.instance.collection('students').doc(studentId).update({
                          'points': FieldValue.increment(pts)
                        });

                        await FirebaseFirestore.instance.collection('points_history').add({
                          'studentId': studentId,
                          'pointsAdded': pts,
                          'reason': reason,
                          'timestamp': FieldValue.serverTimestamp(),
                          'addedBy': currentUid,
                        });

                        NotificationService.sendAndSaveNotification(
                          studentId: studentId,
                          title: "💎 كفو يا بطل! نقاط جديدة",
                          body: "حصلت للتو على $pts نقطة إضافية. السبب: $reason",
                          type: "points_added",
                          context: context,
                        ).catchError((e) => print("فشل الإشعار: $e"));

                        if (!mounted) return;
                        Navigator.pop(context);
                        
                        // 🚀 استدعاء التنبيه الزجاجي الانزلاقي من الأعلى بنجاح
                        _showTopPremiumToast(message: "تمت إضافة النقاط بنجاح وإشعار المحفظة الرقمية للطالب 💎", icon: Icons.check_circle_rounded, statusColor: Colors.green.shade600, isDark: isDark);
                      } catch (e) {
                        setDialogState(() => isAdding = false);
                        _showTopPremiumToast(message: "حدث خطأ غير متوقع: $e", icon: Icons.error_outline_rounded, statusColor: Colors.redAccent, isDark: isDark);
                      }
                    },
                    child: const Text("حفظ وإشعار الطالب", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ]
              ],
            );
          },
        );
      },
    );
  }

  // 🚀 2. نافذة عرض سجل نقاط الطالب
  void _showPointsHistory(String studentId, String studentName, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff1e293b).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                border: Border(top: BorderSide(color: isDark ? Colors.white24 : Colors.white, width: 1.5)),
              ),
              child: Column(
                children: [
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 15),
                  Text("📜 سجل نقاط: $studentName", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('points_history')
                          .where('studentId', isEqualTo: studentId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("لا يوجد سجل نقاط حتى الآن", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.grey)));

                        var docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
                        docs.sort((a, b) {
                          var tA = (a.data() as Map)['timestamp'] as Timestamp?;
                          var tB = (b.data() as Map)['timestamp'] as Timestamp?;
                          if (tA == null) return 1;
                          if (tB == null) return -1;
                          return tB.compareTo(tA);
                        });

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var data = docs[index].data() as Map<String, dynamic>;
                            int pts = (data['pointsAdded'] ?? 0).toInt();
                            String reason = data['reason'] ?? '';
                            Timestamp? ts = data['timestamp'];
                            String dateStr = ts != null ? "${ts.toDate().year}-${ts.toDate().month}-${ts.toDate().day}" : "الآن";

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.white),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: accentGold.withOpacity(0.2), child: Text(pts > 0 ? "+$pts" : "$pts", style: TextStyle(color: pts > 0 ? accentGold : Colors.redAccent, fontWeight: FontWeight.bold))),
                                title: Text(reason, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                                subtitle: Text(dateStr, style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
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
          ),
        );
      },
    );
  }

  // 🚀 3. نافذة إضافة جائزة جديدة للمتجر
  void _showAddRewardDialog(bool isDark) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController pointsController = TextEditingController();
    String? imageUrl;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xff1e293b).withOpacity(0.9) : Colors.white.withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isDark ? Colors.white24 : Colors.white, width: 1.5)
              ),
              title: Row(
                children: [
                  const Text("🎁", style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text("إضافة جائزة جديدة", style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        setDialogState(() => isSaving = true);
                        String? url = await CloudinaryHelper.pickAndUploadProfileImage(); 
                        if (url != null) {
                          setDialogState(() => imageUrl = url);
                        }
                        setDialogState(() => isSaving = false);
                      },
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: accentGold, width: 1.5),
                        ),
                        child: imageUrl != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(15), child: CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded, color: accentGold, size: 30),
                                  const SizedBox(height: 5),
                                  Text("صورة الجائزة", style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade700)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: "اسم الجائزة (مثال: مضارب، ساعة...)",
                        filled: true, fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: "سعرها بالنقاط",
                        prefixIcon: const Icon(Icons.diamond_rounded, color: Colors.blueAccent),
                        filled: true, fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (isSaving)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      int pts = int.tryParse(pointsController.text.trim()) ?? 0;
                      String name = nameController.text.trim();

                      if (pts <= 0 || name.isEmpty || imageUrl == null) {
                        _showTopPremiumToast(message: "يرجى ملء كافة التفاصيل وإرفاق صورة الجائزة!", icon: Icons.warning_rounded, statusColor: Colors.amber, isDark: isDark);
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await FirebaseFirestore.instance.collection('rewards').add({
                          'name': name,
                          'pointsRequired': pts,
                          'imageUrl': imageUrl,
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        if (!mounted) return;
                        Navigator.pop(context);
                        
                        // 🚀 إطلاق توست زجاجي من الأعلى عند إضافة الجائزة
                        _showTopPremiumToast(message: "تم تحديث الواجهة الموحدة للمتجر وإدراج الجائزة بنجاح 🎁", icon: Icons.shopping_bag_rounded, statusColor: accentGold, isDark: isDark);
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        _showTopPremiumToast(message: "تعذر الحفظ: $e", icon: Icons.error_outline_rounded, statusColor: Colors.redAccent, isDark: isDark);
                      }
                    },
                    child: const Text("إضافة للمتجر", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ]
              ],
            );
          },
        );
      },
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
          centerTitle: true,
          title: Text("بنك النقاط والمكافآت 💎", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor)),
          iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
        ),
        body: Stack(
          children: [
            Container(
              width: double.infinity, height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] 
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)], 
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
            
            Stack(
              children: [
                Positioned(
                  top: -50, right: -50, 
                  child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)))
                ),
                Positioned(
                  bottom: 100, left: -80, 
                  child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)))
                ),
              ],
            ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1.5),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: accentGold,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: isDark ? Colors.white54 : primaryColor.withOpacity(0.7),
                      labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [
                        Tab(text: "رصيد الطلاب", iconMargin: EdgeInsets.only(bottom: 4), icon: Icon(Icons.people_alt_rounded, size: 18)),
                        Tab(text: "طلبات الاستبدال 🔔", iconMargin: EdgeInsets.only(bottom: 4), icon: Icon(Icons.shopping_cart_checkout_rounded, size: 18)),
                        Tab(text: "متجر الجوائز", iconMargin: EdgeInsets.only(bottom: 4), icon: Icon(Icons.storefront_rounded, size: 18)),
                      ],
                    ),
                  ),

                  Expanded(
                    child: isLoadingCycle
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildStudentsTab(isDark),
                              _buildRequestsTab(isDark), 
                              _buildRewardsTab(isDark),
                            ],
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

  Widget _buildStudentsTab(bool isDark) {
    if (currentCycle == null) {
      return Center(child: Text("لا توجد دورة مفعلة حالياً", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : primaryColor)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students')
          .where('cycleId', isEqualTo: currentCycle!.id)
          .where('archived', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا يوجد طلاب في هذه الدورة", style: TextStyle(fontFamily: 'Cairo')));

        var docs = snapshot.data!.docs;

        var sortedDocs = docs.toList()..sort((a, b) {
          int ptsA = (a.data() as Map<String, dynamic>)['points'] ?? 0;
          int ptsB = (b.data() as Map<String, dynamic>)['points'] ?? 0;
          return ptsB.compareTo(ptsA);
        });

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            var data = sortedDocs[index].data() as Map<String, dynamic>;
            String studentId = sortedDocs[index].id;
            String name = data['name'] ?? 'طالب';
            int points = data['points'] ?? 0;
            String imageUrl = data['imageUrl'] ?? '';
            String firstLetter = name.isNotEmpty ? name.substring(0, 1) : "?";

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                    child: imageUrl.isEmpty ? Text(firstLetter, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.diamond_rounded, color: Colors.blueAccent, size: 16),
                            const SizedBox(width: 4),
                            Text("$points نقطة", style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white70 : Colors.blueGrey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history_edu_rounded, color: Colors.grey),
                        tooltip: "سجل النقاط",
                        onPressed: () => _showPointsHistory(studentId, name, isDark),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGold.withOpacity(0.2),
                          foregroundColor: isDark ? accentGold : primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: accentGold.withOpacity(0.5))),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("نقاط", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => _showAddPointsDialog(studentId, name, isDark),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reward_requests').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("لا توجد طلبات استبدال جوائز حالياً 🗓️", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : primaryColor)));
        }

        var requestDocs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
        requestDocs.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;
          String statusA = dataA['status'] ?? 'pending';
          String statusB = dataB['status'] ?? 'pending';
          
          if (statusA == 'pending' && statusB != 'pending') return -1;
          if (statusA != 'pending' && statusB == 'pending') return 1;
          
          Timestamp? tA = dataA['createdAt'] as Timestamp?;
          Timestamp? tB = dataB['createdAt'] as Timestamp?;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          itemCount: requestDocs.length,
          itemBuilder: (context, index) {
            var req = requestDocs[index].data() as Map<String, dynamic>;
            String requestId = requestDocs[index].id;
            String studentName = req['studentName'] ?? 'طالب مجهول';
            String rewardTitle = req['rewardTitle'] ?? 'جائزة';
            String serial = req['studentSerial']?.toString() ?? '---';
            String studentId = req['studentId'] ?? '';
            int cost = (req['cost'] ?? 0).toInt();
            String status = req['status'] ?? 'pending';
            
            bool isPending = status == 'pending';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isPending 
                    ? (isDark ? const Color(0xff334155).withOpacity(0.4) : Colors.amber.withOpacity(0.08))
                    : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isPending ? accentGold.withOpacity(0.4) : (isDark ? Colors.white12 : Colors.black12), width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text("تسلسلي: $serial", style: TextStyle(fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : primaryColor)),
                            ),
                            const SizedBox(width: 8),
                            if (!isPending)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                child: const Text("تم التسليم ✓", style: TextStyle(fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.green)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(studentName, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor)),
                        const SizedBox(height: 2),
                        Text("طلب استبدال: [$rewardTitle]", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade800)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("$cost نقطة", style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w900, color: accentGold)),
                      const SizedBox(height: 6),
                      if (isPending)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('reward_requests').doc(requestId).update({
                              'status': 'delivered',
                              'deliveredAt': FieldValue.serverTimestamp(),
                            });

                            if (studentId.isNotEmpty) {
                              NotificationService.sendAndSaveNotification(
                                studentId: studentId,
                                title: "🎉 مبارك! تم تسليم جائزتك",
                                body: "وافقت الإدارة على طلبك وتم تسليمك [$rewardTitle]. يعطيك العافية يا بطل!",
                                type: "reward_delivered",
                                context: context,
                              ).catchError((e) => print("فشل الإشعار العكسي: $e"));
                            }

                            // 🚀 إطلاق التنبيه الزجاجي الانزلاقي من الأعلى عند تأكيد التسليم
                            _showTopPremiumToast(message: "تم تأكيد تسليم الهدية بنجاح وإرسال إشعار فوري لموبايل الطالب 🎉", icon: Icons.done_all_rounded, statusColor: Colors.greenAccent.shade700, isDark: isDark);
                          },
                          child: const Text("تأكيد التسليم 🎁", style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRewardsTab(bool isDark) {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('rewards').orderBy('pointsRequired', descending: false).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("المتجر فارغ حالياً، قم بإضافة جوائز!", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.grey)));

            var docs = snapshot.data!.docs;

            return GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 90),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180, 
                childAspectRatio: 0.85,  
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                String rewardId = docs[index].id;
                String name = data['name'] ?? '';
                int pts = (data['pointsRequired'] ?? 0).toInt();
                String img = data['imageUrl'] ?? '';

                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                              child: CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                            ),
                            Positioned(
                              top: 5, left: 5,
                              child: InkWell(
                                onTap: () async {
                                  bool? confirm = await showDialog(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      title: Text("حذف الجائزة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                      content: Text("هل تريد حذف هذه الجائزة من المتجر؟", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white70 : Colors.black87)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
                                        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(c, true), child: const Text("حذف", style: TextStyle(fontFamily: 'Cairo', color: Colors.white))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await FirebaseFirestore.instance.collection('rewards').doc(rewardId).delete();
                                    _showTopPremiumToast(message: "تم حذف الجائزة وتحديث الرفوف الرقمية للمتجر", icon: Icons.delete_sweep_rounded, statusColor: Colors.redAccent, isDark: isDark);
                                  }
                                },
                                child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete_outline, color: Colors.white, size: 18)),
                              ),
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontSize: 13)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.diamond_rounded, color: Colors.blueAccent, size: 14),
                                  const SizedBox(width: 4),
                                  Text("$pts", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 20, left: 20, right: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: accentGold.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? primaryColor.withOpacity(0.9) : primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? Colors.white24 : Colors.transparent)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
                  label: const Text("إضافة جائزة للمتجر", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  onPressed: () => _showAddRewardDialog(isDark),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}