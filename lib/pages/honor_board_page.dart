import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HonorBoardPage
    extends StatelessWidget {
  const HonorBoardPage({
    super.key,
  });

  Future<List<Map<String, dynamic>>>
      getTopStudents(
    String type,
  ) async {
    final students =
        await FirebaseFirestore.instance
            .collection('students')
            .where(
              'studentType',
              isEqualTo: type,
            )
            .where(
              'archived',
              isEqualTo: false,
            )
            .get();

    List<Map<String, dynamic>> result =
        [];

    for (var student in students.docs) {
      final sessions =
          await FirebaseFirestore
              .instance
              .collection('sessions')
              .where(
                'studentId',
                isEqualTo: student.id,
              )
              .get();

      int score = 0;

      for (var session in sessions.docs) {
        final data =
            session.data();

        if (data['absent'] == true) {
          continue;
        }

        final newMem =
            data['newMemorization']
                .toString();

        score +=
            newMem.length;

        if (data['rating'] ==
            "ممتاز") {
          score += 20;
        }

        if (data['rating'] ==
            "جيد") {
          score += 10;
        }
      }

      result.add({
        'name':
            student['name'],
        'serial':
            student['serial'],
        'score': score,
      });
    }

    result.sort(
      (a, b) =>
          b['score']
              .compareTo(a['score']),
    );

    return result.take(5).toList();
  }

  Widget buildSection(
    String title,
    Color color,
    List<Map<String, dynamic>> data,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 20,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
                color: color,
              ),
            ),

            const SizedBox(height: 15),

            ...data.asMap().entries.map(
              (e) {
                final index = e.key;

                final student =
                    e.value;

                return Container(
                  margin:
                      const EdgeInsets
                          .only(
                    bottom: 10,
                  ),
                  padding:
                      const EdgeInsets
                          .all(12),
                  decoration:
                      BoxDecoration(
                    color: color
                        .withOpacity(
                      0.1,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            color,
                        child: Text(
                          "${index + 1}",
                          style:
                              const TextStyle(
                            color: Colors
                                .white,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 15,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              student['name'],
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                            Text(
                              student[
                                  'serial'],
                            ),
                          ],
                        ),
                      ),

                      Text(
                        "${student['score']} نقطة",
                        style:
                            TextStyle(
                          color: color,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      )
                    ],
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("لوحة الشرف"),
      ),
      body: FutureBuilder(
        future: Future.wait([
          getTopStudents("new"),
          getTopStudents("old"),
          getTopStudents("completed"),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final newStudents =
              snapshot.data![0];

          final oldStudents =
              snapshot.data![1];

          final completedStudents =
              snapshot.data![2];

          return ListView(
            padding:
                const EdgeInsets.all(15),
            children: [
              buildSection(
                "الطلاب الجدد",
                Colors.blue,
                newStudents,
              ),

              buildSection(
                "الطلاب القدامى",
                Colors.orange,
                oldStudents,
              ),

              buildSection(
                "الخاتمين",
                Colors.green,
                completedStudents,
              ),
            ],
          );
        },
      ),
    );
  }
}