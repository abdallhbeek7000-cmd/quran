import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/cycle_service.dart';

class CyclesPage extends StatefulWidget {
  const CyclesPage({super.key});

  @override
  State<CyclesPage> createState() => _CyclesPageState();
}

class _CyclesPageState extends State<CyclesPage> {
  final firestore = FirebaseFirestore.instance;

  final cycleService = CycleService();

  archiveCycle(String id) async {
    await cycleService.archiveCycle(id);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("تمت أرشفة الدورة"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الدورات"),
      ),
      body: StreamBuilder(
        stream:
            firestore.collection('cycles').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("لا توجد دورات"),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final cycle = docs[index];

              final data = cycle.data();

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: Icon(
                    data['archived']
                        ? Icons.archive
                        : Icons.check_circle,
                    color: data['archived']
                        ? Colors.grey
                        : Colors.green,
                  ),
                  title: Text(data['name']),
                  subtitle: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        "رقم الدورة: ${data['cycleNumber']}",
                      ),
                      Text(
                        "من: ${data['startDate'].toString().split(' ')[0]}",
                      ),
                      Text(
                        "إلى: ${data['endDate'].toString().split(' ')[0]}",
                      ),
                    ],
                  ),
                  trailing: data['archived']
                      ? null
                      : IconButton(
                          onPressed: () {
                            archiveCycle(cycle.id);
                          },
                          icon: const Icon(
                            Icons.archive,
                            color: Colors.red,
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}