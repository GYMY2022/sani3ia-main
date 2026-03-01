import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getTimeText(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'الآن';
    if (difference.inHours < 1) return 'منذ ${difference.inMinutes} دقيقة';
    if (difference.inDays < 1) return 'اليوم ${_timeFormat.format(date)}';
    if (difference.inDays == 1) return 'أمس ${_timeFormat.format(date)}';
    return _dateFormat.format(date);
  }

  // دالة لجلب Stream للإشعارات
  Stream<List<NotificationModel>> _getNotificationsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList(),
        );
  }

  // دوال التصفية
  List<NotificationModel> getJobNotifications(List<NotificationModel> all) {
    return all.where((n) {
      final typeStr = n.type.toString();
      return typeStr.contains('Job') ||
          n.type == NotificationType.newReview ||
          n.type == NotificationType.jobAgreed ||
          n.type == NotificationType.jobCompleted ||
          n.type == NotificationType.jobCancelled;
    }).toList();
  }

  List<NotificationModel> getMarketNotifications(List<NotificationModel> all) {
    return all.where((n) => n.type.toString().contains('Product')).toList();
  }

  List<NotificationModel> getChatNotifications(List<NotificationModel> all) {
    return all.where((n) => n.type == NotificationType.newMessage).toList();
  }

  List<NotificationModel> getSystemNotifications(List<NotificationModel> all) {
    return all.where((n) {
      return n.type == NotificationType.system ||
          n.type == NotificationType.appUpdate;
    }).toList();
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('خطأ في تعليم الإشعار كمقروء: $e');
    }
  }

  Future<void> _markAllAsRead(List<NotificationModel> notifications) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var n in notifications.where((n) => !n.isRead)) {
      batch.update(
        FirebaseFirestore.instance.collection('notifications').doc(n.id),
        {'isRead': true, 'readAt': FieldValue.serverTimestamp()},
      );
    }
    await batch.commit();
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('خطأ في حذف الإشعار: $e');
    }
  }

  Future<void> _deleteAllNotifications(
    List<NotificationModel> notifications,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var n in notifications) {
      batch.delete(
        FirebaseFirestore.instance.collection('notifications').doc(n.id),
      );
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: const Color(0xFF00A8E8),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.all_inbox), text: 'الكل'),
            Tab(icon: Icon(Icons.work), text: 'الشغلانات'),
            Tab(icon: Icon(Icons.shopping_bag), text: 'السوق'),
            Tab(icon: Icon(Icons.system_update), text: 'النظام'),
          ],
        ),
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: _getNotificationsStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final unreadCount = snapshot.data!.where((n) => !n.isRead).length;
              if (unreadCount == 0) return const SizedBox();

              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'mark_all',
                    child: Row(
                      children: [
                        Icon(Icons.done_all, color: Colors.green),
                        SizedBox(width: 8),
                        Text('تحديد الكل كمقروء'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, color: Colors.red),
                        SizedBox(width: 8),
                        Text('حذف الكل'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'mark_all') {
                    await _markAllAsRead(snapshot.data!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديد الكل كمقروء')),
                    );
                  } else if (value == 'delete_all') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('حذف جميع الإشعارات'),
                        content: const Text(
                          'هل أنت متأكد من حذف جميع الإشعارات؟',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _deleteAllNotifications(snapshot.data!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حذف جميع الإشعارات')),
                      );
                    }
                  }
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد إشعارات',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final allNotifications = snapshot.data!;
          final jobNotifications = getJobNotifications(allNotifications);
          final marketNotifications = getMarketNotifications(allNotifications);
          final chatNotifications = getChatNotifications(allNotifications);
          final systemNotifications = getSystemNotifications(allNotifications);

          return TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationList(allNotifications),
              _buildNotificationList(jobNotifications),
              _buildNotificationList(marketNotifications),
              _buildNotificationList(systemNotifications),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationList(List<NotificationModel> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد إشعارات',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return Dismissible(
          key: Key(notification.id),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            _deleteNotification(notification.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم حذف الإشعار'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: InkWell(
            onTap: () {
              if (!notification.isRead) {
                _markAsRead(notification.id);
              }
              _handleNotificationTap(context, notification);
            },
            child: Container(
              color: notification.isRead
                  ? Colors.white
                  : notification.color.withOpacity(0.05),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: notification.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      notification.icon,
                      color: notification.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: notification.category == 'الشغلانات'
                                    ? Colors.blue[50]
                                    : notification.category == 'السوق'
                                    ? Colors.green[50]
                                    : notification.category == 'المحادثات'
                                    ? Colors.purple[50]
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                notification.category,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: notification.category == 'الشغلانات'
                                      ? Colors.blue[700]
                                      : notification.category == 'السوق'
                                      ? Colors.green[700]
                                      : notification.category == 'المحادثات'
                                      ? Colors.purple[700]
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _getTimeText(notification.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (notification.senderName != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'من ${notification.senderName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: notification.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    NotificationModel notification,
  ) {
    if (notification.targetRoute != null) {
      // ✅ تمرير targetArguments مباشرة إلى Navigator
      Navigator.pushNamed(
        context,
        notification.targetRoute!,
        arguments: notification.targetArguments ?? {},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم فتح الإشعار: ${notification.title}')),
      );
    }
  }
}
