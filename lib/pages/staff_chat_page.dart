import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
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

class _StaffChatPageState extends State<StaffChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  // 🎙️ متحكمات التسجيل الصوتي
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isUploadingAudio = false;
  DateTime? _recordingStartTime;

  late AnimationController _micPulseController;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _clearUnreadBadge();

    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _micPulseController.dispose();
    super.dispose();
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

  // 🎙️ بدء التسجيل الصوتي
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String filePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
        });
      }
    } catch (e) {
      print("❌ خطأ عند بدء التسجيل الصوتي: $e");
    }
  }

  // 🛑 إيقاف التسجيل الصوتي ورفعه
  Future<void> _stopAndSendRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path == null) return;

      int durationSec = 0;
      if (_recordingStartTime != null) {
        durationSec = DateTime.now().difference(_recordingStartTime!).inSeconds;
      }

      setState(() {
        _isRecording = false;
        _isUploadingAudio = true;
      });

      if (durationSec < 1) {
        setState(() => _isUploadingAudio = false);
        return;
      }

      File audioFile = File(path);
      String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('staff_chat_audio')
          .child(widget.chatId)
          .child(fileName);

      UploadTask uploadTask = ref.putFile(audioFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      _sendAudioMessage(downloadUrl, durationSec);
    } catch (e) {
      print("❌ خطأ أثناء رفع التسجيل الصوتي: $e");
    } finally {
      if (mounted) setState(() => _isUploadingAudio = false);
    }
  }

  // 🎙️ إلغاء التسجيل
  Future<void> _cancelRecording() async {
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });
  }

  // 💬 إرسال الرسالة النصية
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
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    });

    _updateChatLastMessage("💬 $text");
  }

  // 🎙️ إرسال الرسالة الصوتية
  void _sendAudioMessage(String audioUrl, int duration) async {
    _scrollToBottom();

    await FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': widget.currentUserId,
      'audioUrl': audioUrl,
      'duration': duration,
      'type': 'audio',
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    });

    _updateChatLastMessage("🎙️ تسجيل صوتي ($duration ثانية)");
  }

  void _updateChatLastMessage(String lastMessage) async {
    await FirebaseFirestore.instance.collection('staff_chats').doc(widget.chatId).set({
      'lastMessage': lastMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': widget.currentUserId,
      'participants': [widget.currentUserId, widget.peerId],
      'unread_${widget.peerId}': FieldValue.increment(1),
    }, SetOptions(merge: true));

    if (mounted) {
      await NotificationService.sendAndSaveNotification(
        studentId: widget.peerId,
        title: "💬 رسالة جديدة (${widget.peerRole == 'manager' ? 'المدير' : 'المشرف'})",
        body: lastMessage,
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

  void _showReactionMenu(BuildContext context, String messageId, bool isDark) {
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(bottom: 35, left: 20, right: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1e293b).withOpacity(0.85) : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: isDark ? Colors.white24 : Colors.white.withOpacity(0.8), width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 25, spreadRadius: 5)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: emojis.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        FirebaseFirestore.instance
                            .collection('staff_chats')
                            .doc(widget.chatId)
                            .collection('messages')
                            .doc(messageId)
                            .set({
                          'reactions': {
                            widget.currentUserId: emoji
                          }
                        }, SetOptions(merge: true));
                        Navigator.pop(context);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 30)),
                    );
                  }).toList(),
                ),
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
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff0b0f19) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xff0f172a).withOpacity(0.7) : Colors.white.withOpacity(0.75),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.transparent),
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: accentGold.withOpacity(0.2),
              child: Icon(
                widget.peerRole == 'manager' ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                size: 20,
                color: accentGold,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo'),
                ),
                Text(
                  widget.peerRole == 'manager' ? 'إدارة المعهد 🌟' : 'كادر الإشراف 🛡️',
                  style: TextStyle(fontSize: 10, color: isDark ? accentGold : Colors.grey.shade600, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // خلفية متدرجة حديثة
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xff090d16), const Color(0xff111827), const Color(0xff0f172a)]
                    : [const Color(0xffe2e8f0), const Color(0xffdbeaff), const Color(0xfff1f5f9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // دوائر ديكورية متوهجة بالخلفية
          Positioned(
            top: 120,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? primaryColor.withOpacity(0.2) : primaryColor.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 80, spreadRadius: 20)
                ],
              ),
            ),
          ),

          Column(
            children: [
              const SizedBox(height: kToolbarHeight + 45),

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
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? Colors.white.withOpacity(0.05) : primaryColor.withOpacity(0.05),
                                  ),
                                  child: Icon(Icons.forum_rounded, size: 60, color: isDark ? accentGold : primaryColor),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "بداية التواصل المباشر والمشفر مع الطاقم 🔒",
                                  style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }

                        final messages = snapshot.data!.docs;

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msgDoc = messages[index];
                            final msg = msgDoc.data() as Map<String, dynamic>;
                            final isMe = msg['senderId'] == widget.currentUserId;
                            final String timeString = _formatTime(msg['timestamp'] as Timestamp?);

                            final Map<String, dynamic> reactions = msg['reactions'] ?? {};
                            final List<String> displayEmojis = reactions.values.map((e) => e.toString()).toSet().toList();
                            final bool isAudio = msg['type'] == 'audio';

                            return _AnimatedMessageBubble(
                              index: index,
                              isMe: isMe,
                              child: Align(
                                alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      GestureDetector(
                                        onLongPress: () => _showReactionMenu(context, msgDoc.id, isDark),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(24),
                                              topRight: const Radius.circular(24),
                                              bottomLeft: Radius.circular(isMe ? 6 : 24),
                                              bottomRight: Radius.circular(isMe ? 24 : 6),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isMe 
                                                    ? primaryColor.withOpacity(0.2) 
                                                    : Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                                                blurRadius: 12,
                                                offset: const Offset(0, 5),
                                              )
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(24),
                                              topRight: const Radius.circular(24),
                                              bottomLeft: Radius.circular(isMe ? 6 : 24),
                                              bottomRight: Radius.circular(isMe ? 24 : 6),
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                              child: Container(
                                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: isMe
                                                        ? [primaryColor.withOpacity(0.92), const Color(0xff2d4356)]
                                                        : (isDark 
                                                            ? [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.04)] 
                                                            : [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.85)]),
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  border: Border.all(
                                                    color: isMe
                                                        ? Colors.white.withOpacity(0.2)
                                                        : (isDark ? Colors.white.withOpacity(0.12) : Colors.white),
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                                  children: [
                                                    if (isAudio)
                                                      _AudioMessagePlayer(
                                                        audioUrl: msg['audioUrl'] ?? '',
                                                        duration: msg['duration'] ?? 0,
                                                        isMe: isMe,
                                                        isDark: isDark,
                                                        accentGold: accentGold,
                                                      )
                                                    else
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
                                                            fontWeight: FontWeight.w600,
                                                            color: isMe ? Colors.white70 : (isDark ? Colors.white54 : Colors.black54),
                                                          ),
                                                        ),
                                                        if (isMe) ...[
                                                          const SizedBox(width: 5),
                                                          Icon(
                                                            Icons.done_all_rounded,
                                                            size: 15,
                                                            color: isReadByPeer ? accentGold : Colors.white38,
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
                                          bottom: -12,
                                          left: isMe ? 15 : null,
                                          right: isMe ? null : 15,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xff1e293b) : Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1),
                                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                                            ),
                                            child: Text(
                                              displayEmojis.join(' '),
                                              style: const TextStyle(fontSize: 13),
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
                  },
                ),
              ),

              // 🎙️ صندوق الكتابة والتسجيل المتطور
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
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff1e293b).withOpacity(0.85) : Colors.white.withOpacity(0.9),
                        border: Border.all(color: isDark ? Colors.white24 : Colors.white, width: 1.5),
                      ),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _messageController,
                        builder: (context, value, child) {
                          bool hasText = value.text.trim().isNotEmpty;

                          if (_isUploadingAudio) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 12),
                                  Text("جاري رفع التسجيل الصوتي...", style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }

                          if (_isRecording) {
                            return Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 26),
                                  onPressed: _cancelRecording,
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ScaleTransition(
                                        scale: Tween(begin: 0.8, end: 1.2).animate(_micPulseController),
                                        child: const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "جاري التسجيل الصوتي...",
                                        style: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _stopAndSendRecording,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                  ),
                                )
                              ],
                            );
                          }

                          return Row(
                            children: [
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: 'Cairo', fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: "اكتب رسالة متطورة...",
                                    hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade500, fontFamily: 'Cairo', fontSize: 13),
                                    fillColor: Colors.transparent,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: hasText ? _sendMessage : _startRecording,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: hasText 
                                          ? [accentGold, const Color(0xffb89228)] 
                                          : [primaryColor, const Color(0xff2d4356)],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (hasText ? accentGold : primaryColor).withOpacity(0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Icon(
                                    hasText ? Icons.send_rounded : Icons.mic_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              )
                            ],
                          );
                        },
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

