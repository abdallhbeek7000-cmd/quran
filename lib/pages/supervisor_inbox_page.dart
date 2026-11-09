import 'dart:async';
import 'dart:async' as async;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'supervisor_chat_page.dart'; 
import 'staff_chat_page.dart'; 
import '../widgets/offline_wrapper.dart';

class SupervisorInboxPage extends StatefulWidget {
  final String supervisorId;

  const SupervisorInboxPage({super.key, required this.supervisorId});

  @override
  State<SupervisorInboxPage> createState() => _SupervisorInboxPageState();
}

class _SupervisorInboxPageState extends State<SupervisorInboxPage> {
  final Color primaryColor = const Color(0xff0f172a);
  final Color goldColor = const Color(0xfffbbf24);
  final Color brandBlue = const Color(0xff2563eb);
  
  final Map<String, Map<String, dynamic>> _peerCache = {};
  
  String? _effectiveSupervisorId;
  bool _isLoadingEffectiveId = true;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _resolveEffectiveSupervisorId();
  }

  async.Future<void> _resolveEffectiveSupervisorId() async {
    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.supervisorId).get();
      if (userDoc.exists && userDoc.data()?['linkedSupervisorId'] != null) {
        String linkedId = userDoc.data()!['linkedSupervisorId'];
        if (linkedId.isNotEmpty) {
          if (mounted) {
            setState(() {
              _effectiveSupervisorId = linkedId;
              _isLoadingEffectiveId = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("خطأ أثناء جلب حساب المشرف المربوط: $e");
    }

    if (mounted) {
      setState(() {
        _effectiveSupervisorId = widget.supervisorId;
        _isLoadingEffectiveId = false;
      });
    }
  }

  String _generateStaffChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort(); 
    return "staff_${ids[0]}_${ids[1]}";
  }

  // 🛠️ دالة جلب بيانات الطرف الآخر مع دعم التخزين المؤقت وفحص المجموعات
  Future<Map<String, dynamic>> _getPeerDataCached(String peerId) async {
    if (peerId.isEmpty) return {'name': 'حساب إداري', 'role': 'manager', 'imageUrl': null};
    if (_peerCache.containsKey(peerId)) return _peerCache[peerId]!;

    try {
      // 1. البحث في مجموعة المستخدمين / الإدارة
      var manDoc = await FirebaseFirestore.instance.collection('users').doc(peerId).get();
      if (manDoc.exists && manDoc.data() != null) {
        _peerCache[peerId] = {
          'name': manDoc.data()?['name'] ?? 'عضو إدارة', 
          'role': 'manager', 
          'imageUrl': manDoc.data()?['imageUrl']
        };
        return _peerCache[peerId]!;
      }

      // 2. البحث في مجموعة المشرفين
      var supDoc = await FirebaseFirestore.instance.collection('supervisors').doc(peerId).get();
      if (supDoc.exists && supDoc.data() != null) {
        _peerCache[peerId] = {
          'name': supDoc.data()?['name'] ?? 'زميل إشراف', 
          'role': 'supervisor', 
          'imageUrl': supDoc.data()?['imageUrl']
        };
        return _peerCache[peerId]!;
      }
    } catch (e) {
      debugPrint("خطأ جلب بيانات المستخدم: $e");
    }

    return {'name': 'حساب إداري', 'role': 'manager', 'imageUrl': null};
  }

  Future<void> _deleteChat(String docId, bool isStaff) async {
    try {
      String collectionName = isStaff ? 'staff_chats' : 'chats';
      await FirebaseFirestore.instance.collection(collectionName).doc(docId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green, 
            content: Text("تم حذف المحادثة بنجاح 🗑️", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))
          ),
        );
      }
    } catch (e) {
      debugPrint("خطأ في حذف المحادثة: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.redAccent, content: Text("فشل الحذف، تأكد من الاتصال بالإنترنت", style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(String docId, bool isStaff, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text("حذف المحادثة", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text("هل أنت متأكد أنك تريد إزالة هذه المحادثة من صندوق الوارد الخاص بك؟", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white70 : Colors.black87, fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(docId, isStaff);
            },
            child: const Text("حذف", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNewChatBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: Container(
            margin: const EdgeInsets.only(top: 60),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.78, 
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xff1e293b).withOpacity(0.92) : Colors.white.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    border: Border.all(color: isDark ? Colors.white24 : Colors.white, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 12),
                      
                      TabBar(
                        indicatorColor: goldColor,
                        indicatorWeight: 3,
                        labelColor: goldColor,
                        unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                        labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                        tabs: const [
                          Tab(text: "الطلاب (الأهالي)"),
                          Tab(text: "طاقم العمل"),
                        ],
                      ),
                      
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildStudentsTab(isDark), 
                            _buildStaffTab(isDark),    
                          ],
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
  }

  Widget _buildStudentsTab(bool isDark) {
    String currentSupId = _effectiveSupervisorId ?? widget.supervisorId;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').where('supervisorId', isEqualTo: currentSupId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: goldColor));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("لا يوجد طلاب مسجلين باسمك حالياً", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54)));

        final students = snapshot.data!.docs;
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final studentDoc = students[index];
            final studentData = studentDoc.data() as Map<String, dynamic>;
            final studentName = studentData['name'] ?? 'غير معروف';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), 
                borderRadius: BorderRadius.circular(18), 
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12)
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: goldColor.withOpacity(0.2), 
                  child: Icon(Icons.person_rounded, color: goldColor, size: 22),
                ),
                title: Text(studentName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                subtitle: Text("ولي الأمر", style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black54)),
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: brandBlue.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(Icons.chat_bubble_outline_rounded, color: brandBlue, size: 18),
                ),
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => SupervisorChatPage(
                        chatId: studentDoc.id,
                        studentId: studentDoc.id, 
                        studentName: studentName, 
                        supervisorId: currentSupId,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStaffTab(bool isDark) {
    String currentSupId = _effectiveSupervisorId ?? widget.supervisorId;

    return FutureBuilder<List<QuerySnapshot>>(
      future: Future.wait([FirebaseFirestore.instance.collection('users').get(), FirebaseFirestore.instance.collection('supervisors').get()]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData) return const Center(child: Text("خطأ في جلب البيانات"));

        List<Map<String, dynamic>> allStaff = [];
        for (var doc in snapshot.data![0].docs) { 
          if (doc.id != widget.supervisorId && doc.id != currentSupId) { var data = doc.data() as Map<String, dynamic>; data['id'] = doc.id; data['staffRole'] = 'manager'; allStaff.add(data); }
        }
        for (var doc in snapshot.data![1].docs) { 
          if (doc.id != widget.supervisorId && doc.id != currentSupId) { var data = doc.data() as Map<String, dynamic>; data['id'] = doc.id; data['staffRole'] = 'supervisor'; allStaff.add(data); }
        }

        if (allStaff.isEmpty) return Center(child: Text("لا يوجد أعضاء آخرين في الطاقم.", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54)));

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          itemCount: allStaff.length,
          itemBuilder: (context, index) {
            final staff = allStaff[index];
            final String staffId = staff['id'];
            final String staffName = staff['name'] ?? 'عضو إدارة';
            final String staffRole = staff['staffRole'];
            final String? imageUrl = staff['imageUrl'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6), 
                borderRadius: BorderRadius.circular(18), 
                border: Border.all(color: staffRole == 'manager' ? goldColor.withOpacity(0.4) : (isDark ? Colors.white12 : Colors.white), width: 1.2)
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: staffRole == 'manager' ? goldColor.withOpacity(0.2) : brandBlue.withOpacity(0.12), 
                  backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null, 
                  child: (imageUrl == null || imageUrl.isEmpty) ? Icon(staffRole == 'manager' ? Icons.admin_panel_settings_rounded : Icons.person_rounded, color: staffRole == 'manager' ? goldColor : brandBlue, size: 20) : null
                ),
                title: Text(staffName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontFamily: 'Cairo')),
                subtitle: Text(staffRole == 'manager' ? 'إدارة المعهد 🌟' : 'كادر الإشراف 🛡️', style: TextStyle(fontSize: 11.5, color: staffRole == 'manager' ? goldColor : (isDark ? Colors.white54 : Colors.black54), fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: brandBlue.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(Icons.chat_rounded, color: brandBlue, size: 18),
                ),
                onTap: () {
                  String chatRoomId = _generateStaffChatId(currentSupId, staffId);
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => StaffChatPage(chatId: chatRoomId, currentUserId: currentSupId, peerId: staffId, peerName: staffName, peerRole: staffRole)));
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    if (_isLoadingEffectiveId) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xff090d16) : const Color(0xfff8fafc),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String currentSupId = _effectiveSupervisorId ?? widget.supervisorId;

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDark ? const Color(0xff090d16) : const Color(0xfff8fafc),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
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
                      : Colors.white.withOpacity(0.8),
                  centerTitle: true,
                  iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
                  title: Text("صندوق الوارد 📥", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                ),
              ),
            ),
          ),
        ),
        
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: goldColor.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => _showNewChatBottomSheet(context, isDark),
            backgroundColor: goldColor,
            elevation: 0,
            icon: const Icon(Icons.add_comment_rounded, color: Colors.black87),
            label: const Text("مراسلة جديدة", style: TextStyle(color: Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),

        body: Stack(
          children: [
            // 🌌 خلفية زجاجية متدرجة مع أشكال مضيئة
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
              top: 100,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandBlue.withOpacity(isDark ? 0.1 : 0.12),
                  boxShadow: [BoxShadow(color: brandBlue.withOpacity(0.15), blurRadius: 100, spreadRadius: 30)],
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -50,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: goldColor.withOpacity(isDark ? 0.08 : 0.12),
                  boxShadow: [BoxShadow(color: goldColor.withOpacity(0.15), blurRadius: 100, spreadRadius: 30)],
                ),
              ),
            ),

            SafeArea(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('chats').where('supervisorId', whereIn: [widget.supervisorId, currentSupId]).snapshots(),
                builder: (context, parentSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('staff_chats').where('participants', arrayContainsAny: [widget.supervisorId, currentSupId]).snapshots(),
                    builder: (context, staffSnap) {
                      if (parentSnap.connectionState == ConnectionState.waiting && staffSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      List<Map<String, dynamic>> allChats = [];

                      if (parentSnap.hasData) {
                        for (var doc in parentSnap.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;
                          if (data.containsKey('studentId') && data['studentId'].toString().isNotEmpty) {
                            data['docId'] = doc.id;
                            data['isStaff'] = false;
                            data['sortTime'] = data['lastMessageTime'] ?? Timestamp.now();
                            allChats.add(data);
                          }
                        }
                      }

                      if (staffSnap.hasData) {
                        for (var doc in staffSnap.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;
                          data['docId'] = doc.id;
                          data['isStaff'] = true;
                          data['sortTime'] = data['lastMessageTime'] ?? Timestamp.now();
                          allChats.add(data);
                        }
                      }

                      allChats.sort((a, b) => (b['sortTime'] as Timestamp).compareTo(a['sortTime'] as Timestamp));

                      if (allChats.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? Colors.white.withOpacity(0.04) : primaryColor.withOpacity(0.05),
                                  border: Border.all(color: goldColor.withOpacity(0.3), width: 1.5),
                                ),
                                child: Icon(Icons.mark_chat_read_rounded, size: 60, color: goldColor),
                              ),
                              const SizedBox(height: 16),
                              Text("صندوق الوارد فارغ حالياً", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                              const SizedBox(height: 6),
                              Text("اضغط على مراسلة جديدة للبدء بالتواصل", style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white54 : Colors.black45, fontFamily: 'Cairo')),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), 
                        itemCount: allChats.length,
                        itemBuilder: (context, index) {
                          final chatData = allChats[index];
                          final bool isStaff = chatData['isStaff'];
                          final String docId = chatData['docId'];
                          final lastMessage = chatData['lastMessage'] ?? '';
                          final lastTime = (chatData['sortTime'] as Timestamp).toDate();

                          if (!isStaff) {
                            final studentName = chatData['studentName'] ?? 'طالب غير معروف';
                            final unreadCount = chatData['unreadBySupervisor'] ?? 0;
                            final studentId = chatData['studentId'] ?? docId;
                            
                            return _buildChatTile(
                              context: context, isDark: isDark, isStaff: false,
                              title: "ولي أمر الطالب: $studentName",
                              subtitle: lastMessage,
                              time: lastTime,
                              unreadCount: unreadCount,
                              icon: Icons.person_rounded, iconColor: brandBlue,
                              onTap: () => Navigator.push(
                                context, 
                                MaterialPageRoute(
                                  builder: (_) => SupervisorChatPage(
                                    chatId: studentId, 
                                    studentId: studentId, 
                                    studentName: studentName, 
                                    supervisorId: currentSupId,
                                  ),
                                ),
                              ),
                              onLongPress: () => _showDeleteConfirmDialog(docId, false, isDark),
                            );
                          } 
                          else {
                            final unreadCount = chatData['unread_${widget.supervisorId}'] ?? chatData['unread_$currentSupId'] ?? 0;
                            
                            // 🔑 المنطق المحسّن لاستخراج peerId ومنع ظهور "غير معروف"
                            List parts = chatData['participants'] ?? [];
                            String peerId = '';

                            for (var id in parts) {
                              if (id.toString() != widget.supervisorId && id.toString() != currentSupId) {
                                peerId = id.toString();
                                break;
                              }
                            }

                            // فحص احتياطي عبر docId إذا كان مبنياً بالشكل staff_UID1_UID2
                            if (peerId.isEmpty && docId.startsWith('staff_')) {
                              List<String> rawIds = docId.replaceFirst('staff_', '').split('_');
                              for (var id in rawIds) {
                                if (id != widget.supervisorId && id != currentSupId) {
                                  peerId = id;
                                  break;
                                }
                              }
                            }

                            return FutureBuilder<Map<String, dynamic>>(
                              future: _getPeerDataCached(peerId),
                              builder: (context, peerSnap) {
                                String peerName = peerSnap.data?['name'] ?? '...';
                                String peerRole = peerSnap.data?['role'] ?? '';
                                bool isManager = peerRole == 'manager';

                                return _buildChatTile(
                                  context: context, isDark: isDark, isStaff: true,
                                  title: peerName,
                                  subtitle: lastMessage,
                                  time: lastTime,
                                  unreadCount: unreadCount,
                                  icon: isManager ? Icons.admin_panel_settings_rounded : Icons.shield_rounded, 
                                  iconColor: isManager ? goldColor : brandBlue,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffChatPage(chatId: docId, currentUserId: currentSupId, peerId: peerId, peerName: peerName, peerRole: peerRole))),
                                  onLongPress: () => _showDeleteConfirmDialog(docId, true, isDark),
                                );
                              },
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTile({
    required BuildContext context, required bool isDark, required bool isStaff,
    required String title, required String subtitle, required DateTime time, required int unreadCount,
    required IconData icon, required Color iconColor, required VoidCallback onTap, required VoidCallback onLongPress
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isStaff ? goldColor.withOpacity(0.35) : (isDark ? Colors.white.withOpacity(0.12) : Colors.white), 
                  width: 1.2
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: iconColor.withOpacity(0.18),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isStaff) 
                              Container(
                                margin: const EdgeInsets.only(left: 6), 
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), 
                                decoration: BoxDecoration(color: goldColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), 
                                child: Text("طاقم العمل", style: TextStyle(fontSize: 9.5, color: goldColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))
                              ),
                            Expanded(
                              child: Text(
                                title, 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 14, 
                                  color: isDark ? Colors.white : primaryColor, 
                                  fontFamily: 'Cairo'
                                ), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle.isEmpty ? 'انقر لبدء المحادثة...' : subtitle, 
                          style: TextStyle(
                            fontSize: 12, 
                            color: unreadCount > 0 
                                ? (isDark ? Colors.white : Colors.black87) 
                                : (isDark ? Colors.white54 : Colors.grey.shade600), 
                            fontFamily: 'Cairo',
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ), 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeago.format(time, locale: 'ar'), 
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500, fontFamily: 'Cairo', fontWeight: FontWeight.w500)
                      ),
                      const SizedBox(height: 8),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), 
                          decoration: BoxDecoration(
                            color: Colors.redAccent, 
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))
                            ]
                          ), 
                          child: Text(
                            unreadCount.toString(), 
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'Cairo')
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
  }
}