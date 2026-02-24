import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatRoom {
  final String id;
  final String user1Id;
  final String user2Id;
  final String user1Name;
  final String user2Name;
  final String user1Image;
  final String user2Image;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? postId;
  final String? postImage;
  final String? postTitle;
  final String? chatType; // 'job' or 'product'

  ChatRoom({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.user1Name,
    required this.user2Name,
    required this.user1Image,
    required this.user2Image,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCounts,
    required this.createdAt,
    required this.updatedAt,
    this.postId,
    this.postImage,
    this.postTitle,
    this.chatType,
  });

  // ⭐⭐ دالة جديدة لتوليد ID المحادثة بناءً على المستخدمين والمنتج
  static String generateChatId(String user1Id, String user2Id, String? postId) {
    final sortedIds = [user1Id, user2Id]..sort();
    if (postId != null && postId.isNotEmpty) {
      // لو فيه postId (منتج أو شغلانة)، نستخدمه في الـ ID
      return '${sortedIds[0]}_${sortedIds[1]}_$postId';
    } else {
      // لو مفيش postId (محادثة عادية)
      return '${sortedIds[0]}_${sortedIds[1]}';
    }
  }

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      user1Id: data['user1Id'] ?? '',
      user2Id: data['user2Id'] ?? '',
      user1Name: data['user1Name'] ?? 'مستخدم',
      user2Name: data['user2Name'] ?? 'مستخدم',
      user1Image: data['user1Image'] ?? 'assets/images/default_profile.png',
      user2Image: data['user2Image'] ?? 'assets/images/default_profile.png',
      lastMessage: data['lastMessage'] ?? 'لا توجد رسائل',
      lastMessageTime:
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      postId: data['postId'],
      postImage: data['postImage'],
      postTitle: data['postTitle'],
      chatType: data['chatType'] ?? 'job',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user1Id': user1Id,
      'user2Id': user2Id,
      'user1Name': user1Name,
      'user2Name': user2Name,
      'user1Image': user1Image,
      'user2Image': user2Image,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'unreadCounts': unreadCounts,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'postId': postId,
      'postImage': postImage,
      'postTitle': postTitle,
      'chatType': chatType,
    };
  }

  ChatRoom copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    String? user1Name,
    String? user2Name,
    String? user1Image,
    String? user2Image,
    String? lastMessage,
    DateTime? lastMessageTime,
    Map<String, int>? unreadCounts,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? postId,
    String? postImage,
    String? postTitle,
    String? chatType,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      user1Name: user1Name ?? this.user1Name,
      user2Name: user2Name ?? this.user2Name,
      user1Image: user1Image ?? this.user1Image,
      user2Image: user2Image ?? this.user2Image,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      postId: postId ?? this.postId,
      postImage: postImage ?? this.postImage,
      postTitle: postTitle ?? this.postTitle,
      chatType: chatType ?? this.chatType,
    );
  }

  String get chatImage {
    if (postImage != null && postImage!.isNotEmpty) {
      return postImage!;
    } else {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        return currentUser.uid == user1Id ? user2Image : user1Image;
      }
      return user1Image;
    }
  }

  String get chatTitle {
    if (postTitle != null && postTitle!.isNotEmpty) {
      return postTitle!;
    } else {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        return currentUser.uid == user1Id ? user2Name : user1Name;
      }
      return user1Name;
    }
  }

  int getUnreadCountForUser(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  bool isUserInChat(String userId) {
    return user1Id == userId || user2Id == userId;
  }

  String getOtherUserName(String currentUserId) {
    return currentUserId == user1Id ? user2Name : user1Name;
  }

  String getOtherUserImage(String currentUserId) {
    return currentUserId == user1Id ? user2Image : user1Image;
  }

  String getOtherUserId(String currentUserId) {
    return currentUserId == user1Id ? user2Id : user1Id;
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? postId;
  final bool isAvailabilityQuestion;
  final bool isAvailabilityResponse;
  final bool? availabilityStatus;
  final DateTime? readAt;
  final bool isEdited;
  final DateTime? editedAt;
  final String? mediaUrl;
  final String? mediaType;
  final String? fileName;
  final int? fileSize;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.postId,
    this.isAvailabilityQuestion = false,
    this.isAvailabilityResponse = false,
    this.availabilityStatus,
    this.readAt,
    this.isEdited = false,
    this.editedAt,
    this.mediaUrl,
    this.mediaType,
    this.fileName,
    this.fileSize,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
      'postId': postId,
      'isAvailabilityQuestion': isAvailabilityQuestion,
      'isAvailabilityResponse': isAvailabilityResponse,
      'availabilityStatus': availabilityStatus,
      'readAt': readAt,
      'isEdited': isEdited,
      'editedAt': editedAt,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'fileName': fileName,
      'fileSize': fileSize,
    };
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      postId: data['postId'],
      isAvailabilityQuestion: data['isAvailabilityQuestion'] ?? false,
      isAvailabilityResponse: data['isAvailabilityResponse'] ?? false,
      availabilityStatus: data['availabilityStatus'],
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
      isEdited: data['isEdited'] ?? false,
      editedAt: data['editedAt'] != null
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
      mediaUrl: data['mediaUrl'],
      mediaType: data['mediaType'],
      fileName: data['fileName'],
      fileSize: data['fileSize'],
    );
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? postId,
    bool? isAvailabilityQuestion,
    bool? isAvailabilityResponse,
    bool? availabilityStatus,
    DateTime? readAt,
    bool? isEdited,
    DateTime? editedAt,
    String? mediaUrl,
    String? mediaType,
    String? fileName,
    int? fileSize,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      postId: postId ?? this.postId,
      isAvailabilityQuestion:
          isAvailabilityQuestion ?? this.isAvailabilityQuestion,
      isAvailabilityResponse:
          isAvailabilityResponse ?? this.isAvailabilityResponse,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      readAt: readAt ?? this.readAt,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  bool get isJobAvailabilityMessage {
    return isAvailabilityQuestion || isAvailabilityResponse;
  }

  String get availabilityStatusText {
    if (availabilityStatus == true) {
      return 'متوفرة';
    } else if (availabilityStatus == false) {
      return 'غير متوفرة';
    } else {
      return 'غير محدد';
    }
  }

  bool isSentBy(String userId) {
    return senderId == userId;
  }

  bool isReceivedBy(String userId) {
    return receiverId == userId;
  }

  bool get hasMedia {
    return mediaUrl != null && mediaUrl!.isNotEmpty;
  }

  @override
  String toString() {
    return 'ChatMessage{id: $id, sender: $senderId, message: $message, media: $mediaUrl, mediaType: $mediaType}';
  }
}

class UserPresence {
  final String userId;
  final bool isOnline;
  final DateTime lastSeen;

  UserPresence({
    required this.userId,
    required this.isOnline,
    required this.lastSeen,
  });

  factory UserPresence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPresence(
      userId: doc.id,
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'isOnline': isOnline, 'lastSeen': lastSeen};
  }

  UserPresence copyWith({String? userId, bool? isOnline, DateTime? lastSeen}) {
    return UserPresence(
      userId: userId ?? this.userId,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  String get lastSeenFormatted {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

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

  bool get isRecentlyOnline {
    final now = DateTime.now();
    return isOnline || now.difference(lastSeen).inMinutes < 5;
  }
}
