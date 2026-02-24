import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:snae3ya/models/chat_model.dart';
import 'package:snae3ya/models/application_model.dart';
import 'package:snae3ya/providers/chat_provider.dart';
import 'package:snae3ya/providers/application_provider.dart';
import 'package:snae3ya/providers/post_provider.dart';
import 'package:snae3ya/services/media_service.dart';
import 'package:snae3ya/services/chat_service.dart';
import 'package:snae3ya/screens/full_screen_image_viewer.dart';
import 'package:snae3ya/screens/video_player_screen.dart';
import 'package:snae3ya/services/location_service.dart';
import 'package:snae3ya/screens/live_tracking_screen.dart';
import 'package:snae3ya/models/location_model.dart';
import 'package:snae3ya/models/post_model.dart';
import 'package:snae3ya/providers/user_provider.dart';

// ⭐ كاش لصور المستخدمين
class UserImageCache {
  static final _cache = <String, String>{};

  static Future<String> getUserImage(String userId) async {
    if (_cache.containsKey(userId)) {
      return _cache[userId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final image =
          userDoc.data()?['profileImage'] ??
          'assets/images/default_profile.png';

      _cache[userId] = image;
      return image;
    } catch (e) {
      print('❌ خطأ في جلب صورة المستخدم: $e');
      return 'assets/images/default_profile.png';
    }
  }

  static void clearCache() {
    _cache.clear();
  }
}

class SingleChatScreen extends StatefulWidget {
  final String userName;
  final String userImage;
  final bool isOnline;
  final String? initialMessage;
  final String? postId;
  final String receiverId;
  final bool? isFromJobApplication;
  final String? chatType;
  final bool? isFromProductQuery;

  const SingleChatScreen({
    super.key,
    required this.userName,
    required this.userImage,
    required this.receiverId,
    this.isOnline = false,
    this.initialMessage,
    this.postId,
    this.isFromJobApplication = false,
    this.chatType = 'job',
    this.isFromProductQuery = false,
  });

  @override
  State<SingleChatScreen> createState() => _SingleChatScreenState();
}

class _SingleChatScreenState extends State<SingleChatScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focusNode = FocusNode();

  bool _isSendingMessage = false;
  String? _editingMessageId;
  String? _selectedMessageId;
  String? _currentUserImage;
  bool _isDisposed = false;
  String? _currentReceiverId;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;

  // متغيرات لوحة الإيموجي
  bool _showEmojiPicker = false;
  double _emojiPickerHeight = 0;
  final List<String> _recentEmojis = [];

  // متغيرات لمنع التكرار
  bool _hasMarkedAsRead = false;
  Timer? _markAsReadTimer;
  Timer? _autoMarkAsReadTimer;

  // لتتبع الرسائل التي تم الرد عليها
  final Set<String> _respondedMessages = {};
  final Set<String> _respondedApplications = {};

  // خدمات جديدة
  late MediaService _mediaService;
  late ChatService _chatService;
  late LocationService _locationService;
  File? _selectedMediaFile;
  bool _isEditingMedia = false;

  // ⭐⭐ متغيرات إضافية للمنتجات
  String? _productTitle;
  String? _productImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    print(
      '📱 SingleChatScreen initState - isFromProductQuery: ${widget.isFromProductQuery}',
    );
    print(
      '📱 SingleChatScreen initState - initialMessage: ${widget.initialMessage}',
    );
    print('📱 SingleChatScreen initState - chatType: ${widget.chatType}');
    print('📱 SingleChatScreen initState - postId: ${widget.postId}');

