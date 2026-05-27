import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart'; // استيراد الـ main لقط لـ navigatorKey السحري

class UpdateChecker {
  // رقم إصدار تطبيق المشرفين الحالي بـ الكود (اربطه بـ رقم الـ build بـ pubspec)
  static const int currentVersionCode = 4; 

  static Future<void> checkForUpdates() async {
    try {
      print("🎯 [UpdateChecker] بدأ فحص التحديثات الحين...");
      
      // 🎯 المسار الصحيح بعد التصحيح الملوكي
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('version_control')
          .get();

      print("🎯 [UpdateChecker] هل المستند موجود بالسيرفر؟: ${documentSnapshot.exists}");

      if (documentSnapshot.exists && documentSnapshot.data() != null) {
        Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;

        // قراءة الحقول الصفراء المعزولة للمشرفين
        int serverVersion = int.tryParse(data['supervisors_current_version']?.toString() ?? '0') ?? 0;
        String updateUrl = data['supervisors_update_url']?.toString() ?? '';

        print("🎯 [UpdateChecker] إصدار السيرفر المقروء: $serverVersion");
        print("🎯 [UpdateChecker] إصدار الكود الحالي: $currentVersionCode");
        print("🎯 [UpdateChecker] رابط التحديث المقروء: $updateUrl");

        // إذا كان إصدار السيرفر (7) أكبر من إصدار الكود (4)، والرابط ليس فارغاً، يظهر المنبثق فوراً
        if (serverVersion > currentVersionCode && updateUrl.isNotEmpty) {
          print("🎯 [UpdateChecker] الشروط تحققت! جاري محاولة إظهار المنبثق...");
          _showUpdateDialog(updateUrl);
        } else {
          print("🎯 [UpdateChecker] الشروط لم تتحقق (إما الإصدار أصغر أو الرابط فارغ)");
        }
      } else {
        print("❌ [UpdateChecker] خطأ: المستند فارغ أو غير موجود على هذا المسار بالفايربيز!");
      }
    } catch (e) {
      print("❌ [UpdateChecker] خطأ فادح أثناء جلب البيانات من السيرفر: $e");
    }
  }

  static void _showUpdateDialog(String downloadUrl) {
    final BuildContext? currentContext = navigatorKey.currentState?.overlay?.context;
    
    if (currentContext == null) {
      print("❌ [UpdateChecker] خطأ: الـ currentContext قيمته null، لا يمكن إظهار الـ Dialog!");
      return;
    }

    showDialog(
      context: currentContext,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, 
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
                      print('❌ [UpdateChecker] Could not launch update URL');
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