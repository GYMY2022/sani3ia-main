import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> notifications = [
    {
      'id': '1',
      'title': 'طلب جديد!',
      'message': 'فيه عميل طلب شغلانة جديدة في منطقتك.',
      'time': 'منذ دقيقة',
      'isRead': false,
      'icon': Icons.notifications_active,
    },
    {
      'id': '2',
      'title': 'تم قبول عرضك!',
      'message': 'العميل وافق على عرضك في شغلانة النجارة.',
      'time': 'منذ ساعتين',
      'isRead': false,
      'icon': Icons.check_circle,
    },
    {
      'id': '3',
      'title': 'تقييم جديد',
      'message': 'عميلك السابق قيّـمك بـ 5 نجوم!',
      'time': 'منذ 4 ساعات',
      'isRead': true,
      'icon': Icons.star,
    },
    {
      'id': '4',
      'title': 'تنبيه نظام',
      'message': 'يرجى تحديث بيانات حسابك لضمان الاستمرار في الخدمة.',
      'time': 'أمس',
      'isRead': true,
      'icon': Icons.warning,
    },
  ];

  void _markAsRead(String id) {
    setState(() {
      var notification = notifications.firstWhere((n) => n['id'] == id);
      notification['isRead'] = true;
    });
  }

  void _deleteNotification(String id) {
    setState(() {
      notifications.removeWhere((n) => n['id'] == id);
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in notifications) {
        notification['isRead'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int unreadCount = notifications.where((n) => !n['isRead']).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: const Color(0xFF00A8E8),
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _markAllAsRead,
              tooltip: 'تمييز الكل كمقروء',
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Text(
                'لا توجد إشعارات حالياً',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Dismissible(
                  key: Key(notification['id']),
                  background: Container(color: Colors.red),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _deleteNotification(notification['id']);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم حذف الإشعار: ${notification['title']}',
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: Icon(notification['icon'], color: Colors.blue),
                      title: Text(
                        notification['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: notification['isRead']
                              ? Colors.black
                              : Colors.blue,
                        ),
                      ),
                      subtitle: Text(notification['message']),
                      trailing: Text(
                        notification['time'],
                        style: const TextStyle(color: Colors.grey),
                      ),
                      onTap: () {
                        if (!notification['isRead']) {
                          _markAsRead(notification['id']);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'فتحت الإشعار: ${notification['title']}',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
