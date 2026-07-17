import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';

class SessionService {
  final firestore = FirebaseFirestore.instance;

  Future<void> addSession(SessionModel session) async {
    final sessionMap = session.toMap();
    final String studentId = session.studentId;
    final bool isAbsent = sessionMap['absent'] ?? false;

    // تصفير أولي للعداد محلياً لو كان حاضر
    if (!isAbsent) {
      await firestore.collection('students').doc(studentId).update({
        'consecutiveAbsences': 0,
      }).catchError((e) => print("⚠️ فشل التحديث المسبق للعداد: $e"));
    }

    try {
      // محاولة الرفع المباشر أونلاين
      await firestore.collection('sessions').add(sessionMap);
      await recalculateConsecutiveAbsences(studentId);
    } catch (e) {
      print("🚨 [Offline] تعذر الرفع المباشر، جاري الحفظ في طابور الانتظار المحلي بالخلفية...");
      
      // التخزين الاحترافي في طابور الشيرد بريفرنسز لترسله الـ Workmanager بالخلفية صامتاً
      final prefs = await SharedPreferences.getInstance();
      List<String> offlineSessions = prefs.getStringList('offline_sessions_queue') ?? [];
      
      // تحويل الموديل إلى JSON string
      offlineSessions.add(jsonEncode(sessionMap));
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
    } catch (e) {
      print("❌ خطأ في حساب الغيابات: $e");
    }
  }
}