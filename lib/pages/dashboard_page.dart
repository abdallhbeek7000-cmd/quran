import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/app_colors.dart';

class DashboardPage
    extends StatelessWidget {
  const DashboardPage({
    super.key,
  });

  Widget buildCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),

          const SizedBox(height: 15),

          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight:
                  FontWeight.bold,
              color: color,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            title,
            style: const TextStyle(
              color:
                  AppColors.textLight,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("لوحة التحكم"),
      ),
      body: FutureBuilder(
        future: Future.wait([
          FirebaseFirestore.instance
              .collection('students')
              .where(
                'archived',
                isEqualTo: false,
              )
              .get(),

          FirebaseFirestore.instance
              .collection(
                'users',
              )
              .where(
                'role',
                isEqualTo:
                    "supervisor",
              )
              .get(),

          FirebaseFirestore.instance
              .collection('sessions')
              .get(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final students =
              snapshot.data![0].docs;

          final supervisors =
              snapshot.data![1].docs;

          final sessions =
              snapshot.data![2].docs;

          int absentCount = 0;

          int noSupervisor = 0;

          for (var s in sessions) {
            final data =
                s.data()
                    as Map<String, dynamic>;

            if (data['absent'] ==
                true) {
              absentCount++;
            }
          }

          for (var s in students) {
            final data =
                s.data()
                    as Map<String, dynamic>;

            if (data['supervisorId'] ==
                    null ||
                data['supervisorId'] ==
                    '') {
              noSupervisor++;
            }
          }

          return SingleChildScrollView(
            padding:
                const EdgeInsets.all(20),
            child: Column(
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  children: [
                    buildCard(
                      title:
                          "عدد الطلاب",
                      value: students.length
                          .toString(),
                      icon: Icons.people,
                      color:
                          AppColors.primary,
                    ),

                    buildCard(
                      title:
                          "عدد المشرفين",
                      value: supervisors
                          .length
                          .toString(),
                      icon:
                          Icons.admin_panel_settings,
                      color:
                          AppColors.gold,
                    ),

                    buildCard(
                      title:
                          "عدد الجلسات",
                      value: sessions.length
                          .toString(),
                      icon:
                          Icons.menu_book,
                      color:
                          AppColors.secondary,
                    ),

                    buildCard(
                      title:
                          "عدد الغياب",
                      value:
                          absentCount
                              .toString(),
                      icon:
                          Icons.warning,
                      color:
                          AppColors.danger,
                    ),

                    buildCard(
                      title:
                          "بدون مشرف",
                      value:
                          noSupervisor
                              .toString(),
                      icon:
                          Icons.person_off,
                      color:
                          AppColors.warning,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 25,
                ),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets
                          .all(20),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: const [
                      Text(
                        "ملاحظات الإدارة",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),

                      SizedBox(
                        height: 15,
                      ),

                      Text(
                        "• تأكد من توزيع الطلاب على المشرفين",

                      ),

                      SizedBox(
                        height: 8,
                      ),

                      Text(
                        "• راقب الطلاب كثيري الغياب",

                      ),

                      SizedBox(
                        height: 8,
                      ),

                      Text(
                        "• تابع لوحة الشرف أسبوعيًا",
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}