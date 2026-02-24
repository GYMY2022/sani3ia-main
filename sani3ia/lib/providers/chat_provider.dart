import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:snae3ya/models/chat_model.dart';
import 'package:snae3ya/services/chat_service.dart';
import 'package:snae3ya/services/media_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  List<ChatRoom> _chatRooms = [];
  List<ChatRoom> _jobChatRooms = []; // ⭐⭐ جديد: محادثات الشغلانات
  List<ChatRoom> _marketChatRooms = []; // ⭐⭐ جديد: محادثات السوق
  Map<String, List<ChatMessage>> _messages = {};
  bool _isLoading = false;
  String _error = '';

  // ⭐ محسّن: إدارة أفضل لحالة الاتصال
  Map<String, bool> _userOnlineStatus = {};
  Map<String, StreamSubscription> _onlineStatusSubscriptions = {};
  final Set<String> _visibleChatIds = {};

  List<StreamSubscription<dynamic>> _activeSubscriptions = [];
  bool _isDisposed = false;

  // ⭐ جديد: متغيرات التحكم في التكرار
  bool _isAlreadyLoading = false;
  bool _isNotifying = false;
  Timer? _debounceTimer;
  DateTime? _lastLoadTime;

  // ⭐ جديد: متغيرات لمنع تكرار تعيين الرسائل كمقروءة
  final Set<String> _currentlyMarkingAsRead = {};
  final Map<String, DateTime> _lastMarkAsReadTime = {};

  ChatProvider()
    : _chatService = ChatService(),
      _auth = FirebaseAuth.instance,
      _firestore = FirebaseFirestore.instance;

  // ⭐⭐ Getters (مع الحفاظ على القديم وإضافة الجديد)
  List<ChatRoom> get chatRooms => _chatRooms; // قديم
  List<ChatRoom> get jobChatRooms => _jobChatRooms; // ⭐⭐ جديد
  List<ChatRoom> get marketChatRooms => _marketChatRooms; // ⭐⭐ جديد
  List<ChatRoom> get allChatRooms => [
    ..._jobChatRooms,
    ..._marketChatRooms,
  ]; // ⭐⭐ جديد
  bool get isLoading => _isLoading;
  String get error => _error;

  // ⭐ محسّن: دالة للتحقق من حالة الاتصال
  bool isUserOnline(String userId) {
    return _userOnlineStatus[userId] ?? false;
  }

  // ⭐ محسّن: دالة موحدة لإيقاف جميع الـ listeners
  void stopAllListeners() {
    if (_isDisposed) return;

    print('🛑 ChatProvider: إيقاف جميع الـ listeners...');

    // إيقاف الـ debounce timer
    _debounceTimer?.cancel();
    _debounceTimer = null;

    // إيقاف اشتراكات حالة الاتصال أولاً
    _stopAllOnlineStatusListeners();

    // إيقاف الاشتراكات النشطة
    for (var subscription in _activeSubscriptions) {
      try {
        subscription.cancel();
      } catch (e) {
        print('⚠️ خطأ في إلغاء الاشتراك: $e');
      }
    }
    _activeSubscriptions.clear();

    // تنظيف البيانات
    _chatRooms = [];
    _jobChatRooms = [];
    _marketChatRooms = [];
    _messages = {};
    _error = '';
    _userOnlineStatus.clear();
    _visibleChatIds.clear();
    _isAlreadyLoading = false;
    _currentlyMarkingAsRead.clear();
    _lastMarkAsReadTime.clear();

    print('✅ ChatProvider: تم إيقاف جميع الـ listeners بنجاح');
  }

  // ⭐ جديد: إيقاف جميع اشتراكات حالة الاتصال
  void _stopAllOnlineStatusListeners() {
    for (var subscription in _onlineStatusSubscriptions.values) {
      try {
        subscription.cancel();
      } catch (e) {
        print('⚠️ خطأ في إلغاء اشتراك حالة الاتصال: $e');
      }
    }
    _onlineStatusSubscriptions.clear();
  }

  void addSubscription(StreamSubscription<dynamic> subscription) {
    if (_isDisposed) {
      subscription.cancel();
      return;
    }
    _activeSubscriptions.add(subscription);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    stopAllListeners();
    super.dispose();
  }

  // ⭐ محسّن جداً: دالة آمنة لـ notifyListeners مع منع التكرار
  void _safeNotifyListeners() {
    if (!_isDisposed && mounted && !_isNotifying) {
      _isNotifying = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _isNotifying = false;
        if (!_isDisposed && mounted) {
          notifyListeners();
        }
      });
    }
  }

  // ⭐ محسّن: دالة للتحقق إذا كان الـ Provider mounted
  bool get mounted => !_isDisposed;

  // ⭐ محسّن: الحصول على المستخدم الحالي
  User? get currentUser => _auth.currentUser;

  // ⭐⭐ **تحميل محادثات الشغلانات (جديد)**
  Future<void> loadJobChatRooms() async {
    if (_isLoading || _isDisposed || _isAlreadyLoading) return;

    // ⭐ Debounce: منع التكرار في أقل من 5 ثواني
    if (_lastLoadTime != null &&
        DateTime.now().difference(_lastLoadTime!).inSeconds < 5) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      if (_isDisposed) return;

      _isLoading = true;
      _isAlreadyLoading = true;
      _lastLoadTime = DateTime.now();
      _error = '';
      _safeNotifyListeners();

      try {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          _error = 'يجب تسجيل الدخول أولاً';
          _isLoading = false;
          _isAlreadyLoading = false;
          _safeNotifyListeners();
          return;
        }

        // ⭐ إيقاف أي اشتراكات سابقة
        await Future.delayed(const Duration(milliseconds: 100));
        _stopAllOnlineStatusListeners();

        // ⭐ تحميل المحادثات مع Stream محسن
        final chatSubscription = _chatService.getJobChatRooms().listen(
          (chatRooms) {
            if (_isDisposed) return;

            // ⭐ منع التحديث إذا البيانات نفسها
            if (_jobChatRooms.length == chatRooms.length &&
                _jobChatRooms.every(
                  (room) => chatRooms.any((r) => r.id == room.id),
                )) {
              _isLoading = false;
              _isAlreadyLoading = false;
              return;
            }

            _jobChatRooms = chatRooms;

            // ⭐ تحديث حالة الاتصال للمستخدمين في المحادثات المرئية فقط
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!_isDisposed) {
                _updateOnlineStatusForVisibleChats();
              }
            });

            _isLoading = false;
            _isAlreadyLoading = false;
            _safeNotifyListeners();
            print('✅ تم تحميل ${chatRooms.length} محادثة شغلانات');
          },
          onError: (error) {
            if (_isDisposed) return;

            print('❌ خطأ في تحميل محادثات الشغلانات: $error');
            _error = 'فشل في تحميل محادثات الشغلانات: $error';
            _isLoading = false;
            _isAlreadyLoading = false;
            _safeNotifyListeners();
          },
        );

        addSubscription(chatSubscription);
      } catch (e) {
        if (_isDisposed) return;

        _error = 'فشل في تحميل محادثات الشغلانات: $e';
        _isLoading = false;
        _isAlreadyLoading = false;
        _safeNotifyListeners();
        if (kDebugMode) {
          print('Error loading job chat rooms: $e');
        }
      }
    });
  }

  // ⭐⭐ **تحميل محادثات السوق (جديد)**
  Future<void> loadMarketChatRooms() async {
    if (_isLoading || _isDisposed || _isAlreadyLoading) return;

    // ⭐ Debounce: منع التكرار في أقل من 5 ثواني
    if (_lastLoadTime != null &&
        DateTime.now().difference(_lastLoadTime!).inSeconds < 5) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      if (_isDisposed) return;

      _isLoading = true;
      _isAlreadyLoading = true;
      _lastLoadTime = DateTime.now();
      _error = '';
      _safeNotifyListeners();

      try {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          _error = 'يجب تسجيل الدخول أولاً';
          _isLoading = false;
          _isAlreadyLoading = false;
          _safeNotifyListeners();
          return;
        }

        // ⭐ إيقاف أي اشتراكات سابقة
        await Future.delayed(const Duration(milliseconds: 100));
        _stopAllOnlineStatusListeners();

        // ⭐ تحميل المحادثات مع Stream محسن
        final chatSubscription = _chatService.getMarketChatRooms().listen(
          (chatRooms) {
            if (_isDisposed) return;

            // ⭐ منع التحديث إذا البيانات نفسها
            if (_marketChatRooms.length == chatRooms.length &&
                _marketChatRooms.every(
                  (room) => chatRooms.any((r) => r.id == room.id),
                )) {
              _isLoading = false;
              _isAlreadyLoading = false;
              return;
            }

            _marketChatRooms = chatRooms;

            // ⭐ تحديث حالة الاتصال للمستخدمين في المحادثات المرئية فقط
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!_isDisposed) {
                _updateOnlineStatusForVisibleChats();
              }
            });

            _isLoading = false;
            _isAlreadyLoading = false;
            _safeNotifyListeners();
            print('✅ تم تحميل ${chatRooms.length} محادثة سوق');
          },
          onError: (error) {
            if (_isDisposed) return;

            print('❌ خطأ في تحميل محادثات السوق: $error');
            _error = 'فشل في تحميل محادثات السوق: $error';
            _isLoading = false;
            _isAlreadyLoading = false;
            _safeNotifyListeners();
          },
        );

        addSubscription(chatSubscription);
      } catch (e) {
        if (_isDisposed) return;

        _error = 'فشل في تحميل محادثات السوق: $e';
        _isLoading = false;
        _isAlreadyLoading = false;
        _safeNotifyListeners();
        if (kDebugMode) {
          print('Error loading market chat rooms: $e');
        }
      }
    });
  }

  // ⭐⭐ **تحميل جميع المحادثات (جديد)**
  Future<void> loadAllChatRooms() async {
    await Future.wait([loadJobChatRooms(), loadMarketChatRooms()]);
  }

  // ⭐ محسّن جداً: تحميل أسرع مع تحديث الوقت الحقيقي ومنع التكرار (قديم - للتوافق)
  Future<void> loadChatRooms() async {
    await loadJobChatRooms();
  }

  // ⭐ محسّن: دالة لتحديث حالة الاتصال للمحادثات المرئية فقط
  void _updateOnlineStatusForVisibleChats() {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _isDisposed) return;

    for (final chatRoom in [..._jobChatRooms, ..._marketChatRooms]) {
      final otherUserId = currentUser.uid == chatRoom.user1Id
          ? chatRoom.user2Id
          : chatRoom.user1Id;

      // ⭐ مراقبة حالة الاتصال للمستخدم الآخر فقط إذا كانت المحادثة مرئية
      if (_visibleChatIds.contains(chatRoom.id)) {
        _listenToUserOnlineStatus(otherUserId);
      }
    }
  }

  // ⭐ محسّن: إدارة ظهور واختفاء المحادثات
  void onChatVisible(String chatId, String otherUserId) {
    if (_isDisposed) return;

    if (!_visibleChatIds.contains(chatId)) {
      _visibleChatIds.add(chatId);
      _listenToUserOnlineStatus(otherUserId);
    }
  }

  void onChatHidden(String chatId, String otherUserId) {
    if (_isDisposed) return;

    _visibleChatIds.remove(chatId);

    // ⭐ إلغاء الاشتراك إذا لم تكن المحادثة مرئية في أي مكان آخر
    final isUserInOtherVisibleChats = [..._jobChatRooms, ..._marketChatRooms]
        .any((room) {
          final otherUserInRoom = _auth.currentUser?.uid == room.user1Id
              ? room.user2Id
              : room.user1Id;
          return otherUserInRoom == otherUserId &&
              _visibleChatIds.contains(room.id);
        });

    if (!isUserInOtherVisibleChats) {
      _onlineStatusSubscriptions[otherUserId]?.cancel();
      _onlineStatusSubscriptions.remove(otherUserId);
      _userOnlineStatus.remove(otherUserId);
    }
  }

  // ⭐ محسّن: دالة للاستماع لحالة الاتصال للمستخدم
  void _listenToUserOnlineStatus(String userId) {
    if (_isDisposed || _onlineStatusSubscriptions.containsKey(userId)) return;

    try {
      final statusSubscription = _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .handleError((error) {
            print('⚠️ خطأ في مراقبة حالة الاتصال: $error');
            // تعيين حالة افتراضية عند الخطأ
            if (!_isDisposed) {
              _userOnlineStatus[userId] = false;
              _safeNotifyListeners();
            }
          })
          .listen((userDoc) {
            if (_isDisposed) return;

            if (userDoc.exists) {
              final userData = userDoc.data();
              final isOnline = userData?['isOnline'] ?? false;

              _userOnlineStatus[userId] = isOnline;
              _safeNotifyListeners();

              print(
                '👤 حالة الاتصال للمستخدم $userId: ${isOnline ? 'متصل' : 'غير متصل'}',
              );
            }
          });

      _onlineStatusSubscriptions[userId] = statusSubscription;
    } catch (e) {
      print('⚠️ خطأ في إعداد مراقبة حالة الاتصال: $e');
      // تعيين حالة افتراضية
      if (!_isDisposed) {
        _userOnlineStatus[userId] = false;
        _safeNotifyListeners();
      }
    }
  }

  // ✅ ⭐⭐ التصحيح: دالة تحديث حالة الاتصال المحسنة
  Future<void> updateMyOnlineStatus(bool isOnline) async {
    if (_isDisposed) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('⚠️ لا يوجد مستخدم مسجل لتحديث حالة الاتصال');
        return;
      }

      print('🔄 تحديث حالة الاتصال للمستخدم: ${currentUser.uid}');

      await _chatService.updateUserOnlineStatus(isOnline);

      print('✅ تم تحديث حالة الاتصال: ${isOnline ? 'متصل' : 'غير متصل'}');
    } catch (e) {
      print('⚠️ خطأ في تحديث حالة الاتصال: $e');
      // لا ترمي استثناء هنا حتى لا يعطل التطبيق
    }
  }

  // ⭐⭐ **تعديل: دالة للتحقق من إعداد Supabase - بدون setupSupabaseForChat**
  Future<bool> checkAndSetupSupabase() async {
    try {
      final mediaService = MediaService();

      // 1. التحقق من الاتصال
      final isConnected = await mediaService.checkSupabaseConnection();
      if (!isConnected) {
        _error = 'لا يمكن الاتصال بخادم الوسائط';
        _safeNotifyListeners();
        return false;
      }

      // 2. التحقق من صلاحيات الـ Storage
      final hasAccess = await mediaService.checkSupabaseStorageAccess();
      if (!hasAccess) {
        _error = 'لا توجد صلاحيات لرفع الوسائط';
        _safeNotifyListeners();
        return false;
      }

      // 3. اختبار الرفع بدلاً من setupSupabaseForChat
      final canUpload = await mediaService.testUploadToBucket();
      if (!canUpload) {
        _error = 'فشل في اختبار رفع الملفات';
        _safeNotifyListeners();
        return false;
      }

      return true;
    } catch (e) {
      _error = 'فشل في إعداد الوسائط: $e';
      _safeNotifyListeners();
      return false;
    }
  }

  // ⭐⭐ **تعديل دالة sendMediaMessage في ChatProvider**
  Future<void> sendMediaMessage({
    required String receiverId,
    required File mediaFile,
    String? message,
    String? postId,
    String? chatType = 'job',
  }) async {
    if (_isDisposed) return;

    // ⭐⭐ **التحقق من Supabase أولاً**
    final isSupabaseReady = await checkAndSetupSupabase();
    if (!isSupabaseReady) {
      throw Exception('فشل في إعداد نظام الوسائط');
    }

    // ⭐⭐ **بقية الكود كما هو مع تحسينات**
    try {
      print('🔄 إرسال وسائط عبر ChatProvider...');

      await _chatService.sendMediaMessage(
        receiverId: receiverId,
        mediaFile: mediaFile,
        message: message,
        postId: postId,
        chatType: chatType,
      );

      // ⭐ تحديث الرسائل المحلية
      if (!_isDisposed) {
        loadChatMessages(receiverId, postId, chatType);
      }

      print('✅ تم إرسال الوسائط بنجاح');
    } catch (e) {
      print('❌ فشل في إرسال الوسائط: $e');

      if (!_isDisposed) {
        _error = 'فشل في إرسال الوسائط: $e';
        _safeNotifyListeners();
      }
      rethrow;
    }
  }

  // ⭐ محسّن جداً: دالة لتعيين الرسائل كمقروءة مع منع التكرار
  Future<void> markMessagesAsRead(
    String otherUserId, [
    String? postId,
    String? chatType,
  ]) async {
    if (_isDisposed || _currentlyMarkingAsRead.contains(otherUserId)) return;

    // ⭐ منع التكرار في أقل من 3 ثواني
    final now = DateTime.now();
    final lastTime = _lastMarkAsReadTime[otherUserId];
    if (lastTime != null && now.difference(lastTime).inSeconds < 3) {
      return;
    }

    _currentlyMarkingAsRead.add(otherUserId);
    _lastMarkAsReadTime[otherUserId] = now;

    try {
      await _chatService.markMessagesAsRead(otherUserId, postId, chatType);

      // ⭐ تحديث الحالة المحلية فوراً
      final currentUser = _auth.currentUser;
      if (currentUser != null && !_isDisposed) {
        final chatId = _chatService.generateChatId(
          currentUser.uid,
          otherUserId,
          postId,
        );

        // ⭐ التصحيح: تحديث unreadCounts محلياً باستخدام copyWith
        final allRooms = [..._jobChatRooms, ..._marketChatRooms];
        final chatIndex = allRooms.indexWhere((room) => room.id == chatId);
        if (chatIndex != -1) {
          final oldRoom = allRooms[chatIndex];
          final updatedRoom = oldRoom.copyWith(
            unreadCounts: {...oldRoom.unreadCounts, currentUser.uid: 0},
            updatedAt: DateTime.now(),
          );

          // تحديث في القائمة المناسبة
          if (oldRoom.chatType == 'product') {
            final marketIndex = _marketChatRooms.indexWhere(
              (r) => r.id == chatId,
            );
            if (marketIndex != -1) {
              _marketChatRooms[marketIndex] = updatedRoom;
            }
          } else {
            final jobIndex = _jobChatRooms.indexWhere((r) => r.id == chatId);
            if (jobIndex != -1) {
              _jobChatRooms[jobIndex] = updatedRoom;
            }
          }
        }

        // تحديث الرسائل المحلية
        if (_messages.containsKey(chatId)) {
          for (int i = 0; i < _messages[chatId]!.length; i++) {
            final message = _messages[chatId]![i];
            if (message.receiverId == currentUser.uid && !message.isRead) {
              _messages[chatId]![i] = message.copyWith(isRead: true);
            }
          }
        }

        _safeNotifyListeners();
      }
    } catch (e) {
      print('❌ خطأ في تعيين الرسائل كمقروءة: $e');
    } finally {
      _currentlyMarkingAsRead.remove(otherUserId);
    }
  }

  // ⭐ محسّن جداً: دالة لتعيين المحادثة كمقروءة مع منع التكرار
  Future<void> markChatAsRead(
    String otherUserId, [
    String? postId,
    String? chatType,
  ]) async {
    if (_isDisposed || _currentlyMarkingAsRead.contains(otherUserId)) return;

    // ⭐ منع التكرار في أقل من 3 ثواني
    final now = DateTime.now();
    final lastTime = _lastMarkAsReadTime[otherUserId];
    if (lastTime != null && now.difference(lastTime).inSeconds < 3) {
      return;
    }

    _currentlyMarkingAsRead.add(otherUserId);
    _lastMarkAsReadTime[otherUserId] = now;

    try {
      await _chatService.markChatAsRead(otherUserId, postId, chatType);

      // ⭐ تحديث محلياً باستخدام copyWith
      final currentUser = _auth.currentUser;
      if (currentUser != null && !_isDisposed) {
        final chatId = _chatService.generateChatId(
          currentUser.uid,
          otherUserId,
          postId,
        );

        final allRooms = [..._jobChatRooms, ..._marketChatRooms];
        final chatIndex = allRooms.indexWhere((room) => room.id == chatId);
        if (chatIndex != -1) {
          final oldRoom = allRooms[chatIndex];
          final updatedRoom = oldRoom.copyWith(
            unreadCounts: {...oldRoom.unreadCounts, currentUser.uid: 0},
            updatedAt: DateTime.now(),
          );

          // تحديث في القائمة المناسبة
          if (oldRoom.chatType == 'product') {
            final marketIndex = _marketChatRooms.indexWhere(
              (r) => r.id == chatId,
            );
            if (marketIndex != -1) {
              _marketChatRooms[marketIndex] = updatedRoom;
            }
          } else {
            final jobIndex = _jobChatRooms.indexWhere((r) => r.id == chatId);
            if (jobIndex != -1) {
              _jobChatRooms[jobIndex] = updatedRoom;
            }
          }

          _safeNotifyListeners();
        }
      }
    } catch (e) {
      print('⚠️ خطأ في تعيين المحادثة كمقروءة: $e');
    } finally {
      _currentlyMarkingAsRead.remove(otherUserId);
    }
  }

  // ⭐ محسّن: جلب رسائل محادثة محددة - تم التصحيح
  void loadChatMessages(
    String otherUserId, [
    String? postId,
    String? chatType,
  ]) {
    if (_isDisposed) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final subscription = _chatService
          .getChatMessages(otherUserId, postId, chatType)
          .listen(
            (messages) {
              if (_isDisposed) return;

              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (!_isDisposed) {
                  final chatId = _chatService.generateChatId(
                    currentUser.uid,
                    otherUserId,
                    postId,
                  );
                  _messages[chatId] = messages;
                  _safeNotifyListeners();
                }
              });
            },
            onError: (error) {
              print('❌ خطأ في تحميل الرسائل: $error');
            },
          );

      addSubscription(subscription);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading chat messages: $e');
      }
    }
  }

  // ⭐ جديد: دالة لاسترجاع Stream للرسائل مباشرة
  Stream<List<ChatMessage>> getChatMessagesStream(
    String otherUserId,
    String? postId,
    String? chatType,
  ) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    final collectionName = chatType == 'product' ? 'market_chats' : 'chats';
    final chatId = _chatService.generateChatId(
      currentUser.uid,
      otherUserId,
      postId,
    );

    return _firestore
        .collection(collectionName)
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList(),
        );
  }

  // ⭐ محسّن: الحصول على رسائل محادثة محددة - تم التصحيح
  List<ChatMessage> getChatMessages(String otherUserId, [String? postId]) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final chatId = _chatService.generateChatId(
      currentUser.uid,
      otherUserId,
      postId,
    );
    return _messages[chatId] ?? [];
  }

  // ⭐ جديد: إضافة رسالة مؤقتة للقائمة
  void addTempMessage(
    String otherUserId,
    ChatMessage tempMessage, [
    String? postId,
  ]) {
    if (_isDisposed) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = _chatService.generateChatId(
      currentUser.uid,
      otherUserId,
      postId,
    );

    if (!_messages.containsKey(chatId)) {
      _messages[chatId] = [];
    }

    _messages[chatId]!.insert(0, tempMessage);
    _safeNotifyListeners();
  }

  // ⭐ جديد: إزالة رسالة مؤقتة من القائمة
  void removeTempMessage(
    String otherUserId,
    String tempMessageId, [
    String? postId,
  ]) {
    if (_isDisposed) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = _chatService.generateChatId(
      currentUser.uid,
      otherUserId,
      postId,
    );

    if (_messages.containsKey(chatId)) {
      _messages[chatId]!.removeWhere((msg) => msg.id == tempMessageId);
      _safeNotifyListeners();
    }
  }

  // ⭐ محسّن: إرسال رسالة مع Error Handling محسن
  Future<void> sendMessage({
    required String receiverId,
    required String message,
    String? postId,
    bool isAvailabilityQuestion = false,
    bool isAvailabilityResponse = false,
    bool? availabilityStatus,
    String? mediaUrl,
    String? mediaType,
    String? fileName,
    int? fileSize,
    String? chatType = 'job',
  }) async {
    if (_isDisposed) return;

    try {
      await _chatService.sendMessage(
        receiverId: receiverId,
        message: message,
        postId: postId,
        isAvailabilityQuestion: isAvailabilityQuestion,
        isAvailabilityResponse: isAvailabilityResponse,
        availabilityStatus: availabilityStatus,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        fileName: fileName,
        fileSize: fileSize,
        chatType: chatType,
      );

      // تحديث الرسائل المحلية
      if (!_isDisposed) {
        loadChatMessages(receiverId, postId, chatType);
      }
    } catch (e) {
      if (!_isDisposed) {
        _error = 'فشل في إرسال الرسالة: $e';
        _safeNotifyListeners();

        // ⭐ إعادة إلقاء الخطأ لعرضه في UI
        rethrow;
      }
    }
  }

  // ⭐⭐ **التصحيح: دالة sendMediaMessageDirect المصححة**
  Future<void> sendMediaMessageDirect({
    required String receiverId,
    required File mediaFile,
    String? message,
    String? postId,
    String? chatType = 'job',
  }) async {
    try {
      print('📤 === إرسال وسائط مباشر من ChatProvider ===');
      print('👤 المستقبل: $receiverId');
      print('📁 الملف: ${mediaFile.path}');

      // ⭐⭐ **استخدام MediaService الجديدة بدون setupSupabaseForChat**
      final mediaService = MediaService();

      // ⭐⭐ **التحقق من اتصال Supabase فقط**
      final isConnected = await mediaService.checkSupabaseConnection();
      if (!isConnected) {
        throw Exception('لا يمكن الاتصال بـ Supabase');
      }

      // ⭐⭐ **اختبار الرفع**
      final canUpload = await mediaService.testUploadToBucket();
      if (!canUpload) {
        throw Exception('لا يمكن رفع الملفات إلى التخزين');
      }

      print('🔼 جاري رفع الوسائط...');
      final uploadResult = await mediaService.uploadMediaForChat(
        mediaFile: mediaFile,
      );

      if (!uploadResult['success']) {
        throw Exception('فشل في رفع الوسائط: ${uploadResult['error']}');
      }

      final String mediaUrl = uploadResult['url']!;
      final String mediaType = uploadResult['fileType']!;
      final String fileName = uploadResult['fileName']!;
      final int fileSize = uploadResult['fileSize']!;

      print('✅ تم رفع الملف بنجاح');
      print('🔗 الرابط: $mediaUrl');
      print('📊 النوع: $mediaType');
      print('📁 الاسم: $fileName');
      print('💾 الحجم: ${mediaService.formatFileSize(fileSize)}');

      // ⭐⭐ **إرسال الرسالة عبر ChatService**
      await _chatService.sendMessage(
        receiverId: receiverId,
        message:
            message ??
            (mediaType == 'image'
                ? '📸 صورة'
                : mediaType == 'video'
                ? '🎬 فيديو'
                : '📎 ملف مرفق'),
        postId: postId,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        fileName: fileName,
        fileSize: fileSize,
        chatType: chatType,
      );

      print('✅ === تم إرسال الوسائط بنجاح ===');
    } catch (e) {
      print('❌ === فشل في إرسال الوسائط ===');
      print('🚨 الخطأ: $e');
      print('📋 StackTrace: ${e.toString()}');

      if (!_isDisposed) {
        _error = 'فشل في إرسال الوسائط: ${e.toString()}';
        _safeNotifyListeners();
      }

      throw Exception('فشل في إرسال الوسائط: ${e.toString()}');
    }
  }

  // ⭐ محسّن: حذف محادثة
  Future<void> deleteChat(
    String otherUserId, [
    String? postId,
    String? chatType,
  ]) async {
    if (_isDisposed) return;

    try {
      await _chatService.deleteChat(otherUserId, postId, chatType);

      // تحديث الحالة المحلية
      final currentUser = _auth.currentUser;
      if (currentUser != null && !_isDisposed) {
        final chatId = _chatService.generateChatId(
          currentUser.uid,
          otherUserId,
          postId,
        );
        _messages.remove(chatId);

        if (chatType == 'product') {
          _marketChatRooms.removeWhere((room) => room.id == chatId);
        } else {
          _jobChatRooms.removeWhere((room) => room.id == chatId);
        }
        _safeNotifyListeners();
      }
    } catch (e) {
      if (!_isDisposed) {
        _error = 'فشل في حذف المحادثة: $e';
        _safeNotifyListeners();
      }
      rethrow;
    }
  }

  // الحصول على عدد الرسائل غير المقروءة
  int getUnreadCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 0;

    int total = 0;
    for (var room in _jobChatRooms) {
      total += room.unreadCounts[currentUser.uid] ?? 0;
    }
    for (var room in _marketChatRooms) {
      total += room.unreadCounts[currentUser.uid] ?? 0;
    }
    return total;
  }

  // الحصول على عدد الرسائل غير المقروءة لمحادثة محددة
  int getUnreadCountForChat(String otherUserId, [String? postId]) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 0;

    final chatId = _chatService.generateChatId(
      currentUser.uid,
      otherUserId,
      postId,
    );

    // ابحث في كلتا القائمتين
    ChatRoom? chatRoom = _jobChatRooms.firstWhere(
      (room) => room.id == chatId,
      orElse: () => ChatRoom(
        id: '',
        user1Id: '',
        user2Id: '',
        user1Name: '',
        user2Name: '',
        user1Image: '',
        user2Image: '',
        lastMessage: '',
        lastMessageTime: DateTime.now(),
        unreadCounts: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (chatRoom.id.isEmpty) {
      chatRoom = _marketChatRooms.firstWhere(
        (room) => room.id == chatId,
        orElse: () => ChatRoom(
          id: '',
          user1Id: '',
          user2Id: '',
          user1Name: '',
          user2Name: '',
          user1Image: '',
          user2Image: '',
          lastMessage: '',
          lastMessageTime: DateTime.now(),
          unreadCounts: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    return chatRoom.unreadCounts[currentUser.uid] ?? 0;
  }

  // ⭐ جديد: دالة إعادة التهيئة
  Future<void> reinitializeChat() async {
    if (_isDisposed) return;

    stopAllListeners();

    // إعادة تعيين جميع المتغيرات
    _jobChatRooms = [];
    _marketChatRooms = [];
    _messages = {};
    _userOnlineStatus = {};
    _error = '';
    _isLoading = false;
    _isAlreadyLoading = false;
    _visibleChatIds.clear();
    _currentlyMarkingAsRead.clear();
    _lastMarkAsReadTime.clear();

    // إعادة تحميل المحادثات بعد تأخير بسيط
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_isDisposed && mounted) {
      await loadAllChatRooms();
    }
  }

  // ⭐ جديد: التحقق من اكتمال التحميل
  bool get isChatInitialized =>
      (_jobChatRooms.isNotEmpty || _marketChatRooms.isNotEmpty) && !_isLoading;

  // مسح الأخطاء
  void clearError() {
    if (_error.isNotEmpty && !_isDisposed) {
      _error = '';
      _safeNotifyListeners();
    }
  }

  // إعادة تعيين البيانات
  void reset() {
    if (_isDisposed) return;

    _jobChatRooms = [];
    _marketChatRooms = [];
    _messages = {};
    _error = '';
    _userOnlineStatus.clear();
    _visibleChatIds.clear();
    _isAlreadyLoading = false;
    _currentlyMarkingAsRead.clear();
    _lastMarkAsReadTime.clear();
    _stopAllOnlineStatusListeners();
    _safeNotifyListeners();
  }

  // ⭐⭐ **جديد: دالة للتحقق من وجود الملفات في Supabase**
  Future<bool> checkFileExists(String fileUrl) async {
    try {
      final response = await http.head(Uri.parse(fileUrl));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ خطأ في التحقق من وجود الملف: $fileUrl - $e');
      return false;
    }
  }

  // ⭐⭐ **جديد: دالة لإصلاح روابط Supabase**
  String fixSupabaseUrl(String url) {
    if (url.contains('supabase.co/storage/v1/object/public/')) {
      return url;
    }

    // إذا كان الرابط يحتوي على اسم ملف فقط
    if (!url.contains('http')) {
      return 'https://cezhcyhaiztoqgetxehv.supabase.co/storage/v1/object/public/posts_images/chat_media/$url';
    }

    return url;
  }
}
