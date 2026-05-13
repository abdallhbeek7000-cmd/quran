import 'package:flutter/material.dart';

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

      body: const Center(

        child: Text(
          "صفحة الإحصائيات اليومية",
        ),
      ),
    );
  }
}