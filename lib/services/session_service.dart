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
}