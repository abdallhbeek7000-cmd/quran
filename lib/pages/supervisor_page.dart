import 'package:flutter/material.dart';
import 'add_supervisor_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupervisorPage extends StatelessWidget {
  const SupervisorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(
    title: const Text("المشرفين"),
  ),

  floatingActionButton: FloatingActionButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AddSupervisorPage(),
        ),
      );
    },

    child: const Icon(Icons.add),
  ),

  body: StreamBuilder(

  stream:
      FirebaseFirestore.instance
          .collection('supervisors')
          .snapshots(),

  builder: (context, snapshot) {

    if (!snapshot.hasData) {

      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    final supervisors =
        snapshot.data!.docs;

    if (supervisors.isEmpty) {

      return const Center(
        child: Text(
          "لا يوجد مشرفين",
        ),
      );
    }

    return ListView.builder(

      itemCount:
          supervisors.length,

      itemBuilder: (context, index) {

        final supervisor =
            supervisors[index];

        final data =
            supervisor.data();

        return ListTile(

          leading: const Icon(
            Icons.person,
          ),

          title: Text(
            data['name'] ?? '',
          ),

          subtitle: Text(
            data['email'] ?? '',
          ),
        );
      },
    );
  },
),
);
    
  }
}