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

  void _clearUnreadBadge() async {
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
      'unreadBySupervisor': 0,
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

    // 1️⃣ إرسال الرسالة إلى داتابيز الفايرستور (تظهر بالشات فوراً)
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': widget.supervisorId, 
      'senderType': 'supervisor',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {}, 
    });

    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderType': 'supervisor',
      'lastSenderId': widget.supervisorId,
      'studentId': widget.studentId,
      'studentName': widget.studentName,
      'supervisorId': widget.supervisorId, 
      'unreadByParent': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // 2️⃣ إرسال الإشعار بخلفية سريعة وبدون تسبب في أي خطأ بصري
    if (mounted) {
      NotificationService.sendAndSaveNotification(
        studentId: widget.studentId, 
        title: "💬 رسالة جديدة من مشرف الدورة",
        body: text,
        type: "chat",
        chatStudentId: widget.studentId,
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

  void _showReactionMenu(BuildContext context, String messageId, bool isDark) {
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1e293b).withOpacity(0.8) : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isDark ? Colors.white24 : Colors.white, width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: emojis.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        FirebaseFirestore.instance
                            .collection('chats')
                            .doc(widget.chatId)
                            .collection('messages')
                            .doc(messageId)
                            .set({
                          'reactions': {
                            widget.supervisorId: emoji 
                          }
                        }, SetOptions(merge: true));
                        Navigator.pop(context);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff0f172a) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xff1e293b).withOpacity(0.7) : Colors.white.withOpacity(0.7),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: Colors.transparent),
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
        title: Column(
          children: [
            Text(
              "ولي أمر الطالب",
              style: TextStyle(fontSize: 10, color: isDark ? accentGold : Colors.grey.shade600, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
            Text(
              widget.studentName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo'),
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
          Positioned(top: 100, left: -50, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.1)))),
          Positioned(bottom: 200, right: -80, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.15)))),

          Column(
            children: [
              const SizedBox(height: kToolbarHeight + 40),
              
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
                  builder: (context, chatSnapshot) {
                    bool isReadByParent = false;
                    if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                      final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
                      isReadByParent = (chatData['unreadByParent'] ?? 0) == 0;
                    }

                    return StreamBuilder<QuerySnapshot>(
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
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.forum_rounded, size: 80, color: isDark ? Colors.white24 : primaryColor.withOpacity(0.3)),
                                const SizedBox(height: 10),
                                Text("لا توجد رسائل سابقة. ابدأ المحادثة!", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54)),
                              ],
                            ),
                          );
                        }

                        final messages = snapshot.data!.docs;

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msgDoc = messages[index];
                            final msg = msgDoc.data() as Map<String, dynamic>;
                            final isMe = msg['senderId'] == widget.supervisorId; 
                            final String timeString = _formatTime(msg['timestamp'] as Timestamp?);
                            
                            final Map<String, dynamic> reactions = msg['reactions'] ?? {};
                            final List<String> displayEmojis = reactions.values.map((e) => e.toString()).toSet().toList();

                            return _AnimatedMessageBubble(
                              index: index,
                              isMe: isMe,
                              child: Align(
                                alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 22), 
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.78, 
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      GestureDetector(
                                        onLongPress: () => _showReactionMenu(context, msgDoc.id, isDark),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              )
                                            ]
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(22),
                                              topRight: const Radius.circular(22),
                                              bottomLeft: Radius.circular(isMe ? 5 : 22), 
                                              bottomRight: Radius.circular(isMe ? 22 : 5),
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                              child: Container(
                                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: isMe 
                                                        ? [primaryColor.withOpacity(0.85), primaryColor.withOpacity(0.7)] 
                                                        : (isDark ? [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)] : [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)]),
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  border: Border.all(
                                                    color: isMe 
                                                        ? Colors.white.withOpacity(0.25) 
                                                        : (isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.8)),
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
                                                        fontSize: 14.5,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          timeString,
                                                          style: TextStyle(
                                                            fontFamily: 'Cairo',
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: isMe ? Colors.white70 : (isDark ? Colors.white54 : Colors.black54),
                                                          ),
                                                        ),
                                                        if (isMe) ...[
                                                          const SizedBox(width: 5),
                                                          Icon(
                                                            Icons.done_all_rounded,
                                                            size: 15,
                                                            color: isReadByParent ? (isDark ? accentGold : Colors.lightBlueAccent) : Colors.white38,
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
                                      ),
                                      
                                      if (displayEmojis.isNotEmpty)
                                        Positioned(
                                          bottom: -14,
                                          left: isMe ? 15 : null,
                                          right: isMe ? null : 15,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(20),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xff1e293b).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1.2),
                                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                                ),
                                                child: Text(
                                                  displayEmojis.join(' '), 
                                                  style: const TextStyle(fontSize: 14),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
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

              Container(
                margin: EdgeInsets.only(
                  left: 15, 
                  right: 15, 
                  top: 5, 
                  bottom: isKeyboardOpen ? 15 : 25, 
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff1e293b).withOpacity(0.8) : Colors.white.withOpacity(0.85),
                        border: Border.all(color: isDark ? Colors.white24 : Colors.white, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: 'Cairo', fontSize: 14),
                              decoration: InputDecoration(
                                hintText: "اكتب رسالتك لولي الأمر...",
                                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade500, fontFamily: 'Cairo', fontSize: 13),
                                filled: true,
                                fillColor: Colors.transparent, 
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: accentGold, 
                                shape: BoxShape.circle, 
                                boxShadow: [BoxShadow(color: accentGold.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            ),
                          )
                        ],
                      ),
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

class _AnimatedMessageBubble extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final int index;

  const _AnimatedMessageBubble({
    required this.child,
    required this.isMe,
    required this.index,
  });

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    
    double startDx = widget.isMe ? -0.2 : 0.2; 
    
    _slideAnimation = Tween<Offset>(begin: Offset(startDx, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
        
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    if (widget.index == 0) {
      _controller.forward();
    } else {
      _controller.value = 1.0; 
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: widget.isMe ? Alignment.bottomLeft : Alignment.bottomRight, 
        child: widget.child,
      ),
    );
  }
}