import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:snae3ya/services/location_service.dart';
import 'package:snae3ya/models/location_model.dart';
import 'package:snae3ya/services/navigation_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String sessionId;
  final String? postId;
  final String clientId;
  final String workerId;
  final String userName;

  const LiveTrackingScreen({
    super.key,
    required this.sessionId,
    this.postId,
    required this.clientId,
    required this.workerId,
    required this.userName,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  late GoogleMapController _mapController;
  final LocationService _locationService = LocationService();
  LatLng? _clientLocation;
  LatLng? _workerLocation;
  List<LatLng> _routePolyline = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Timer? _updateTimer;
  double _remainingDistance = 0;
  double _remainingTime = 0;
  bool _isWorker = false;
  Map<String, dynamic>? _trackingSession;
  bool _isLoading = true;
  bool _mapReady = false;
  double _workerSpeed = 0;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _initializeTracking();
  }

  void _checkUserRole() {
    final currentUser = FirebaseAuth.instance.currentUser;
    _isWorker = currentUser?.uid == widget.workerId;
    print('👤 دور المستخدم: ${_isWorker ? 'عامل' : 'عميل'}');
  }

  void _initializeTracking() async {
    try {
      await _loadTrackingSession();
      _startTracking();
    } catch (e) {
      print('❌ خطأ في تهيئة المتابعة: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startTracking() {
    _updateLocations();
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateLocations();
    });
  }

  Future<void> _loadTrackingSession() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('live_tracking_sessions')
          .doc(widget.sessionId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _trackingSession = doc.data();
        });
        print('✅ تم تحميل جلسة المتابعة');
      }
    } catch (e) {
      print('❌ خطأ في جلب جلسة المتابعة: $e');
    }
  }

  Future<void> _updateLocations() async {
    if (_isUpdating || !mounted) return;
    _isUpdating = true;

    try {
      // جلب موقع العميل
      final clientLocationDoc = await FirebaseFirestore.instance
          .collection('user_locations')
          .doc(widget.clientId)
          .get();

      if (clientLocationDoc.exists) {
        final data = clientLocationDoc.data();
        if (data != null &&
            data['latitude'] != null &&
            data['longitude'] != null) {
          final newClientLocation = LatLng(
            (data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble(),
          );

          if (mounted) {
            setState(() {
              _clientLocation = newClientLocation;
            });
          }
        }
      }

      // جلب موقع العامل
      final workerLocationDoc = await FirebaseFirestore.instance
          .collection('user_locations')
          .doc(widget.workerId)
          .get();

      if (workerLocationDoc.exists) {
        final data = workerLocationDoc.data();
        if (data != null &&
            data['latitude'] != null &&
            data['longitude'] != null) {
          final newWorkerLocation = LatLng(
            (data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble(),
          );

          if (mounted) {
            setState(() {
              if (data['speed'] != null) {
                _workerSpeed = (data['speed'] as num).toDouble();
              }
              _workerLocation = newWorkerLocation;
            });
            print('📍 تم تحديث موقع العامل');
          }
        } else {
          print('⚠️ بيانات موقع العامل غير مكتملة');
        }
      } else {
        print('⚠️ لا توجد بيانات موقع للعامل: ${widget.workerId}');
      }

      _updateMarkers();

      if (_clientLocation != null && _workerLocation != null) {
        _updateRoute();
        _calculateRemaining();
      }

      if (_isWorker && _workerLocation != null) {
        await _updateWorkerLocation();
      }

      if (_mapReady && mounted) {
        _updateMapView();
      }
    } catch (e) {
      print('❌ خطأ في تحديث المواقع: $e');
    } finally {
      _isUpdating = false;
    }
  }

  Future<void> _updateWorkerLocation() async {
    try {
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      final workerLocation = UserLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: widget.workerId,
        latitude: _workerLocation!.latitude,
        longitude: _workerLocation!.longitude,
        address: '',
        city: '',
        country: '',
        timestamp: DateTime.now(),
        speed: currentPosition.speed,
        heading: currentPosition.heading,
      );

      await FirebaseFirestore.instance
          .collection('live_tracking_sessions')
          .doc(widget.sessionId)
          .update({
            'workerPath': FieldValue.arrayUnion([workerLocation.toFirestore()]),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastWorkerLocation': {
              'latitude': _workerLocation!.latitude,
              'longitude': _workerLocation!.longitude,
              'speed': currentPosition.speed,
              'heading': currentPosition.heading,
              'timestamp': DateTime.now(),
            },
          });

      print('📍 تم تحديث موقع العامل في Firebase');
    } catch (e) {
      print('❌ خطأ في تحديث موقع العامل: $e');
    }
  }

  void _updateMarkers() {
    if (!mounted) return;

    final newMarkers = <Marker>{};

    if (_clientLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('client'),
          position: _clientLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'موقع العميل',
            snippet: _isWorker ? 'وجهتك' : 'موقعك',
          ),
          zIndex: 1,
        ),
      );
    }

    if (_workerLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('worker'),
          position: _workerLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _isWorker ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: _isWorker ? 'أنت' : 'الصنايعي',
            snippet: _workerSpeed > 0
                ? 'السرعة: ${(_workerSpeed * 3.6).toStringAsFixed(1)} كم/س'
                : null,
          ),
          zIndex: 2,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  Future<void> _updateRoute() async {
    if (_clientLocation == null || _workerLocation == null) return;

    try {
      _routePolyline = await _locationService.getRoutePolyline(
        origin: _workerLocation!,
        destination: _clientLocation!,
      );

      final newPolylines = <Polyline>{};
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePolyline,
          color: Colors.blue,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );

      if (mounted) {
        setState(() {
          _polylines = newPolylines;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحديث المسار: $e');
    }
  }

  void _calculateRemaining() {
    if (_clientLocation == null || _workerLocation == null) return;

    final distance = Geolocator.distanceBetween(
      _workerLocation!.latitude,
      _workerLocation!.longitude,
      _clientLocation!.latitude,
      _clientLocation!.longitude,
    );

    double speed = _workerSpeed > 0 ? _workerSpeed : 8.33;
    double timeInSeconds = distance / speed;
    double timeInMinutes = timeInSeconds / 60;

    if (mounted) {
      setState(() {
        _remainingDistance = distance / 1000;
        _remainingTime = timeInMinutes;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapReady = true;

    Future.delayed(const Duration(milliseconds: 300), () {
      _updateMapView();
    });
  }

  void _updateMapView() {
    if (_clientLocation != null && _workerLocation != null && _mapReady) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _clientLocation!.latitude < _workerLocation!.latitude
              ? _clientLocation!.latitude
              : _workerLocation!.latitude,
          _clientLocation!.longitude < _workerLocation!.longitude
              ? _clientLocation!.longitude
              : _workerLocation!.longitude,
        ),
        northeast: LatLng(
          _clientLocation!.latitude > _workerLocation!.latitude
              ? _clientLocation!.latitude
              : _workerLocation!.latitude,
          _clientLocation!.longitude > _workerLocation!.longitude
              ? _clientLocation!.longitude
              : _workerLocation!.longitude,
        ),
      );

      _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
    } else if (_clientLocation != null && _mapReady) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_clientLocation!, 15.0),
      );
    } else if (_workerLocation != null && _mapReady) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_workerLocation!, 15.0),
      );
    }
  }

  Future<void> _endTracking() async {
    try {
      await FirebaseFirestore.instance
          .collection('live_tracking_sessions')
          .doc(widget.sessionId)
          .update({
            'endTime': DateTime.now(),
            'status': 'completed',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      print('✅ تم إنهاء جلسة المتابعة');
    } catch (e) {
      print('❌ خطأ في إنهاء المتابعة: $e');
    }

    _updateTimer?.cancel();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ⭐⭐ دالة فتح الملاحة المعدلة - مع تحسين التعامل مع موقع العامل
  Future<void> _openNavigation() async {
    print('📍 محاولة فتح الملاحة...');
    print('   - موقع العميل: $_clientLocation');
    print('   - موقع العامل: $_workerLocation');
    print('   - هل أنا عامل: $_isWorker');

    if (_isWorker) {
      // العامل يريد الذهاب إلى العميل
      if (_clientLocation == null) {
        // إذا لم يكن موقع العميل متاحاً، استخدم موقع العامل نفسه كبداية
        if (_workerLocation != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('جاري تحميل موقع العميل... سيتم التحديث تلقائياً'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('موقع العميل غير متاح حالياً. يرجى الانتظار.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        // فتح خرائط جوجل للملاحة إلى موقع العميل
        await NavigationService.openGoogleMapsNavigation(
          destLat: _clientLocation!.latitude,
          destLng: _clientLocation!.longitude,
          destName: widget.userName,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في فتح الملاحة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // العميل يريد متابعة الصنايعي
      if (_workerLocation == null) {
        // إذا لم يكن موقع العامل متاحاً، استخدم موقع العميل نفسه
        if (_clientLocation != null) {
          try {
            await NavigationService.openGoogleMapsAtLocation(
              lat: _clientLocation!.latitude,
              lng: _clientLocation!.longitude,
              label: 'موقعك الحالي',
            );

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'موقع الصنايعي غير متاح، تم عرض موقعك بدلاً من ذلك',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          } catch (e) {
            print('❌ خطأ في فتح الموقع: $e');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري تحميل موقع الصنايعي... يرجى الانتظار.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        // فتح خرائط جوجل لعرض موقع الصنايعي
        await NavigationService.openGoogleMapsAtLocation(
          lat: _workerLocation!.latitude,
          lng: _workerLocation!.longitude,
          label: 'موقع الصنايعي',
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في فتح الموقع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('متابعة ${widget.userName}'),
        centerTitle: true,
        actions: [
          if (!_isWorker)
            IconButton(
              icon: const Icon(Icons.directions),
              onPressed: _openNavigation,
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(30.0444, 31.2357),
              zoom: 12.0,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            compassEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: false,
            zoomGesturesEnabled: true,
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'المسافة المتبقية:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _remainingDistance < 1
                            ? '${(_remainingDistance * 1000).toStringAsFixed(0)} متر'
                            : '${_remainingDistance.toStringAsFixed(1)} كم',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الوقت المتوقع:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_remainingTime.toStringAsFixed(0)} دقيقة',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  if (_workerSpeed > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'السرعة:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(_workerSpeed * 3.6).toStringAsFixed(1)} كم/س',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openNavigation,
                    icon: const Icon(Icons.navigation),
                    label: const Text('فتح الملاحة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _endTracking,
                    icon: const Icon(Icons.cancel),
                    label: const Text('إنهاء المتابعة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isWorker)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: Text(
                  '⚠️ أنت في وضع المتابعة. العميل يمكنه رؤية موقعك الآن.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.amber.shade900),
                ),
              ),
            ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
