import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  // رقم إصدار تطبيق المشرفين الحالي بـ الكود (اربطه بـ رقم الـ build بـ pubspec)
  static const int currentVersionCode = 4; 

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // جلب مستند التحكم بالإصدارات من الفايربيز
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('version_control')
          .doc('version_info')
          .get();

      if (documentSnapshot.exists && documentSnapshot.data() != null) {
        Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;

        // 🎯 قراءة الحقول المخصصة للمشرفين من السيرفر بالملي
        int serverVersion = int.tryParse(data['supervisors_current_version']?.toString() ?? '0') ?? 0;
        
        // 🛠️ فحص ذكي: إذا كان حقل المشرفين فاضي أو null، يسحب الرابط العام فوراً كخيار احتياطي
        String updateUrl = (data['supervisors_update_url'] != null && data['supervisors_update_url'].toString().isNotEmpty)
            ? data['supervisors_update_url'].toString()
            : (data['update_url'] ?? '').toString();

        // إذا كان إصدار السيرفر أكبر من إصدار التطبيق الحالي، يظهر المنبثق فوراً
        if (serverVersion > currentVersionCode && updateUrl.isNotEmpty) {
          if (!context.mounted) return;
          _showUpdateDialog(context, updateUrl);
        }
      }
    } catch (e) {
      print("Error checking for supervisor updates: $e");
    }
  }

  static void _showUpdateDialog(BuildContext context, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // إجبار المستخدم على التحديث لمنع الدخول بنسخة قديمة
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // منع زر الرجوع بالجوال
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.system_update_rounded, color: Color(0xff425c75), size: 28),
                SizedBox(width: 10),
                Text('تحديث جديد متاح 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: const Text(
              'يتوفر إصدار جديد وتحديث أمني مهم لتطبيق المشرفين والمدير. يرجى التحديث الآن لضمان استقرار النظام ومتابعة العمليات بنجاح.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff425c75),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('تحديث الآن 🔄', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () async {
                    final Uri url = Uri.parse(downloadUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      print('Could not launch update URL');
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}