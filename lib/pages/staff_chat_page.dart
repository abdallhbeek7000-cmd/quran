import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart';

class StaffChatPage extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String peerId;
  final String peerName;
  final String peerRole;

  const StaffChatPage({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.peerId,
    required this.peerName,
    required this.peerRole,
  });

  @override
  State<StaffChatPage> createState() => _StaffChatPageState();
}

class _StaffChatPageState extends State<StaffChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  @override
  void initState() {
    super.initState();
    _clearUnreadBadge();
  }

  void _clearUnreadBadge() async {
    await FirebaseFirestore.instance.collection('staff_chats').doc(widget.chatId).set({
      'unread_${widget.currentUserId}': 0,
    }, SetOptions(merge: true));
  }

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

    await FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': widget.currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {}, // 🚀 تجهيز حقل التفاعلات
    });

    await FirebaseFirestore.instance.collection('staff_chats').doc(widget.chatId).set({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': widget.currentUserId,
      'participants': [widget.currentUserId, widget.peerId], 
      'unread_${widget.peerId}': FieldValue.increment(1), 
    }, SetOptions(merge: true));

    if (mounted) {
      await NotificationService.sendAndSaveNotification(
        studentId: widget.peerId, 
        title: "💬 رسالة من الطاقم (${widget.peerRole == 'manager' ? 'المدير' : 'المشرف'})",
        body: text,
        type: "staff_chat",
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

  // 🚀 دالة إظهار قائمة التفاعلات (الإيموجي) عند الضغط المطول
  void _showReactionMenu(BuildContext context, String messageId, bool isDark) {
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff1e293b).withOpacity(0.95) : Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis.map((emoji) {
              return GestureDetector(
                onTap: () {
                  // 🚀 إضافة أو تحديث التفاعل في قاعدة البيانات
                  FirebaseFirestore.instance
                      .collection('staff_chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .doc(messageId)
                      .set({
                    'reactions': {
                      widget.currentUserId: emoji // نحفظ التفاعل باسم المستخدم الحالي
                    }
                  }, SetOptions(merge: true));
                  Navigator.pop(context);
                },
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              );
            }).toList(),
          ),
        );
      }
    );
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
        title: Column(
          children: [
            Text(
              widget.peerName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo'),
            ),
            Text(
              widget.peerRole == 'manager' ? 'مدير المعهد' : 'زميل إشراف',
              style: TextStyle(fontSize: 11, color: isDark ? accentGold : Colors.grey.shade600, fontFamily: 'Cairo'),
            ),
          ],
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
              
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('staff_chats').doc(widget.chatId).snapshots(),
                  builder: (context, chatSnapshot) {
                    bool isReadByPeer = false;
                    if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                      final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
                      isReadByPeer = (chatData['unread_${widget.peerId}'] ?? 0) == 0;
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('staff_chats')
                          .doc(widget.chatId)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
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
                                Icon(Icons.groups_rounded, size: 80, color: isDark ? Colors.white24 : primaryColor.withOpacity(0.3)),
                                const SizedBox(height: 10),
                                Text("بداية المحادثة مع الطاقم الداخلي.", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54)),
                              ],
                            ),
                          );
                        }

                        final messages = snapshot.data!.docs;

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msgDoc = messages[index];
                            final msg = msgDoc.data() as Map<String, dynamic>;
                            final isMe = msg['senderId'] == widget.currentUserId;
                            final String timeString = _formatTime(msg['timestamp'] as Timestamp?);
                            
                            // 🚀 قراءة التفاعلات إن وجدت
                            final Map<String, dynamic> reactions = msg['reactions'] ?? {};
                            final List<String> displayEmojis = reactions.values.map((e) => e.toString()).toSet().toList();

                            return Align(
                              alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 20), // مسافة إضافية لتتسع للتفاعل
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // 🚀 فقاعة الرسالة (مع GestureDetector للضغطة المطولة)
                                    GestureDetector(
                                      onLongPress: () => _showReactionMenu(context, msgDoc.id, isDark),
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
                                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                            decoration: BoxDecoration(
                                              color: isMe 
                                                  ? primaryColor.withOpacity(0.75) 
                                                  : (isDark ? accentGold.withOpacity(0.15) : Colors.white.withOpacity(0.7)),
                                              border: Border.all(
                                                color: isMe 
                                                    ? Colors.white.withOpacity(0.2) 
                                                    : (isDark ? accentGold.withOpacity(0.3) : Colors.white.withOpacity(0.8)),
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
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      timeString,
                                                      style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontSize: 10,
                                                        color: isMe ? Colors.white60 : (isDark ? Colors.white54 : Colors.black54),
                                                      ),
                                                    ),
                                                    if (isMe) ...[
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.done_all_rounded,
                                                        size: 14,
                                                        color: isReadByPeer ? (isDark ? accentGold : Colors.lightBlueAccent) : Colors.white38,
                                                      ),
                                                    ]
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // 🚀 شارة التفاعل (تظهر فقط إذا كان هناك تفاعل)
                                    if (displayEmojis.isNotEmpty)
                                      Positioned(
                                        bottom: -12,
                                        left: isMe ? 15 : null,
                                        right: isMe ? null : 15,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xff1e293b) : Colors.white,
                                            borderRadius: BorderRadius.circular(15),
                                            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1),
                                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                          ),
                                          child: Text(
                                            displayEmojis.join(' '), // دمج الإيموجيات وعرضها
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }
                ),
              ),

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
                              hintText: "اكتب رسالتك لزميلك...",
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