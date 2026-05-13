import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cycle_model.dart';

class CycleService {
  final firestore = FirebaseFirestore.instance;

  Future<void> createCycle({
    required String type,
    required int year,
    required int cycleNumber,
    required String startDate,
    required String endDate,
  }) async {
    final name = "$type $year";

    await firestore.collection('cycles').add({
      'name': name,
      'type': type,
      'year': year,
      'cycleNumber': cycleNumber,
      'startDate': startDate,
      'endDate': endDate,
      'active': true,
      'archived': false,
      'createdAt': DateTime.now().toString(),
    });
  }

  Future<CycleModel?> getCurrentCycle() async {
    final result = await firestore
        .collection('cycles')
        .where('active', isEqualTo: true)
        .where('archived', isEqualTo: false)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return null;
    }

    final doc = result.docs.first;

    return CycleModel.fromMap(
      doc.id,
      doc.data(),
    );
  }

  Future<void> archiveCycle(String id) async {
    await firestore.collection('cycles').doc(id).update({
      'active': false,
      'archived': true,
    });
  }

  Future<void> updateCycleEndDate({
    required String id,
    required String endDate,
  }) async {
    await firestore.collection('cycles').doc(id).update({
      'endDate': endDate,
    });
  }
}