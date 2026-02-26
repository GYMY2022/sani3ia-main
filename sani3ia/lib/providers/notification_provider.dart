import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

class NotificationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String _error = '';
  StreamSubscription? _notificationsSubscription;
  int _unreadCount = 0;
  bool _isDisposed = false;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String get error => _error;
  int get unreadCount => _unreadCount;

  // تصفية الإشعارات حسب النوع
  List<NotificationModel> getJobNotifications() {
    return _notifications
        .where(
          (n) =>
              n.type.toString().contains('Job') ||
              n.type == NotificationType.newReview ||
              n.type == NotificationType.jobAgreed ||
              n.type == NotificationType.jobCompleted ||
              n.type == NotificationType.jobCancelled,
        )
        .toList();
  }

  List<NotificationModel> getMarketNotifications() {
    return _notifications
        .where((n) => n.type.toString().contains('Product'))
        .toList();
  }

  List<NotificationModel> getChatNotifications() {
    return _notifications
        .where(
          (n) =>
              n.type == NotificationType.newMessage ||
              n.type == NotificationType.messageRead,
        )
        .toList();
  }

  List<NotificationModel> getSystemNotifications() {
    return _notifications
        .where(
          (n) =>
              n.type == NotificationType.system ||
              n.type == NotificationType.appUpdate,
        )
        .toList();
  }

  // تحميل الإشعارات
  void loadNotifications() {
    if (_isDisposed) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _notifications = [];
      _unreadCount = 0;
      _safeNotify();
      return;
    }

    _isLoading = true;
    _safeNotify();

    _notificationsSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (_isDisposed) return;
            _notifications = snapshot.docs
                .map((doc) => NotificationModel.fromFirestore(doc))
                .toList();
            _unreadCount = _notifications.where((n) => !n.isRead).length;
            _isLoading = false;
            _error = '';
            _safeNotify();
          },
          onError: (error) {
            if (_isDisposed) return;
            _error = 'فشل في تحميل الإشعارات: $error';
            _isLoading = false;
            _safeNotify();
          },
        );
  }

  // تعليم إشعار كمقروء
  Future<void> markAsRead(String notificationId) async {
    if (_isDisposed) return;

    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        _safeNotify();
      }
    } catch (e) {
      _error = 'فشل في تحديث الإشعار: $e';
      _safeNotify();
    }
  }

  // تعليم جميع الإشعارات كمقروءة
  Future<void> markAllAsRead() async {
    if (_isDisposed) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final batch = _firestore.batch();
      final unreadNotifications = _notifications
          .where((n) => !n.isRead)
          .toList();

      for (var notification in unreadNotifications) {
        final ref = _firestore.collection('notifications').doc(notification.id);
        batch.update(ref, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
      _unreadCount = 0;
      _safeNotify();
    } catch (e) {
      _error = 'فشل في تعليم الإشعارات كمقروءة: $e';
      _safeNotify();
    }
  }

  // حذف إشعار
  Future<void> deleteNotification(String notificationId) async {
    if (_isDisposed) return;

    try {
      await _firestore.collection('notifications').doc(notificationId).delete();

      _notifications.removeWhere((n) => n.id == notificationId);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      _safeNotify();
    } catch (e) {
      _error = 'فشل في حذف الإشعار: $e';
      _safeNotify();
    }
  }

  // حذف جميع الإشعارات
  Future<void> deleteAllNotifications() async {
    if (_isDisposed) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final batch = _firestore.batch();
      for (var notification in _notifications) {
        final ref = _firestore.collection('notifications').doc(notification.id);
        batch.delete(ref);
      }
      await batch.commit();

      _notifications.clear();
      _unreadCount = 0;
      _safeNotify();
    } catch (e) {
      _error = 'فشل في حذف الإشعارات: $e';
      _safeNotify();
    }
  }

  // إعادة تعيين
  void reset() {
    if (_isDisposed) return;
    _notificationsSubscription?.cancel();
    _notifications = [];
    _unreadCount = 0;
    _error = '';
    _safeNotify();
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _notificationsSubscription?.cancel();
    super.dispose();
  }
}
