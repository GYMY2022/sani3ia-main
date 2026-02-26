import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:snae3ya/models/notification_model.dart';
import 'package:snae3ya/models/post_model.dart';
import 'package:snae3ya/models/product_model.dart';

class NotificationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ⭐ بيانات OneSignal – استبدلها بقيم حسابك
  static const String _oneSignalAppId = 'YOUR_ONESIGNAL_APP_ID';
  static const String _oneSignalApiKey =
      'YOUR_ONESIGNAL_API_KEY'; // Rest API Key

  // ==================== إشعارات الشغلانات (نفس الدوال السابقة) ====================

  static Future<void> sendNewJobApplicationNotification({
    required String postOwnerId,
    required String applicantId,
    required String applicantName,
    required String postTitle,
    required String postId,
    String? applicantImage,
  }) async {
    await _createNotification(
      userId: postOwnerId,
      senderId: applicantId,
      senderName: applicantName,
      senderImage: applicantImage,
      type: NotificationType.newJobApplication,
      title: 'تقديم جديد على شغلانة',
      body: 'قام $applicantName بالتقديم على شغلانتك "$postTitle"',
      data: {'postId': postId, 'applicantId': applicantId},
      targetRoute: '/single-chat',
      targetArguments: {
        'receiverId': applicantId,
        'userName': applicantName,
        'userImage': applicantImage ?? 'assets/images/default_profile.png',
        'postId': postId,
        'chatType': 'job',
        'isOnline': false,
      },
    );
  }

  static Future<void> sendJobApplicationAcceptedNotification({
    required String applicantId,
    required String postOwnerName,
    required String postTitle,
    required String postId,
    String? postOwnerImage,
  }) async {
    await _createNotification(
      userId: applicantId,
      senderId: null,
      senderName: postOwnerName,
      senderImage: postOwnerImage,
      type: NotificationType.jobApplicationAccepted,
      title: 'تم قبول طلبك',
      body: 'تم قبول طلبك في شغلانة "$postTitle"',
      data: {'postId': postId},
      targetRoute: '/single-chat',
      targetArguments: {
        'receiverId': await _getOwnerIdFromPost(postId),
        'userName': postOwnerName,
        'userImage': postOwnerImage ?? 'assets/images/default_profile.png',
        'postId': postId,
        'chatType': 'job',
        'isOnline': false,
      },
    );
  }

  static Future<void> sendJobApplicationRejectedNotification({
    required String applicantId,
    required String postOwnerName,
    required String postTitle,
    required String postId,
  }) async {
    await _createNotification(
      userId: applicantId,
      senderId: null,
      senderName: postOwnerName,
      type: NotificationType.jobApplicationRejected,
      title: 'تم رفض طلبك',
      body: 'للأسف، تم رفض طلبك في شغلانة "$postTitle"',
      data: {'postId': postId},
      targetRoute: '/post-details',
      targetArguments: {'postId': postId},
    );
  }

  static Future<void> sendNewJobPostedNotification({required Post post}) async {
    final snapshot = await _firestore
        .collection('users')
        .where('profession', isEqualTo: post.category)
        .get();

    for (var doc in snapshot.docs) {
      final userId = doc.id;
      if (userId == post.authorId) continue;

      await _createNotification(
        userId: userId,
        senderId: post.authorId,
        senderName: post.authorName,
        senderImage: post.authorImage,
        type: NotificationType.newJobPosted,
        title: 'شغلانة جديدة في تخصصك',
        body: 'شغلانة "${post.title}" متاحة الآن في تخصص ${post.category}',
        data: {'postId': post.id},
        targetRoute: '/post-details',
        targetArguments: {'postId': post.id},
      );
    }
  }

  static Future<void> sendJobAgreedNotification({
    required String postId,
    required String postTitle,
    required String clientId,
    required String clientName,
    required String workerId,
    required String workerName,
    String? clientImage,
    String? workerImage,
  }) async {
    await _createNotification(
      userId: clientId,
      senderId: workerId,
      senderName: workerName,
      senderImage: workerImage,
      type: NotificationType.jobAgreed,
      title: 'تم الاتفاق على الشغلانة',
      body: 'تم الاتفاق مع $workerName على تنفيذ "${postTitle}"',
      data: {'postId': postId, 'workerId': workerId},
      targetRoute: '/single-chat',
      targetArguments: {
        'receiverId': workerId,
        'userName': workerName,
        'userImage': workerImage ?? 'assets/images/default_profile.png',
        'postId': postId,
        'chatType': 'job',
        'isOnline': false,
      },
    );

    await _createNotification(
      userId: workerId,
      senderId: clientId,
      senderName: clientName,
      senderImage: clientImage,
      type: NotificationType.jobAgreed,
      title: 'تم الاتفاق على الشغلانة',
      body: 'تم الاتفاق مع $clientName على تنفيذ "${postTitle}"',
      data: {'postId': postId, 'clientId': clientId},
      targetRoute: '/single-chat',
      targetArguments: {
        'receiverId': clientId,
        'userName': clientName,
        'userImage': clientImage ?? 'assets/images/default_profile.png',
        'postId': postId,
        'chatType': 'job',
        'isOnline': false,
      },
    );
  }

  static Future<void> sendJobCompletedNotification({
    required String clientId,
    required String workerName,
    required String postTitle,
    required String postId,
    String? workerImage,
  }) async {
    await _createNotification(
      userId: clientId,
      senderId: null,
      senderName: workerName,
      senderImage: workerImage,
      type: NotificationType.jobCompleted,
      title: 'تم إنجاز الشغلانة',
      body: 'قام $workerName بإنجاز "${postTitle}"، يرجى تقييم العمل',
      data: {'postId': postId},
      targetRoute: '/post-details',
      targetArguments: {'postId': postId},
    );
  }

  // ==================== إشعارات المنتجات (نفس الدوال السابقة) ====================

  static Future<void> sendNewProductQueryNotification({
    required String sellerId,
    required String buyerId,
    required String buyerName,
    required String productTitle,
    required String productId,
    String? buyerImage,
  }) async {
    await _createNotification(
      userId: sellerId,
      senderId: buyerId,
      senderName: buyerName,
      senderImage: buyerImage,
      type: NotificationType.newProductQuery,
      title: 'استفسار جديد على منتج',
      body: 'قام $buyerName بالاستفسار عن منتجك "$productTitle"',
      data: {'productId': productId, 'buyerId': buyerId},
      targetRoute: '/single-chat',
      targetArguments: {
        'receiverId': buyerId,
        'userName': buyerName,
        'userImage': buyerImage ?? 'assets/images/default_profile.png',
        'postId': productId,
        'chatType': 'product',
        'isOnline': false,
      },
    );
  }

  static Future<void> sendProductQueryResponseNotification({
    required String buyerId,
    required String sellerName,
    required String productTitle,
    required String productId,
    required bool isAvailable,
    String? sellerImage,
    String? sellerId,
  }) async {
    await _createNotification(
      userId: buyerId,
      senderId: sellerId,
      senderName: sellerName,
      senderImage: sellerImage,
      type: NotificationType.productQueryResponse,
      title: isAvailable ? 'المنتج متوفر ✅' : 'المنتج غير متوفر ❌',
      body: isAvailable
          ? 'البائع $sellerName أكد أن منتج "$productTitle" متوفر'
          : 'للأسف، البائع $sellerName أكد أن منتج "$productTitle" غير متوفر حالياً',
      data: {'productId': productId, 'isAvailable': isAvailable},
      targetRoute: '/single-chat',
      targetArguments: {
        'receiverId': sellerId,
        'userName': sellerName,
        'userImage': sellerImage ?? 'assets/images/default_profile.png',
        'postId': productId,
        'chatType': 'product',
        'isOnline': false,
      },
    );
  }

  static Future<void> sendProductSoldNotification({
    required String? buyerId,
    required String sellerName,
    required String productTitle,
    required String productId,
  }) async {
    if (buyerId == null) return;
    await _createNotification(
      userId: buyerId,
      senderId: null,
      senderName: sellerName,
      type: NotificationType.productSold,
      title: 'تم بيع المنتج',
      body: 'المنتج "$productTitle" الذي استفسرت عنه تم بيعه',
      data: {'productId': productId},
      targetRoute: '/product',
      targetArguments: {'productId': productId},
    );
  }

  static Future<void> sendNewProductAddedNotification({
    required Product product,
    required List<String> interestedUserIds,
  }) async {
    for (var userId in interestedUserIds) {
      if (userId == product.sellerId) continue;
      await _createNotification(
        userId: userId,
        senderId: product.sellerId,
        senderName: product.sellerName,
        senderImage: product.sellerImage,
        type: NotificationType.newProductAdded,
        title: 'منتج جديد في ${product.category}',
        body: 'تم إضافة "${product.title}" بواسطة ${product.sellerName}',
        data: {'productId': product.id},
        targetRoute: '/product',
        targetArguments: {'productId': product.id},
      );
    }
  }

  // ==================== إشعارات المحادثات ====================

  static Future<void> sendNewMessageNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String messagePreview,
    String? postId,
    String? chatType,
    String? senderImage,
  }) async {
    await _createNotification(
      userId: receiverId,
      senderId: senderId,
      senderName: senderName,
      senderImage: senderImage,
      type: NotificationType.newMessage,
      title: 'رسالة جديدة',
      body: '$senderName: $messagePreview',
      data: {'postId': postId, 'chatType': chatType, 'senderId': senderId},
      targetRoute: '/single-chat',
      targetArguments: {
        'receiverId': senderId,
        'userName': senderName,
        'userImage': senderImage ?? 'assets/images/default_profile.png',
        'postId': postId,
        'chatType': chatType ?? 'job',
        'isOnline': false,
      },
    );
  }

  // ==================== إشعارات التقييمات ====================

  static Future<void> sendNewReviewNotification({
    required String workerId,
    required String clientName,
    required double rating,
    required String postTitle,
    String? clientImage,
  }) async {
    await _createNotification(
      userId: workerId,
      senderId: null,
      senderName: clientName,
      senderImage: clientImage,
      type: NotificationType.newReview,
      title: 'تقييم جديد',
      body: 'قام $clientName بتقييمك ${rating} نجوم على "${postTitle}"',
      data: {'rating': rating, 'workerId': workerId},
      targetRoute: '/worker-profile',
      targetArguments: {'workerId': workerId},
    );
  }

  // ==================== إشعارات النظام ====================

  static Future<void> sendAppUpdateNotification({
    required String version,
    required String changelog,
    required bool forceUpdate,
  }) async {
    final usersSnapshot = await _firestore.collection('users').get();
    for (var doc in usersSnapshot.docs) {
      await _createNotification(
        userId: doc.id,
        type: NotificationType.appUpdate,
        title: 'تحديث جديد للتطبيق 🚀',
        body: forceUpdate
            ? 'تحديث إجباري: يرجى تحديث التطبيق إلى الإصدار $version للاستمرار'
            : 'تحديث جديد $version متاح الآن: $changelog',
        data: {'version': version, 'forceUpdate': forceUpdate},
        targetRoute: '/settings',
        targetArguments: {'showUpdate': true},
        isSystemWide: true,
      );
    }
  }

  static Future<void> sendSystemNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? targetRoute,
    Map<String, dynamic>? targetArguments,
  }) async {
    final usersSnapshot = await _firestore.collection('users').get();
    for (var doc in usersSnapshot.docs) {
      await _createNotification(
        userId: doc.id,
        type: NotificationType.system,
        title: title,
        body: body,
        data: data,
        targetRoute: targetRoute ?? '/home',
        targetArguments: targetArguments,
        isSystemWide: true,
      );
    }
  }

  // ==================== الدالة الأساسية لإنشاء الإشعار ====================

  static Future<void> _createNotification({
    required String userId,
    String? senderId,
    String? senderName,
    String? senderImage,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? targetRoute,
    Map<String, dynamic>? targetArguments,
    bool isSystemWide = false,
  }) async {
    try {
      final notification = NotificationModel(
        id: '',
        userId: userId,
        senderId: senderId,
        senderName: senderName,
        senderImage: senderImage,
        type: type,
        title: title,
        body: body,
        data: data,
        createdAt: DateTime.now(),
        targetRoute: targetRoute,
        targetArguments: targetArguments,
        isSystemWide: isSystemWide,
      );

      await _firestore
          .collection('notifications')
          .add(notification.toFirestore());
      print('✅ تم إضافة إشعار إلى Firestore للمستخدم $userId');

      // ⭐ إرسال Push Notification عبر OneSignal
      await _sendPushViaOneSignal(
        userId: userId,
        title: title,
        body: body,
        data: {
          ...?data,
          'type': type.index,
          'targetRoute': targetRoute,
          'targetArguments': targetArguments != null
              ? jsonEncode(targetArguments)
              : null,
        },
      );
    } catch (e) {
      print('❌ فشل في إرسال الإشعار: $e');
    }
  }

  // ⭐ دالة لإرسال Push Notification عبر OneSignal
  static Future<void> _sendPushViaOneSignal({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // جلب الـ playerId الخاص بالمستخدم من Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final playerId = userDoc.data()?['onesignalPlayerId'];

      if (playerId == null) {
        print('⚠️ لا يوجد playerId للمستخدم $userId');
        return;
      }

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_oneSignalApiKey',
        },
        body: jsonEncode({
          'app_id': _oneSignalAppId,
          'include_player_ids': [playerId],
          'headings': {'en': title, 'ar': title},
          'contents': {'en': body, 'ar': body},
          'data': data,
          'android_channel_id': 'high_importance_channel',
          'sound': 'default',
          'priority': 10,
        }),
      );

      if (response.statusCode == 200) {
        print('📱 تم إرسال Push Notification للمستخدم $userId عبر OneSignal');
      } else {
        print('❌ فشل OneSignal: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ خطأ في استدعاء OneSignal: $e');
    }
  }

  // دالة مساعدة لجلب id صاحب الشغلانة
  static Future<String> _getOwnerIdFromPost(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists) {
        return doc.data()?['authorId'] ?? '';
      }
    } catch (e) {
      print('⚠️ خطأ في جلب ownerId: $e');
    }
    return '';
  }
}
