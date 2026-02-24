import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/models/location_model.dart';
import 'package:snae3ya/services/location_service.dart' as location_service;

class LiveTrackingProvider with ChangeNotifier {
  final location_service.LocationService _locationService =
      location_service.LocationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  LiveTrackingSession? _currentSession;
  bool _isLoading = false;
  String _error = '';
  Timer? _locationUpdateTimer;
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;

  LiveTrackingSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  String get error => _error;

  // بدء جلسة تتبع جديدة
  Future<String> startTracking({
    required String postId,
    required String clientId,
    required String workerId,
    required UserLocation clientLocation,
    required UserLocation workerLocation,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final sessionId = await _locationService.startLiveTracking(
        postId: postId,
        clientId: clientId,
        workerId: workerId,
        clientLocation: clientLocation,
        workerLocation: workerLocation,
      );

      _listenToSession(sessionId);

      final currentUser = _auth.currentUser;
      if (currentUser?.uid == workerId) {
        _startWorkerLocationUpdates(sessionId);
      }

      return sessionId;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _listenToSession(String sessionId) {
    _sessionSubscription = _firestore
        .collection('live_tracking_sessions')
        .doc(sessionId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              _currentSession = LiveTrackingSession.fromFirestore(
                snapshot.data()!,
              );
              notifyListeners();
            }
          },
          onError: (error) {
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  void _startWorkerLocationUpdates(String sessionId) {
    _locationUpdateTimer?.cancel();

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      try {
        final currentLocation = await _locationService.getCurrentLocation();
        await _locationService.updateWorkerLocation(sessionId, currentLocation);
      } catch (e) {
        print('❌ خطأ في تحديث موقع العامل: $e');
      }
    });
  }

  Future<void> endTracking(String sessionId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _locationService.endLiveTracking(sessionId);
      _stopUpdates();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _stopUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _currentSession = null;
  }

  @override
  void dispose() {
    _stopUpdates();
    super.dispose();
  }
}
