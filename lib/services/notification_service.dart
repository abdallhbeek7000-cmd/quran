import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter/material.dart'; 
import 'package:googleapis_auth/auth_io.dart';

class NotificationService {
  
  // 🔐 دالة جلب تصريح الوصول الذكي بالقراءة المحلية الآمنة
  static Future<String> _getAccessToken() async {
    try {
      final String serviceAccountStr = await rootBundle.loadString('assets/service-account.json');
      final Map<String, dynamic> serviceAccountJson = jsonDecode(serviceAccountStr);
      
      final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      
      final client = await clientViaServiceAccount(accountCredentials, scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();
      return accessToken;
    } catch (e) {
      print("Error reading secure service account asset: $e");
      return '';
    }
  }

  // 🚀 الدالة الجوكر: ترسل الإشعار للطالب أو المشرف بذكاء
  static Future<void> sendAndSaveNotification({
    required String studentId, // يعمل كمعرف عام (يستقبل آي دي طالب أو مشرف)
    required String title,
    required String body,
    required String type, 
    String? chatStudentId, // 💬 معرف الطالب الخاص بالمحادثة لتجميع الإشعارات
    BuildContext? context, 
  }) async {
    try {
      // 🎯 1. البحث الذكي لتحديد نوع المستلم
      String targetCollection = 'students';
      DocumentSnapshot targetDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();

      // إن لم يكن طالباً، ابحث في المشرفين
      if (!targetDoc.exists) {
        targetDoc = await FirebaseFirestore.instance.collection('supervisors').doc(studentId).get();
        if (targetDoc.exists) {
          targetCollection = 'supervisors';
        } else {
          // إن لم يكن مشرفاً، ابحث في المدراء
          targetDoc = await FirebaseFirestore.instance.collection('users').doc(studentId).get();
          if (targetDoc.exists) {
            targetCollection = 'users';
          }
        }
      }

      if (!targetDoc.exists || targetDoc.data() == null) {
        print("❌ المستلم غير موجود في أي جدول. تم إلغاء الإشعار.");
        return;
      }

      // 🎯 2. توثيق التنبيه في مجموعة المستلم الصحيحة (سجل الإشعارات الداخلي)
      await FirebaseFirestore.instance
          .collection(targetCollection)
          .doc(studentId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      print("Notification documented in [$targetCollection] successfully! ✅");

      // 🎯 3. جلب التوكن وإرسال الإشعار عبر Google FCM
      var data = targetDoc.data() as Map<String, dynamic>;
      String? fcmToken = data['fcmToken'];

      if (fcmToken != null && fcmToken.isNotEmpty) {
        final String accessToken = await _getAccessToken();
        if (accessToken.isEmpty) {
          print("Access token generation failed.");
          return;
        }
        
        const String projectId = 'quran-habal';
        var url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

        var headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        };

        // 💬 تخصيص الـ Tag لتجميع إشعارات المحادثة
        String? notificationTag;
        if (type == 'chat') {
          notificationTag = 'chat_${chatStudentId ?? studentId}';
        }

        // 🎯 بناء الـ Payload المعتمد القاطع لـ FCM v1
        Map<String, dynamic> messagePayload = {
          'token': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            'title': title,
            'body': body,
            'studentId': studentId,
            'type': type,
            if (chatStudentId != null) 'chatStudentId': chatStudentId,
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'high_importance_channel',
              'sound': 'default',
              if (notificationTag != null) 'tag': notificationTag,
            }
          },
        };

        var requestBody = jsonEncode({'message': messagePayload});

        var response = await http.post(url, headers: headers, body: requestBody);
        
        if (response.statusCode == 200) {
          print("Push Notification fired successfully to $targetCollection! 🔔🚀");
        } else {
          print("FCM V1 Broadcast Status: ${response.statusCode} - ${response.body}");

          // 🛠️ معالجة التوكن التالف ومسحه لتنظيف Firestore بدون إزعاج المستخدم
          if (response.body.contains("UNREGISTERED") || 
              response.body.contains("NOT_FOUND") || 
              response.body.contains("INVALID_ARGUMENT")) {
            print("⚠️ FCM Token expired or unregistered for user ($studentId). Cleaning up token...");
            await FirebaseFirestore.instance
                .collection(targetCollection)
                .doc(studentId)
                .update({'fcmToken': FieldValue.delete()});
          }
          
          // 🛑 تم إلغاء الـ SnackBar الأحمر الذي كان يظهر للمستخدم ليظل الشات سلس وبدون أخطاء ظاهرة
        }
      } else {
        print("FCM Token is empty for this user ($targetCollection). لم يتم تسجيل الدخول لتلقي الإشعارات.");
      }
    } catch (e) {
      print("Error inside V1 Notification Service: $e");
      // عدم إظهار أي SnackBar للمستخدم نهائياً في حالات إرسال الرسائل لضمان تجربة شات ممتازة
    }
  }
}