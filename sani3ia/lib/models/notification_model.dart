import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  // الشغلانات
  newJobApplication, // تقدم جديد لشغلانة
  jobApplicationAccepted, // قبول طلب شغلانة
  jobApplicationRejected, // رفض طلب شغلانة
  newJobPosted, // شغلانة جديدة في تخصص المستخدم
  jobAgreed, // تم الاتفاق على شغلانة
  jobCompleted, // تم إنجاز شغلانة
  jobCancelled, // تم إلغاء شغلانة
  // المنتجات
  newProductQuery, // استفسار جديد عن منتج
  productQueryResponse, // رد على استفسار منتج
  productSold, // تم بيع منتج
  newProductAdded, // منتج جديد في نفس التصنيف
  // المحادثات
  newMessage, // رسالة جديدة
  messageRead, // تم قراءة الرسالة
  // التقييمات
  newReview, // تقييم جديد
  // النظام
  appUpdate, // تحديث التطبيق
  system, // إشعار نظام
}

class NotificationModel {
  final String id;
  final String userId; // المستلم
  final String? senderId; // المرسل
  final String? senderName;
  final String? senderImage;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data; // بيانات إضافية
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? targetRoute; // المسار المستهدف عند الضغط
  final Map<String, dynamic>? targetArguments; // ⭐ الوسائط المستهدفة
  final bool isSystemWide; // هل الإشعار لجميع المستخدمين؟

  NotificationModel({
    required this.id,
    required this.userId,
    this.senderId,
    this.senderName,
    this.senderImage,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.targetRoute,
    this.targetArguments, // ⭐ إضافة
    this.isSystemWide = false,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      senderId: data['senderId'],
      senderName: data['senderName'],
      senderImage: data['senderImage'],
      type: _typeFromInt(data['type'] ?? 0),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      data: data['data'] as Map<String, dynamic>?,
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      targetRoute: data['targetRoute'],
      targetArguments:
          data['targetArguments'] as Map<String, dynamic>?, // ⭐ إضافة
      isSystemWide: data['isSystemWide'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'senderId': senderId,
      'senderName': senderName,
      'senderImage': senderImage,
      'type': type.index,
      'title': title,
      'body': body,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'targetRoute': targetRoute,
      'targetArguments': targetArguments, // ⭐ إضافة
      'isSystemWide': isSystemWide,
    };
  }

  static NotificationType _typeFromInt(int index) {
    switch (index) {
      case 0:
        return NotificationType.newJobApplication;
      case 1:
        return NotificationType.jobApplicationAccepted;
      case 2:
        return NotificationType.jobApplicationRejected;
      case 3:
        return NotificationType.newJobPosted;
      case 4:
        return NotificationType.jobAgreed;
      case 5:
        return NotificationType.jobCompleted;
      case 6:
        return NotificationType.jobCancelled;
      case 7:
        return NotificationType.newProductQuery;
      case 8:
        return NotificationType.productQueryResponse;
      case 9:
        return NotificationType.productSold;
      case 10:
        return NotificationType.newProductAdded;
      case 11:
        return NotificationType.newMessage;
      case 12:
        return NotificationType.messageRead;
      case 13:
        return NotificationType.newReview;
      case 14:
        return NotificationType.appUpdate;
      default:
        return NotificationType.system;
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.newJobApplication:
        return Icons.person_add;
      case NotificationType.jobApplicationAccepted:
        return Icons.check_circle;
      case NotificationType.jobApplicationRejected:
        return Icons.cancel;
      case NotificationType.newJobPosted:
        return Icons.work;
      case NotificationType.jobAgreed:
        return Icons.handshake;
      case NotificationType.jobCompleted:
        return Icons.work_off;
      case NotificationType.jobCancelled:
        return Icons.event_busy;
      case NotificationType.newProductQuery:
        return Icons.shopping_bag;
      case NotificationType.productQueryResponse:
        return Icons.reply;
      case NotificationType.productSold:
        return Icons.sell;
      case NotificationType.newProductAdded:
        return Icons.add_shopping_cart;
      case NotificationType.newMessage:
        return Icons.message;
      case NotificationType.messageRead:
        return Icons.done_all;
      case NotificationType.newReview:
        return Icons.star;
      case NotificationType.appUpdate:
        return Icons.system_update;
      case NotificationType.system:
        return Icons.info;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.newJobApplication:
        return Colors.blue;
      case NotificationType.jobApplicationAccepted:
        return Colors.green;
      case NotificationType.jobApplicationRejected:
        return Colors.red;
      case NotificationType.newJobPosted:
        return Colors.purple;
      case NotificationType.jobAgreed:
        return Colors.orange;
      case NotificationType.jobCompleted:
        return Colors.teal;
      case NotificationType.jobCancelled:
        return Colors.grey;
      case NotificationType.newProductQuery:
        return Colors.indigo;
      case NotificationType.productQueryResponse:
        return Colors.lightGreen;
      case NotificationType.productSold:
        return Colors.pink;
      case NotificationType.newProductAdded:
        return Colors.amber;
      case NotificationType.newMessage:
        return Colors.cyan;
      case NotificationType.messageRead:
        return Colors.lightBlue;
      case NotificationType.newReview:
        return Colors.yellow;
      case NotificationType.appUpdate:
        return Colors.deepPurple;
      case NotificationType.system:
        return Colors.grey;
    }
  }

  String get category {
    if (type.toString().contains('Job')) return 'الشغلانات';
    if (type.toString().contains('Product')) return 'السوق';
    if (type == NotificationType.newMessage ||
        type == NotificationType.messageRead)
      return 'المحادثات';
    if (type == NotificationType.newReview) return 'التقييمات';
    if (type == NotificationType.appUpdate) return 'تحديثات التطبيق';
    return 'نظام';
  }

  NotificationModel copyWith({bool? isRead, DateTime? readAt}) {
    return NotificationModel(
      id: id,
      userId: userId,
      senderId: senderId,
      senderName: senderName,
      senderImage: senderImage,
      type: type,
      title: title,
      body: body,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      targetRoute: targetRoute,
      targetArguments: targetArguments,
      isSystemWide: isSystemWide,
    );
  }
}
