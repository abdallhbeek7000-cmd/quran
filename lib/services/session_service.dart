import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_model.dart';

class SessionService {
  final firestore = FirebaseFirestore.instance;

  Future<void> addSession(
    SessionModel session,
  ) async {
    await firestore
        .collection('sessions')
        .add(session.toMap());
  }

  Future<void> updateSession({
    required String sessionId,
    required Map<String, dynamic> data,
  }) async {
    await firestore
        .collection('sessions')
        .doc(sessionId)
        .update(data);
  }

  Future<void> deleteSession(
    String sessionId,
  ) async {
    await firestore
        .collection('sessions')
        .doc(sessionId)
        .delete();
  }

  Stream<QuerySnapshot> getStudentSessions(
    String studentId,
  ) {
    return firestore
        .collection('sessions')
        .where(
          'studentId',
          isEqualTo: studentId,
        )
        .snapshots();
  }

  Future<bool> hasSessionToday(
    String studentId,
  ) async {
    final now = DateTime.now();

    final today =
        "${now.year}-${now.month}-${now.day}";

    final result = await firestore
        .collection('sessions')
        .where(
          'studentId',
          isEqualTo: studentId,
        )
        .where(
          'date',
          isEqualTo: today,
        )
        .get();

    return result.docs.isNotEmpty;
  }

  // 🚀 خوارزمية المسح الزمني لحساب الغياب المتكرر بدقة 100%
  Future<void> recalculateConsecutiveAbsences(String studentId) async {
    try {
      // 1. جلب كل جلسات الطالب
      final snap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('studentId', isEqualTo: studentId)
          .get();

      // إذا حذفنا كل الجلسات وصار السجل فارغ، نصفر العداد فوراً
      if (snap.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('students').doc(studentId).update({
          'consecutiveAbsences': 0,
        });
        return;
      }

      List<Map<String, dynamic>> sessions = snap.docs.map((e) => e.data()).toList();

      // 2. ترتيب الجلسات من الأحدث إلى الأقدم
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

      // 3. المسح: نعد الغيابات من الأحدث، وأول ما نلاقي حضور نكسر العداد
      for (var session in sessions) {
        bool isAbsent = session['absent'] ?? false;
        if (isAbsent) {
          consecutiveAbsences++;
        } else {
          break; // 🛑 ضربنا فرام! لقينا جلسة حضور، انتهت سلسلة الغياب
        }
      }

      // 4. تحديث الرقم النهائي والمؤكد في ملف الطالب بالفايربيز
      await FirebaseFirestore.instance.collection('students').doc(studentId).update({
        'consecutiveAbsences': consecutiveAbsences,
      });
      
      print("✅ تم إعادة حساب غيابات الطالب بدقة: $consecutiveAbsences");

    } catch (e) {
      print("❌ خطأ في حساب الغيابات: $e");
    }
  }
}