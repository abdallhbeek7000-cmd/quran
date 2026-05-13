import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_session_page.dart';
import '../services/session_service.dart';

class StudentSessionsPage
    extends StatelessWidget {
  final String studentId;

  final String studentName;

  final String role;

  const StudentSessionsPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final sessionService = SessionService();

    return Scaffold(
      appBar: AppBar(
        title: Text(studentName),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: sessionService
            .getStudentSessions(studentId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final sessions =
              snapshot.data!.docs;

          if (sessions.isEmpty) {
            return const Center(
              child: Text(
                "لا يوجد جلسات",
              ),
            );
          }

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session =
                  sessions[index];

              final data =
                  session.data()
                      as Map<String, dynamic>;

              Color ratingColor =
                  Colors.orange;

              if (data['rating'] ==
                  "ممتاز") {
                ratingColor = Colors.green;
              }

              if (data['rating'] ==
                  "سيء") {
                ratingColor = Colors.red;
              }

              return Card(
                margin:
                    const EdgeInsets.all(10),
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    15,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          Text(
                            data['date'],
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          if (data['absent'])
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    10,
                                vertical: 5,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.red,
                                borderRadius:
                                    BorderRadius.circular(
                                  10,
                                ),
                              ),
                              child: const Text(
                                "غائب",
                                style:
                                    TextStyle(
                                  color: Colors
                                      .white,
                                ),
                              ),
                            )
                        ],
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      if (!data['absent']) ...[
                        Text(
                          "الحفظ الجديد: ${data['newMemorization']}",
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          "المراجعة: ${data['review']}",
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          "الواجب: ${data['homework']}",
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Row(
                          children: [
                            const Text(
                              "التقييم: ",
                            ),
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    10,
                                vertical: 5,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    ratingColor,
                                borderRadius:
                                    BorderRadius.circular(
                                  10,
                                ),
                              ),
                              child: Text(
                                data['rating'],
                                style:
                                    const TextStyle(
                                  color: Colors
                                      .white,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          "حالة الطالب: ${data['studentStatus']}",
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          "نشاطات دينية: ${data['religiousActivities']}",
                        ),
                      ],

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        "ملاحظات: ${data['notes']}",
                      ),
Align(
  alignment: Alignment.centerLeft,
  child: TextButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditSessionPage(
            sessionId: session.id,
            data: data,
          ),
        ),
      );
    },
    child: const Text(
      "تعديل الجلسة",
    ),
  ),
),
                      if (role == "manager")
                        Align(
                          alignment:
                              Alignment.centerLeft,
                          child: TextButton(
                            onPressed:
                                () async {
                              await sessionService
                                  .deleteSession(
                                session.id,
                              );
                            },
                            child: const Text(
                              "حذف الجلسة",
                              style: TextStyle(
                                color:
                                    Colors.red,
                              ),
                            ),
                          ),
                        )
                    ],
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