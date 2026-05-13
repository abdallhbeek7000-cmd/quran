import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الإحصائيات"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            StreamBuilder(
  stream: FirebaseFirestore.instance
      .collection('students')
      .snapshots(),

  builder: (context, snapshot) {

    if (!snapshot.hasData) {
      return const CircularProgressIndicator();
    }

    final count =
        snapshot.data!.docs.length;

    return statCard(
      "عدد الطلاب",
      count.toString(),
    );
  },
),

            const SizedBox(height: 15),

            StreamBuilder(
  stream: FirebaseFirestore.instance
      .collection('users')
      .where(
        'role',
        isEqualTo: 'supervisor',
      )
      .snapshots(),

  builder: (context, snapshot) {

    if (!snapshot.hasData) {
      return const CircularProgressIndicator();
    }

    final count =
        snapshot.data!.docs.length;

    return statCard(
      "عدد المشرفين",
      count.toString(),
    );
  },
),

            const SizedBox(height: 15),

            StreamBuilder(
  stream: FirebaseFirestore.instance
      .collection('sessions')
      .snapshots(),

  builder: (context, snapshot) {

    if (!snapshot.hasData) {
      return const CircularProgressIndicator();
    }

    final count =
        snapshot.data!.docs.length;

    return statCard(
      "عدد الجلسات",
      count.toString(),
    );
  },
),

            const SizedBox(height: 15),

            StreamBuilder(
  stream: FirebaseFirestore.instance
      .collection('sessions')
      .where(
        'absent',
        isEqualTo: true,
      )
      .snapshots(),

  builder: (context, snapshot) {

    if (!snapshot.hasData) {
      return const CircularProgressIndicator();
    }

    final count =
        snapshot.data!.docs.length;

    return statCard(
      "عدد الغياب",
      count.toString(),
    );
  },
),
          ],
        ),
      ),
    );
  }

  Widget statCard(
    String title,
    String value,
  ) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.05,
            ),
            blurRadius: 8,
          ),
        ],
      ),

      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

        children: [

          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}