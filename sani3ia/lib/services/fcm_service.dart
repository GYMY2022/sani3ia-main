import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http; // ⭐ لإرسال HTTP requests
import 'notification_service.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ⭐ Server key من Firebase Console (مهم جداً لإرسال الإشعارات)
  static const String _serverKey =
      'YOUR_SERVER_KEY_HERE'; // ⭐ ضع الـ Server Key هنا

  static Map<String, dynamic>? _lastNotificationData;

  static Map<String, dynamic>? getLastNotificationData() =>
      _lastNotificationData;
  static void clearLastNotificationData() => _lastNotificationData = null;

  Future<void> initialize() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('⚠️ لم يتم منح إذن الإشعارات');
      return;
    }

    print('✅ تم منح إذن الإشعارات');

    String? token = await _firebaseMessaging.getToken();
    if (token != null) await _saveTokenToFirestore(token);

    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);
    _setupMessageHandlers();
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ تم حفظ FCM token للمستخدم: ${user.uid}');
    } catch (e) {
      print('❌ فشل في حفظ FCM token: $e');
    }
  }

  Future<void> removeToken() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmTokens': FieldValue.arrayRemove([token]),
        }, SetOptions(merge: true));
        print('✅ تم إزالة FCM token');
      }
    } catch (e) {
      print('❌ فشل في إزالة FCM token: $e');
    }
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    FirebaseMessaging.instance.getInitialMessage().then(
      _handleMessageOpenedApp,
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📩 إشعار في المقدمة: ${message.messageId}');
    print('   العنوان: ${message.notification?.title}');
    print('   المحتوى: ${message.notification?.body}');
    print('   البيانات: ${message.data}');

    _showLocalNotification(message);
  }

  void _handleMessageOpenedApp(RemoteMessage? message) {
    if (message == null) return;
    print('📱 فتح التطبيق من إشعار: ${message.messageId}');
    print('   البيانات: ${message.data}');
    _lastNotificationData = message.data;
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notificationService = NotificationService();
    await notificationService.showNotification(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: message.notification?.title ?? 'إشعار جديد',
      body: message.notification?.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  // ⭐ دالة جديدة لإرسال Push Notification عبر FCM HTTP API
  static Future<void> sendPushNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode({
          'to': token,
          'notification': {
            'title': title,
            'body': body,
            'sound':
                'default', // ⭐ يمكن تغييره إلى اسم ملف صوتي مخصص (مثل 'notification.mp3')
            'android_channel_id':
                'high_importance_channel', // مهم لتحديد القناة
          },
          'data': {'click_action': 'FLUTTER_NOTIFICATION_CLICK', ...data},
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        print('✅ تم إرسال FCM بنجاح إلى token: $token');
      } else {
        print('❌ فشل إرسال FCM: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ خطأ في إرسال FCM: $e');
    }
  }
}
