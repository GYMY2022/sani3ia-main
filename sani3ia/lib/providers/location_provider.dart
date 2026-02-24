import 'package:flutter/material.dart';
import 'package:snae3ya/services/location_service.dart';
import 'package:snae3ya/models/location_model.dart';

class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  UserLocation? _currentLocation;
  bool _isLoading = false;
  bool _hasPermission = false;

  UserLocation? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;

  Future<void> initializeLocation() async {
    try {
      _isLoading = true;
      notifyListeners();

      _hasPermission = await _locationService.requestLocationPermission();

      if (_hasPermission) {
        _currentLocation = await _locationService.getCurrentLocation();
      }
    } catch (e) {
      print('❌ خطأ في تهيئة الموقع: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLocation() async {
    if (!_hasPermission) return;

    try {
      _currentLocation = await _locationService.getCurrentLocation();
      notifyListeners();
    } catch (e) {
      print('❌ خطأ في تحديث الموقع: $e');
    }
  }

  Future<void> updateUserLocation(String userId) async {
    if (_currentLocation == null) return;

    try {
      final location = _currentLocation!.copyWith(
        userId: userId,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      await _locationService.updateUserLocation(userId, location);
    } catch (e) {
      print('❌ خطأ في تحديث موقع المستخدم: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyPosts(double radius) async {
    if (_currentLocation == null) return [];

    try {
      return await _locationService.findNearbyPosts(
        userLocation: _currentLocation!,
        radiusInKm: radius,
      );
    } catch (e) {
      print('❌ خطأ في جلب المنشورات القريبة: $e');
      return [];
    }
  }
}
