import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snae3ya/models/location_model.dart';
import 'package:snae3ya/models/post_model.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String googleMapsApiKey =
      'AIzaSyDinwJW-nruj1jb0IacrxX2U6NuGiLGoek';

  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      print('❌ خطأ في طلب صلاحيات الموقع: $e');
      return false;
    }
  }

  Future<UserLocation> getCurrentLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('تم رفض صلاحيات الموقع');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String address = "جاري تحديد العنوان...";

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final street = placemark.street ?? '';
          final locality = placemark.locality ?? '';
          final administrativeArea = placemark.administrativeArea ?? '';
          final country = placemark.country ?? '';

          address = '$street, $locality, $administrativeArea, $country';
        }
      } catch (e) {
        print('⚠️ خطأ في جلب العنوان: $e');
        address = 'موقع المستخدم';
      }

      return UserLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '',
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        city: '',
        country: '',
        timestamp: DateTime.now(),
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
      );
    } catch (e) {
      print('❌ خطأ في جلب الموقع: $e');
      return UserLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '',
        latitude: 30.0444,
        longitude: 31.2357,
        address: 'موقع افتراضي',
        city: 'القاهرة',
        country: 'مصر',
        timestamp: DateTime.now(),
      );
    }
  }

  Future<void> updateUserLocation(String userId, UserLocation location) async {
    try {
      await _firestore.collection('user_locations').doc(userId).set({
        ...location.toFirestore(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ تم تحديث موقع المستخدم: $userId');
    } catch (e) {
      print('❌ خطأ في تحديث الموقع: $e');
      rethrow;
    }
  }

  Future<List<LatLng>> getRoutePolyline({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      // بديل بسيط بدون polyline_points
      // نحسب مسار خطي بسيط
      final List<LatLng> simpleRoute = [
        origin,
        LatLng(
          (origin.latitude + destination.latitude) / 2,
          (origin.longitude + destination.longitude) / 2,
        ),
        destination,
      ];

      print('✅ تم إنشاء مسار بسيط');
      return simpleRoute;
    } catch (e) {
      print('❌ خطأ في جلب المسار: $e');
      return [origin, destination];
    }
  }

  Future<Map<String, dynamic>> calculateDistanceAndTime({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      double distanceInMeters = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );

      double distanceInKm = distanceInMeters / 1000;

      double estimatedTimeMinutes = (distanceInKm / 30) * 60;

      return {
        'distance': distanceInKm,
        'distanceText': distanceInKm < 1
            ? '${(distanceInKm * 1000).toStringAsFixed(0)} متر'
            : '${distanceInKm.toStringAsFixed(1)} كم',
        'estimatedTime': estimatedTimeMinutes,
        'estimatedTimeText': '${estimatedTimeMinutes.toStringAsFixed(0)} دقيقة',
      };
    } catch (e) {
      print('❌ خطأ في حساب المسافة: $e');
      return {
        'distance': 5.0,
        'distanceText': '5 كم',
        'estimatedTime': 10.0,
        'estimatedTimeText': '10 دقيقة',
      };
    }
  }

  Stream<Position> getLiveLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 20,
      ),
    );
  }

  // ⭐⭐ **جديد: دالة محسنة للبحث عن المنشورات القريبة**
  Future<List<Map<String, dynamic>>> findNearbyPosts({
    required UserLocation userLocation,
    double radiusInKm = 50, // زيادة نصف القطر إلى 50 كم
    String? type, // نوع المنشور (customer أو worker)
    String? category, // التصنيف
  }) async {
    try {
      print('🔍 البحث عن منشورات قريبة من: ${userLocation.address}');
      print(
        '📍 إحداثيات المستخدم: ${userLocation.latitude}, ${userLocation.longitude}',
      );
      print('📏 نصف القطر: $radiusInKm كم');

      // جلب جميع المنشورات النشطة
      Query query = _firestore
          .collection('posts')
          .where('status', isEqualTo: 'open');

      // إضافة فلتر النوع إذا كان موجوداً
      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      final postsSnapshot = await query.limit(100).get();

      print(
        '📊 تم العثور على ${postsSnapshot.docs.length} منشور في قاعدة البيانات',
      );

      List<Map<String, dynamic>> nearbyPosts = [];

      for (var postDoc in postsSnapshot.docs) {
        final postData = postDoc.data() as Map<String, dynamic>?;

        if (postData == null) continue;

        // محاولة استخراج إحداثيات المنشور
        double? postLat;
        double? postLng;

        // البحث عن الإحداثيات في أماكن مختلفة
        if (postData['geoLocation'] != null) {
          final geo = postData['geoLocation'];
          postLat = (geo['latitude'] as num?)?.toDouble();
          postLng = (geo['longitude'] as num?)?.toDouble();
        } else if (postData['latitude'] != null &&
            postData['longitude'] != null) {
          postLat = (postData['latitude'] as num).toDouble();
          postLng = (postData['longitude'] as num).toDouble();
        }

        // حساب المسافة إذا كانت الإحداثيات موجودة
        double distance = 999999.0; // قيمة كبيرة جداً للمنشورات بدون إحداثيات

        if (postLat != null && postLng != null) {
          distance =
              Geolocator.distanceBetween(
                userLocation.latitude,
                userLocation.longitude,
                postLat,
                postLng,
              ) /
              1000; // تحويل إلى كيلومتر
        }

        // إضافة المنشور إذا كان ضمن نصف القطر أو إذا كانت المسافة محسوبة
        if (distance <= radiusInKm) {
          nearbyPosts.add({
            'post': postData,
            'postId': postDoc.id,
            'distance': distance,
            'hasLocation': postLat != null && postLng != null,
          });
        }
      }

      // ترتيب المنشورات حسب المسافة (الأقرب أولاً)
      nearbyPosts.sort((a, b) {
        // المنشورات ذات الموقع تأتي أولاً
        if (a['hasLocation'] && !b['hasLocation']) return -1;
        if (!a['hasLocation'] && b['hasLocation']) return 1;
        // ثم ترتيب حسب المسافة
        return a['distance'].compareTo(b['distance']);
      });

      print('✅ تم العثور على ${nearbyPosts.length} منشور قريب');
      for (var i = 0; i < nearbyPosts.length && i < 5; i++) {
        final post = nearbyPosts[i];
        final title = post['post']['title'] ?? 'بدون عنوان';
        final dist = post['distance'] == 999999.0
            ? 'غير محدد'
            : '${post['distance'].toStringAsFixed(2)} كم';
        print('   ${i + 1}. $title - المسافة: $dist');
      }

      return nearbyPosts;
    } catch (e) {
      print('❌ خطأ في البحث عن شغلانات قريبة: $e');
      return [];
    }
  }

  // ⭐⭐ **جديد: دالة لحساب المسافة بين نقطتين**
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  // ⭐⭐ **جديد: دالة لترتيب قائمة المنشورات حسب المسافة**
  List<Post> sortPostsByDistance({
    required List<Post> posts,
    required double userLat,
    required double userLon,
  }) {
    final List<Post> sortedPosts = List.from(posts);

    for (var post in sortedPosts) {
      if (post.geoLocation != null) {
        final postLat = post.geoLocation!['latitude'] as double?;
        final postLon = post.geoLocation!['longitude'] as double?;

        if (postLat != null && postLon != null) {
          post.distance = calculateDistance(
            lat1: userLat,
            lon1: userLon,
            lat2: postLat,
            lon2: postLon,
          );
        }
      }
    }

    sortedPosts.sort((a, b) {
      // المنشورات ذات المسافة المحددة تأتي أولاً
      if (a.distance != null && b.distance == null) return -1;
      if (a.distance == null && b.distance != null) return 1;
      if (a.distance == null && b.distance == null) return 0;
      return a.distance!.compareTo(b.distance!);
    });

    return sortedPosts;
  }

  Future<String> startLiveTracking({
    required String postId,
    required String clientId,
    required String workerId,
    required UserLocation clientLocation,
    required UserLocation workerLocation,
  }) async {
    try {
      final sessionId = 'track_${DateTime.now().millisecondsSinceEpoch}';

      final distanceInfo = await calculateDistanceAndTime(
        origin: LatLng(workerLocation.latitude, workerLocation.longitude),
        destination: LatLng(clientLocation.latitude, clientLocation.longitude),
      );

      final trackingSession = LiveTrackingSession(
        id: sessionId,
        postId: postId,
        clientId: clientId,
        workerId: workerId,
        startTime: DateTime.now(),
        workerPath: [workerLocation],
        clientLocation: clientLocation,
        workerStartLocation: workerLocation,
        totalDistance: distanceInfo['distance'],
        estimatedDuration: distanceInfo['estimatedTime'],
      );

      await _firestore
          .collection('live_tracking_sessions')
          .doc(sessionId)
          .set(trackingSession.toFirestore());

      print('✅ بدأت جلسة المتابعة: $sessionId');
      print('📏 المسافة: ${distanceInfo['distanceText']}');
      print('⏰ الوقت المتوقع: ${distanceInfo['estimatedTimeText']}');

      return sessionId;
    } catch (e) {
      print('❌ خطأ في بدء المتابعة الحية: $e');
      return 'temp_track_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<LiveTrackingSession?> getLiveTrackingSession(String sessionId) async {
    try {
      final doc = await _firestore
          .collection('live_tracking_sessions')
          .doc(sessionId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return LiveTrackingSession.fromFirestore(data);
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب جلسة المتابعة: $e');
      return null;
    }
  }

  Future<void> updateWorkerLocation(
    String sessionId,
    UserLocation workerLocation,
  ) async {
    try {
      await _firestore
          .collection('live_tracking_sessions')
          .doc(sessionId)
          .update({
            'workerPath': FieldValue.arrayUnion([workerLocation.toFirestore()]),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      print('📍 تم تحديث موقع العامل في جلسة: $sessionId');
    } catch (e) {
      print('❌ خطأ في تحديث موقع العامل: $e');
      rethrow;
    }
  }

  Future<void> endLiveTracking(String sessionId) async {
    try {
      await _firestore
          .collection('live_tracking_sessions')
          .doc(sessionId)
          .update({
            'endTime': DateTime.now(),
            'status': 'completed',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      print('✅ تم إنهاء جلسة المتابعة: $sessionId');
    } catch (e) {
      print('❌ خطأ في إنهاء المتابعة: $e');
      rethrow;
    }
  }

  Future<UserLocation?> getUserLocation(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_locations')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return UserLocation.fromFirestore(data);
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب موقع المستخدم: $e');
      return null;
    }
  }
}

class LiveTrackingSession {
  final String id;
  final String postId;
  final String clientId;
  final String workerId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<UserLocation> workerPath;
  final UserLocation clientLocation;
  final UserLocation workerStartLocation;
  final double totalDistance;
  final double estimatedDuration;
  final String status;

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
    required this.totalDistance,
    required this.estimatedDuration,
    this.status = 'active',
  });

  factory LiveTrackingSession.fromFirestore(Map<String, dynamic> data) {
    List<UserLocation> workerPath = [];

    if (data['workerPath'] != null && data['workerPath'] is List) {
      workerPath = (data['workerPath'] as List).map((item) {
        return UserLocation.fromFirestore(Map<String, dynamic>.from(item));
      }).toList();
    }

    return LiveTrackingSession(
      id: data['id']?.toString() ?? '',
      postId: data['postId']?.toString() ?? '',
      clientId: data['clientId']?.toString() ?? '',
      workerId: data['workerId']?.toString() ?? '',
      startTime: data['startTime'] != null
          ? (data['startTime'] as Timestamp).toDate()
          : DateTime.now(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      workerPath: workerPath,
      clientLocation: UserLocation.fromFirestore(
        Map<String, dynamic>.from(data['clientLocation'] ?? {}),
      ),
      workerStartLocation: UserLocation.fromFirestore(
        Map<String, dynamic>.from(data['workerStartLocation'] ?? {}),
      ),
      totalDistance: (data['totalDistance'] as num?)?.toDouble() ?? 0.0,
      estimatedDuration: (data['estimatedDuration'] as num?)?.toDouble() ?? 0.0,
      status: data['status']?.toString() ?? 'active',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'postId': postId,
      'clientId': clientId,
      'workerId': workerId,
      'startTime': Timestamp.fromDate(startTime),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime!),
      'workerPath': workerPath.map((loc) => loc.toFirestore()).toList(),
      'clientLocation': clientLocation.toFirestore(),
      'workerStartLocation': workerStartLocation.toFirestore(),
      'totalDistance': totalDistance,
      'estimatedDuration': estimatedDuration,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
