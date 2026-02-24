class Order {
  final String id;
  final String postTitle;
  final String craftsmanName;
  final String craftsmanImage;
  final double agreedPrice;
  final DateTime arrivalDate;
  final String location;
  OrderStatus status;
  LiveLocation? craftsmanLocation;
  double? rating;

  Order({
    required this.id,
    required this.postTitle,
    required this.craftsmanName,
    required this.craftsmanImage,
    required this.agreedPrice,
    required this.arrivalDate,
    required this.location,
    required this.status,
    this.craftsmanLocation,
    this.rating,
  });

  // ⭐ إضافة copyWith لـ Order
  Order copyWith({
    String? id,
    String? postTitle,
    String? craftsmanName,
    String? craftsmanImage,
    double? agreedPrice,
    DateTime? arrivalDate,
    String? location,
    OrderStatus? status,
    LiveLocation? craftsmanLocation,
    double? rating,
  }) {
    return Order(
      id: id ?? this.id,
      postTitle: postTitle ?? this.postTitle,
      craftsmanName: craftsmanName ?? this.craftsmanName,
      craftsmanImage: craftsmanImage ?? this.craftsmanImage,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      location: location ?? this.location,
      status: status ?? this.status,
      craftsmanLocation: craftsmanLocation ?? this.craftsmanLocation,
      rating: rating ?? this.rating,
    );
  }
}

class LiveLocation {
  final double lat;
  final double lng;

  const LiveLocation({required this.lat, required this.lng});

  // ⭐ إضافة copyWith لـ LiveLocation
  LiveLocation copyWith({double? lat, double? lng}) {
    return LiveLocation(lat: lat ?? this.lat, lng: lng ?? this.lng);
  }
}

enum OrderStatus {
  confirmed, // تم التأكيد
  inProgress, // قيد التنفيذ
  completed, // مكتمل
  cancelled, // ملغي
}
