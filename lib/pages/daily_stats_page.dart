import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyStatsPage
    extends StatelessWidget {

  const DailyStatsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "الإحصائيات اليومية",
        ),
      ),

      body: ListView(

        children: [

          Card(

            margin:
                const EdgeInsets.all(10),

            child: Padding(

              padding:
                  const EdgeInsets.all(20),

              child: Column(

                children: [

                  const Text(

                    "عدد الغائبين اليوم",

                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  StreamBuilder(

  stream: FirebaseFirestore.instance
      .collection('sessions')
      .where(
  'date',
  isEqualTo:
      "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}"
)
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

    return Text(

      count.toString(),

      style: const TextStyle(
        fontSize: 35,
        color: Colors.red,
        fontWeight:
            FontWeight.bold,
      ),
    );
  },
),
                ],
              ),
            ),
          ),
          Card(

  margin:
      const EdgeInsets.all(10),

  child: Padding(

    padding:
        const EdgeInsets.all(20),

    child: Column(

      children: [

        const Text(

          "عدد التسميعات اليوم",

          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 15,
        ),

        StreamBuilder(

  stream: FirebaseFirestore.instance
      .collection('sessions')

      .where(
        'date',
        isEqualTo:
            "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}"
      )

      .where(
        'absent',
        isEqualTo: false,
      )

      .snapshots(),

  builder: (context, snapshot) {

    if (!snapshot.hasData) {
      return const CircularProgressIndicator();
    }

    final count =
        snapshot.data!.docs.length;

    return Text(

      count.toString(),

      style: const TextStyle(
        fontSize: 35,
        color: Colors.green,
        fontWeight:
            FontWeight.bold,
      ),
    );
  },
),
      ],
    ),
  ),
),

Card(

  margin:
      const EdgeInsets.all(10),

  child: Padding(

    padding:
        const EdgeInsets.all(20),

    child: Column(

      children: [

        const Text(

          "نسبة الحضور اليوم",

          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 15,
        ),

        StreamBuilder(

  stream: FirebaseFirestore.instance
      .collection('sessions')

      .where(
        'date',
        isEqualTo:
            "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}"
      )

      .snapshots(),

  builder: (context, snapshot) {

    if (!snapshot.hasData) {
      return const CircularProgressIndicator();
    }

    final docs =
        snapshot.data!.docs;

    if (docs.isEmpty) {

      return const Text(

        "0%",

        style: TextStyle(
          fontSize: 35,
          color: Colors.blue,
          fontWeight:
              FontWeight.bold,
        ),
      );
    }

    int presentCount = 0;

    for (var doc in docs) {

      final data =
          doc.data();

      if (data['absent'] == false) {

        presentCount++;
      }
    }

    final percentage =
        ((presentCount /
                    docs.length) *
                100)
            .round();

    return Text(

      "$percentage%",

      style: const TextStyle(
        fontSize: 35,
        color: Colors.blue,
        fontWeight:
            FontWeight.bold,
      ),
    );
  },
),
      ],
    ),
  ),
),
        ],
      ),
    );
  }
}