// 🔊 مشغل الصوت العصري داخل الرسائل
class _AudioMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final int duration;
  final bool isMe;
  final bool isDark;
  final Color accentGold;

  const _AudioMessagePlayer({
    required this.audioUrl,
    required this.duration,
    required this.isMe,
    required this.isDark,
    required this.accentGold,
  });

  @override
  State<_AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<_AudioMessagePlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _totalDuration = Duration(seconds: widget.duration);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration duration) {
    String minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    Color iconColor = widget.isMe ? Colors.white : (widget.isDark ? Colors.white : const Color(0xff425c75));

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isMe ? Colors.white.withOpacity(0.2) : widget.accentGold.withOpacity(0.2),
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 28,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    trackHeight: 3,
                    activeTrackColor: widget.isMe ? widget.accentGold : iconColor,
                    inactiveTrackColor: iconColor.withOpacity(0.25),
                    thumbColor: widget.isMe ? widget.accentGold : iconColor,
                  ),
                  child: Slider(
                    value: _position.inSeconds.toDouble().clamp(0.0, _totalDuration.inSeconds.toDouble()),
                    max: _totalDuration.inSeconds > 0 ? _totalDuration.inSeconds.toDouble() : 1.0,
                    onChanged: (value) async {
                      final pos = Duration(seconds: value.toInt());
                      await _audioPlayer.seek(pos);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    _formatDuration(_isPlaying ? _position : _totalDuration),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: widget.isMe ? Colors.white70 : (widget.isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
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

    _slideAnimation = Tween<Offset>(begin: Offset(startDx, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
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