import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String title;
  final String description;
  final List<String> images;
  final String type;
  final String category;
  final DateTime date;
  final String authorId;
  final String authorName;
  final String authorImage;
  final String location;
  final double budget;
  final bool isFavorite;
  final int views;
  final int applications;
  final String status; // open, agreed, completed, cancelled
  final DateTime createdAt;
  final Map<String, dynamic>? geoLocation;
  double? distance;

  // حقول للعامل المنفذ
  final String? workerId;
  final String? workerName;
  final String? workerImage;
  final DateTime? agreedAt;
  final DateTime? completedAt;
  final List<String> completionImages;

  // حقول التقييم
  final double? workerRating;
  final int? workerReviewCount;
  final double? clientRating;
  final String? clientReview;
  final String? clientName;
  final String? clientImage;

  // ⭐⭐ حقل جديد: حالة التوفر
  final bool isAvailable; // true = متوفرة, false = غير متوفرة

  Post({
    required this.id,
    required this.title,
    required this.description,
    required this.images,
    required this.type,
    required this.category,
    required this.date,
    required this.authorId,
    required this.authorName,
    this.authorImage = 'assets/images/default_profile.png',
    this.location = '',
    this.budget = 0.0,
    this.isFavorite = false,
    this.views = 0,
    this.applications = 0,
    this.status = 'open',
    required this.createdAt,
    this.geoLocation,
    this.distance,
    this.workerId,
    this.workerName,
    this.workerImage,
    this.agreedAt,
    this.completedAt,
    this.completionImages = const [],
    this.workerRating,
    this.workerReviewCount,
    this.clientRating,
    this.clientReview,
    this.clientName,
    this.clientImage,
    this.isAvailable = true, // ⭐⭐ القيمة الافتراضية: متوفرة
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      List<String> images = [];
      try {
        final rawImages = data['images'] ?? [];
        if (rawImages is List) {
          images = List<String>.from(
            rawImages.where((img) => img is String && img.isNotEmpty),
          );
        }
      } catch (e) {
        print('❌ خطأ في تحويل الصور: $e');
        images = [];
      }

      if (images.isEmpty) {
        images = [
          'assets/images/default_job_1.png',
          'assets/images/default_job_2.png',
        ];
      }

      String authorImage = 'assets/images/default_profile.png';
      try {
        final rawAuthorImage = data['authorImage'];
        if (rawAuthorImage is String && rawAuthorImage.isNotEmpty) {
          authorImage = rawAuthorImage;
        }
      } catch (e) {
        print('❌ خطأ في تحويل authorImage: $e');
      }

      Map<String, dynamic>? geoLocation;
      try {
        final rawGeoLocation = data['geoLocation'];
        if (rawGeoLocation is Map<String, dynamic>) {
          geoLocation = rawGeoLocation;
        } else if (data['latitude'] != null && data['longitude'] != null) {
          geoLocation = {
            'latitude': (data['latitude'] as num).toDouble(),
            'longitude': (data['longitude'] as num).toDouble(),
            'address': data['address'] ?? '',
            'city': data['city'] ?? '',
          };
        }
      } catch (e) {
        print('❌ خطأ في تحويل geoLocation: $e');
      }

      List<String> completionImages = [];
      try {
        final rawCompletionImages = data['completionImages'] ?? [];
        if (rawCompletionImages is List) {
          completionImages = List<String>.from(
            rawCompletionImages.where((img) => img is String && img.isNotEmpty),
          );
        }
      } catch (e) {
        print('❌ خطأ في تحويل صور الإنجاز: $e');
      }

      return Post(
        id: doc.id,
        title: (data['title'] as String?) ?? 'عنوان الشغلانة',
        description: (data['description'] as String?) ?? 'وصف الشغلانة',
        images: images,
        type: (data['type'] as String?) ?? 'customer',
        category: (data['category'] as String?) ?? 'عام',
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        authorId: (data['authorId'] as String?) ?? '',
        authorName: (data['authorName'] as String?) ?? 'مستخدم',
        authorImage: authorImage,
        location: (data['location'] as String?) ?? 'موقع غير محدد',
        budget: ((data['budget'] ?? 0.0) as num).toDouble(),
        isFavorite: (data['isFavorite'] as bool?) ?? false,
        views: ((data['views'] ?? 0) as num).toInt(),
        applications: ((data['applications'] ?? 0) as num).toInt(),
        status: (data['status'] as String?) ?? 'open',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        geoLocation: geoLocation,
        distance: ((data['distance'] ?? 0.0) as num?)?.toDouble(),
        workerId: data['workerId'],
        workerName: data['workerName'],
        workerImage: data['workerImage'],
        agreedAt: data['agreedAt'] != null
            ? (data['agreedAt'] as Timestamp).toDate()
            : null,
        completedAt: data['completedAt'] != null
            ? (data['completedAt'] as Timestamp).toDate()
            : null,
        completionImages: completionImages,
        workerRating: (data['workerRating'] as num?)?.toDouble(),
        workerReviewCount: data['workerReviewCount'],
        clientRating: (data['clientRating'] as num?)?.toDouble(),
        clientReview: data['clientReview'],
        clientName: data['clientName'],
        clientImage: data['clientImage'],
        // ⭐⭐ التأكد من عدم وجود null
        isAvailable: data['isAvailable'] ?? true,
      );
    } catch (e) {
      print('❌ خطأ فادح في Post.fromFirestore: $e');
      return Post(
        id: doc.id,
        title: 'عنوان افتراضي',
        description: 'وصف افتراضي',
        images: ['assets/images/default_job_1.png'],
        type: 'customer',
        category: 'عام',
        date: DateTime.now(),
        authorId: 'unknown',
        authorName: 'مستخدم',
        authorImage: 'assets/images/default_profile.png',
        location: 'موقع غير محدد',
        budget: 0.0,
        views: 0,
        applications: 0,
        status: 'open',
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'images': images,
      'type': type,
      'category': category,
      'date': Timestamp.fromDate(date),
      'authorId': authorId,
      'authorName': authorName,
      'authorImage': authorImage,
      'location': location,
      'budget': budget,
      'isFavorite': isFavorite,
      'views': views,
      'applications': applications,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'geoLocation': geoLocation,
      'workerId': workerId,
      'workerName': workerName,
      'workerImage': workerImage,
      'agreedAt': agreedAt != null ? Timestamp.fromDate(agreedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'completionImages': completionImages,
      'workerRating': workerRating,
      'workerReviewCount': workerReviewCount,
      'clientRating': clientRating,
      'clientReview': clientReview,
      'clientName': clientName,
      'clientImage': clientImage,
      'isAvailable': isAvailable,
    };
  }

  Post copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? images,
    String? type,
    String? category,
    DateTime? date,
    String? authorId,
    String? authorName,
    String? authorImage,
    String? location,
    double? budget,
    bool? isFavorite,
    int? views,
    int? applications,
    String? status,
    DateTime? createdAt,
    Map<String, dynamic>? geoLocation,
    double? distance,
    String? workerId,
    String? workerName,
    String? workerImage,
    DateTime? agreedAt,
    DateTime? completedAt,
    List<String>? completionImages,
    double? workerRating,
    int? workerReviewCount,
    double? clientRating,
    String? clientReview,
    String? clientName,
    String? clientImage,
    bool? isAvailable,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorImage: authorImage ?? this.authorImage,
      location: location ?? this.location,
      budget: budget ?? this.budget,
      isFavorite: isFavorite ?? this.isFavorite,
      views: views ?? this.views,
      applications: applications ?? this.applications,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      geoLocation: geoLocation ?? this.geoLocation,
      distance: distance ?? this.distance,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      workerImage: workerImage ?? this.workerImage,
      agreedAt: agreedAt ?? this.agreedAt,
      completedAt: completedAt ?? this.completedAt,
      completionImages: completionImages ?? this.completionImages,
      workerRating: workerRating ?? this.workerRating,
      workerReviewCount: workerReviewCount ?? this.workerReviewCount,
      clientRating: clientRating ?? this.clientRating,
      clientReview: clientReview ?? this.clientReview,
      clientName: clientName ?? this.clientName,
      clientImage: clientImage ?? this.clientImage,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  bool get hasGeoLocation {
    return geoLocation != null &&
        geoLocation!['latitude'] != null &&
        geoLocation!['longitude'] != null;
  }

  String get distanceText {
    if (distance == null) return 'غير محدد';
    if (distance! < 1) {
      return '${(distance! * 1000).toStringAsFixed(0)} متر';
    }
    return '${distance!.toStringAsFixed(1)} كم';
  }

  bool get isOpen => status == 'open';
  bool get isAgreed => status == 'agreed';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool isWorker(String userId) => workerId == userId;
  bool isOwner(String userId) => authorId == userId;
}
