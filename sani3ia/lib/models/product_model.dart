import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final double? originalPrice;
  final List<String> imageUrls;
  final String category;
  final String location;
  final String sellerId;
  final String sellerName;
  final String sellerImage;
  final double rating;
  final int reviewCount;
  final int views;
  final int favoriteCount;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? latitude;
  final double? longitude;
  final String? fullAddress;
  bool isFavorite;
  final int? discount;
  double? distance;

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.imageUrls,
    required this.category,
    required this.location,
    required this.sellerId,
    required this.sellerName,
    required this.sellerImage,
    required this.rating,
    this.reviewCount = 0,
    this.views = 0,
    this.favoriteCount = 0,
    this.status = 'available',
    required this.createdAt,
    this.updatedAt,
    this.latitude,
    this.longitude,
    this.fullAddress,
    this.isFavorite = false,
    this.discount,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    print('🔍 تحويل منتج: ${doc.id}');
    print('   البيانات الخام: $data');

    // دوال مساعدة للتحويل الآمن
    T? _safeCast<T>(dynamic value, T? Function(dynamic) castFunc) {
      try {
        return castFunc(value);
      } catch (e) {
        print('   ⚠️ فشل تحويل القيمة $value إلى النوع المطلوب: $e');
        return null;
      }
    }

    String? _toString(dynamic value) => value?.toString();

    double? _toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value);
      }
      return null;
    }

    int? _toInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }

    DateTime? _toDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    // معالجة الحقول الأساسية مع طباعة القيم
    String id = doc.id;
    String title = _safeCast<String>(data['title'], _toString) ?? 'بدون عنوان';
    String description =
        _safeCast<String>(data['description'], _toString) ?? '';
    double price = _safeCast<double>(data['price'], _toDouble) ?? 0.0;
    double? originalPrice = _safeCast<double?>(
      data['originalPrice'],
      _toDouble,
    );
    String category = _safeCast<String>(data['category'], _toString) ?? 'عام';
    String location =
        _safeCast<String>(data['location'], _toString) ?? 'موقع غير محدد';
    String sellerId =
        _safeCast<String>(data['sellerId'] ?? data['authorId'], _toString) ??
        '';
    String sellerName =
        _safeCast<String>(
          data['sellerName'] ?? data['authorName'],
          _toString,
        ) ??
        'بائع';
    String sellerImage =
        _safeCast<String>(
          data['sellerImage'] ?? data['authorImage'],
          _toString,
        ) ??
        'assets/images/default_profile.png';
    double rating = _safeCast<double>(data['rating'], _toDouble) ?? 0.0;
    int reviewCount = _safeCast<int>(data['reviewCount'], _toInt) ?? 0;
    int views = _safeCast<int>(data['views'], _toInt) ?? 0;
    int favoriteCount = _safeCast<int>(data['favoriteCount'], _toInt) ?? 0;
    int? discount = _safeCast<int?>(data['discount'], _toInt);

    // ⭐ معالجة الحالة (status) - هذه أهم نقطة: نجبرها على النص
    String status = 'available';
    if (data['status'] != null) {
      status = data['status'].toString();
      print(
        '   الحالة الخام: ${data['status']} (${data['status'].runtimeType}) -> المحولة: $status',
      );
    } else {
      print('   الحالة: غير موجودة، استخدام القيمة الافتراضية "available"');
    }

    // معالجة الصور
    List<String> imageUrls = [];
    try {
      final rawImages = data['imageUrls'] ?? data['images'] ?? [];
      if (rawImages is List) {
        imageUrls = List<String>.from(
          rawImages
              .where((img) => img != null && img.toString().isNotEmpty)
              .map((img) => img.toString()),
        );
      } else if (rawImages is String) {
        imageUrls = [rawImages];
      }
    } catch (e) {
      print('   ⚠️ خطأ في معالجة الصور: $e');
    }
    print('   عدد الصور: ${imageUrls.length}');

    // استخراج الموقع الجغرافي
    double? latitude;
    double? longitude;
    String? fullAddress;
    try {
      if (data['location'] is Map) {
        final loc = data['location'] as Map<String, dynamic>;
        latitude = _safeCast<double>(loc['latitude'], _toDouble);
        longitude = _safeCast<double>(loc['longitude'], _toDouble);
        fullAddress = _safeCast<String>(loc['fullAddress'], _toString);
      } else {
        latitude = _safeCast<double>(data['latitude'], _toDouble);
        longitude = _safeCast<double>(data['longitude'], _toDouble);
        fullAddress = _safeCast<String>(data['fullAddress'], _toString);
      }
    } catch (e) {
      print('   ⚠️ خطأ في معالجة الموقع: $e');
    }

    // معالجة التواريخ
    DateTime createdAt =
        _safeCast<DateTime>(data['createdAt'], _toDateTime) ?? DateTime.now();
    DateTime? updatedAt = _safeCast<DateTime?>(data['updatedAt'], _toDateTime);

    bool isFavorite = data['isFavorite'] ?? false;

    print('✅ تم إنشاء المنتج بنجاح: $title - السعر: $price');

    return Product(
      id: id,
      title: title,
      description: description,
      price: price,
      originalPrice: originalPrice,
      imageUrls: imageUrls,
      category: category,
      location: location,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerImage: sellerImage,
      rating: rating,
      reviewCount: reviewCount,
      views: views,
      favoriteCount: favoriteCount,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      latitude: latitude,
      longitude: longitude,
      fullAddress: fullAddress,
      isFavorite: isFavorite,
      discount: discount,
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic>? locationMap;
    if (latitude != null || longitude != null || fullAddress != null) {
      locationMap = {};
      if (latitude != null) locationMap['latitude'] = latitude;
      if (longitude != null) locationMap['longitude'] = longitude;
      if (fullAddress != null) locationMap['fullAddress'] = fullAddress;
    }
    return {
      'title': title,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'imageUrls': imageUrls,
      'category': category,
      'location': locationMap,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerImage': sellerImage,
      'rating': rating,
      'reviewCount': reviewCount,
      'views': views,
      'favoriteCount': favoriteCount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'discount': discount,
    };
  }

  Product copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    double? originalPrice,
    List<String>? imageUrls,
    String? category,
    String? location,
    String? sellerId,
    String? sellerName,
    String? sellerImage,
    double? rating,
    int? reviewCount,
    int? views,
    int? favoriteCount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    String? fullAddress,
    bool? isFavorite,
    int? discount,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      imageUrls: imageUrls ?? this.imageUrls,
      category: category ?? this.category,
      location: location ?? this.location,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerImage: sellerImage ?? this.sellerImage,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      views: views ?? this.views,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      fullAddress: fullAddress ?? this.fullAddress,
      isFavorite: isFavorite ?? this.isFavorite,
      discount: discount ?? this.discount,
    );
  }

  bool get isAvailable => status == 'available';
  bool get isSoldOut => status == 'sold';
  bool get isReserved => status == 'reserved';
  bool get hasGeoLocation => latitude != null && longitude != null;

  String get distanceText {
    if (distance == null) return 'غير محدد';
    if (distance! < 1) {
      return '${(distance! * 1000).toStringAsFixed(0)} متر';
    }
    return '${distance!.toStringAsFixed(1)} كم';
  }

  bool isOwner(String userId) => sellerId == userId;

  @override
  String toString() {
    return 'Product{id: $id, title: $title, price: $price, seller: $sellerName, hasLocation: $hasGeoLocation}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
