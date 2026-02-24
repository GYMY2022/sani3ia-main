import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OnlineStatusManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final OnlineStatusManager _instance = OnlineStatusManager._internal();
  factory OnlineStatusManager() => _instance;
  OnlineStatusManager._internal();

  // ⭐ محسّن: دالة آمنة لتحديث حالة الاتصال
  Future<void> setOnlineStatus(bool isOnline) async {
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
      // لا نرمي استثناء هنا لنستمر في العملية
    }
  }

  // ⭐ محسّن: دالة آمنة للاستماع لحالة الاتصال
  Stream<bool> getUserOnlineStatus(String userId) {
    try {
      return _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .handleError((error) {
            print('⚠️ خطأ في مراقبة حالة الاتصال: $error');
            return false;
          })
          .map((snapshot) => snapshot.data()?['isOnline'] ?? false);
    } catch (e) {
      print('❌ خطأ في إعداد مراقبة حالة الاتصال: $e');
      return Stream.value(false);
    }
  }

  // ⭐ محسّن: دالة آمنة للحصول على آخر ظهور
  Stream<Timestamp?> getUserLastSeen(String userId) {
    try {
      return _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .handleError((error) {
            print('⚠️ خطأ في مراقبة آخر ظهور: $error');
            return null;
          })
          .map((snapshot) => snapshot.data()?['lastSeen'] as Timestamp?);
    } catch (e) {
      print('❌ خطأ في إعداد مراقبة آخر ظهور: $e');
      return Stream.value(null);
    }
  }

  String formatLastSeen(Timestamp? lastSeen) {
    if (lastSeen == null) return 'غير معروف';

    final now = DateTime.now();
    final lastSeenTime = lastSeen.toDate();
    final difference = now.difference(lastSeenTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else {
      return 'منذ ${difference.inDays} يوم';
    }
  }
}
