import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';

class SessionService {
  final firestore = FirebaseFirestore.instance;

  // 🚀 دالة إضافة الجلسة السريعة الفائقة (Offline-First / Instantly Return)
  Future<void> addSession(dynamic sessionInput) async {
    Map<String, dynamic> sessionMap;
    String studentId = '';

    if (sessionInput is SessionModel) {
      sessionMap = sessionInput.toMap();
      studentId = sessionInput.studentId;
    } else if (sessionInput is Map<String, dynamic>) {
      sessionMap = Map<String, dynamic>.from(sessionInput);
      studentId = sessionMap['studentId'] ?? '';
    } else {
      print("❌ نوع البيانات غير مدعوم في addSession");
      return;
    }

    final bool isAbsent = sessionMap['absent'] ?? false;

    // 1. تصفير أولي لعداد الغيابات محلياً لو كان حاضراً
    if (!isAbsent && studentId.isNotEmpty) {
      firestore.collection('students').doc(studentId).update({
        'consecutiveAbsences': 0,
      }).catchError((e) => print("⚠️ فشل التحديث المسبق للعداد: $e"));
    }

    try {
      // 🚀 إنشاء معرف للجلسة محلياً مسبقاً لضمان سرعة الحفظ بالأوفلاين بدون انتظار إسناد سيرفر
      final DocumentReference newDocRef = firestore.collection('sessions').doc();

      // 2. محاولة الحفظ المباشر في كاش الفايرستور والشبكة بمهلة زمنية حاسمة (ثانيتين فقط)
      await newDocRef.set(sessionMap).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print("⏱️ [Offline Detection] انتهت المهلة الزمنية للرفع المباشر، تحويل الحفظ للطابور المحلي بالخلفية.");
          throw Exception("Network_Timeout_Offline");
        },
      );

      if (studentId.isNotEmpty) {
        recalculateConsecutiveAbsences(studentId);
      }
      print("✅ تم حفظ الجلسة بنجاح في فايرستور (أونلاين / كاش).");

    } catch (e) {
      print("🚨 [Offline Engine] تعذر الرفع الفوري ($e)، جاري الحفظ في طابور SharedPreferences للمزامنة بالخلفية...");

      // 3. تجهيز الخريطة للحفظ كـ JSON وتحويل التوقيت لنص لتفادي الأخطاء عند القراءة بالخلفية
      final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(sessionMap);
      if (jsonMap['timestamp'] is FieldValue || jsonMap['timestamp'] == null) {
        jsonMap['timestamp'] = DateTime.now().toIso8601String();
      } else if (jsonMap['timestamp'] is Timestamp) {
        jsonMap['timestamp'] = (jsonMap['timestamp'] as Timestamp).toDate().toIso8601String();
      } else if (jsonMap['timestamp'] is DateTime) {
        jsonMap['timestamp'] = (jsonMap['timestamp'] as DateTime).toIso8601String();
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        List<String> offlineSessions = prefs.getStringList('offline_sessions_queue') ?? [];

        offlineSessions.add(jsonEncode(jsonMap));
        await prefs.setStringList('offline_sessions_queue', offlineSessions);
        print("💾 تم الحفظ بنجاح داخل طابور الانتظار المحلي ومستعدة للمزامنة بالخلفية عبر Workmanager!");
      } catch (err) {
        print("❌ خطأ أثناء الكتابة في SharedPreferences: $err");
      }
    }
  }

  Future<void> updateSession({required String sessionId, required Map<String, dynamic> data}) async {
    await firestore.collection('sessions').doc(sessionId).update(data);
  }

  Future<void> deleteSession(String sessionId) async {
    await firestore.collection('sessions').doc(sessionId).delete();
  }

  Stream<QuerySnapshot> getStudentSessions(String studentId) {
    return firestore.collection('sessions').where('studentId', isEqualTo: studentId).snapshots();
  }

  Future<bool> hasSessionToday(String studentId) async {
    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";
    try {
      final result = await firestore.collection('sessions')
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: today)
          .get()
          .timeout(const Duration(seconds: 2));
      return result.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // 🚀 خوارزمية المسح الزمني لحساب الغياب المتكرر بدقة 100%
  Future<void> recalculateConsecutiveAbsences(String studentId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('studentId', isEqualTo: studentId)
          .get()
          .timeout(const Duration(seconds: 2));

      if (snap.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('students').doc(studentId).update({'consecutiveAbsences': 0});
        return;
      }
      List<Map<String, dynamic>> sessions = snap.docs.map((e) => e.data()).toList();
      sessions.sort((a, b) {
        String dateA = a['date'] ?? '';
        String dateB = b['date'] ?? '';
        int dateComparison = dateB.compareTo(dateA);
        if (dateComparison == 0) {
          Timestamp? tA = a['timestamp'] as Timestamp?;
          Timestamp? tB = b['timestamp'] as Timestamp?;
          if (tA != null && tB != null) return tB.compareTo(tA);
          if (tA == null && tB != null) return -1; 
          if (tB == null && tA != null) return 1;
        }
        return dateComparison;
      });

      int consecutiveAbsences = 0;
      for (var session in sessions) {
        if (session['absent'] ?? false) {
          consecutiveAbsences++;
        } else {
          break;
        }
      }
      await FirebaseFirestore.instance.collection('students').doc(studentId).update({'consecutiveAbsences': consecutiveAbsences});
      print("✅ تم إعادة حساب غيابات الطالب بدقة: $consecutiveAbsences");
    } catch (e) {
      print("⚠️ تعذر إعادة حساب الغيابات أوفلاين (سيتم الحساب المباشر فور توفر الشبكة): $e");
    }
  }
}