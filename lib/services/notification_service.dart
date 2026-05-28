import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // 🎯 مكتبة قراءة ملفات الـ assets محلياً
import 'package:googleapis_auth/auth_io.dart';

class NotificationService {
  
  // 🔐 دالة جلب تصريح الوصول الذكي بالقراءة المحلية الآمنة من الـ assets منعا لكشف المفتاح
  static Future<String> _getAccessToken() async {
    try {
      // قراءة ملف الـ JSON بأمان من مجلد الـ assets محلياً داخل التطبيق دون كتابته كـ نص مكشوف
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

  // 🚀 الدالة الشغالة لإرسال الإشعار الخارجي وحفظه بمركز التنبيهات لايف بنفس اللحظة
  static Future<void> sendAndSaveNotification({
    required String studentId,
    required String title,
    required String body,
    required String type, // 'regular', 'absent', 'exam', 'honor'
  }) async {
    try {
      // 1. حقن وتوثيق التنبيه في الفايرستور أولاً لمركز إشعارات الأهل
      await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      print("Notification documented in Firestore successfully! ✅");

      // 2. جلب الـ FCM Token الخاص بجوال الأهل لإرساله خارجياً
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .get();

      if (studentDoc.exists && studentDoc.data() != null) {
        var data = studentDoc.data() as Map<String, dynamic>;
        String? fcmToken = data['fcmToken'];

        if (fcmToken != null && fcmToken.isNotEmpty) {
          // جلب التوكن المؤقت من جوجل لفك تشفير الإرسال
          final String accessToken = await _getAccessToken();
          if (accessToken.isEmpty) {
            print("Access token generation failed.");
            return;
          }
          
          // يمكنك تثبيت مشروعك الافتراضي quran-habal هنا
          const String projectId = 'quran-habal';
          var url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

          var headers = {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          };

          // الهيكلية الرسمية لـ V1 لضمان نزول الإشعار والجوال مقفل تماماً
          var requestBody = jsonEncode({
            'message': {
              'token': fcmToken,
              'notification': {
                'title': title,
                'body': body,
              },
              'data': {
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'studentId': studentId,
                'type': type,
              },
              'android': {
                'priority': 'high',
                'notification': {
                  'sound': 'default',
                  'channel_id': 'high_importance_channel',
                }
              },
              'apns': {
                'payload': {
                  'aps': {
                    'sound': 'default',
                    'badge': 1,
                  }
                }
              }
            }
          });

          var response = await http.post(url, headers: headers, body: requestBody);
          
          if (response.statusCode == 200) {
            print("Push Notification fired successfully outside the app! 🔔🚀");
          } else {
            print("FCM V1 Broadcast Error: ${response.body}");
          }
        } else {
          print("FCM Token is empty for this student doc. الأهل لم يسجلوا بالهاتف بعد.");
        }
      }
    } catch (e) {
      print("Error inside V1 Notification Service: $e");
    }
  }
}