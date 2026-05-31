import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart'; 

class SupervisorChatPage extends StatefulWidget {
  final String chatId;
  final String studentId;
  final String studentName;
  final String supervisorId;

  const SupervisorChatPage({
    super.key,
    required this.chatId,
    required this.studentId,
    required this.studentName,
    required this.supervisorId,
  });

  @override
  State<SupervisorChatPage> createState() => _SupervisorChatPageState();
}

class _SupervisorChatPageState extends State<SupervisorChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  @override
  void initState() {
    super.initState();
    _clearUnreadBadge();
  }

  // 🎯 تصفير العداد لما المشرف يفتح المحادثة
  void _clearUnreadBadge() async {
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'unreadBySupervisor': 0,
    });
  }

  // 🎯 دالة تنسيق الوقت بدون مكتبات خارجية (مثال: 10:30 م)
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'م' : 'ص';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _scrollToBottom();

    // 1. حفظ رسالة المشرف في فايربيز
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': widget.supervisorId,
      'senderType': 'supervisor',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. تحديث مستند المتابعة الرئيسي
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderType': 'supervisor',
    }, SetOptions(merge: true));

    // 3. إرسال إشعار فوري لهاتف الأب
    if (mounted) {
      await NotificationService.sendAndSaveNotification(
        studentId: widget.studentId, 
        title: "💬 رسالة جديدة من مشرف الدورة",
        body: text,
        type: "chat",
        context: context,
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
        title: Text(
          "محادثة ولي أمر: ${widget.studentName}",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo'),
        ),
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

          Column(
            children: [
              const SizedBox(height: kToolbarHeight + 40),
              
              // 📝 منطقة استعراض رسائل المحادثة الحية
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text("لا توجد رسائل سابقة.", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54)));
                    }

                    final messages = snapshot.data!.docs;

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index].data() as Map<String, dynamic>;
                        final isMe = msg['senderType'] == 'supervisor';
                        final String timeString = _formatTime(msg['timestamp'] as Timestamp?);

                        return Align(
                          alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            // 🚀 تأثير الزجاج للرسائل
                            child: ClipRRect(
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(isMe ? 0 : 20),
                                bottomRight: Radius.circular(isMe ? 20 : 0),
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isMe 
                                        ? primaryColor.withOpacity(0.75) 
                                        : (isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.7)),
                                    border: Border.all(
                                      color: isMe 
                                          ? Colors.white.withOpacity(0.2) 
                                          : (isDark ? Colors.white24 : Colors.white.withOpacity(0.8)),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        msg['text'] ?? '',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // 🕒 عرض الوقت بشكل أنيق
                                      Text(
                                        timeString,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 10,
                                          color: isMe ? Colors.white60 : (isDark ? Colors.white54 : Colors.black54),
                                        ),
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

              // ⌨️ صندوق إدخال النص الزجاجي الفاخر للمشرف
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1e293b).withOpacity(0.6) : Colors.white.withOpacity(0.7),
                      border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.white, width: 1.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: 'Cairo'),
                            decoration: InputDecoration(
                              hintText: "اكتب رداً لولي الأمر...",
                              hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontFamily: 'Cairo', fontSize: 13),
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.white54,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: isDark ? accentGold : primaryColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (isDark ? accentGold : primaryColor).withOpacity(0.3), blurRadius: 10, spreadRadius: 1)]),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}