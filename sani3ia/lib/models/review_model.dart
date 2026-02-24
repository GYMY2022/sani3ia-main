import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String workerId;
  final String clientId;
  final String clientName;
  final String clientImage;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String? postId;

  Review({
    required this.id,
    required this.workerId,
    required this.clientId,
    required this.clientName,
    required this.clientImage,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.postId,
  });

  factory Review.fromMap(Map<String, dynamic> map, String documentId) {
    return Review(
      id: documentId,
      workerId: map['workerId'] ?? '',
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? 'مستخدم',
      clientImage: map['clientImage'] ?? 'assets/images/default_profile.png',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      postId: map['postId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workerId': workerId,
      'clientId': clientId,
      'clientName': clientName,
      'clientImage': clientImage,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'postId': postId,
    };
  }
}
