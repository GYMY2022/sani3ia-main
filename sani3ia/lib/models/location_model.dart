import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class UserLocation {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String country;
  final DateTime timestamp;
  final double? accuracy;
  final bool isActive;
  final double? speed; // السرعة بالمتر/ثانية
  final double? heading; // الاتجاه بالدرجات

  UserLocation({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.country,
    required this.timestamp,
    this.accuracy,
    this.isActive = true,
    this.speed,
    this.heading,
  });

  factory UserLocation.fromFirestore(Map<String, dynamic> data) {
    return UserLocation(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      country: data['country'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      isActive: data['isActive'] ?? true,
      speed: (data['speed'] as num?)?.toDouble(),
      heading: (data['heading'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'country': country,
      'timestamp': timestamp,
      'accuracy': accuracy,
      'isActive': isActive,
      'speed': speed,
      'heading': heading,
    };
  }

  // ⭐⭐ **إضافة دالة copyWith المطلوبة**
  UserLocation copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? country,
    DateTime? timestamp,
    double? accuracy,
    bool? isActive,
    double? speed,
    double? heading,
  }) {
    return UserLocation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      isActive: isActive ?? this.isActive,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
    );
  }

  // حساب المسافة بين موقعين (بالكيلومتر)
  double distanceTo(UserLocation other) {
    const double earthRadius = 6371; // نصف قطر الأرض بالكيلومتر

    double lat1 = _toRadians(latitude);
    double lon1 = _toRadians(longitude);
    double lat2 = _toRadians(other.latitude);
    double lon2 = _toRadians(other.longitude);

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // تقدير وقت الوصول (بالدقائق)
  double estimateArrivalTime(UserLocation destination, {double? averageSpeed}) {
    double distance = distanceTo(destination);
    double speed = averageSpeed ?? (this.speed ?? 20); // 20 كم/س افتراضياً

    if (speed <= 0) return 0;

    return (distance / speed) * 60; // تحويل إلى دقائق
  }

  String get distanceText {
    // هذه الدالة تحتاج تعديل
    return 'غير محسوبة';
  }
}

class LiveTrackingSession {
  final String id;
  final String postId;
  final String clientId;
  final String workerId;
  final DateTime startTime;
  DateTime? endTime;
  final List<UserLocation> workerPath;
  final UserLocation clientLocation;
  final UserLocation workerStartLocation;
  final String status; // active, completed, cancelled
  final double totalDistance;
  final double estimatedDuration;
  final double? actualDuration;

  LiveTrackingSession({
    required this.id,
    required this.postId,
    required this.clientId,
    required this.workerId,
    required this.startTime,
    this.endTime,
    required this.workerPath,
    required this.clientLocation,
    required this.workerStartLocation,
    this.status = 'active',
    required this.totalDistance,
    required this.estimatedDuration,
    this.actualDuration,
  });

  // احتساب الوقت المتبقي للوصول
  double get remainingTime {
    if (workerPath.isEmpty) return estimatedDuration;

    final lastLocation = workerPath.last;
    final remainingDistance = lastLocation.distanceTo(clientLocation);
    final avgSpeed = _calculateAverageSpeed();

    if (avgSpeed <= 0) return estimatedDuration;

    return (remainingDistance / avgSpeed) * 60;
  }

  double _calculateAverageSpeed() {
    if (workerPath.length < 2) return 20; // 20 كم/س افتراضياً

    double totalSpeed = 0;
    int count = 0;

    for (var location in workerPath) {
      if (location.speed != null) {
        totalSpeed += location.speed!;
        count++;
      }
    }

    return count > 0 ? totalSpeed / count : 20;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'postId': postId,
      'clientId': clientId,
      'workerId': workerId,
      'startTime': startTime,
      'endTime': endTime,
      'workerPath': workerPath.map((loc) => loc.toFirestore()).toList(),
      'clientLocation': clientLocation.toFirestore(),
      'workerStartLocation': workerStartLocation.toFirestore(),
      'status': status,
      'totalDistance': totalDistance,
      'estimatedDuration': estimatedDuration,
      'actualDuration': actualDuration,
    };
  }

  factory LiveTrackingSession.fromFirestore(Map<String, dynamic> data) {
    return LiveTrackingSession(
      id: data['id'] ?? '',
      postId: data['postId'] ?? '',
      clientId: data['clientId'] ?? '',
      workerId: data['workerId'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      workerPath: (data['workerPath'] as List)
          .map((item) => UserLocation.fromFirestore(item))
          .toList(),
      clientLocation: UserLocation.fromFirestore(data['clientLocation']),
      workerStartLocation: UserLocation.fromFirestore(
        data['workerStartLocation'],
      ),
      status: data['status'] ?? 'active',
      totalDistance: (data['totalDistance'] as num).toDouble(),
      estimatedDuration: (data['estimatedDuration'] as num).toDouble(),
      actualDuration: (data['actualDuration'] as num?)?.toDouble(),
    );
  }
}