    // ⭐⭐ لا نتحقق هنا لأن _chatService لم يُهيأ بعد

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _hideEmojiPicker();
      }
    });

    _loadRecentEmojis();
    _loadProductInfo();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_isDisposed && mounted) {
        _initializeChat();
        _currentReceiverId = widget.receiverId;
        _loadResponseStatus();
        _mediaService = MediaService();
        _chatService = ChatService();
        _locationService = LocationService();

        // ⭐⭐ بعد تهيئة _chatService، نتحقق من أول مرة ونرسل الرسالة التلقائية إذا لزم الأمر
        if (widget.isFromProductQuery == true &&
            widget.initialMessage != null) {
          _checkIfFirstTime()
              .then((isFirst) {
                print('📱 بعد التهيئة: _checkIfFirstTime returned $isFirst');
                if (isFirst && mounted) {
                  print('📱 بعد التهيئة: أول مرة، سأرسل الرسالة فوراً');
                  _sendProductAvailabilityQuery();
                } else {
                  print('📱 بعد التهيئة: ليست أول مرة، لن أرسل التلقائية');
                }
              })
              .catchError((e) {
                print('❌ بعد التهيئة: خطأ في _checkIfFirstTime: $e');
              });
        } else if (widget.isFromJobApplication == true &&
            widget.initialMessage != null) {
          print(
            '📱 بعد التهيئة: isFromJobApplication == true, سأضع الرسالة في TextController',
          );
          _messageController.text = widget.initialMessage!;
        }
      }
    });
  }

  // ⭐⭐ دالة جديدة للتحقق من وجود رسائل سابقة في هذه المحادثة
  Future<bool> _checkIfFirstTime() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;
      final chatId = _chatService.generateChatId(
        currentUser.uid,
        widget.receiverId,
        widget.postId,
      );
      final collectionName = widget.chatType == 'product'
          ? 'market_chats'
          : 'chats';
      final messagesQuery = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(chatId)
          .collection('messages')
          .limit(1)
          .get();
      print(
        '📱 _checkIfFirstTime: messages count = ${messagesQuery.docs.length}',
      );
      return messagesQuery.docs.isEmpty;
    } catch (e) {
      print('❌ خطأ في التحقق من أول مرة: $e');
      return false;
    }
  }

  // ⭐⭐ دالة لتحميل معلومات المنتج
  Future<void> _loadProductInfo() async {
    if (widget.chatType == 'product' && widget.postId != null) {
      try {
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.postId)
            .get();

        if (productDoc.exists) {
          final data = productDoc.data()!;
          setState(() {
            _productTitle = data['title'] ?? 'منتج';
            final images = data['imageUrls'] ?? [];
            if (images is List && images.isNotEmpty) {
              _productImage = images[0];
            }
          });
        }
      } catch (e) {
        print('❌ خطأ في تحميل معلومات المنتج: $e');
      }
    }
  }

  // ⭐⭐ دالة لإرسال استفسار توفر المنتج
  Future<void> _sendProductAvailabilityQuery() async {
    if (_isDisposed || widget.initialMessage == null) {
      print(
        '❌ _sendProductAvailabilityQuery: _isDisposed=$_isDisposed, initialMessage=${widget.initialMessage}',
      );
      return;
    }

    print(
      '📤 _sendProductAvailabilityQuery: جاري إرسال الرسالة التلقائية: ${widget.initialMessage}',
    );

    if (!_isDisposed && mounted) {
      print(
        '✅ _sendProductAvailabilityQuery: سأرسل الرسالة الآن via _sendMessage',
      );
      await _sendMessage(isAvailabilityQuestion: true);
      print('✅ _sendProductAvailabilityQuery: تم إرسال الرسالة');
    } else {
      print(
        '❌ _sendProductAvailabilityQuery: لا يمكن إرسال الرسالة - _isDisposed=$_isDisposed, mounted=$mounted',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _markMessagesAsReadImmediately();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_currentReceiverId != widget.receiverId) {
      _cleanupSubscriptions();
      _currentReceiverId = widget.receiverId;
      _initializeChat();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    _markAsReadTimer?.cancel();
    _autoMarkAsReadTimer?.cancel();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOnlineStatus(false);
    });

    _cleanupSubscriptions();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _cleanupSubscriptions() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
  }

  Future<void> _loadRecentEmojis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = prefs.getStringList('recent_emojis') ?? [];
      setState(() {
        _recentEmojis.addAll(recent);
      });
    } catch (e) {
      print('⚠️ خطأ في تحميل الإيموجي الحديثة: $e');
    }
  }

  Future<void> _saveRecentEmoji(String emoji) async {
    try {
      if (_recentEmojis.contains(emoji)) return;

      _recentEmojis.insert(0, emoji);
      if (_recentEmojis.length > 30) {
        _recentEmojis.removeLast();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_emojis', _recentEmojis);
    } catch (e) {
      print('⚠️ خطأ في حفظ الإيموجي: $e');
    }
  }

  Future<void> _loadResponseStatus() async {
    if (_isDisposed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final respondedMessagesJson = prefs.getStringList(
        'respondedMessages_${widget.receiverId}',
      );
      final respondedAppsJson = prefs.getStringList(
        'respondedApplications_${widget.receiverId}',
      );

      if (respondedMessagesJson != null) {
        setState(() {
          _respondedMessages.addAll(respondedMessagesJson);
        });
      }

      if (respondedAppsJson != null) {
        setState(() {
          _respondedApplications.addAll(respondedAppsJson);
        });
      }
    } catch (e) {
      print('⚠️ خطأ في تحميل حالة الردود: $e');
    }
  }

  Future<void> _saveResponseStatus() async {
    if (_isDisposed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'respondedMessages_${widget.receiverId}',
        _respondedMessages.toList(),
      );
      await prefs.setStringList(
        'respondedApplications_${widget.receiverId}',
        _respondedApplications.toList(),
      );
    } catch (e) {
      print('⚠️ خطأ في حفظ حالة الردود: $e');
    }
  }

  void _initializeChat() async {
    if (_isDisposed) return;

    print('🚀 بدء تهيئة الشات مع: ${widget.receiverId}');
    print('📁 نوع المحادثة: ${widget.chatType}');
    print('📌 postId: ${widget.postId}');

    await _updateOnlineStatus(true);
    _markMessagesAsReadImmediately();
    await _loadCurrentUserImage();
    _startAutoMarkAsReadTimer();

    print('✅ تم تهيئة الشات بنجاح');
  }

  void _markMessagesAsReadImmediately() {
    if (_isDisposed || _hasMarkedAsRead) return;

    print('📖 تعيين الرسائل كمقروءة فور الدخول للشات');

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.markMessagesAsRead(
      widget.receiverId,
      widget.postId,
      widget.chatType,
    );
    chatProvider.markChatAsRead(
      widget.receiverId,
      widget.postId,
      widget.chatType,
    );

    _hasMarkedAsRead = true;
  }

  void _startAutoMarkAsReadTimer() {
    if (_isDisposed) return;

    _autoMarkAsReadTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.markMessagesAsRead(
        widget.receiverId,
        widget.postId,
        widget.chatType,
      );
      chatProvider.markChatAsRead(
        widget.receiverId,
        widget.postId,
        widget.chatType,
      );

      print('🔄 تحديث تلقائي لحالة القراءة');
    });
  }

  Future<void> _loadCurrentUserImage() async {
    if (_isDisposed) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final image = await UserImageCache.getUserImage(currentUser.uid);
        if (!_isDisposed && mounted) {
          setState(() {
            _currentUserImage = image;
          });
        }
        print('✅ تم تحميل صورة المستخدم: $image');
      }
    } catch (e) {
      print('❌ خطأ في تحميل صورة المستخدم: $e');
    }
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    if (_isDisposed) return;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.updateMyOnlineStatus(isOnline);
      print('✅ تم تحديث حالة الاتصال: ${isOnline ? 'متصل' : 'غير متصل'}');
    } catch (e) {
      print('⚠️ خطأ في تحديث حالة الاتصال: $e');
    }
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      _hideEmojiPicker();
      _focusNode.requestFocus();
    } else {
      _showEmojiPicker = true;
      _focusNode.unfocus();

      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _emojiPickerHeight = 250;
          });
        }
      });
    }
  }

  void _hideEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
        _emojiPickerHeight = 0;
      });
    }
  }

  void _addEmoji(String emoji) {
    _saveRecentEmoji(emoji);
    _messageController.text += emoji;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  void _deleteLastChar() {
    if (_messageController.text.isNotEmpty) {
      _messageController.text = _messageController.text.substring(
        0,
        _messageController.text.length - 1,
      );
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    }
  }

  Widget _buildEmojiPicker() {
    final List<String> allEmojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '😂',
      '🤣',
      '😊',
      '😇',
      '🙂',
      '🙃',
      '😉',
      '😌',
      '😍',
      '🥰',
      '😘',
      '😗',
      '😙',
      '😚',
      '😋',
      '😛',
      '😝',
      '😜',
      '🤪',
      '🤨',
      '🧐',
      '🤓',
      '😎',
      '🥸',
      '🤩',
      '🥳',
      '😏',
      '😒',
      '😞',
      '😔',
      '😟',
      '😕',
      '🙁',
      '☹️',
      '😣',
      '😖',
      '😫',
      '😩',
      '🥺',
      '😢',
      '😭',
      '😤',
      '😠',
      '😡',
      '🤬',
      '🤯',
      '😳',
      '🥵',
      '🥶',
      '😱',
      '😨',
      '😰',
      '😥',
      '😓',
      '🤗',
      '🤔',
      '🤭',
      '🤫',
      '🤥',
      '😶',
      '😐',
      '😑',
      '😬',
      '🙄',
      '😯',
      '😦',
      '😧',
      '😮',
      '😲',
      '🥱',
      '😴',
      '🤤',
      '😪',
      '😵',
      '🤐',
      '🥴',
      '🤢',
      '🤮',
      '🤧',
      '😷',
      '🤒',
      '🤕',
      '🤑',
      '🤠',
      '😈',
      '👿',
      '👹',
      '👺',
      '🤡',
      '💩',
      '👻',
      '💀',
      '☠️',
      '👽',
      '👾',
      '🤖',
      '🎃',
      '😺',
      '😸',
      '😹',
      '😻',
      '😼',
      '😽',
      '🙀',
      '😿',
      '😾',
      '🤲',
      '👐',
      '🙌',
      '👏',
      '🤝',
      '👍',
      '👎',
      '👊',
      '✊',
      '🤛',
      '🤜',
      '🤞',
      '✌️',
      '🤟',
      '🤘',
      '👌',
      '👈',
      '👉',
      '👆',
      '👇',
      '☝️',
      '✋',
      '🤚',
      '🖐',
      '🖖',
      '👋',
      '🤙',
      '💪',
      '🦾',
      '🦿',
      '🦵',
      '🦶',
      '👂',
      '🦻',
      '👃',
      '🧠',
      '🦷',
      '🦴',
      '👀',
      '👁',
      '👅',
      '👄',
      '💋',
      '🩸',
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '🤎',
      '💔',
      '❣️',
      '💕',
      '💞',
      '💓',
      '💗',
      '💖',
      '💘',
      '💝',
      '💟',
      '☮️',
      '✝️',
      '☪️',
      '🕉',
      '☸️',
      '✡️',
      '🔯',
      '🕎',
      '☯️',
      '☦️',
      '🛐',
      '⛎',
      '♈',
      '♉',
      '♊',
      '♋',
      '♌',
      '♍',
      '♎',
      '♏',
      '♐',
      '♑',
      '♒',
      '♓',
      '🆔',
    ];

    final List<String> displayEmojis = [];
    if (_recentEmojis.isNotEmpty) {
      displayEmojis.addAll(_recentEmojis);
      displayEmojis.addAll(
        allEmojis.where((emoji) => !_recentEmojis.contains(emoji)).toList(),
      );
    } else {
      displayEmojis.addAll(allEmojis);
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = (screenWidth / 40).floor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _emojiPickerHeight,
      curve: Curves.easeInOut,
      color: Colors.grey[100],
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount.clamp(6, 10),
                childAspectRatio: 1,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: displayEmojis.length,
              itemBuilder: (context, index) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _addEmoji(displayEmojis[index]),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        displayEmojis[index],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            height: 40,
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.backspace, size: 20),
                  onPressed: _deleteLastChar,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.keyboard, size: 20),
                  onPressed: () {
                    _hideEmojiPicker();
                    _focusNode.requestFocus();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkFileExists(String url) async {
    if (!url.startsWith('http')) return false;

    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ فشل في التحقق من الملف: $url - $e');
      return false;
    }
  }

  String _safeFixUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    if (url.contains('supabase.co')) {
      return url;
    }

    const baseUrl =
        'https://cezhcyhaiztoqgetxehv.supabase.co/storage/v1/object/public/posts_images/chat_media/';
    return '$baseUrl$url';
  }

  Widget _safeNetworkImage(String url, {double? width, double? height}) {
    final fixedUrl = _safeFixUrl(url);

    return FutureBuilder<bool>(
      future: _checkFileExists(fixedUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          return Image.network(
            fixedUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: width,
                height: height,
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorPlaceholder(width, height);
            },
          );
        } else {
          return _buildErrorPlaceholder(width, height);
        }
      },
    );
  }

  Widget _buildErrorPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.grey, size: 40),
            SizedBox(height: 8),
            Text(
              'تعذر تحميل الملف',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaAttachmentButton() {
    return IconButton(
      icon: const Icon(Icons.attach_file, color: Color(0xFF00A8E8)),
      onPressed: () async {
        _hideEmojiPicker();
        _focusNode.unfocus();

        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'إرسال وسائط',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMediaOption(
                          icon: Icons.image,
                          color: Colors.blue,
                          label: 'صورة',
                          onTap: () {
                            Navigator.pop(context);
                            _sendImage();
                          },
                        ),
                        _buildMediaOption(
                          icon: Icons.videocam,
                          color: Colors.green,
                          label: 'فيديو',
                          onTap: () {
                            Navigator.pop(context);
                            _sendVideo();
                          },
                        ),
                        _buildMediaOption(
                          icon: Icons.insert_drive_file,
                          color: Colors.orange,
                          label: 'ملف',
                          onTap: () {
                            Navigator.pop(context);
                            _sendFile();
                          },
                        ),
                        _buildMediaOption(
                          icon: Icons.camera_alt,
                          color: Colors.purple,
                          label: 'كاميرا',
                          onTap: () {
                            Navigator.pop(context);
                            _sendImageFromCamera();
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'الحد الأقصى لحجم الملف: 20MB\nالأنواع المسموحة: صور، فيديوهات، PDF، مستندات',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'أضف تعليقاً (اختياري)...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        prefixIcon: const Icon(Icons.text_fields),
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Future<void> _sendImageFromCamera() async {
    if (_isDisposed) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (pickedFile != null && !_isDisposed) {
        final File imageFile = File(pickedFile.path);
        await _sendMediaMessage(imageFile);
      }
    } catch (e) {
      print('❌ خطأ في التقاط صورة من الكاميرا: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في التقاط صورة: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendImage() async {
    if (_isDisposed) return;

    try {
      final imageFile = await _mediaService.pickImageFromGallery();
      if (imageFile != null && !_isDisposed) {
        await _sendMediaMessage(imageFile);
      }
    } catch (e) {
      print('❌ خطأ في اختيار الصورة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في اختيار الصورة: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendFile() async {
    if (_isDisposed) return;

    try {
      final file = await _mediaService.pickFileFromDevice();
      if (file != null && !_isDisposed) {
        await _sendMediaMessage(file);
      }
    } catch (e) {
      print('❌ خطأ في اختيار الملف: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في اختيار الملف: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendVideo() async {
    if (_isDisposed) return;

    try {
      final videoFile = await _mediaService.pickVideoFromGallery();
      if (videoFile != null && !_isDisposed) {
        await _sendMediaMessage(videoFile);
      }
    } catch (e) {
      print('❌ خطأ في اختيار الفيديو: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في اختيار الفيديو: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMediaMessage(File mediaFile) async {
    if (_isDisposed || _isSendingMessage) return;

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      final tempMessageId =
          'temp_media_${DateTime.now().millisecondsSinceEpoch}';
      final mediaType = _mediaService.getFileType(mediaFile.path);
      String tempMessageText = '';

      switch (mediaType) {
        case 'image':
          tempMessageText = '📸 جاري رفع الصورة...';
          break;
        case 'video':
          tempMessageText = '🎬 جاري رفع الفيديو...';
          break;
        default:
          tempMessageText = '📎 جاري رفع الملف...';
      }

      final tempMessage = ChatMessage(
        id: tempMessageId,
        senderId: FirebaseAuth.instance.currentUser!.uid,
        receiverId: widget.receiverId,
        message: tempMessageText,
        timestamp: DateTime.now(),
        isRead: false,
        postId: widget.postId,
        mediaType: mediaType,
      );

      chatProvider.addTempMessage(
        widget.receiverId,
        tempMessage,
        widget.postId,
      );
      _scrollToBottom();

      print('🔼 بدء رفع الوسائط...');
      print('📁 نوع الملف: $mediaType');
      print('📏 حجم الملف: ${await mediaFile.length()} بايت');

      await _chatService.sendMediaMessage(
        receiverId: widget.receiverId,
        mediaFile: mediaFile,
        message: _messageController.text.trim().isNotEmpty
            ? _messageController.text.trim()
            : null,
        postId: widget.postId,
        chatType: widget.chatType,
      );

      print('✅ تم إرسال الوسائط بنجاح');

      _messageController.clear();
      setState(() {
        _selectedMediaFile = null;
      });

      chatProvider.removeTempMessage(
        widget.receiverId,
        tempMessageId,
        widget.postId,
      );
    } catch (e) {
      print('❌ فشل في إرسال الوسائط: $e');

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.removeTempMessage(
        widget.receiverId,
        'temp_media_${DateTime.now().millisecondsSinceEpoch}',
        widget.postId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إرسال الوسائط: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: () => _sendMediaMessage(mediaFile),
            ),
          ),
        );
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  Future<void> _sendMessage({bool isAvailabilityQuestion = false}) async {
    if (_isSendingMessage || _isDisposed) return;

    final text = _messageController.text.trim();
    if (text.isEmpty && !isAvailabilityQuestion) return;

    setState(() => _isSendingMessage = true);

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      _hideEmojiPicker();

      print('📤 _sendMessage: isAvailabilityQuestion=$isAvailabilityQuestion');
      print('📤 _sendMessage: receiverId=${widget.receiverId}');
      print('📤 _sendMessage: text="$text"');

      final messageToSend = text.isNotEmpty
          ? text
          : (widget.initialMessage ?? '');

      final tempMessage = ChatMessage(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        senderId: currentUser.uid,
        receiverId: widget.receiverId,
        message: messageToSend,
        timestamp: DateTime.now(),
        isRead: false,
        isAvailabilityQuestion: isAvailabilityQuestion,
        postId: widget.postId,
      );

      chatProvider.addTempMessage(
        widget.receiverId,
        tempMessage,
        widget.postId,
      );
      _messageController.clear();

      _scrollToBottom();

      await chatProvider.sendMessage(
        receiverId: widget.receiverId,
        message: messageToSend,
        postId: widget.postId,
        isAvailabilityQuestion: isAvailabilityQuestion,
        chatType: widget.chatType,
      );

      print('✅ _sendMessage: تم إرسال الرسالة بنجاح');

      chatProvider.removeTempMessage(
        widget.receiverId,
        tempMessage.id,
        widget.postId,
      );
    } catch (e) {
      print('❌ _sendMessage: فشل في إرسال الرسالة: $e');

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.removeTempMessage(
        widget.receiverId,
        'temp_${DateTime.now().millisecondsSinceEpoch}',
        widget.postId,
      );

      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('فشل إرسال الرسالة: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: () =>
                  _sendMessage(isAvailabilityQuestion: isAvailabilityQuestion),
            ),
          ),
        );
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isSendingMessage = false;
          _editingMessageId = null;
        });
      }
    }
  }

  // دالة للتأكد من وجود موقع المستخدم
  Future<bool> _ensureUserLocation() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('user_locations')
          .doc(currentUser.uid)
          .get();

      if (doc.exists && doc.data()?['latitude'] != null) {
        print('✅ موقع المستخدم موجود بالفعل');
        return true;
      }

      print('🔄 موقع المستخدم غير موجود، جاري التحديث...');
      final location = await _locationService.getCurrentLocation();
      await _locationService.updateUserLocation(currentUser.uid, location);

      print('✅ تم تحديث موقع المستخدم بنجاح');
      return true;
    } catch (e) {
      print('❌ فشل في التأكد من موقع المستخدم: $e');
      return false;
    }
  }

  // دالة بدء المتابعة الحية
  Future<void> _startLiveTracking() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final hasLocation = await _ensureUserLocation();
      if (!hasLocation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في تحديد موقعك. يرجى المحاولة مرة أخرى.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final hasPermission = await _locationService.requestLocationPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب منح صلاحيات الموقع لبدء المتابعة الحية'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final currentLocation = await _locationService.getCurrentLocation();

      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('بدء المتابعة الحية'),
          content: const Text(
            'هل تريد بدء متابعة الصنايعي في طريقه إليك؟ سيتم مشاركة موقعك مع الصنايعي.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('بدأ المتابعة'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.sendMessage(
        receiverId: widget.receiverId,
        message: '🚗 تم بدء المتابعة الحية. أنا في طريقي إليك!',
        postId: widget.postId,
        chatType: widget.chatType,
      );

      String clientId, workerId;

      clientId = currentUser.uid;
      workerId = widget.receiverId;

      UserLocation? workerLocation;
      try {
        workerLocation = await _locationService.getUserLocation(workerId);
      } catch (e) {
        print(
          '⚠️ لم يتم العثور على موقع العامل، سيتم استخدام موقع العميل مؤقتاً',
        );
      }

      final sessionId = await _locationService.startLiveTracking(
        postId: widget.postId ?? '',
        clientId: clientId,
        workerId: workerId,
        clientLocation: currentLocation,
        workerLocation: workerLocation ?? currentLocation,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveTrackingScreen(
            sessionId: sessionId,
            postId: widget.postId,
            clientId: clientId,
            workerId: workerId,
            userName: widget.userName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في بدء المتابعة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ⭐⭐ دالة عرض حوار تأكيد الاتفاق (للشغلانات فقط)
  Future<void> _showAgreeJobDialog(Post post) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الاتفاق'),
        content: Text(
          'هل أنت متأكد من الاتفاق مع ${widget.userName} على تنفيذ "${post.title}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.sendMessage(
          receiverId: widget.receiverId,
          message: '✅ تم الاتفاق على بدء العمل في "${post.title}"',
          postId: post.id,
          chatType: widget.chatType,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد الاتفاق بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تأكيد الاتفاق: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ⭐⭐ دالة عرض حوار إكمال الشغلانة مع رفع صور (للشغلانات فقط)
  Future<void> _showCompleteJobDialog(Post post) async {
    final picker = ImagePicker();
    List<File> selectedImages = [];

    final result = await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('إنجاز الشغلانة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('يرجى رفع صور للعمل بعد الإنجاز:'),
                const SizedBox(height: 16),

                // عرض الصور المختارة
                if (selectedImages.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Image.file(
                                selectedImages[index],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedImages.removeAt(index);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),

                // زر إضافة صور
                ElevatedButton.icon(
                  onPressed: () async {
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (pickedFile != null) {
                      setState(() {
                        selectedImages.add(File(pickedFile.path));
                      });
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('إضافة صور'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: selectedImages.isEmpty
                    ? null
                    : () => Navigator.pop(context, selectedImages),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('تأكيد الإنجاز'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result is List<File> && result.isNotEmpty) {
      try {
        final postProvider = Provider.of<PostProvider>(context, listen: false);
        await postProvider.completeJob(post.id, result);

        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.sendMessage(
          receiverId: post.authorId,
          message: '✅ تم إنجاز الشغلانة "${post.title}" بنجاح',
          postId: post.id,
          chatType: widget.chatType,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الإنجاز بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تسجيل الإنجاز: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ⭐⭐ دالة عرض حوار التقييم (للشغلانات فقط)
  Future<void> _showRatingDialog(Post post) async {
    double rating = 5;
    TextEditingController reviewController = TextEditingController();

    final result = await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('تقييم الشغلانة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ما تقييمك للصنايعي؟'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reviewController,
                  decoration: const InputDecoration(
                    labelText: 'أضف تعليق (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, {
                  'rating': rating,
                  'review': reviewController.text,
                }),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                child: const Text('تقييم'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result is Map) {
      try {
        final postProvider = Provider.of<PostProvider>(context, listen: false);
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        await postProvider.rateJob(
          post.id,
          result['rating'],
          result['review'].toString().isNotEmpty
              ? result['review'].toString()
              : null,
          clientName: userProvider.user.name ?? 'مستخدم',
          clientImage: userProvider.user.profileImage,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة التقييم بنجاح، شكراً لك!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إضافة التقييم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ⭐⭐ دالة معالجة ردود التوفر (للمنتجات والشغلانات)
  void _handleAvailabilityResponse(
    ChatMessage message,
    bool isAvailable,
  ) async {
    if (_isDisposed || _respondedMessages.contains(message.id)) return;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      setState(() {
        _respondedMessages.add(message.id);
      });
      await _saveResponseStatus();

      String responseText;
      if (isAvailable) {
        responseText = widget.chatType == 'product'
            ? "نعم، المنتج متوفر ✅"
            : "نعم، الشغلانة متوفرة ✅";
      } else {
        responseText = widget.chatType == 'product'
            ? "للأسف، المنتج غير متوفر حالياً ❌"
            : "للأسف، الشغلانة غير متوفرة حالياً ❌";
      }

      await chatProvider.sendMessage(
        receiverId: message.senderId,
        message: responseText,
        postId: message.postId,
        isAvailabilityResponse: true,
        availabilityStatus: isAvailable,
        chatType: widget.chatType,
      );

      _scrollToBottom();
      await _saveResponseStatus();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _respondedMessages.remove(message.id);
      });

      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إرسال الرد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMediaOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download, color: Colors.blue),
                title: const Text('تنزيل الملف'),
                onTap: () async {
                  Navigator.pop(context);
                  if (message.mediaUrl != null) {
                    await _downloadMedia(message);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.green),
                title: const Text('مشاركة'),
                onTap: () {
                  Navigator.pop(context);
                  _shareMedia(message);
                },
              ),
              if (message.senderId == FirebaseAuth.instance.currentUser?.uid)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('حذف', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMediaMessage(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadMedia(ChatMessage message) async {
    if (message.mediaUrl == null || message.fileName == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('جاري التنزيل...'),
            ],
          ),
        ),
      );

      final File? downloadedFile = await _mediaService.downloadMedia(
        message.mediaUrl!,
        message.fileName!,
      );

      if (downloadedFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تنزيل الملف بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        await _mediaService.openFile(downloadedFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل في التنزيل: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareMedia(ChatMessage message) async {
    if (message.mediaUrl == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('جاري تحضير الملف للمشاركة...'),
            ],
          ),
        ),
      );

      final File? downloadedFile = await _mediaService.downloadMedia(
        message.mediaUrl!,
        message.fileName ?? 'file',
      );

      if (downloadedFile != null) {
        await _mediaService.shareFile(downloadedFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل في المشاركة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteMediaMessage(ChatMessage message) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم تنفيذ الحذف في التحديثات القادمة')),
    );
  }

  String _fixSupabaseUrl(String url) {
    if (url.contains('storage/v1/object/public/posts_images/chat_media/')) {
      return url;
    }

    if (url.contains('supabase.co/storage/v1/object/public/')) {
      return url;
    }

    return url;
  }

  void _openFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  void _playVideo(String videoUrl, {String? videoTitle}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VideoPlayerScreen(videoUrl: videoUrl, videoTitle: videoTitle),
      ),
    );
  }

  Future<void> _openDocument(ChatMessage message) async {
    if (message.mediaUrl == null || message.fileName == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('جاري تحميل الملف...'),
            ],
          ),
        ),
      );

      final File? downloadedFile = await _mediaService.downloadMedia(
        message.mediaUrl!,
        message.fileName!,
      );

      if (downloadedFile != null) {
        await _mediaService.openFile(downloadedFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل في فتح الملف: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editMessage(String messageId, String currentMessage) async {
    if (_isDisposed) return;

    setState(() {
      _editingMessageId = messageId;
      _messageController.text = currentMessage;
    });
  }

  Future<void> _updateMessage(String messageId) async {
    if (_isDisposed) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      if (!_isDisposed) {
        setState(() {
          _editingMessageId = null;
          _messageController.clear();
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تعديل الرسالة'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تعديل الرسالة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    if (_isDisposed) return;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      if (!_isDisposed) {
        setState(() {
          _selectedMessageId = null;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الرسالة'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حذف الرسالة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelEdit() {
    if (_isDisposed) return;

    setState(() {
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  void _showMessageOptions(String messageId) {
    if (_isDisposed) return;

    setState(() {
      _selectedMessageId = messageId;
    });

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل الرسالة'),
              onTap: () {
                Navigator.pop(context);
                if (!_isDisposed) {
                  final messages = Provider.of<ChatProvider>(
                    context,
                    listen: false,
                  ).getChatMessages(widget.receiverId, widget.postId);
                  final message = messages.firstWhere((m) => m.id == messageId);
                  _editMessage(messageId, message.message);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'حذف الرسالة',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('نسخ الرسالة'),
              onTap: () {
                Navigator.pop(context);
                if (!_isDisposed) {
                  final messages = Provider.of<ChatProvider>(
                    context,
                    listen: false,
                  ).getChatMessages(widget.receiverId, widget.postId);
                  final message = messages.firstWhere((m) => m.id == messageId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ الرسالة')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_isDisposed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMediaMessage(
    ChatMessage message,
    bool isMe,
    String hour,
    String minute,
  ) {
    final String? fixedMediaUrl = message.mediaUrl != null
        ? _safeFixUrl(message.mediaUrl!)
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(isMe ? 12 : 0),
          bottomRight: Radius.circular(isMe ? 0 : 12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (message.mediaType == 'image')
            _buildImageMessage(message, fixedMediaUrl)
          else if (message.mediaType == 'video')
            _buildVideoMessage(message, fixedMediaUrl)
          else
            _buildDocumentMessage(message, fixedMediaUrl),

          if (message.message.isNotEmpty &&
              message.message != '📸 صورة' &&
              message.message != '🎬 فيديو' &&
              !message.message.startsWith('📎 ملف:'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message.message,
                style: const TextStyle(fontSize: 16),
                textAlign: isMe ? TextAlign.end : TextAlign.start,
              ),
            ),

          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$hour:$minute',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              if (isMe) const SizedBox(width: 4),
              if (isMe) _buildMessageStatusIcons(message),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(ChatMessage message, String? mediaUrl) {
    final fixedUrl = _safeFixUrl(mediaUrl);

    return GestureDetector(
      onTap: () {
        if (fixedUrl.isNotEmpty) {
          _openFullScreenImage(fixedUrl);
        }
      },
      onLongPress: () {
        _showMediaOptions(message);
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _safeNetworkImage(fixedUrl, width: 250, height: 150),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _downloadMedia(message),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoMessage(ChatMessage message, String? mediaUrl) {
    final fixedUrl = _safeFixUrl(mediaUrl);

    return GestureDetector(
      onTap: () {
        if (fixedUrl.isNotEmpty) {
          _playVideo(fixedUrl, videoTitle: message.fileName);
        }
      },
      onLongPress: () {
        _showMediaOptions(message);
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 250,
                  height: 150,
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _downloadMedia(message),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message.fileName ?? 'فيديو',
                      style: const TextStyle(color: Colors.black),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildDocumentMessage(ChatMessage message, String? mediaUrl) {
    final fixedUrl = _safeFixUrl(mediaUrl);

    return GestureDetector(
      onTap: () {
        _openDocument(message);
      },
      onLongPress: () {
        _showMediaOptions(message);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.blue, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'ملف',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (message.fileSize != null)
                    Text(
                      '${(message.fileSize! / 1024).toStringAsFixed(1)} كيلوبايت',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.blue),
              onPressed: () => _downloadMedia(message),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final time = message.timestamp;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMe = message.senderId == currentUser?.uid;
    final isSelected = _selectedMessageId == message.id;

    final userImage = isMe
        ? (_currentUserImage ?? 'assets/images/default_profile.png')
        : widget.userImage;

    return GestureDetector(
      onLongPress: isMe ? () => _showMessageOptions(message.id) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        color: isSelected ? Colors.grey[100] : Colors.transparent,
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  final isOnline = chatProvider.isUserOnline(widget.receiverId);
                  return Stack(
                    children: [
                      CircleAvatar(
                        backgroundImage: _getProfileImage(userImage),
                        radius: 16,
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (message.isAvailabilityQuestion)
                    _buildAvailabilityQuestion(message)
                  else if (message.isAvailabilityResponse)
                    _buildAvailabilityResponse(message)
                  else if (message.hasMedia)
                    _buildMediaMessage(message, isMe, hour, minute)
                  else
                    _buildNormalMessage(message, isMe, hour, minute, userImage),
                ],
              ),
            ),
            if (isMe)
              Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  final isOnline = chatProvider.isUserOnline(
                    currentUser?.uid ?? '',
                  );
                  return Stack(
                    children: [
                      CircleAvatar(
                        backgroundImage: _getProfileImage(userImage),
                        radius: 16,
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityQuestion(ChatMessage message) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMe = message.senderId == currentUser?.uid;
    final hasResponded = _respondedMessages.contains(message.id);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.message,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (!isMe &&
              message.receiverId == currentUser?.uid &&
              !hasResponded &&
              message.postId != null)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAvailabilityResponse(message, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.chatType == 'product'
                          ? Colors.green
                          : Colors.green,
                    ),
                    child: Text(
                      widget.chatType == 'product' ? 'نعم متوفر' : 'نعم متوفرة',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _handleAvailabilityResponse(message, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: Text(
                      widget.chatType == 'product' ? 'للأسف لا' : 'للأسف لا',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

          if (hasResponded)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'تم الرد على هذا الاستفسار',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityResponse(ChatMessage message) {
    final isAvailable = message.availabilityStatus ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAvailable ? Colors.green : Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.message,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isAvailable ? Colors.green[800] : Colors.red[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAvailable ? '✅ تم قبول طلبك' : '❌ تم رفض طلبك',
            style: TextStyle(
              fontSize: 12,
              color: isAvailable ? Colors.green[600] : Colors.red[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalMessage(
    ChatMessage message,
    bool isMe,
    String hour,
    String minute,
    String userImage,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(isMe ? 12 : 0),
          bottomRight: Radius.circular(isMe ? 0 : 12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            message.message,
            style: const TextStyle(fontSize: 16),
            textAlign: isMe ? TextAlign.end : TextAlign.start,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$hour:$minute',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              if (isMe) const SizedBox(width: 4),
              if (isMe) _buildMessageStatusIcons(message),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStatusIcons(ChatMessage message) {
    if (!message.isRead) {
      return Icon(
        Icons.done,
        size: 16,
        color: const Color.fromARGB(255, 201, 20, 233),
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done,
            size: 16,
            color: const Color.fromARGB(255, 215, 33, 243),
          ),
          Icon(
            Icons.done,
            size: 16,
            color: const Color.fromARGB(255, 215, 33, 243),
          ),
        ],
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A8E8),
        titleSpacing: 0,
        title: InkWell(
          onTap: () {},
          child: Row(
            children: [
              Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  final isOnline = chatProvider.isUserOnline(widget.receiverId);
                  return Stack(
                    children: [
                      FutureBuilder<String>(
                        future: UserImageCache.getUserImage(widget.receiverId),
                        builder: (context, snapshot) {
                          String profileImage =
                              'assets/images/default_profile.png';

                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.hasData &&
                              snapshot.data!.isNotEmpty &&
                              snapshot.data !=
                                  'assets/images/default_profile.png') {
                            profileImage = snapshot.data!;
                          }

                          return CircleAvatar(
                            backgroundImage: _getProfileImage(profileImage),
                          );
                        },
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.userName, style: const TextStyle(fontSize: 16)),
                  Consumer<ChatProvider>(
                    builder: (context, chatProvider, child) {
                      final isOnline = chatProvider.isUserOnline(
                        widget.receiverId,
                      );
                      if (isOnline) {
                        return const Text(
                          'متصل الآن',
                          style: TextStyle(fontSize: 12),
                        );
                      } else {
                        return const Text(
                          'غير متصل',
                          style: TextStyle(fontSize: 12),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (widget.postId != null && widget.chatType == 'job')
            Consumer<PostProvider>(
              builder: (context, postProvider, child) {
                return FutureBuilder<Post?>(
                  future: postProvider.getPostById(widget.postId!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox();
                    }

                    final post = snapshot.data!;
                    final currentUser = FirebaseAuth.instance.currentUser;

                    if (post.authorId == currentUser?.uid) {
                      if (post.status == 'open') {
                        return IconButton(
                          icon: const Icon(
                            Icons.handshake,
                            color: Colors.orange,
                          ),
                          onPressed: () => _showAgreeJobDialog(post),
                          tooltip: 'تم الاتفاق مع الصنايعي',
                        );
                      } else if (post.status == 'agreed' &&
                          post.clientRating == null) {
                        return IconButton(
                          icon: const Icon(Icons.star, color: Colors.amber),
                          onPressed: () => _showRatingDialog(post),
                          tooltip: 'تقييم الشغلانة',
                        );
                      }
                    } else if (post.workerId == currentUser?.uid) {
                      if (post.status == 'agreed') {
                        return IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          onPressed: () => _showCompleteJobDialog(post),
                          tooltip: 'تم إنجاز الشغلانة',
                        );
                      }
                    }

                    return const SizedBox();
                  },
                );
              },
            ),

          if (widget.chatType == 'job')
            IconButton(
              icon: const Icon(Icons.directions_car, color: Colors.green),
              onPressed: _startLiveTracking,
            ),

          if (widget.chatType == 'product' && _productTitle != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _productTitle!,
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  return StreamBuilder<List<ChatMessage>>(
                    stream: chatProvider.getChatMessagesStream(
                      widget.receiverId,
                      widget.postId,
                      widget.chatType,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'خطأ في تحميل الرسائل',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد رسائل بعد',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              if (widget.initialMessage != null) ...[
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _sendMessage(
                                    isAvailabilityQuestion: true,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                  child: const Text('إرسال الرسالة'),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessage(messages[index]);
                        },
                      );
                    },
                  );
                },
              ),
            ),

            if (_showEmojiPicker) _buildEmojiPicker(),

            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _showEmojiPicker
                              ? Icons.keyboard
                              : Icons.emoji_emotions_outlined,
                          color: _showEmojiPicker ? Colors.blue : Colors.grey,
                        ),
                        onPressed: _toggleEmojiPicker,
                      ),

                      _buildMediaAttachmentButton(),

                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالة...',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            suffixIcon: _editingMessageId != null
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check,
                                          color: Colors.green,
                                        ),
                                        onPressed: () =>
                                            _updateMessage(_editingMessageId!),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                        ),
                                        onPressed: _cancelEdit,
                                      ),
                                    ],
                                  )
                                : IconButton(
                                    icon: _isSendingMessage
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send,
                                            color: Color(0xFF00A8E8),
                                          ),
                                    onPressed: _isSendingMessage
                                        ? null
                                        : () => _sendMessage(),
                                  ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
