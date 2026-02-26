import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'package:snae3ya/models/chat_model.dart';
import 'package:snae3ya/services/media_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  // ⭐ OneSignal constants
  static const String _oneSignalAppId = "06a56c7a-1579-4cf0-997d-11982bfb1c35";
  // ⭐ ضع REST API Key الخاص بك هنا (من لوحة تحكم OneSignal)
  static const String _oneSignalRestApiKey =
      "YOUR_REST_API_KEY"; // استبدلها بالمفتاح الحقيقي

  // ⭐ دالة مساعدة لجلب playerId لمستخدم
  Future<String?> _getUserPlayerId(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['onesignalPlayerId'];
    } catch (e) {
      print('❌ خطأ في جلب playerId: $e');
      return null;
    }
  }

  // ⭐ دالة لإرسال إشعار عبر OneSignal
  Future<void> _sendOneSignalNotification({
    required String playerId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final url = Uri.parse('https://onesignal.com/api/v1/notifications');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Basic $_oneSignalRestApiKey',
    };
    final payload = {
      'app_id': _oneSignalAppId,
      'include_player_ids': [playerId],
      'headings': {'en': title},
      'contents': {'en': body},
      'data': data,
      'android_channel_id':
          'high_importance_channel', // ⭐ مهم للصوت على أندرويد
      'sound': 'default', // ⭐ صوت افتراضي
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );
      print('📤 OneSignal response status: ${response.statusCode}');
      print('📤 OneSignal response body: ${response.body}');
      if (response.statusCode == 200) {
        print('✅ تم إرسال إشعار OneSignal');
      } else {
        print('❌ فشل إرسال إشعار OneSignal: ${response.body}');
      }
    } catch (e) {
      print('❌ خطأ في إرسال إشعار OneSignal: $e');
    }
  }

  // ⭐ دالة لإرسال إشعار عند رسالة جديدة وتخزينه في Firestore
  Future<void> sendNewMessageNotification({
    required String receiverId,
    required String senderName,
    required String messagePreview,
    required String? postId,
    required String? chatType,
    required String? senderId,
  }) async {
    final playerId = await _getUserPlayerId(receiverId);
    if (playerId == null) {
      print('⚠️ لا يوجد playerId للمستقبل');
    } else {
      await _sendOneSignalNotification(
        playerId: playerId,
        title: 'رسالة جديدة',
        body: '$senderName: $messagePreview',
        data: {
          'screen': 'single-chat',
          'receiverId': senderId,
          'userName': senderName,
          'postId': postId,
          'chatType': chatType ?? 'job',
        },
      );
    }

    // ⭐ تخزين الإشعار في Firestore (لشاشة الإشعارات الداخلية)
    try {
      final notificationRef = _firestore.collection('notifications').doc();
      final notificationData = {
        'userId': receiverId,
        'senderId': senderId,
        'senderName': senderName,
        'type':
            11, // NotificationType.newMessage (حسب تعريفك في NotificationModel)
        'title': 'رسالة جديدة',
        'body': '$senderName: $messagePreview',
        'data': {'postId': postId, 'chatType': chatType, 'senderId': senderId},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'targetRoute': 'single-chat',
        'targetArguments': {
          'receiverId': senderId,
          'userName': senderName,
          'postId': postId,
          'chatType': chatType,
        },
      };
      await notificationRef.set(notificationData);
      print('✅ تم تخزين الإشعار في Firestore');
    } catch (e) {
      print('❌ فشل تخزين الإشعار في Firestore: $e');
    }
  }

  // باقي دوال ChatService (كما هي في ملفك السابق، بدون تغيير)
  // ⭐ دالة لتحديد Collection المناسبة
  String _getChatCollection(String? chatType) {
    return chatType == 'product' ? 'market_chats' : 'chats';
  }

  String generateChatId(String user1Id, String user2Id, [String? postId]) {
    final sortedIds = [user1Id, user2Id]..sort();
    if (postId != null && postId.isNotEmpty) {
      return '${sortedIds[0]}_${sortedIds[1]}_$postId';
    } else {
      return '${sortedIds[0]}_${sortedIds[1]}';
    }
  }

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
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('يجب تسجيل الدخول أولاً');

      if (message.trim().isEmpty && mediaUrl == null) {
        throw Exception('الرسالة لا يمكن أن تكون فارغة');
      }

      if (receiverId.isEmpty || receiverId == currentUser.uid) {
        throw Exception('معرف المستقبل غير صالح');
      }

      if (isAvailabilityQuestion && isAvailabilityResponse) {
        throw Exception('لا يمكن أن تكون الرسالة سؤال ورد في نفس الوقت');
      }

      final collectionName = _getChatCollection(chatType);
      final chatId = generateChatId(currentUser.uid, receiverId, postId);
      final messageRef = _firestore
          .collection(collectionName)
          .doc(chatId)
          .collection('messages')
          .doc();

      String? postImage;
      String? postTitle;
      String? finalChatType = chatType;

      if (postId != null && postId.isNotEmpty) {
        try {
          print('🔍 جاري جلب بيانات المنشور: $postId');

          if (chatType == 'product') {
            final productDoc = await _firestore
                .collection('products')
                .doc(postId)
                .get();

            if (productDoc.exists) {
              final productData = productDoc.data();
              final images = productData?['imageUrls'] ?? [];
              if (images is List && images.isNotEmpty) {
                final firstImage = images[0];
                if (firstImage is String && firstImage.isNotEmpty) {
                  postImage = firstImage;
                }
              }
              postTitle = productData?['title'] ?? 'منتج';
              finalChatType = 'product';

              if (postImage == null || postImage!.isEmpty) {
                postImage = 'assets/images/default_product.png';
              }

              print('✅ تم جلب صورة المنتج: $postImage');
              print('📝 عنوان المنتج: $postTitle');
            }
          } else {
            final postDoc = await _firestore
                .collection('posts')
                .doc(postId)
                .get();

            if (postDoc.exists) {
              final postData = postDoc.data();
              final images = postData?['images'] ?? [];
              if (images is List && images.isNotEmpty) {
                final firstImage = images[0];
                if (firstImage is String && firstImage.isNotEmpty) {
                  postImage = firstImage;
                }
              }
              postTitle = postData?['title'] ?? 'شغلانة';
              finalChatType = 'job';

              if (postImage == null || postImage!.isEmpty) {
                postImage =
                    postData?['imageUrl'] ??
                    postData?['image'] ??
                    postData?['postImage'] ??
                    'assets/images/default_job_1.png';
              }

              print('✅ تم جلب صورة الشغلانة: $postImage');
              print('📝 عنوان الشغلانة: $postTitle');
            } else {
              postImage = 'assets/images/default_job_1.png';
              postTitle = 'شغلانة';
            }
          }
        } catch (e) {
          print('⚠️ خطأ في جلب بيانات المنشور: $e');
          postImage = chatType == 'product'
              ? 'assets/images/default_product.png'
              : 'assets/images/default_job_1.png';
          postTitle = chatType == 'product' ? 'منتج' : 'شغلانة';
        }
      }

      await _firestore.runTransaction((transaction) async {
        final chatRef = _firestore.collection(collectionName).doc(chatId);
        final chatDoc = await transaction.get(chatRef);

        final currentUserData = await _getUserData(currentUser.uid);
        final receiverUserData = await _getUserData(receiverId);

        final chatMessage = ChatMessage(
          id: messageRef.id,
          senderId: currentUser.uid,
          receiverId: receiverId,
          message: message.trim(),
          timestamp: DateTime.now(),
          isRead: false,
          postId: postId,
          isAvailabilityQuestion: isAvailabilityQuestion,
          isAvailabilityResponse: isAvailabilityResponse,
          availabilityStatus: availabilityStatus,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          fileName: fileName,
          fileSize: fileSize,
        );

        transaction.set(messageRef, chatMessage.toFirestore());

        if (!chatDoc.exists) {
          transaction.set(chatRef, {
            'user1Id': currentUser.uid,
            'user2Id': receiverId,
            'user1Name': currentUserData['name'] ?? 'مستخدم',
            'user2Name': receiverUserData['name'] ?? 'مستخدم',
            'user1Image':
                currentUserData['profileImage'] ??
                'assets/images/default_profile.png',
            'user2Image':
                receiverUserData['profileImage'] ??
                'assets/images/default_profile.png',
            'unreadCounts': {currentUser.uid: 0, receiverId: 1},
            'lastMessage': message.trim(),
            'lastMessageTime': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'postId': postId,
            'postImage': postImage,
            'postTitle': postTitle,
            'chatType': finalChatType,
          });

          print('✅ تم إنشاء محادثة جديدة في $collectionName: $chatId');
          print('📌 postId: $postId');
          print('🖼️ postImage: $postImage');
          print('🏷️ postTitle: $postTitle');
          print('📁 chatType: $finalChatType');
        } else {
          transaction.update(chatRef, {
            'lastMessage': message.trim(),
            'lastMessageTime': FieldValue.serverTimestamp(),
            'unreadCounts.$receiverId': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final existingData = chatDoc.data() as Map<String, dynamic>;
          final existingPostId = existingData['postId'];
          if (postId != null && postId != existingPostId) {
            transaction.update(chatRef, {
              'postId': postId,
              'postImage': postImage,
              'postTitle': postTitle,
              'chatType': finalChatType,
            });
            print('🔄 تم تحديث صورة المنشور للمحادثة الموجودة');
          }

          print('✅ تم تحديث المحادثة الموجودة في $collectionName: $chatId');
        }
      });

      print('✅ تم إرسال الرسالة بنجاح');
      print('👤 المرسل: ${currentUser.uid}');
      print('👥 المستقبل: $receiverId');
      print('📝 الرسالة: ${message.trim()}');
      print('🆔 معرف المحادثة: $chatId');
      print('📌 معرف المنشور: $postId');
      print('🖼️ صورة المنشور: $postImage');
      print('🏷️ عنوان المنشور: $postTitle');
      print('🔗 رابط الوسائط: $mediaUrl');
      print('📊 نوع الوسائط: $mediaType');
      print('📁 نوع المحادثة: $finalChatType');
      print('📁 Collection: $collectionName');
    } catch (e) {
      print('❌ فشل في إرسال الرسالة: $e');
      throw Exception('فشل في إرسال الرسالة: $e');
    }
  }

  Future<void> sendMediaMessage({
    required String receiverId,
    required File mediaFile,
    String? message,
    String? postId,
    String? chatType = 'job',
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('يجب تسجيل الدخول أولاً');

      print('📤 === بدء إرسال وسائط ===');
      print('👤 المرسل: ${currentUser.uid}');
      print('👥 المستقبل: $receiverId');
      print('📁 الملف: ${mediaFile.path}');

      final mediaService = MediaService();

      final isConnected = await mediaService.checkSupabaseConnection();
      if (!isConnected) {
        throw Exception('لا يمكن الاتصال بـ Supabase. تحقق من اتصال الإنترنت.');
      }

      final canUpload = await mediaService.testUploadToBucket();
      if (!canUpload) {
        throw Exception('''
❌ لا يمكن رفع الملفات إلى Supabase Storage
💡 تأكد من:
1. وجود bucket باسم "posts_images" في Supabase Dashboard
2. وجود مجلد "posts" داخل الـ bucket
3. إعدادات RLS Policies تسمح بالرفع
''');
      }

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

      await sendMessage(
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

      throw Exception('فشل في إرسال الملف: ${e.toString()}');
    }
  }

  Future<void> sendImageMessage({
    required String receiverId,
    String? message,
    String? postId,
    String? chatType = 'job',
  }) async {
    try {
      final mediaService = MediaService();
      final File? imageFile = await mediaService.pickImageFromGallery();

      if (imageFile != null) {
        await sendMediaMessage(
          receiverId: receiverId,
          mediaFile: imageFile,
          message: message ?? '📸 صورة',
          postId: postId,
          chatType: chatType,
        );
      } else {
        throw Exception('لم يتم اختيار صورة');
      }
    } catch (e) {
      print('❌ فشل في إرسال الصورة: $e');
      throw Exception('فشل في إرسال الصورة: ${e.toString()}');
    }
  }

  Future<void> sendVideoMessage({
    required String receiverId,
    String? message,
    String? postId,
    String? chatType = 'job',
  }) async {
    try {
      final mediaService = MediaService();
      final File? videoFile = await mediaService.pickVideoFromGallery();

      if (videoFile != null) {
        await sendMediaMessage(
          receiverId: receiverId,
          mediaFile: videoFile,
          message: message ?? '🎬 فيديو',
          postId: postId,
          chatType: chatType,
        );
      } else {
        throw Exception('لم يتم اختيار فيديو');
      }
    } catch (e) {
      print('❌ فشل في إرسال الفيديو: $e');
      throw Exception('فشل في إرسال الفيديو: ${e.toString()}');
    }
  }

  Future<void> sendFileMessage({
    required String receiverId,
    String? message,
    String? postId,
    String? chatType = 'job',
  }) async {
    try {
      final mediaService = MediaService();
      final File? file = await mediaService.pickFileFromDevice();

      if (file != null) {
        await sendMediaMessage(
          receiverId: receiverId,
          mediaFile: file,
          message: message ?? '📎 ملف مرفق',
          postId: postId,
          chatType: chatType,
        );
      } else {
        throw Exception('لم يتم اختيار ملف');
      }
    } catch (e) {
      print('❌ فشل في إرسال الملف: $e');
      throw Exception('فشل في إرسال الملف: ${e.toString()}');
    }
  }

  Future<void> testMediaSystem() async {
    try {
      print('🧪 === اختبار نظام الوسائط بالكامل ===');

      final mediaService = MediaService();
      await mediaService.testCompleteSystem();

      print('🎉 === اختبار النظام ناجح ===');
    } catch (e) {
      print('❌ === اختبار النظام فشل ===');
      print('🚨 الخطأ: $e');
      throw Exception('فشل في اختبار النظام: $e');
    }
  }

  Stream<List<ChatRoom>> getJobChatRooms() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('❌ لا يوجد مستخدم مسجل دخول');
      return const Stream.empty();
    }

    print('🔍 جاري تحميل محادثات الشغلانات للمستخدم: ${currentUser.uid}');

    final Stream<List<ChatRoom>> user1Stream = _firestore
        .collection('chats')
        .where('user1Id', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatRoom.fromFirestore).toList());

    final Stream<List<ChatRoom>> user2Stream = _firestore
        .collection('chats')
        .where('user2Id', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatRoom.fromFirestore).toList());

    return Rx.combineLatest2<List<ChatRoom>, List<ChatRoom>, List<ChatRoom>>(
      user1Stream,
      user2Stream,
      (List<ChatRoom> user1Chats, List<ChatRoom> user2Chats) {
        final allChats = [...user1Chats, ...user2Chats];
        allChats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        print('✅ تم تحميل ${allChats.length} محادثة شغلانات');
        return allChats;
      },
    );
  }

  Stream<List<ChatRoom>> getMarketChatRooms() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('❌ لا يوجد مستخدم مسجل دخول');
      return const Stream.empty();
    }

    print('🔍 جاري تحميل محادثات السوق للمستخدم: ${currentUser.uid}');

    final Stream<List<ChatRoom>> user1Stream = _firestore
        .collection('market_chats')
        .where('user1Id', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatRoom.fromFirestore).toList());

    final Stream<List<ChatRoom>> user2Stream = _firestore
        .collection('market_chats')
        .where('user2Id', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatRoom.fromFirestore).toList());

    return Rx.combineLatest2<List<ChatRoom>, List<ChatRoom>, List<ChatRoom>>(
      user1Stream,
      user2Stream,
      (List<ChatRoom> user1Chats, List<ChatRoom> user2Chats) {
        final allChats = [...user1Chats, ...user2Chats];
        allChats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        print('✅ تم تحميل ${allChats.length} محادثة سوق');
        return allChats;
      },
    );
  }

  Stream<List<ChatMessage>> getChatMessages(
    String otherUserId,
    String? postId,
    String? chatType,
  ) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('❌ لا يوجد مستخدم مسجل دخول');
      return const Stream.empty();
    }

    final collectionName = _getChatCollection(chatType);
    final chatId = generateChatId(currentUser.uid, otherUserId, postId);
    print('🔍 جاري تحميل رسائل المحادثة من $collectionName: $chatId');

    return _firestore
        .collection(collectionName)
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList();
          print('✅ تم تحميل ${messages.length} رسالة للمحادثة: $chatId');
          return messages;
        });
  }

  Future<void> markMessagesAsRead(
    String otherUserId,
    String? postId,
    String? chatType,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final collectionName = _getChatCollection(chatType);
      final chatId = generateChatId(currentUser.uid, otherUserId, postId);

      await Future.wait([
        _updateMessagesReadStatus(collectionName, chatId, currentUser.uid),
        _updateChatRoomReadStatus(collectionName, chatId, currentUser.uid),
      ]);

      print('✅ تم تعيين جميع الرسائل كمقروءة للمحادثة: $chatId');
    } catch (e) {
      print('❌ فشل في تعيين الرسائل كمقروءة: $e');
    }
  }

  Future<void> _updateMessagesReadStatus(
    String collectionName,
    String chatId,
    String userId,
  ) async {
    final messagesSnapshot = await _firestore
        .collection(collectionName)
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    if (messagesSnapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in messagesSnapshot.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    print('✅ تم تحديث ${messagesSnapshot.docs.length} رسالة كمقروءة');
  }

  Future<void> _updateChatRoomReadStatus(
    String collectionName,
    String chatId,
    String userId,
  ) async {
    await _firestore.collection(collectionName).doc(chatId).update({
      'unreadCounts.$userId': 0,
      'lastReadBy_$userId': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    print('✅ تم تحديث unreadCount للمستخدم: $userId');
  }

  Future<void> markChatAsRead(
    String otherUserId,
    String? postId,
    String? chatType,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final collectionName = _getChatCollection(chatType);
      final chatId = generateChatId(currentUser.uid, otherUserId, postId);

      await _firestore.collection(collectionName).doc(chatId).update({
        'unreadCounts.${currentUser.uid}': 0,
        'lastReadBy_${currentUser.uid}': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ تم تعيين المحادثة كمقروءة: $chatId');
    } catch (e) {
      print('❌ فشل في تعيين المحادثة كمقروءة: $e');
    }
  }

  Future<void> updateMessage(
    String chatId,
    String messageId,
    String newMessage,
  ) async {
    try {
      if (newMessage.trim().isEmpty) {
        throw Exception('الرسالة لا يمكن أن تكون فارغة');
      }

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
            'message': newMessage.trim(),
            'isEdited': true,
            'editedAt': FieldValue.serverTimestamp(),
          });

      print('✅ تم تعديل الرسالة: $messageId');
    } catch (e) {
      print('❌ فشل في تعديل الرسالة: $e');
      throw Exception('فشل في تعديل الرسالة: $e');
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();

      print('✅ تم حذف الرسالة: $messageId');
    } catch (e) {
      print('❌ فشل في حذف الرسالة: $e');
      throw Exception('فشل في حذف الرسالة: $e');
    }
  }

  Future<void> deleteChat(
    String otherUserId,
    String? postId,
    String? chatType,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final collectionName = _getChatCollection(chatType);
      final chatId = generateChatId(currentUser.uid, otherUserId, postId);

      final messagesSnapshot = await _firestore
          .collection(collectionName)
          .doc(chatId)
          .collection('messages')
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      await _firestore.collection(collectionName).doc(chatId).delete();

      print('✅ تم حذف المحادثة بنجاح: $chatId');
    } catch (e) {
      print('❌ فشل في حذف المحادثة: $e');
      throw Exception('فشل في حذف المحادثة: $e');
    }
  }

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      print('🔍 جاري جلب بيانات المستخدم: $userId');
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        print('✅ تم جلب بيانات المستخدم: ${data['name'] ?? 'غير معروف'}');
        return data;
      } else {
        print('⚠️ المستخدم غير موجود في قاعدة البيانات: $userId');
        return {
          'name': 'مستخدم',
          'profileImage': 'assets/images/default_profile.png',
        };
      }
    } catch (e) {
      print('❌ فشل في جلب بيانات المستخدم: $e');
      return {
        'name': 'مستخدم',
        'profileImage': 'assets/images/default_profile.png',
      };
    }
  }

  Future<bool> doesChatExist(
    String user1Id,
    String user2Id, [
    String? postId,
    String? chatType,
  ]) async {
    final collectionName = _getChatCollection(chatType);
    final chatId = generateChatId(user1Id, user2Id, postId);
    final doc = await _firestore.collection(collectionName).doc(chatId).get();
    return doc.exists;
  }

  Future<void> updateUserOnlineStatus(bool isOnline) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('users').doc(currentUser.uid).set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ تم تحديث حالة الاتصال: ${isOnline ? 'متصل' : 'غير متصل'}');
    } catch (e) {
      print('❌ خطأ في تحديث حالة الاتصال: $e');
    }
  }

  Stream<DocumentSnapshot?> getLastMessageStream(
    String chatId,
    String? chatType,
  ) {
    final collectionName = _getChatCollection(chatType);
    return _firestore
        .collection(collectionName)
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null,
        );
  }

  Future<Map<String, dynamic>> getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data() ?? {};
      }
      return {};
    } catch (e) {
      print('❌ خطأ في جلب بيانات المستخدم: $e');
      return {};
    }
  }

  Future<void> debugChatRoom(String chatId, String? chatType) async {
    try {
      final collectionName = _getChatCollection(chatType);
      print('🐛 === تصحيح غرفة المحادثة في $collectionName ===');

      final chatDoc = await _firestore
          .collection(collectionName)
          .doc(chatId)
          .get();
      print('🔄 حالة الغرفة: ${chatDoc.exists ? 'موجودة' : 'غير موجودة'}');

      if (chatDoc.exists) {
        final data = chatDoc.data();
        print('📊 بيانات الغرفة:');
        print('   👤 user1: ${data?['user1Name']} (${data?['user1Id']})');
        print('   👤 user2: ${data?['user2Name']} (${data?['user2Id']})');
        print('   💬 آخر رسالة: ${data?['lastMessage']}');
        print('   🔢 unreadCounts: ${data?['unreadCounts']}');
        print('   📌 postId: ${data?['postId']}');
        print('   🖼️ postImage: ${data?['postImage']}');
        print('   🏷️ postTitle: ${data?['postTitle']}');
        print('   📁 chatType: ${data?['chatType']}');
      } else {
        print('❌ غرفة المحادثة غير موجودة في قاعدة البيانات');
      }

      final messagesSnapshot = await _firestore
          .collection(collectionName)
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      print('💬 عدد الرسائل: ${messagesSnapshot.docs.length}');

      for (var doc in messagesSnapshot.docs) {
        final messageData = doc.data();
        print('   📨 ${messageData['senderId']}: ${messageData['message']}');
      }

      print('🐛 === انتهاء التصحيح ===');
    } catch (e) {
      print('❌ فشل في تصحيح المحادثة: $e');
    }
  }

  Future<void> enableOfflinePersistence() async {
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      print('✅ تم تفعيل Offline Persistence');
    } catch (e) {
      print(
        '⚠️ ملاحظة: Offline Persistence مفعل تلقائياً في الإصدارات الحديثة',
      );
    }
  }

  Future<String?> getPostImage(String postId) async {
    try {
      if (postId.isEmpty) return null;

      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final postData = postDoc.data();
        final images = postData?['images'] ?? [];
        if (images is List && images.isNotEmpty) {
          final firstImage = images[0];
          if (firstImage is String && firstImage.isNotEmpty) {
            return firstImage;
          }
        }

        return postData?['imageUrl'] ??
            postData?['image'] ??
            postData?['postImage'];
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب صورة المنشور: $e');
      return null;
    }
  }

  Stream<List<ChatRoom>> getChatRooms() {
    return getJobChatRooms();
  }
}
