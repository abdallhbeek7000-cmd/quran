import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';

class SessionService {
  final firestore = FirebaseFirestore.instance;

  // 🚀 دالة إضافة الجلسة الذكية: تقبل إما SessionModel أو Map<String, dynamic>
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
      await firestore.collection('students').doc(studentId).update({
        'consecutiveAbsences': 0,
      }).catchError((e) => print("⚠️ فشل التحديث المسبق للعداد: $e"));
    }

    try {
      // 2. محاولة الرفع المباشر أونلاين
      await firestore.collection('sessions').add(sessionMap);
      if (studentId.isNotEmpty) {
        await recalculateConsecutiveAbsences(studentId);
      }
    } catch (e) {
      print("🚨 [Offline] تعذر الرفع المباشر، جاري الحفظ في طابور الانتظار المحلي بالخلفية...");
      
      // تجهيز الخريطة للحفظ كـ JSON وتحويل التوقيت لنص لتفادي الأخطاء
      final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(sessionMap);
      if (jsonMap['timestamp'] is FieldValue || jsonMap['timestamp'] == null) {
        jsonMap['timestamp'] = DateTime.now().toIso8601String();
      } else if (jsonMap['timestamp'] is Timestamp) {
        jsonMap['timestamp'] = (jsonMap['timestamp'] as Timestamp).toDate().toIso8601String();
      } else if (jsonMap['timestamp'] is DateTime) {
        jsonMap['timestamp'] = (jsonMap['timestamp'] as DateTime).toIso8601String();
      }

      final prefs = await SharedPreferences.getInstance();
      List<String> offlineSessions = prefs.getStringList('offline_sessions_queue') ?? [];
      
      offlineSessions.add(jsonEncode(jsonMap));
      await prefs.setStringList('offline_sessions_queue', offlineSessions);
      print("💾 تم حفظ الجلسة بنجاح داخل طابور الانتظار المحلي ومستعدة للطيران بالخلفية!");
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
    final result = await firestore.collection('sessions')
        .where('studentId', isEqualTo: studentId)
        .where('date', isEqualTo: today)
        .get();
    return result.docs.isNotEmpty;
  }

  // 🚀 خوارزمية المسح الزمني لحساب الغياب المتكرر بدقة 100%
  Future<void> recalculateConsecutiveAbsences(String studentId) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('sessions').where('studentId', isEqualTo: studentId).get();
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
      print("❌ خطأ في حساب الغيابات: $e");
    }
  }
}