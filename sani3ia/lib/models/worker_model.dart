class Worker {
  final String id;
  final String userId;
  final String name;
  final String profession;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final String location;
  final String phone;
  final String description;
  final double? latitude;
  final double? longitude;
  final String? bio; // ⭐⭐ إضافة حقل bio

  Worker({
    required this.id,
    required this.userId,
    required this.name,
    required this.profession,
    required this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.phone,
    required this.description,
    this.latitude,
    this.longitude,
    this.bio, // ⭐⭐ إضافة حقل bio
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'profession': profession,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'location': location,
      'phone': phone,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'bio': bio, // ⭐⭐ إضافة حقل bio
    };
  }

  factory Worker.fromMap(Map<String, dynamic> map, String documentId) {
    return Worker(
      id: documentId,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      profession: map['profession'] ?? '',
      imageUrl: map['profileImage'] ?? 'assets/images/default_profile.png',
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      location:
          map['location']?['fullAddress'] ?? map['address'] ?? 'موقع غير محدد',
      phone: map['phone'] ?? '',
      description: map['description'] ?? '',
      latitude: map['latitude'] ?? map['location']?['latitude'],
      longitude: map['longitude'] ?? map['location']?['longitude'],
      bio: map['bio'], // ⭐⭐ إضافة حقل bio
    );
  }
}
