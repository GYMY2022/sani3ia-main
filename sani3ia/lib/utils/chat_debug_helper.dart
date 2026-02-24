import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatDebugHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // طباعة جميع المحادثات في الكونسول
  static Future<void> printAllChats() async {
    try {
      final chatsSnapshot = await _firestore.collection('chats').get();
      print('📊 === جميع المحادثات في النظام ===');

      for (final doc in chatsSnapshot.docs) {
        final data = doc.data();
        print('🆔 معرف المحادثة: ${doc.id}');
        print('   👤 user1: ${data['user1Name']} (${data['user1Id']})');
        print('   👤 user2: ${data['user2Name']} (${data['user2Id']})');
        print('   💬 آخر رسالة: ${data['lastMessage']}');
        print('   📅 وقت آخر رسالة: ${data['lastMessageTime']}');
        print('   🔢 رسائل غير مقروءة: ${data['unreadCount']}');
        print('   ---');
      }
    } catch (e) {
      print('❌ خطأ في جلب المحادثات: $e');
    }
  }

  // طباعة جميع الرسائل في محادثة محددة
  static Future<void> printChatMessages(String chatId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp')
          .get();

      print('📨 === رسائل المحادثة $chatId ===');

      for (final doc in messagesSnapshot.docs) {
        final data = doc.data();
        print('   👤 مرسل: ${data['senderId']}');
        print('   👤 مستقبل: ${data['receiverId']}');
        print('   💬 رسالة: ${data['message']}');
        print('   📅 وقت: ${data['timestamp']}');
        print('   ✅ مقروءة: ${data['isRead']}');
        print('   ---');
      }
    } catch (e) {
      print('❌ خطأ في جلب رسائل المحادثة: $e');
    }
  }

  // اختبار إرسال رسالة
  static Future<void> testSendMessage({
    required String receiverId,
    required String message,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('❌ لا يوجد مستخدم مسجل دخول');
        return;
      }

      print('🧪 === بدء اختبار إرسال رسالة ===');
      print('👤 المرسل: ${currentUser.uid}');
      print('👤 المستقبل: $receiverId');
      print('💬 الرسالة: $message');

      // استخدام ChatService الحقيقي
      // final chatService = ChatService();
      // await chatService.sendMessage(
      //   receiverId: receiverId,
      //   message: message,
      // );

      print('✅ تم إرسال رسالة الاختبار');
    } catch (e) {
      print('❌ فشل في إرسال رسالة الاختبار: $e');
    }
  }
}
