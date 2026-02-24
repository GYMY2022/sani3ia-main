import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:snae3ya/screens/single_chat_screen.dart';
import 'package:snae3ya/providers/chat_provider.dart';
import 'package:snae3ya/models/chat_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  final String? clientName;
  final String? clientImage;
  final int initialTabIndex;

  const ChatScreen({
    super.key,
    this.clientName,
    this.clientImage,
    this.initialTabIndex = 0,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchField = false;
  bool _isInitialized = false;
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.loadAllChatRooms(); // ⭐⭐ استخدام الدالة الجديدة
      setState(() {
        _isInitialized = true;
      });
    });

    // ⭐ إضافة listener للتبويب
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      // تحديث البيانات عند تغيير التبويب
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (_tabController.index == 0) {
        chatProvider.loadJobChatRooms();
      } else {
        chatProvider.loadMarketChatRooms();
      }
    }
  }

  void _toggleSearchField() {
    setState(() {
      _showSearchField = !_showSearchField;
      if (!_showSearchField) {
        _searchController.clear();
      }
    });
  }

  List<ChatRoom> _filterChatRooms(List<ChatRoom> chatRooms, String type) {
    return chatRooms.where((room) => room.chatType == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    // إذا كان فيه clientName و clientImage (للمحادثة المباشرة)
    if (widget.clientName != null && widget.clientImage != null) {
      return SingleChatScreen(
        userName: widget.clientName!,
        userImage: widget.clientImage!,
        receiverId: 'temp_user_id',
        isOnline: true,
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: _showSearchField ? null : const Text('الدردشات'),
        centerTitle: true,
        backgroundColor: const Color(0xFF782DCE),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.work_outline), text: 'شغلانات'),
            Tab(icon: Icon(Icons.shopping_bag), text: 'السوق'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _toggleSearchField,
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final jobChats =
              chatProvider.jobChatRooms; // ⭐⭐ استخدام القوائم الجديدة
          final marketChats = chatProvider.marketChatRooms;

          if (!_isInitialized || chatProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // تبويب الشغلانات
              _buildChatList(jobChats, chatProvider, 'job'),

              // تبويب السوق
              _buildChatList(marketChats, chatProvider, 'product'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChatList(
    List<ChatRoom> chatRooms,
    ChatProvider chatProvider,
    String type,
  ) {
    // تطبيق البحث إذا كان موجود
    List<ChatRoom> filteredRooms = chatRooms;
    if (_searchController.text.isNotEmpty) {
      filteredRooms = chatRooms.where((room) {
        final otherUser = _getOtherUser(room);
        return otherUser.name.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ) ||
            (room.lastMessage.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ));
      }).toList();
    }

    if (filteredRooms.isEmpty) {
      String emptyMessage = type == 'job'
          ? 'لا توجد محادثات شغلانات بعد'
          : 'لا توجد محادثات سوق بعد';
      String emptySubMessage = type == 'job'
          ? 'سيظهر هنا المحادثات المتعلقة بالشغلانات'
          : 'سيظهر هنا المحادثات المتعلقة بالمنتجات';

      if (_searchController.text.isNotEmpty) {
        emptyMessage = 'لا توجد نتائج للبحث';
        emptySubMessage = 'حاول بكلمات بحث أخرى';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'job' ? Icons.work_outline : Icons.shopping_bag_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: filteredRooms.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final chatRoom = filteredRooms[index];
        final currentUser = FirebaseAuth.instance.currentUser;

        final otherUser = _getOtherUser(chatRoom);

        return FutureBuilder<Map<String, dynamic>>(
          future: _getChatDisplayInfo(chatRoom, otherUser),
          builder: (context, snapshot) {
            String displayName = otherUser.name;
            String postTitle = '';
            String displayImage = chatRoom.postImage ?? otherUser.image;

            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              displayName = snapshot.data!['userName'] ?? otherUser.name;
              postTitle = snapshot.data!['postTitle'] ?? '';
            }

            return _buildChatListItem(
              chatRoom,
              _UserInfo(
                name: displayName,
                image: displayImage,
                id: otherUser.id,
              ),
              chatProvider,
              postTitle: postTitle,
            );
          },
        );
      },
    );
  }

  // ⭐⭐ دالة مساعدة للحصول على المستخدم الآخر
  _UserInfo _getOtherUser(ChatRoom chatRoom) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser?.uid == chatRoom.user1Id
        ? _UserInfo(
            name: chatRoom.user2Name,
            image: chatRoom.user2Image,
            id: chatRoom.user2Id,
          )
        : _UserInfo(
            name: chatRoom.user1Name,
            image: chatRoom.user1Image,
            id: chatRoom.user1Id,
          );
  }

  Future<Map<String, dynamic>> _getChatDisplayInfo(
    ChatRoom chatRoom,
    _UserInfo otherUser,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return {};

      String userName = otherUser.name;
      String postTitle = chatRoom.postTitle ?? '';

      if (chatRoom.postId != null && chatRoom.postId!.isNotEmpty) {
        if (chatRoom.chatType == 'product') {
          // جلب بيانات المنتج
          final productDoc = await _firestore
              .collection('products')
              .doc(chatRoom.postId)
              .get();

          if (productDoc.exists) {
            final productData = productDoc.data()!;
            postTitle = productData['title']?.toString() ?? 'منتج';
            final sellerId = productData['sellerId']?.toString() ?? '';

            // اسم المستخدم المناسب
            if (sellerId == currentUser.uid) {
              // أنا البائع => اسم المشتري
              userName = await _getUserName(otherUser.id);
            } else {
              // أنا المشتري => اسم البائع
              userName = await _getUserName(sellerId);
            }
          }
        } else {
          // جلب بيانات الشغلانة
          final postDoc = await _firestore
              .collection('posts')
              .doc(chatRoom.postId)
              .get();

          if (postDoc.exists) {
            final postData = postDoc.data()!;
            postTitle = postData['title']?.toString() ?? 'شغلانة';
            final postOwnerId = postData['authorId']?.toString() ?? '';

            // اسم المستخدم المناسب
            if (postOwnerId == currentUser.uid) {
              // أنا صاحب الشغلانة => اسم المتقدم
              userName = await _getUserName(otherUser.id);
            } else {
              // أنا المتقدم => اسم صاحب الشغلانة
              userName = await _getUserName(postOwnerId);
            }
          }
        }
      } else {
        // محادثة عادية بدون postId
        userName = await _getUserName(otherUser.id);
      }

      return {'userName': userName, 'postTitle': postTitle};
    } catch (e) {
      print('❌ خطأ في جلب معلومات العرض: $e');
      return {};
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      if (userId.isEmpty) return 'مستخدم';

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final name = userData['name']?.toString() ?? '';

        if (name.isNotEmpty && name != 'مستخدم') {
          return _extractFirstName(name);
        }

        final email = userData['email']?.toString() ?? '';
        if (email.isNotEmpty && email.contains('@')) {
          return email.split('@')[0];
        }
      }

      return 'مستخدم';
    } catch (e) {
      print('❌ خطأ في جلب اسم المستخدم: $e');
      return 'مستخدم';
    }
  }

  Widget _buildChatListItem(
    ChatRoom chatRoom,
    _UserInfo otherUser,
    ChatProvider chatProvider, {
    String postTitle = '',
  }) {
    final timeFormat = DateFormat.jm();
    final isToday = chatRoom.lastMessageTime.day == DateTime.now().day;
    final timeText = isToday
        ? timeFormat.format(chatRoom.lastMessageTime)
        : DateFormat.MMMd().format(chatRoom.lastMessageTime);

    final isOnline = chatProvider.isUserOnline(otherUser.id);
    final unreadCount = chatRoom.getUnreadCountForUser(
      FirebaseAuth.instance.currentUser?.uid ?? '',
    );

    return InkWell(
      onTap: () {
        // تعيين المحادثة كمقروءة
        chatProvider.markChatAsRead(
          otherUser.id,
          chatRoom.postId,
          chatRoom.chatType,
        );

        // فتح شاشة المحادثة
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SingleChatScreen(
              userName: otherUser.name,
              userImage: otherUser.image,
              receiverId: otherUser.id,
              isOnline: isOnline,
              postId: chatRoom.postId,
              chatType: chatRoom.chatType,
            ),
          ),
        );
      },
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: _getChatImage(otherUser.image),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherUser.name,
                          style: TextStyle(
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 16,
                            color: unreadCount > 0
                                ? Colors.black
                                : Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeText,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? const Color(0xFF782DCE)
                              : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chatRoom.lastMessage,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? Colors.black
                                : Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF782DCE),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (postTitle.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: chatRoom.chatType == 'product'
                            ? Colors.green[50]
                            : Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            chatRoom.chatType == 'product'
                                ? Icons.shopping_bag
                                : Icons.work_outline,
                            size: 10,
                            color: chatRoom.chatType == 'product'
                                ? Colors.green[700]
                                : Colors.blue[700],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              postTitle,
                              style: TextStyle(
                                fontSize: 10,
                                color: chatRoom.chatType == 'product'
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractFirstName(String fullName) {
    if (fullName.isEmpty) return 'مستخدم';

    List<String> nameParts = fullName.split(' ');
    List<String> titles = [
      'السيد',
      'الأستاذ',
      'دكتور',
      'د',
      'أ',
      'الدكتور',
      'المهندس',
      'م',
      'انسة',
    ];

    for (String title in titles) {
      if (nameParts.isNotEmpty && nameParts[0].contains(title)) {
        nameParts.removeAt(0);
      }
    }

    for (String part in nameParts) {
      if (part.isNotEmpty && part.trim().length > 1) {
        return part.trim();
      }
    }

    return fullName;
  }

  ImageProvider _getChatImage(String imagePath) {
    if (imagePath.startsWith('http') || imagePath.startsWith('https')) {
      return NetworkImage(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    } else if (imagePath.contains('supabase.co') ||
        imagePath.contains('firebasestorage') ||
        imagePath.contains('storage.googleapis.com')) {
      return NetworkImage(imagePath);
    } else if (imagePath.contains('job') ||
        imagePath.contains('post') ||
        imagePath.contains('product') ||
        imagePath.contains('default_job') ||
        imagePath.contains('work')) {
      try {
        if (imagePath.startsWith('http')) {
          return NetworkImage(imagePath);
        } else {
          return const AssetImage('assets/images/default_job_1.png');
        }
      } catch (e) {
        print('⚠️ خطأ في تحميل صورة المنشور: $imagePath');
        return const AssetImage('assets/images/default_job_1.png');
      }
    } else {
      return const AssetImage('assets/images/default_profile.png');
    }
  }

  ImageProvider _getProfileImage(String imagePath) {
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    } else {
      return const AssetImage('assets/images/default_profile.png');
    }
  }
}

class _UserInfo {
  final String name;
  final String image;
  final String id;

  _UserInfo({required this.name, required this.image, required this.id});
}
