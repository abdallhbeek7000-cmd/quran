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
    _tabController = TabController(length: 2, vsync: this);
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال عدد النقاط والسبب!", style: TextStyle(fontFamily: 'Cairo'))));
                        return;
                      }

                      setDialogState(() => isAdding = true);
                      try {
                        String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

                        // 1. تحديث رصيد الطالب
                        await FirebaseFirestore.instance.collection('students').doc(studentId).update({
                          'points': FieldValue.increment(pts)
                        });

                        // 2. تسجيل العملية
                        await FirebaseFirestore.instance.collection('points_history').add({
                          'studentId': studentId,
                          'pointsAdded': pts,
                          'reason': reason,
                          'timestamp': FieldValue.serverTimestamp(),
                          'addedBy': currentUid,
                        });

                        // 3. إرسال إشعار فوري
                        NotificationService.sendAndSaveNotification(
                          studentId: studentId,
                          title: "💎 كفو يا بطل! نقاط جديدة",
                          body: "حصلت للتو على $pts نقطة إضافية. السبب: $reason",
                          type: "points_added",
                          context: context,
                        ).catchError((e) => print("فشل الإشعار: $e"));

                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("تمت إضافة النقاط بنجاح!", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))));
                      } catch (e) {
                        setDialogState(() => isAdding = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text("حدث خطأ: $e", style: const TextStyle(fontFamily: 'Cairo'))));
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
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("لا يوجد سجل نقاط حتى الآن", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.grey)));

                        var docs = snapshot.data!.docs;
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var data = docs[index].data() as Map<String, dynamic>;
                            int pts = data['pointsAdded'] ?? 0;
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
                                leading: CircleAvatar(backgroundColor: accentGold.withOpacity(0.2), child: Text("+$pts", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold))),
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
      }
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إكمال جميع الحقول وإرفاق الصورة!", style: TextStyle(fontFamily: 'Cairo'))));
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("تم إضافة الجائزة للمتجر بنجاح 🎁", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))));
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text("حدث خطأ: $e", style: const TextStyle(fontFamily: 'Cairo'))));
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
          title: Text("بنك النقاط 💎", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor)),
          iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
        ),
        body: Stack(
          children: [
            // 🚀 1. خلفية التدرج
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
            
            // 🚀 2. الدوائر الخلفية المضيئة
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
                  // 🚀 3. كبسولة الـ TabBar الزجاجية
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
                      labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: const [
                        Tab(text: "رصيد الطلاب", iconMargin: EdgeInsets.only(bottom: 4), icon: Icon(Icons.people_alt_rounded, size: 20)),
                        Tab(text: "متجر الجوائز", iconMargin: EdgeInsets.only(bottom: 4), icon: Icon(Icons.storefront_rounded, size: 20)),
                      ],
                    ),
                  ),

                  // 🚀 4. محتوى التبويبات
                  Expanded(
                    child: isLoadingCycle
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildStudentsTab(isDark),
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

  // 👥 تبويبة الطلاب الزجاجية
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

        // ترتيب الطلاب بناءً على أعلى نقاط
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

  // 🎁 تبويبة متجر الجوائز الزجاجية المتجاوبة (Responsive Grid)
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
              // 🚀 التعديل السحري: شبكة متجاوبة حسب عرض الشاشة
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180, // أقصى عرض للكرت الواحد
                childAspectRatio: 0.85,  // تناسب الطول مع العرض
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                String rewardId = docs[index].id;
                String name = data['name'] ?? '';
                int pts = data['pointsRequired'] ?? 0;
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