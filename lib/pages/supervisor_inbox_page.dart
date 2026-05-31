import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'supervisor_chat_page.dart'; 

class SupervisorInboxPage extends StatelessWidget {
  final String supervisorId;

  const SupervisorInboxPage({super.key, required this.supervisorId});

  // 🎯 دالة لعرض قائمة طلاب المشرف لبدء محادثة جديدة (Bottom Sheet زجاجي)
  void _showNewChatBottomSheet(BuildContext context, bool isDark, Color primaryColor, Color goldColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65, // القائمة بتاخد 65% من الشاشة
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff1e293b).withOpacity(0.8) : Colors.white.withOpacity(0.9),
                border: Border(top: BorderSide(color: isDark ? Colors.white24 : Colors.white, width: 1.5)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  // مؤشر السحب
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 15),
                  Text("اختر طالباً لمراسلة ولي أمره", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                  const SizedBox(height: 15),
                  
                  // جلب طلاب هذا المشرف من قاعدة البيانات
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('students')
                          .where('supervisorId', isEqualTo: supervisorId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: goldColor));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Text("لا يوجد طلاب مسجلين باسمك حالياً", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54)));
                        }

                        final students = snapshot.data!.docs;
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final studentDoc = students[index];
                            final studentData = studentDoc.data() as Map<String, dynamic>;
                            final studentName = studentData['name'] ?? 'غير معروف';
                            final studentId = studentDoc.id;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: goldColor.withOpacity(0.2), child: Icon(Icons.person, color: goldColor)),
                                title: Text(studentName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                subtitle: Text("ولي الأمر", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                                trailing: Icon(Icons.chat_bubble_outline, color: goldColor),
                                onTap: () {
                                  Navigator.pop(context); // إغلاق القائمة
                                  // 🚀 الانتقال لغرفة الدردشة مع هذا الطالب
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SupervisorChatPage(
                                        chatId: '${studentId}_$supervisorId',
                                        studentId: studentId,
                                        studentName: studentName,
                                        supervisorId: supervisorId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final Color primaryColor = const Color(0xff425c75);
    final Color goldColor = const Color(0xffD4AF37);

    timeago.setLocaleMessages('ar', timeago.ArMessages());

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
        title: Text(
          "رسائل الأهالي",
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo'),
        ),
      ),
      // 🎯 زر عائم فخم لبدء محادثة جديدة
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewChatBottomSheet(context, isDark, primaryColor, goldColor),
        backgroundColor: goldColor,
        elevation: 5,
        icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
        label: const Text("مراسلة ولي أمر", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(top: -50, left: -50, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? goldColor.withOpacity(0.08) : goldColor.withOpacity(0.12)))),

          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('supervisorId', isEqualTo: supervisorId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mark_chat_read_rounded, size: 80, color: isDark ? Colors.white24 : primaryColor.withOpacity(0.3)),
                        const SizedBox(height: 15),
                        Text("لا توجد رسائل سابقة", style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : primaryColor, fontFamily: 'Cairo')),
                        const SizedBox(height: 5),
                        Text("اضغط على الزر بالأسفل لبدء المراسلة", style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black45, fontFamily: 'Cairo')),
                      ],
                    ),
                  );
                }

                var chats = snapshot.data!.docs;
                chats.sort((a, b) {
                  var aData = a.data() as Map<String, dynamic>;
                  var bData = b.data() as Map<String, dynamic>;
                  var aTime = aData['lastMessageTime'] as Timestamp?;
                  var bTime = bData['lastMessageTime'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 80), // 80 بكسل بالأسفل عشان الزر العائم ما يغطي آخر رسالة
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chatDoc = chats[index];
                    final chatData = chatDoc.data() as Map<String, dynamic>;
                    final studentName = chatData['studentName'] ?? 'طالب غير معروف';
                    final lastMessage = chatData['lastMessage'] ?? '';
                    final unreadCount = chatData['unreadBySupervisor'] ?? 0;
                    
                    DateTime? lastTime;
                    if (chatData['lastMessageTime'] != null) {
                      lastTime = (chatData['lastMessageTime'] as Timestamp).toDate();
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SupervisorChatPage(
                                    chatId: chatDoc.id,
                                    studentId: chatData['studentId'] ?? '',
                                    studentName: studentName,
                                    supervisorId: supervisorId,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: isDark ? const Color(0xff1e293b) : primaryColor.withOpacity(0.1),
                                    child: Icon(Icons.person_rounded, color: isDark ? goldColor : primaryColor),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "ولي أمر الطالب: $studentName",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo'),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          lastMessage,
                                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Cairo'),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (lastTime != null)
                                        Text(
                                          timeago.format(lastTime, locale: 'ar'),
                                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey, fontFamily: 'Cairo'),
                                        ),
                                      const SizedBox(height: 8),
                                      if (unreadCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}