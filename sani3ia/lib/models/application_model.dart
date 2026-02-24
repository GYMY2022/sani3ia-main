import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus {
  pending, // قيد الانتظار
  accepted, // مقبول
  rejected, // مرفوض
  completed, // مكتمل
  cancelled, // ملغي
}

class Application {
  final String id;
  final String postId;
  final String postTitle;
  final String applicantId;
  final String applicantName;
  final String applicantImage;
  final String postOwnerId;
  final DateTime appliedAt;
  final ApplicationStatus status;
  final String? message;
  final double? proposedPrice;
  final DateTime? proposedDate;
  final bool hasAvailabilityResponse; // ⭐ جديد: هل تم الرد على استفسار التوفر؟
  final DateTime? respondedAt; // ⭐ جديد: وقت الرد على الاستفسار
  final bool? availabilityStatus; // ⭐ جديد: حالة التوفر من الرد

  Application({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.applicantId,
    required this.applicantName,
    required this.applicantImage,
    required this.postOwnerId,
    required this.appliedAt,
    this.status = ApplicationStatus.pending,
    this.message,
    this.proposedPrice,
    this.proposedDate,
    this.hasAvailabilityResponse = false, // ⭐ جديد
    this.respondedAt, // ⭐ جديد
    this.availabilityStatus, // ⭐ جديد
  });

  Application copyWith({
    String? id,
    String? postId,
    String? postTitle,
    String? applicantId,
    String? applicantName,
    String? applicantImage,
    String? postOwnerId,
    DateTime? appliedAt,
    ApplicationStatus? status,
    String? message,
    double? proposedPrice,
    DateTime? proposedDate,
    bool? hasAvailabilityResponse, // ⭐ جديد
    DateTime? respondedAt, // ⭐ جديد
    bool? availabilityStatus, // ⭐ جديد
  }) {
    return Application(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      postTitle: postTitle ?? this.postTitle,
      applicantId: applicantId ?? this.applicantId,
      applicantName: applicantName ?? this.applicantName,
      applicantImage: applicantImage ?? this.applicantImage,
      postOwnerId: postOwnerId ?? this.postOwnerId,
      appliedAt: appliedAt ?? this.appliedAt,
      status: status ?? this.status,
      message: message ?? this.message,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      proposedDate: proposedDate ?? this.proposedDate,
      hasAvailabilityResponse:
          hasAvailabilityResponse ?? this.hasAvailabilityResponse, // ⭐ جديد
      respondedAt: respondedAt ?? this.respondedAt, // ⭐ جديد
      availabilityStatus:
          availabilityStatus ?? this.availabilityStatus, // ⭐ جديد
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'postId': postId,
      'postTitle': postTitle,
      'applicantId': applicantId,
      'applicantName': applicantName,
      'applicantImage': applicantImage,
      'postOwnerId': postOwnerId,
      'appliedAt': appliedAt,
      'status': status.index,
      'message': message,
      'proposedPrice': proposedPrice,
      'proposedDate': proposedDate,
      'hasAvailabilityResponse': hasAvailabilityResponse, // ⭐ جديد
      'respondedAt': respondedAt, // ⭐ جديد
      'availabilityStatus': availabilityStatus, // ⭐ جديد
    };
  }

