import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
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
  
  final Color primaryColor = const Color(0xff0f172a);
  final Color accentGold = const Color(0xfffbbf24);
  final Color brandBlue = const Color(0xff2563eb);

  late final AudioRecorder _audioRecorder;
  bool _isUploading = false;
  String _uploadStatusText = '';

  final ImagePicker _imagePicker = ImagePicker();

  // ☁️ بيانات Cloudinary
  final String cloudName = 'dqsrrej2b'; 
  final String uploadPreset = 'rhjrrtqz'; 

  // ↩️ الرسالة المراد الرد عليها
  Map<String, dynamic>? _replyMessage;

  // 🔒 تثبيت الاتصال بالـ Firestore لمقاطعة أي رجفان
  late final Stream<QuerySnapshot> _messagesStream;
  late final Stream<DocumentSnapshot> _chatSnapshotStream;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _clearUnreadBadge();

    _chatSnapshotStream = FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
        .snapshots();

    _messagesStream = FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
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

  String _formatRecordTimer(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // ☁️ رفع الصور
  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1200,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploading = true;
        _uploadStatusText = 'جاري رفع الصورة... 🖼️';
      });

      final bytes = await pickedFile.readAsBytes();
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: pickedFile.name),
        );

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var jsonMap = jsonDecode(String.fromCharCodes(responseData));

      if (response.statusCode == 200 && jsonMap['secure_url'] != null) {
        String downloadUrl = jsonMap['secure_url'];
        _sendMediaMessage(imageUrl: downloadUrl, type: 'image');
      } else {
        throw Exception(jsonMap['error']?['message'] ?? 'فشل الرفع إلى Cloudinary');
      }
    } catch (e) {
      debugPrint("❌ خطأ رفع الصورة: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("تعذر رفع الصورة: ${e.toString()}", style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // 🎙️ رفع الصوت
  Future<void> _uploadAndSendAudio(String? path, int durationSeconds) async {
    setState(() {
      _isUploading = true;
      _uploadStatusText = 'جاري إرسال الصوت... 🎙️';
    });

    try {
      Uint8List? audioBytes;
      String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (kIsWeb) {
        if (path != null && path.isNotEmpty) {
          final res = await http.get(Uri.parse(path));
          audioBytes = res.bodyBytes;
        }
      } else if (path != null && path.isNotEmpty) {
        final xFile = XFile(path);
        audioBytes = await xFile.readAsBytes();
      }

      if (audioBytes == null || audioBytes.isEmpty) {
        setState(() => _isUploading = false);
        return;
      }

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', audioBytes, filename: fileName),
        );

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var jsonMap = jsonDecode(String.fromCharCodes(responseData));

      if (response.statusCode == 200 && jsonMap['secure_url'] != null) {
        String downloadUrl = jsonMap['secure_url'];
        _sendMediaMessage(audioUrl: downloadUrl, duration: durationSeconds > 0 ? durationSeconds : 1, type: 'audio');
      } else {
        throw Exception(jsonMap['error']?['message'] ?? 'فشل الرفع');
      }
    } catch (e) {
      debugPrint("❌ خطأ رفع الصوت: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تعذر إرسال التسجيل الصوتي", style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final replyData = _replyMessage;
    setState(() => _replyMessage = null);

    _messageController.clear();
    _scrollToBottom();

    Map<String, dynamic> msgData = {
      'senderId': widget.currentUserId,
      'text': text,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    };

    if (replyData != null) {
      msgData['replyTo'] = replyData;
    }

    await FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(msgData);

    _updateChatLastMessage("💬 $text");
  }

  void _sendMediaMessage({String? audioUrl, String? imageUrl, int? duration, required String type}) async {
    final replyData = _replyMessage;
    setState(() => _replyMessage = null);
    _scrollToBottom();

    Map<String, dynamic> messageData = {
      'senderId': widget.currentUserId,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    };

    if (replyData != null) {
      messageData['replyTo'] = replyData;
    }

    if (type == 'audio') {
      messageData['audioUrl'] = audioUrl;
      messageData['duration'] = duration;
    } else if (type == 'image') {
      messageData['imageUrl'] = imageUrl;
    }

    await FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    String lastMsg = type == 'audio' 
        ? "🎙️ تسجيل صوتي (${_formatRecordTimer(duration ?? 0)})" 
        : "📷 صورة متبادلة";
        
    _updateChatLastMessage(lastMsg);
  }

  void _deleteMessage(String messageId) async {
    await FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم حذف الرسالة", style: TextStyle(fontFamily: 'Cairo')),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
        title: "💬 رسالة من ${widget.peerRole == 'manager' ? 'المدير' : 'المشرف'}",
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
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(bottom: 25, left: 16, right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1e293b).withOpacity(0.92) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: isDark ? Colors.white24 : Colors.white, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.photo_library_rounded,
                      color: const Color(0xffa855f7),
                      label: "المعرض",
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendImage(ImageSource.gallery);
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.camera_alt_rounded,
                      color: const Color(0xff3b82f6),
                      label: "الكاميرا",
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendImage(ImageSource.camera);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _showMessageOptionsMenu(BuildContext context, String messageId, Map<String, dynamic> msg, bool isMe, bool isDark) {
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1e293b).withOpacity(0.92) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: isDark ? Colors.white24 : Colors.white, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                              'reactions': {widget.currentUserId: emoji}
                            }, SetOptions(merge: true));
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 26)),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 24, thickness: 0.8),
                    ListTile(
                      leading: const Icon(Icons.reply_rounded, color: Colors.blueAccent),
                      title: const Text("رد على الرسالة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        String previewText = msg['type'] == 'image'
                            ? '📷 صورة'
                            : (msg['type'] == 'audio' ? '🎙️ تسجيل صوتي' : (msg['text'] ?? ''));
                        setState(() {
                          _replyMessage = {
                            'id': messageId,
                            'senderName': isMe ? 'أنت' : widget.peerName,
                            'text': previewText,
                          };
                        });
                      },
                    ),
                    if (isMe)
                      ListTile(
                        leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        title: const Text("حذف الرسالة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteMessage(messageId);
                        },
                      ),
                  ],
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff090d16) : const Color(0xfff8fafc),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: Container(
          margin: const EdgeInsets.only(top: 10, left: 12, right: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: AppBar(
                elevation: 0,
                backgroundColor: isDark 
                    ? const Color(0xff1e293b).withOpacity(0.75) 
                    : Colors.white.withOpacity(0.85),
                centerTitle: true,
                iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: accentGold.withOpacity(0.2),
                          child: Icon(
                            widget.peerRole == 'manager' ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                            size: 22,
                            color: accentGold,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: isDark ? const Color(0xff1e293b) : Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.peerName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 15, 
                            color: isDark ? Colors.white : primaryColor, 
                            fontFamily: 'Cairo'
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.shield_rounded, size: 11, color: accentGold),
                            const SizedBox(width: 3),
                            Text(
                              widget.peerRole == 'manager' ? 'إدارة المعهد 🌟' : 'كادر الإشراف 🛡️',
                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.grey.shade600, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 🌌 1. الخلفية المضيئة المبتكرة (Creative Mesh Blur)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xff090d16), const Color(0xff0f172a), const Color(0xff1e293b)]
                    : [const Color(0xfff8fafc), const Color(0xffe2e8f0), const Color(0xffcbd5e1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandBlue.withOpacity(isDark ? 0.12 : 0.15),
                boxShadow: [BoxShadow(color: brandBlue.withOpacity(0.2), blurRadius: 120, spreadRadius: 40)],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentGold.withOpacity(isDark ? 0.08 : 0.12),
                boxShadow: [BoxShadow(color: accentGold.withOpacity(0.15), blurRadius: 100, spreadRadius: 30)],
              ),
            ),
          ),

          // 💬 2. محتوى الرسائل
          Column(
            children: [
              const SizedBox(height: kToolbarHeight + 50),

              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _chatSnapshotStream,
                  builder: (context, chatSnapshot) {
                    bool isReadByPeer = false;
                    if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                      final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
                      isReadByPeer = (chatData['unread_${widget.peerId}'] ?? 0) == 0;
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: _messagesStream,
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
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? Colors.white.withOpacity(0.04) : primaryColor.withOpacity(0.05),
                                    border: Border.all(color: accentGold.withOpacity(0.3), width: 1.5),
                                  ),
                                  child: Icon(Icons.lock_outline_rounded, size: 50, color: accentGold),
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  "تواصل آمن ومباشر مع الطاقم 🔒",
                                  style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white70 : Colors.black54, fontSize: 13.5, fontWeight: FontWeight.w600),
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
                            
                            final String msgType = msg['type'] ?? 'text';
                            final Map<String, dynamic>? replyTo = msg['replyTo'];

                            return _AnimatedMessageBubble(
                              key: ValueKey(msgDoc.id),
                              index: index,
                              isMe: isMe,
                              child: Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  constraints: BoxConstraints(
                                    maxWidth: screenWidth > 600 ? 420 : screenWidth * 0.76,
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      GestureDetector(
                                        onLongPress: () => _showMessageOptionsMenu(context, msgDoc.id, msg, isMe, isDark),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isMe
                                                  ? [const Color(0xff2563eb), const Color(0xff1d4ed8)]
                                                  : (isDark 
                                                      ? [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.06)] 
                                                      : [Colors.white.withOpacity(0.9), const Color(0xfff1f5f9)]),
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(22),
                                              topRight: const Radius.circular(22),
                                              bottomLeft: Radius.circular(isMe ? 22 : 6),
                                              bottomRight: Radius.circular(isMe ? 6 : 22),
                                            ),
                                            border: Border.all(
                                              color: isMe
                                                  ? Colors.white.withOpacity(0.25)
                                                  : (isDark ? Colors.white.withOpacity(0.15) : Colors.white),
                                              width: 1.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isMe 
                                                    ? brandBlue.withOpacity(0.25) 
                                                    : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                                blurRadius: 12,
                                                offset: const Offset(0, 5),
                                              )
                                            ],
                                          ),
                                          padding: msgType == 'image' && replyTo == null 
                                              ? const EdgeInsets.all(5) 
                                              : const EdgeInsets.fromLTRB(14, 10, 14, 8),
                                          child: Column(
                                            crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                            children: [
                                              // ↩️ الرد المقتبص البارز
                                              if (replyTo != null) ...[
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  decoration: BoxDecoration(
                                                    color: isMe ? Colors.black.withOpacity(0.25) : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border(
                                                      right: BorderSide(
                                                        color: isMe ? accentGold : brandBlue,
                                                        width: 3.5,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        replyTo['senderName'] ?? '',
                                                        style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                          color: isMe ? accentGold : brandBlue,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        replyTo['text'] ?? '',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          fontSize: 11.5,
                                                          color: isMe ? Colors.white70 : Colors.black87,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],

                                              if (msgType == 'audio')
                                                _AudioMessagePlayer(
                                                  audioUrl: msg['audioUrl'] ?? '',
                                                  duration: msg['duration'] ?? 0,
                                                  isMe: isMe,
                                                  isDark: isDark,
                                                  accentGold: accentGold,
                                                )
                                              else if (msgType == 'image')
                                                GestureDetector(
                                                  onTap: () => _showImagePreview(context, msg['imageUrl'] ?? ''),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(16),
                                                    child: CachedNetworkImage(
                                                      imageUrl: msg['imageUrl'] ?? '',
                                                      width: 240,
                                                      height: 240,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => Container(
                                                        width: 240,
                                                        height: 240,
                                                        color: Colors.black12,
                                                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                      ),
                                                      errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.redAccent),
                                                    ),
                                                  ),
                                                )
                                              else
                                                Text(
                                                  msg['text'] ?? '',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xff1e293b)),
                                                    fontSize: 14,
                                                    height: 1.45,
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
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: isMe ? Colors.white70 : (isDark ? Colors.white54 : Colors.black45),
                                                    ),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.done_all_rounded,
                                                      size: 14,
                                                      color: isReadByPeer ? accentGold : Colors.white54,
                                                    ),
                                                  ]
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      if (displayEmojis.isNotEmpty)
                                        Positioned(
                                          bottom: -10,
                                          right: isMe ? 12 : null,
                                          left: isMe ? null : 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xff1e293b) : Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1),
                                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                                            ),
                                            child: Text(
                                              displayEmojis.join(' '),
                                              style: const TextStyle(fontSize: 12),
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

              // 🎙️/📷 3. شريط الإدخال المبتكر العائم (Floating Glass Dock)
              Container(
                margin: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  top: 6,
                  bottom: isKeyboardOpen ? 12 : 20,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff1e293b).withOpacity(0.85) : Colors.white.withOpacity(0.9),
                        border: Border.all(color: isDark ? Colors.white24 : Colors.white, width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_replyMessage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.reply_rounded, size: 18, color: brandBlue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "الرد على ${_replyMessage!['senderName']}",
                                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: brandBlue),
                                        ),
                                        Text(
                                          _replyMessage!['text'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () => setState(() => _replyMessage = null),
                                  ),
                                ],
                              ),
                            ),

                          if (_isUploading)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                  const SizedBox(width: 10),
                                  Text(_uploadStatusText, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          else
                            _RecordingBar(
                              audioRecorder: _audioRecorder,
                              messageController: _messageController,
                              isDark: isDark,
                              brandBlue: brandBlue,
                              accentGold: accentGold,
                              onSendTextMessage: _sendMessage,
                              onSendAudioMessage: _uploadAndSendAudio,
                              onOpenAttachmentMenu: () => _showAttachmentMenu(context, isDark),
                            ),
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

// 🎙️ الويجيت المستقل المعزول للتسجيل الصوتي
class _RecordingBar extends StatefulWidget {
  final AudioRecorder audioRecorder;
  final TextEditingController messageController;
  final bool isDark;
  final Color brandBlue;
  final Color accentGold;
  final VoidCallback onSendTextMessage;
  final Function(String? path, int durationSeconds) onSendAudioMessage;
  final VoidCallback onOpenAttachmentMenu;

  const _RecordingBar({
    required this.audioRecorder,
    required this.messageController,
    required this.isDark,
    required this.brandBlue,
    required this.accentGold,
    required this.onSendTextMessage,
    required this.onSendAudioMessage,
    required this.onOpenAttachmentMenu,
  });

  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordDurationSeconds = 0;
  late AnimationController _micPulseController;

  @override
  void initState() {
    super.initState();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _micPulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await widget.audioRecorder.hasPermission()) {
        final config = kIsWeb
            ? const RecordConfig(encoder: AudioEncoder.opus)
            : const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000);

        await widget.audioRecorder.start(config, path: '');

        _recordDurationSeconds = 0;
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordDurationSeconds++;
            });
          }
        });

        _micPulseController.repeat(reverse: true);
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint("❌ خطأ عند بدء التسجيل: $e");
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTimer?.cancel();
    _micPulseController.stop();
    final int finalDuration = _recordDurationSeconds;

    try {
      final String? path = await widget.audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordDurationSeconds = 0;
      });

      widget.onSendAudioMessage(path, finalDuration);
    } catch (e) {
      debugPrint("❌ خطأ عند إيقاف التسجيل: $e");
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _micPulseController.stop();
    await widget.audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordDurationSeconds = 0;
    });
  }

  String _formatRecordTimer(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
            onPressed: _cancelRecording,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.25).animate(_micPulseController),
                  child: const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatRecordTimer(_recordDurationSeconds),
                  style: const TextStyle(fontFamily: 'Cairo', color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(width: 8),
                const Text(
                  "تسجيل صوتي...",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _stopAndSendRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          )
        ],
      );
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.messageController,
      builder: (context, value, child) {
        bool hasText = value.text.trim().isNotEmpty;

        return Row(
          children: [
            IconButton(
              icon: Icon(Icons.add_circle_outline_rounded, color: widget.isDark ? Colors.white70 : Colors.grey.shade700, size: 26),
              onPressed: widget.onOpenAttachmentMenu,
            ),
            Expanded(
              child: TextField(
                controller: widget.messageController,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: "اكتب رسالة...",
                  hintStyle: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade400, fontFamily: 'Cairo', fontSize: 13),
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                ),
              ),
            ),
            GestureDetector(
              onTap: hasText ? widget.onSendTextMessage : _startRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasText 
                        ? [widget.brandBlue, const Color(0xff1d4ed8)] 
                        : [widget.accentGold, const Color(0xffb89228)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (hasText ? widget.brandBlue : widget.accentGold).withOpacity(0.35),
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
    );
  }
}

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
    Color iconColor = widget.isMe ? Colors.white : (widget.isDark ? Colors.white : const Color(0xff1e293b));
    double progress = _totalDuration.inSeconds > 0 
        ? (_position.inSeconds / _totalDuration.inSeconds).clamp(0.0, 1.0) 
        : 0.0;

    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isMe ? Colors.white.withOpacity(0.2) : widget.accentGold.withOpacity(0.2),
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 24,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(20, (index) {
                    double height = 5 + ((index * 9) % 18).toDouble();
                    bool isActive = (index / 20) <= progress;

                    return Expanded(
                      child: Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 1.0),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? (widget.isMe ? widget.accentGold : const Color(0xff2563eb))
                              : iconColor.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDuration(_isPlaying ? _position : _totalDuration),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: widget.isMe ? Colors.white70 : (widget.isDark ? Colors.white54 : Colors.black54),
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
    super.key,
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    double startDx = widget.isMe ? 0.15 : -0.15;

    _slideAnimation = Tween<Offset>(begin: Offset(startDx, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
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
        alignment: widget.isMe ? Alignment.bottomRight : Alignment.bottomLeft,
        child: widget.child,
      ),
    );
  }
}