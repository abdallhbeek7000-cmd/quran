import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_provider.dart';
import '../services/cloudinary_helper.dart';
import '../services/notification_service.dart';
import '../widgets/offline_wrapper.dart';

class ActivitiesManagePage extends StatefulWidget {
  const ActivitiesManagePage({super.key});

  @override
  State<ActivitiesManagePage> createState() => _ActivitiesManagePageState();
}

class _ActivitiesManagePageState extends State<ActivitiesManagePage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  // 🗺️ دالة فتح الموقع في خرائط جوجل
  Future<void> _openLocationInMaps(String locationText) async {
    if (locationText.trim().isEmpty) return;
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(locationText)}");
    
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تعذر فتح خرائط جوجل", style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
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
          title: Text(
            "إدارة الأنشطة والرحلات 🚌⚽",
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 18),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: isDark ? accentGold : primaryColor,
          elevation: 4,
          onPressed: () => _showCreateOrEditActivityBottomSheet(isDark: isDark),
          icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
          label: const Text("إنشاء نشاط جديد", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                      : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('activities').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_bus_filled_rounded, size: 70, color: isDark ? accentGold.withOpacity(0.5) : primaryColor.withOpacity(0.4)),
                          const SizedBox(height: 15),
                          Text("لا توجد رحلات أو أنشطة مضافة حتى الآن", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : primaryColor, fontSize: 15)),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      String activityId = docs[index].id;

                      DateTime? deadline;
                      if (data['deadlineTimestamp'] != null) {
                        deadline = (data['deadlineTimestamp'] as Timestamp).toDate();
                      }
                      bool isExpired = deadline != null ? DateTime.now().isAfter(deadline) : false;

                      return _buildActivityCard(activityId, data, isExpired, isDark);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(String id, Map<String, dynamic> data, bool isExpired, bool isDark) {
    String title = data['title'] ?? 'نشاط ترفيهي';
    String details = data['details'] ?? '';
    String imageUrl = data['imageUrl'] ?? '';
    String eventDateTime = data['eventDateTime'] ?? '';
    String location = data['location'] ?? '';
    String targetType = data['targetType'] == 'all' ? 'جميع الطلاب 🌐' : 'طلاب محددون 🎯';

    // 📅 استخراج يوم الأسبوع بالعربية إذا توفر Timestamp
    String dayNameWithDateTime = eventDateTime;
    if (data['eventTimestamp'] != null) {
      DateTime dt = (data['eventTimestamp'] as Timestamp).toDate();
      String dayName = DateFormat('EEEE', 'ar').format(dt);
      String timeFormatted = DateFormat('jm', 'ar').format(dt);
      String dateFormatted = DateFormat('yyyy/MM/dd').format(dt);
      dayNameWithDateTime = "يوم $dayName ($dateFormatted) - الساعة $timeFormatted";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: isExpired
                  ? (isDark ? Colors.red.withOpacity(0.12) : Colors.red.shade50.withOpacity(0.8))
                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.55)),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isExpired ? Colors.redAccent.withOpacity(0.6) : (isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.75)),
                width: isExpired ? 1.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isExpired ? Colors.redAccent : (isDark ? Colors.white : primaryColor),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isExpired ? Colors.redAccent : Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isExpired ? "منتهي 🔴" : "نشط 🟢",
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 📅 عرض يوم الأسبوع والموعد بالتفصيل
                      Row(
                        children: [
                          Icon(Icons.event_rounded, size: 16, color: isDark ? accentGold : primaryColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "موعد النشاط: $dayNameWithDateTime",
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? accentGold : primaryColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // 🗺️ عرض الموقع وزر فتح الخريطة
                      if (location.isNotEmpty) ...[
                        InkWell(
                          onTap: () => _openLocationInMaps(location),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 16, color: Colors.redAccent),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "الموقع: $location (اضغط لفتح الخريطة 🗺️)",
                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],

                      Text("المستهدفون: $targetType", style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white60 : Colors.black54)),
                      const SizedBox(height: 8),
                      Text(details, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, height: 1.4)),
                      const SizedBox(height: 15),
                      Divider(color: isDark ? Colors.white12 : Colors.black12),
                      
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _showResponsesSummarySheet(id, title, isDark),
                            icon: const Icon(Icons.assignment_turned_in_rounded, size: 15, color: Colors.white),
                            label: const Text("موافقات الأهالي 📋", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentGold,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _showActivityAttendanceSheet(id, title, dayNameWithDateTime, isDark),
                            icon: const Icon(Icons.fact_check_rounded, size: 15, color: Colors.white),
                            label: const Text("حضور وتصدير HD 📸", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
                          ),

                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: Colors.amber, size: 26),
                            onPressed: () => _showCreateOrEditActivityBottomSheet(isDark: isDark, activityId: id, existingData: data),
                            tooltip: "تعديل بيانات الرحلة",
                          ),

                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                            onPressed: () => _deleteActivity(id),
                            tooltip: "حذف النشاط",
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📝 📸 أخذ الحضور وتصدير كشف صورة HD مخصص
  void _showActivityAttendanceSheet(String activityId, String activityTitle, String eventDateTime, bool isDark) {
    final WidgetsToImageController imageController = WidgetsToImageController();
    bool isGeneratingImage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.88,
                padding: const EdgeInsets.all(20),
                color: isDark ? const Color(0xff1e293b) : Colors.white,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('activities').doc(activityId).collection('responses').where('status', isEqualTo: 'approved').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final approvedDocs = snapshot.data!.docs;

                    return Stack(
                      children: [
                        Positioned(
                          left: -9999,
                          top: -9999,
                          child: WidgetsToImage(
                            controller: imageController,
                            child: SizedBox(
                              width: 600,
                              child: _buildExportableActivityPoster(activityTitle, eventDateTime, approvedDocs),
                            ),
                          ),
                        ),

                        Column(
                          children: [
                            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)))),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    "تفقد حضور النشاط: $activityTitle",
                                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : primaryColor),
                                  ),
                                ),
                                
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: isGeneratingImage || approvedDocs.isEmpty
                                      ? null
                                      : () async {
                                          setModalState(() => isGeneratingImage = true);
                                          try {
                                            final Uint8List? bytes = await imageController.capture();
                                            if (bytes != null) {
                                              final tempDir = await getTemporaryDirectory();
                                              final file = await File('${tempDir.path}/حضور_$activityTitle.png').create();
                                              await file.writeAsBytes(bytes);

                                              await Share.shareXFiles(
                                                [XFile(file.path)],
                                                text: '📊 كشف حضور نشاط وركوب الحافلة: ($activityTitle)\n📅 الموعد: $eventDateTime\nمعهد الشيخ سعيد العبدالله 🕌',
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء تصدير الصورة: $e", style: const TextStyle(fontFamily: 'Cairo'))));
                                            }
                                          } finally {
                                            setModalState(() => isGeneratingImage = false);
                                          }
                                        },
                                  icon: isGeneratingImage
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                                  label: Text(isGeneratingImage ? "جاري..." : "مشاركة HD 📸", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),

                            if (approvedDocs.isEmpty)
                              const Expanded(child: Center(child: Text("لا يوجد طلاب موافقون على المشاركة بعد 📭", style: TextStyle(fontFamily: 'Cairo'))))
                            else
                              Expanded(
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: approvedDocs.length,
                                  itemBuilder: (context, index) {
                                    var res = approvedDocs[index].data() as Map<String, dynamic>;
                                    String studentId = res['studentId'] ?? '';
                                    String studentName = res['studentName'] ?? 'طالب';
                                    bool attended = res['attended'] ?? false;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: attended ? Colors.green : Colors.redAccent.withOpacity(0.4)),
                                      ),
                                      child: CheckboxListTile(
                                        activeColor: Colors.green,
                                        title: Text(studentName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                        subtitle: Text(attended ? "حضر النشاط ✅" : "غائب عن النشاط ❌", style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: attended ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold)),
                                        value: attended,
                                        onChanged: (val) {
                                          FirebaseFirestore.instance.collection('activities').doc(activityId).collection('responses').doc(studentId).set({
                                            'attended': val ?? false,
                                          }, SetOptions(merge: true));
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🖼️ 🎨 تصميم كشف البوستر للتصدير كصورة عالية الدقة
  Widget _buildExportableActivityPoster(String title, String eventDateTime, List<QueryDocumentSnapshot> docs) {
    int attendedCount = docs.where((d) => (d.data() as Map)['attended'] == true).length;
    int absentCount = docs.length - attendedCount;

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff0f172a), Color(0xff1e293b), Color(0xff0f172a)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mosque, color: accentGold, size: 32),
              const SizedBox(width: 12),
              const Text("معهد الشيخ سعيد العبدالله", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: accentGold.withOpacity(0.15), borderRadius: BorderRadius.circular(25), border: Border.all(color: accentGold, width: 1)),
            child: Text("🚌 كشف حضور نشاط: $title", style: TextStyle(fontSize: 14, color: accentGold, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
          const SizedBox(height: 6),
          Text("الموعد: $eventDateTime", style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'Cairo')),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
                  child: Text("الحاضرون: $attendedCount", textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent)),
                  child: Text("الغياب: $absentCount", textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white24, width: 1.2)),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1.5)},
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12)),
                  children: [
                    _tableHeader("اسم الطالب المشترك"),
                    _tableHeader("حالة الحضور"),
                  ],
                ),
                ...docs.map((d) {
                  var data = d.data() as Map<String, dynamic>;
                  String name = data['studentName'] ?? 'طالب';
                  bool att = data['attended'] ?? false;
                  return TableRow(
                    children: [
                      _tableCell(name, isBold: true),
                      _tableCell(att ? "حاضر ✅" : "غائب ❌", color: att ? Colors.greenAccent : Colors.redAccent, isBold: true),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text("يرجى المتابعة والحرص الدائم على سلامة طلابنا الكرام 🌸", style: TextStyle(fontSize: 13, color: Colors.white60, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _tableHeader(String txt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(txt, textAlign: TextAlign.center, style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
    );
  }

  Widget _tableCell(String txt, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        txt,
        textAlign: TextAlign.center,
        style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontFamily: 'Cairo'),
      ),
    );
  }

  void _showCreateOrEditActivityBottomSheet({required bool isDark, String? activityId, Map<String, dynamic>? existingData}) {
    bool isEditing = activityId != null && existingData != null;

    final titleCtrl = TextEditingController(text: isEditing ? existingData['title'] : '');
    final detailsCtrl = TextEditingController(text: isEditing ? existingData['details'] : '');
    final locationCtrl = TextEditingController(text: isEditing ? existingData['location'] : ''); // 📍 حقل إدخال الموقع

    DateTime? selectedDate = isEditing && existingData['eventTimestamp'] != null ? (existingData['eventTimestamp'] as Timestamp).toDate() : null;
    TimeOfDay? selectedTime = selectedDate != null ? TimeOfDay.fromDateTime(selectedDate) : null;

    DateTime? deadlineDate = isEditing && existingData['deadlineTimestamp'] != null ? (existingData['deadlineTimestamp'] as Timestamp).toDate() : null;
    TimeOfDay? deadlineTime = deadlineDate != null ? TimeOfDay.fromDateTime(deadlineDate) : null;

    String? uploadedImageUrl = isEditing ? existingData['imageUrl'] : null;
    bool isUploadingImage = false;
    bool isSaving = false;

    String targetMode = isEditing ? (existingData['targetType'] ?? 'all') : 'all';
    List<String> selectedStudentIds = isEditing && existingData['targetStudentIds'] != null ? List<String>.from(existingData['targetStudentIds']) : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.88,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1e293b) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 15),
                      Text(
                        isEditing ? "تعديل بيانات النشاط / الرحلة ✏️" : "إنشاء دعوة نشاط / رحلة جديدة 🚌",
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : primaryColor),
                      ),
                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: () async {
                          setModalState(() => isUploadingImage = true);
                          String? url = await CloudinaryHelper.pickAndUploadProfileImage();
                          setModalState(() {
                            uploadedImageUrl = url;
                            isUploadingImage = false;
                          });
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            image: uploadedImageUrl != null && uploadedImageUrl!.isNotEmpty ? DecorationImage(image: NetworkImage(uploadedImageUrl!), fit: BoxFit.cover) : null,
                          ),
                          child: isUploadingImage
                              ? const Center(child: CircularProgressIndicator())
                              : (uploadedImageUrl == null || uploadedImageUrl!.isEmpty
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo_rounded, color: isDark ? accentGold : primaryColor, size: 30),
                                        const SizedBox(height: 6),
                                        Text("إضافة/تعديل صورة النشاط (اختياري)", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                                      ],
                                    )
                                  : null),
                        ),
                      ),
                      const SizedBox(height: 15),

                      TextField(
                        controller: titleCtrl,
                        style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: "عنوان النشاط (مثال: رحلة كرة قدم)",
                          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 📍 حقل إدخال عنوان / اسم الموقع
                      TextField(
                        controller: locationCtrl,
                        style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: "مكان/موقع النشاط (مثال: ملعب المعهد / منتزه كذا)",
                          hintText: "يستطيع الأهل الضغط عليه لفتحه في الخريطة",
                          hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.add_location_alt_rounded, color: Colors.redAccent),
                          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: detailsCtrl,
                        maxLines: 3,
                        style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: "تفاصيل النشاط والمكان الشاملة",
                          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Text("تاريخ ووقت النشاط:", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : primaryColor)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final p = await showDatePicker(
                                  context: context, 
                                  initialDate: selectedDate ?? DateTime.now(), 
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)), 
                                  lastDate: DateTime(2030),
                                  locale: const Locale('ar'),
                                );
                                if (p != null) setModalState(() => selectedDate = p);
                              },
                              icon: const Icon(Icons.calendar_month_rounded, size: 18),
                              label: Text(
                                selectedDate == null 
                                    ? "تحديد اليوم" 
                                    : "يوم ${DateFormat('EEEE', 'ar').format(selectedDate!)} (${DateFormat('yyyy-MM-dd').format(selectedDate!)})", 
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final t = await showTimePicker(context: context, initialTime: selectedTime ?? TimeOfDay.now());
                                if (t != null) setModalState(() => selectedTime = t);
                              },
                              icon: const Icon(Icons.access_time_rounded, size: 18),
                              label: Text(selectedTime == null ? "تحديد الساعة" : selectedTime!.format(context), style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      Text("تاريخ وساعة انتهاء مهلة قبول/رفض الأهل:", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final p = await showDatePicker(
                                  context: context, 
                                  initialDate: deadlineDate ?? DateTime.now(), 
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)), 
                                  lastDate: DateTime(2030),
                                  locale: const Locale('ar'),
                                );
                                if (p != null) setModalState(() => deadlineDate = p);
                              },
                              icon: const Icon(Icons.event_repeat_rounded, size: 18, color: Colors.redAccent),
                              label: Text(
                                deadlineDate == null 
                                    ? "تحديد يوم الإغلاق" 
                                    : "يوم ${DateFormat('EEEE', 'ar').format(deadlineDate!)} (${DateFormat('yyyy-MM-dd').format(deadlineDate!)})", 
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.redAccent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final t = await showTimePicker(context: context, initialTime: deadlineTime ?? TimeOfDay.now());
                                if (t != null) setModalState(() => deadlineTime = t);
                              },
                              icon: const Icon(Icons.timer_off_rounded, size: 18, color: Colors.redAccent),
                              label: Text(deadlineTime == null ? "ساعة الإغلاق" : deadlineTime!.format(context), style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.redAccent)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Text("الجمهور المستهدف بالدعوة:", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : primaryColor)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("جميع الطلاب 🌐", style: TextStyle(fontFamily: 'Cairo')),
                              selected: targetMode == 'all',
                              onSelected: (val) => setModalState(() => targetMode = 'all'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("تحديد طلاب 🎯", style: TextStyle(fontFamily: 'Cairo')),
                              selected: targetMode == 'selected',
                              onSelected: (val) => setModalState(() => targetMode = 'selected'),
                            ),
                          ),
                        ],
                      ),

                      if (targetMode == 'selected') ...[
                        const SizedBox(height: 10),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('students').where('archived', isEqualTo: false).snapshots(),
                          builder: (context, stdSnap) {
                            if (!stdSnap.hasData) return const Center(child: CircularProgressIndicator());
                            final docs = stdSnap.data!.docs;

                            return Container(
                              height: 150,
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                              child: ListView.builder(
                                itemCount: docs.length,
                                itemBuilder: (context, idx) {
                                  var s = docs[idx].data() as Map<String, dynamic>;
                                  String sId = docs[idx].id;
                                  bool isSel = selectedStudentIds.contains(sId);

                                  return CheckboxListTile(
                                    title: Text(s['name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                                    value: isSel,
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (val == true) {
                                          selectedStudentIds.add(sId);
                                        } else {
                                          selectedStudentIds.remove(sId);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 25),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? accentGold : primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (titleCtrl.text.trim().isEmpty || detailsCtrl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى ملء جميع البيانات الأساسية أولاً", style: TextStyle(fontFamily: 'Cairo'))));
                                    return;
                                  }

                                  if (selectedDate == null || selectedTime == null || deadlineDate == null || deadlineTime == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى تحديد مواعيد النشاط وتاريخ الانتهاء بدقة", style: TextStyle(fontFamily: 'Cairo'))));
                                    return;
                                  }

                                  setModalState(() => isSaving = true);

                                  try {
                                    DateTime eventDt = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
                                    DateTime deadlineDt = DateTime(deadlineDate!.year, deadlineDate!.month, deadlineDate!.day, deadlineTime!.hour, deadlineTime!.minute);

                                    String dayName = DateFormat('EEEE', 'ar').format(eventDt);
                                    String eventDtStr = "يوم $dayName (${DateFormat('yyyy-MM-dd').format(eventDt)}) - الساعة ${selectedTime!.format(context)}";

                                    final Map<String, dynamic> updatePayload = {
                                      'title': titleCtrl.text.trim(),
                                      'details': detailsCtrl.text.trim(),
                                      'location': locationCtrl.text.trim(), // 📍 حفظ الموقع
                                      'imageUrl': uploadedImageUrl ?? '',
                                      'eventDateTime': eventDtStr,
                                      'eventTimestamp': Timestamp.fromDate(eventDt),
                                      'deadlineTimestamp': Timestamp.fromDate(deadlineDt),
                                      'targetType': targetMode,
                                      'targetStudentIds': targetMode == 'selected' ? selectedStudentIds : [],
                                    };

                                    if (isEditing) {
                                      await FirebaseFirestore.instance.collection('activities').doc(activityId).update(updatePayload);
                                    } else {
                                      updatePayload['createdAt'] = FieldValue.serverTimestamp();
                                      await FirebaseFirestore.instance.collection('activities').add(updatePayload);

                                      if (targetMode == 'all') {
                                        var stdSnap = await FirebaseFirestore.instance.collection('students').get();
                                        for (var std in stdSnap.docs) {
                                          NotificationService.sendAndSaveNotification(
                                            studentId: std.id,
                                            title: "دعوة نشاط جديدة: ${titleCtrl.text.trim()} 🚌",
                                            body: "يرجى تأكيد القبول أو الرفض قبل موعد الانتهاء.",
                                            type: "activity_invitation",
                                            context: context,
                                          ).catchError((_) {});
                                        }
                                      } else {
                                        for (var sId in selectedStudentIds) {
                                          NotificationService.sendAndSaveNotification(
                                            studentId: sId,
                                            title: "دعوة نشاط جديدة: ${titleCtrl.text.trim()} 🚌",
                                            body: "يرجى تأكيد القبول أو الرفض قبل موعد الانتهاء.",
                                            type: "activity_invitation",
                                            context: context,
                                          ).catchError((_) {});
                                        }
                                      }
                                    }

                                    if (!mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(backgroundColor: Colors.green, content: Text(isEditing ? "تم تعديل بيانات النشاط بنجاح! ✏️" : "تم إرسال دعوة النشاط بنجاح! 🎉", style: const TextStyle(fontFamily: 'Cairo'))),
                                    );
                                  } catch (e) {
                                    setModalState(() => isSaving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء الحفظ: $e", style: const TextStyle(fontFamily: 'Cairo'))));
                                  }
                                },
                          icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(isEditing ? Icons.check_circle_outline_rounded : Icons.send_rounded, color: Colors.white),
                          label: Text(isSaving ? "جاري الحفظ..." : (isEditing ? "تحديث بيانات النشاط ✏️" : "حفظ وبث الدعوة للأهالي 🚀"), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 20),
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

  void _showResponsesSummarySheet(String activityId, String activityTitle, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            color: isDark ? const Color(0xff1e293b) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 15),
                Text("سجل ردود الأهالي: $activityTitle", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : primaryColor)),
                const SizedBox(height: 15),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('activities').doc(activityId).collection('responses').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                      final responses = snapshot.data!.docs;

                      if (responses.isEmpty) {
                        return const Center(child: Text("لم يقم أي من أولياء الأمور بالرد حتى الآن 📭", style: TextStyle(fontFamily: 'Cairo')));
                      }

                      int approvedCount = responses.where((r) => (r.data() as Map)['status'] == 'approved').length;
                      int rejectedCount = responses.where((r) => (r.data() as Map)['status'] == 'rejected').length;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.green)),
                                  child: Column(
                                    children: [
                                      const Text("الموافقون ✅", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                                      Text("$approvedCount", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.redAccent)),
                                  child: Column(
                                    children: [
                                      const Text("الرافضون ❌", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent)),
                                      Text("$rejectedCount", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Expanded(
                            child: ListView.builder(
                              itemCount: responses.length,
                              itemBuilder: (context, index) {
                                var res = responses[index].data() as Map<String, dynamic>;
                                String studentName = res['studentName'] ?? 'طالب';
                                String status = res['status'] ?? 'pending';
                                bool isApproved = status == 'approved';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.black26 : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isApproved ? Colors.green.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5)),
                                  ),
                                  child: ListTile(
                                    title: Text(studentName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isApproved ? Colors.green : Colors.redAccent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(isApproved ? "تمت الموافقة ✅" : "مرفوض ❌", style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteActivity(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف النشاط", style: TextStyle(fontFamily: 'Cairo')),
        content: const Text("هل أنت متأكد من حذف هذا النشاط وسجل الردود بالكامل؟", style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              FirebaseFirestore.instance.collection('activities').doc(id).delete();
              Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          )
        ],
      ),
    );
  }
}