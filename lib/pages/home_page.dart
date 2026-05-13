import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_page.dart';
import 'create_cycle_page.dart';
import 'cycles_page.dart';
import 'add_student_page.dart';
import 'students_page.dart';
import 'assign_students_page.dart';
import '../models/cycle_model.dart';
import '../services/cycle_service.dart';
import 'statistics_page.dart';
import 'honor_board_page.dart';
import 'dashboard_page.dart';
import 'supervisor_page.dart';

class HomePage extends StatefulWidget {
  final String uid;
  final String role;

  const HomePage({
    super.key,
    required this.uid,
    required this.role,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final cycleService = CycleService();

  String currentCycle = "لا يوجد دورة";

CycleModel? currentCycleModel;

  @override
  void initState() {
    super.initState();

    loadCycle();
  }

  loadCycle() async {
    final cycle =
        await cycleService.getCurrentCycle();

    if (cycle != null) {
  currentCycleModel = cycle;

  currentCycle =
      "${cycle.name} (${cycle.cycleNumber})";
}

    setState(() {});
  }

  logout() async {
    await FirebaseAuth.instance.signOut();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.role == "manager"
              ? "لوحة المدير"
              : "لوحة المشرف",
        ),
        actions: [
          IconButton(
onPressed: logout,
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            Card(
  child: ListTile(
    leading: const Icon(Icons.calendar_month),
    title: const Text("الدورة الحالية"),
    subtitle: Text(currentCycle),
  ),
),

const SizedBox(height: 20),

            if (widget.role == "manager") ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const CreateCyclePage(),
                      ),
                    );
                  },
                  child: const Text("إنشاء دورة"),
                ),
                
              ),
            ],
const SizedBox(height: 10),
if (widget.role == "manager")
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const DashboardPage(),
        ),
      );
    },
    child: const Text(
      "لوحة التحكم",
    ),
  ),
),

const SizedBox(height: 10),
if (widget.role == "manager")
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CyclesPage(),
        ),
      );
    },
    child: const Text("عرض الدورات"),
  ),
),
const SizedBox(height: 10),
if (widget.role == "manager")
 if (currentCycleModel != null)
  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddStudentPage(
              cycle: currentCycleModel!,
            ),
          ),
        );
      },
      child: const Text("إضافة طالب"),
    ),
  ),
  const SizedBox(height: 10),

if (currentCycleModel != null)
  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => StudentsPage(
        cycle: currentCycleModel!,
        role: widget.role,
        uid: widget.uid,
      ),
    ),
  );
},

child: const Text("عرض الطلاب"),
),
),

const SizedBox(height: 10),
if (widget.role == "manager")
SizedBox(
  width: double.infinity,

  child: ElevatedButton(

    onPressed: () {

      Navigator.push(
        context,

        MaterialPageRoute(
          builder: (_) =>
              const SupervisorPage(),
        ),
      );
    },

    child: const Text(
      "إضافة مشرفين للمعهد",
    ),
  ),
),

const SizedBox(height: 10),

if (widget.role == "manager" &&
    currentCycleModel != null)
  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AssignStudentsPage(
              cycle: currentCycleModel!,
            ),
          ),
        );
      },
      child: const Text(
        "توزيع الطلاب",
      ),
    ),
  ),
  const SizedBox(height: 10),

SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
         builder: (_) => const StatisticsPage(),
        ),
      );
    },
    child: const Text(
      "الإحصائيات",
    ),
  ),
),
const SizedBox(height: 10),

SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const HonorBoardPage(),
        ),
      );
    },
    child: const Text(
      "لوحة الشرف",
    ),
  ),
),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      widget.role == "manager"
                          ? "أهلاً مدير المعهد"
                          : "أهلاً أيها المشرف",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}