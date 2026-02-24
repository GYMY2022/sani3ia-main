import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snae3ya/models/location_model.dart';

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
