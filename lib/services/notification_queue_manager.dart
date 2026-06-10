import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// 🚀 هذا هو الاستيراد الصحيح لأن الملفين بنفس المجلد
import 'notification_service.dart'; 

class NotificationQueueManager {
  static const String _queueKey = 'pending_notifications_queue';

  // 1. حفظ الإشعار في الطابور عند فشل الإرسال (أوفلاين)
  static Future<void> addToQueue({
    required String studentId,
    required String title,
    required String body,
    required String type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // جلب الطابور الحالي
    List<String> currentQueue = prefs.getStringList(_queueKey) ?? [];

    // تجهيز بيانات الإشعار كـ Map وتحويلها إلى نص (JSON)
    Map<String, dynamic> notificationData = {
      'studentId': studentId,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
    };

    currentQueue.add(jsonEncode(notificationData));
    await prefs.setStringList(_queueKey, currentQueue);
    print("📌 تم حفظ الإشعار في طابور الانتظار بنجاح (وضع أوفلاين)");
  }

  // 2. معالجة وإرسال الإشعارات المخزنة عند عودة الإنترنت
  // نمرر الـ context هنا لأن دالتك الأصلية تحتاجه
  static Future<void> processPendingNotifications(dynamic context) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> currentQueue = prefs.getStringList(_queueKey) ?? [];

    if (currentQueue.isEmpty) return;

    print("🔄 جاري إرسال الإشعارات المعلقة... العدد: ${currentQueue.length}");
    
    // إنشاء نسخة لتجنب مشاكل التعديل أثناء الدوران
    List<String> remainingNotifications = List.from(currentQueue);

    for (String notifStr in currentQueue) {
      try {
        final Map<String, dynamic> notif = jsonDecode(notifStr);
        
        // محاولة إرسال الإشعار عبر دالتك الأساسية
        await NotificationService.sendAndSaveNotification(
          studentId: notif['studentId'],
          title: notif['title'],
          body: notif['body'],
          type: notif['type'],
          context: context, 
        );

        // إذا نجح الإرسال، نحذفه من القائمة الاحتياطية
        remainingNotifications.remove(notifStr);
        print("✅ تم إرسال الإشعار المعلق بنجاح: ${notif['title']}");
      } catch (e) {
        print("❌ فشل إرسال الإشعار المعلق مجدداً، سيبقى في الطابور للمرة القادمة. الخطأ: $e");
        // نتوقف هنا لأن الإنترنت قد يكون قد انقطع مجدداً
        break; 
      }
    }

    // تحديث الطابور في الذاكرة بالباقي (الذي لم يرسل بعد)
    await prefs.setStringList(_queueKey, remainingNotifications);
  }
}