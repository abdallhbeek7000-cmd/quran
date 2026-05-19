import 'package:flutter/material.dart';
import 'package:quran_habal/services/cloudinary_helper.dart';
import 'add_supervisor_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupervisorPage extends StatelessWidget {
  const SupervisorPage({super.key});

  final Color primaryColor = const Color(0xff425c75);

  // دالة ذكية لإظهار قائمة التعديل من الأسفل (BottomSheet)
  void _showEditBottomSheet(BuildContext context, String docId, Map<String, dynamic> currentData) {
    final TextEditingController nameEditController = TextEditingController(text: currentData['name']);
    String? currentImgUrl = currentData['imageUrl'];
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // لتجنب تغطية الكيبورد للواجهة
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder( // لتحديث الواجهة الداخلية عند رفع صورة جديدة
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // مسافة الكيبورد
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(5))),
                    const SizedBox(height: 20),
                    const Text("تعديل بيانات المشرف", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    // الضغط على الصورة داخل التعديل لتغييرها
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
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: currentImgUrl != null && currentImgUrl!.isNotEmpty
                                ? NetworkImage(currentImgUrl!)
                                : null,
                            child: currentImgUrl == null || currentImgUrl!.isEmpty
                                ? Icon(Icons.camera_alt_outlined, color: primaryColor, size: 30)
                                : null,
                          ),
                          if (isUploading)
                            const Positioned.fill(child: CircularProgressIndicator(color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("اضغط على الصورة لتغييرها", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 20),
                    
                    // حقل تعديل الاسم
                    TextField(
                      controller: nameEditController,
                      decoration: InputDecoration(
                        labelText: "اسم المشرف",
                        prefixIcon: Icon(Icons.person, color: primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 25),
                    
                    // أزرار الحفظ والإلغاء
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              if (nameEditController.text.trim().isEmpty) return;
                              
                              // تحديث البيانات في الفايربيز فوراً
                              await FirebaseFirestore.instance
                                  .collection('supervisors')
                                  .doc(docId)
                                  .update({
                                'name': nameEditController.text.trim(),
                                'imageUrl': currentImgUrl ?? '',
                              });
                              
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(backgroundColor: Colors.green, content: Text("تم تحديث البيانات بنجاح")),
                              );
                            },
                            child: const Text("حفظ التعديلات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text("إلغاء"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text("قائمة المشرفين", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
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
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('supervisors').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final supervisors = snapshot.data!.docs;

          if (supervisors.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: supervisors.length,
            itemBuilder: (context, index) {
              final supervisor = supervisors[index];
              final data = supervisor.data();
              String? imageUrl = data['imageUrl'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  onTap: () => _showEditBottomSheet(context, supervisor.id, data), // عند الضغط يفتح التعديل فوراً
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    backgroundImage: imageUrl != null && imageUrl.isNotEmpty 
                        ? NetworkImage(imageUrl) 
                        : null,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? Icon(Icons.person, color: primaryColor, size: 28)
                        : null,
                  ),
                  title: Text(
                    data['name'] ?? 'بدون اسم',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(Icons.email_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          data['email'] ?? '',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "نشط",
                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text(
            "لا يوجد مشرفين مضافين بعد",
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}