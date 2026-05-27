import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart'; 
import '../main.dart'; // استيراد الـ main لقط لـ navigatorKey السحري

class UpdateChecker {

  static Future<void> checkForUpdates() async {
    try {
      print("🎯 [UpdateChecker] بدأ فحص التحديثات المعزول تماماً...");
      
      // 1. جلب رقم إصدار التطبيق الحالي من الـ pubspec.yaml تلقائياً
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 2. جلب المستند الصحيح من السيرفر (app_settings -> version_control)
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('version_control')
          .get();

      if (documentSnapshot.exists && documentSnapshot.data() != null) {
        Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;

        // 🎯 العزل المطلق: قراءة حقول المشرفين فقط بالاسم الحرفي لمنع التداخل
        int serverVersion = int.tryParse(data['supervisors_current_version']?.toString() ?? '0') ?? 0;
        
        // ⚠️ قفل الأمان: نسحب فقط الحقل المخصّص للمشرفين ولا نلتفت لـ update_url نهائياً!
        String updateUrl = data['supervisors_update_url']?.toString()?.trim() ?? '';

        print("🎯 [UpdateChecker] إصدار السيرفر المقروء: $serverVersion");
        print("🎯 [UpdateChecker] إصدار جهاز المشرف الحالي: $currentVersionCode");
        print("🎯 [UpdateChecker] الرابط الذي سيفتح قسراً: $updateUrl");

        // المقارنة الذكية: المنبثق يظهر فقط وفقط إذا كان السيرفر أعلى من إصدار الجهاز
        if (serverVersion > currentVersionCode && updateUrl.isNotEmpty) {
          print("🎯 [UpdateChecker] تم اكتشاف نسخة أعلى! جاري إظهار المنبثق...");
          _showUpdateDialog(updateUrl);
        } else {
          print("🎯 [UpdateChecker] نظامك محدث بالكامل أو الشروط لم تتطابق ✅");
        }
      } else {
        print("❌ [UpdateChecker] خطأ: المستند غير موجود على هذا المسار بالفايربيز!");
      }
    } catch (e) {
      print("❌ [UpdateChecker] خطأ فادح أثناء جلب البيانات: $e");
    }
  }

  static void _showUpdateDialog(String downloadUrl) {
    final BuildContext? currentContext = navigatorKey.currentState?.overlay?.context;
    
    if (currentContext == null) {
      print("❌ [UpdateChecker] خطأ: الـ currentContext قيمته null!");
      return;
    }

    showDialog(
      context: currentContext,
      barrierDismissible: false, // إجبار المستخدم على التحديث
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
                    print("🎯 [UpdateChecker] جاري توجيه المشرف للرابط الصحيح الحين غصب: $url");
                    
                    try {
                      // الفتح المباشر لتخطي قيود حماية الأندرويد وفتح المتصفح الخارجي فوراً
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      print('❌ [UpdateChecker] خطأ، جاري التجربة بالمود الافتراضي: $e');
                      try {
                        await launchUrl(url);
                      } catch (err) {
                        print('❌ [UpdateChecker] فشل قاطع في فتح الرابط: $err');
                      }
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