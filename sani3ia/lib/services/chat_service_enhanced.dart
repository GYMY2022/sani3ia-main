import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatServiceEnhanced {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final ChatServiceEnhanced _instance = ChatServiceEnhanced._internal();
  factory ChatServiceEnhanced() => _instance;
  ChatServiceEnhanced._internal();

  // ⭐ جديد: تحديث حالة الرسائل كمقروءة بشكل فعال
  Future<void> markMessagesAsReadEnhanced(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatId = generateChatId(currentUser.uid, otherUserId);

      // تحديث جميع الرسائل غير المقروءة دفعة واحدة
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // تحديث عدد الرسائل غير المقروءة في غرفة المحادثة
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount': 0,
        'lastReadBy_${currentUser.uid}': FieldValue.serverTimestamp(),
      });

      print('✅ تم تعيين جميع الرسائل كمقروءة للمحادثة: $chatId');
    } catch (e) {
      print('❌ فشل في تعيين الرسائل كمقروءة: $e');
      rethrow;
    }
  }

  // ⭐ جديد: دالة لتعديل الرسالة
  Future<void> updateMessage(
    String chatId,
    String messageId,
    String newMessage,
  ) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
            'message': newMessage,
            'isEdited': true,
            'editedAt': FieldValue.serverTimestamp(),
          });

      print('✅ تم تعديل الرسالة: $messageId');
    } catch (e) {
      print('❌ فشل في تعديل الرسالة: $e');
      throw Exception('فشل في تعديل الرسالة: $e');
    }
  }

  // ⭐ جديد: دالة لحذف الرسالة
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

  // ⭐ جديد: دالة للحصول على آخر رسالة في المحادثة
  Stream<DocumentSnapshot> getLastMessageStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null,
        )
        .where((doc) => doc != null)
        .cast<DocumentSnapshot>();
  }

  // ⭐ جديد: دالة للتحقق من وجود محادثة
  Future<bool> doesChatExist(String user1Id, String user2Id) async {
    final chatId = generateChatId(user1Id, user2Id);
    final doc = await _firestore.collection('chats').doc(chatId).get();
    return doc.exists;
  }

  String generateChatId(String user1Id, String user2Id) {
    final sortedIds = [user1Id, user2Id]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // ⭐ جديد: دالة للحصول على معلومات المستخدم
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

  // ⭐ جديد: دالة لتحديث آخر ظهور للمستخدم
  Future<void> updateUserPresence(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ خطأ في تحديث حالة المستخدم: $e');
    }
  }
}