  factory Application.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Application(
      id: doc.id,
      postId: data['postId'] ?? '',
      postTitle: data['postTitle'] ?? '',
      applicantId: data['applicantId'] ?? '',
      applicantName: data['applicantName'] ?? '',
      applicantImage: data['applicantImage'] ?? '',
      postOwnerId: data['postOwnerId'] ?? '',
      appliedAt: (data['appliedAt'] as Timestamp).toDate(),
      status: ApplicationStatus.values[data['status'] ?? 0],
      message: data['message'],
      proposedPrice: data['proposedPrice'],
      proposedDate: data['proposedDate'] != null
          ? (data['proposedDate'] as Timestamp).toDate()
          : null,
      hasAvailabilityResponse:
          data['hasAvailabilityResponse'] ?? false, // ⭐ جديد
      respondedAt: data['respondedAt'] != null
          ? (data['respondedAt'] as Timestamp).toDate()
          : null, // ⭐ جديد
      availabilityStatus: data['availabilityStatus'], // ⭐ جديد
    );
  }

  // ⭐ جديد: دالة للحصول على نص الحالة
  String get statusText {
    switch (status) {
      case ApplicationStatus.pending:
        return 'قيد الانتظار';
      case ApplicationStatus.accepted:
        return 'مقبول';
      case ApplicationStatus.rejected:
        return 'مرفوض';
      case ApplicationStatus.completed:
        return 'مكتمل';
      case ApplicationStatus.cancelled:
        return 'ملغي';
    }
  }

  // ⭐ جديد: دالة للحصول على لون الحالة
  int get statusColor {
    switch (status) {
      case ApplicationStatus.pending:
        return 0xFFFFA000; // برتقالي
      case ApplicationStatus.accepted:
        return 0xFF4CAF50; // أخضر
      case ApplicationStatus.rejected:
        return 0xFFF44336; // أحمر
      case ApplicationStatus.completed:
        return 0xFF2196F3; // أزرق
      case ApplicationStatus.cancelled:
        return 0xFF9E9E9E; // رمادي
    }
  }

  // ⭐ جديد: دالة للتحقق إذا كان الطلب نشطاً
  bool get isActive {
    return status == ApplicationStatus.pending ||
        status == ApplicationStatus.accepted;
  }

  // ⭐ جديد: دالة للتحقق إذا كان الطلب مكتملاً
  bool get isCompleted {
    return status == ApplicationStatus.completed;
  }

  // ⭐ جديد: دالة للتحقق إذا كان الطلب مرفوضاً أو ملغياً
  bool get isInactive {
    return status == ApplicationStatus.rejected ||
        status == ApplicationStatus.cancelled;
  }

  // ⭐ جديد: دالة للحصول على نص حالة التوفر
  String get availabilityStatusText {
    if (availabilityStatus == true) {
      return 'الشغلانة متوفرة';
    } else if (availabilityStatus == false) {
      return 'الشغلانة غير متوفرة';
    } else {
      return 'لم يتم الرد بعد';
    }
  }

  // ⭐ جديد: دالة للتحقق إذا كان يمكن الرد على الاستفسار
  bool get canRespondToAvailability {
    return status == ApplicationStatus.pending && !hasAvailabilityResponse;
  }

  // ⭐ جديد: دالة لتحديث حالة الرد على الاستفسار
  Application withAvailabilityResponse(bool isAvailable) {
    return copyWith(
      hasAvailabilityResponse: true,
      respondedAt: DateTime.now(),
      availabilityStatus: isAvailable,
      status: isAvailable
          ? ApplicationStatus.accepted
          : ApplicationStatus.rejected,
    );
  }

  // ⭐ جديد: دالة للحصول على مدة تقديم الطلب
  String get appliedAgo {
    final now = DateTime.now();
    final difference = now.difference(appliedAt);

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

  // ⭐ جديد: دالة للتحقق إذا كان الطلب جديداً
  bool get isNew {
    final now = DateTime.now();
    return now.difference(appliedAt).inHours < 24;
  }

  @override
  String toString() {
    return 'Application{id: $id, post: $postTitle, applicant: $applicantName, status: $status, hasResponse: $hasAvailabilityResponse, availability: $availabilityStatus}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Application && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ⭐ جديد: نموذج لإحصائيات الطلبات
class ApplicationStats {
  final int totalApplications;
  final int pendingApplications;
  final int acceptedApplications;
  final int rejectedApplications;
  final int completedApplications;

  ApplicationStats({
    required this.totalApplications,
    required this.pendingApplications,
    required this.acceptedApplications,
    required this.rejectedApplications,
    required this.completedApplications,
  });

  // ⭐ جديد: دالة لإنشاء إحصائيات من قائمة طلبات
  factory ApplicationStats.fromApplications(List<Application> applications) {
    return ApplicationStats(
      totalApplications: applications.length,
      pendingApplications: applications
          .where((app) => app.status == ApplicationStatus.pending)
          .length,
      acceptedApplications: applications
          .where((app) => app.status == ApplicationStatus.accepted)
          .length,
      rejectedApplications: applications
          .where((app) => app.status == ApplicationStatus.rejected)
          .length,
      completedApplications: applications
          .where((app) => app.status == ApplicationStatus.completed)
          .length,
    );
  }

  // ⭐ جديد: دالة للحصول على نسبة الإنجاز
  double get completionRate {
    if (totalApplications == 0) return 0.0;
    return completedApplications / totalApplications;
  }

  // ⭐ جديد: دالة للحصول على نسبة القبول
  double get acceptanceRate {
    if (totalApplications == 0) return 0.0;
    return acceptedApplications / totalApplications;
  }
}
