import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:snae3ya/services/location_service.dart';
import 'package:snae3ya/models/location_model.dart';

class LocationPickerScreen extends StatefulWidget {
  final bool isRegistration;

  const LocationPickerScreen({super.key, this.isRegistration = true});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final LocationService _locationService = LocationService();
  late GoogleMapController _mapController;
  UserLocation? _currentLocation;
  LatLng? _selectedLocation;
  bool _isLoading = true;
  String _address = '';
  bool _mapCreated = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);

      _currentLocation = await _locationService.getCurrentLocation();
      _selectedLocation = LatLng(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      setState(() {
        _isLoading = false;
        _address = _currentLocation!.address;
      });

      if (_mapCreated && _selectedLocation != null) {
        _moveToLocation(_selectedLocation!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('فشل في تحديد الموقع: $e');
    }
  }

  void _moveToLocation(LatLng location) {
    if (_mapController != null) {
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(location, 15.0));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapCreated = true;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (_selectedLocation != null && mounted) {
        _moveToLocation(_selectedLocation!);
      }
    });
  }

  void _onMapTap(LatLng location) async {
    if (_isLoading) return;

    setState(() {
      _selectedLocation = location;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final street = placemark.street ?? '';
        final locality = placemark.locality ?? '';
        final administrativeArea = placemark.administrativeArea ?? '';
        final country = placemark.country ?? '';

        setState(() {
          _address = '$street, $locality, $administrativeArea, $country';
        });
      }
    } catch (e) {
      print('❌ خطأ في جلب العنوان: $e');
      setState(() {
        _address =
            'الموقع: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
      });
    }
  }

  Future<void> _confirmLocation() async {
    if (_selectedLocation == null) {
      _showSnackBar('الرجاء تحديد موقع على الخريطة');
      return;
    }

    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final userLocation = UserLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '',
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        address: _address.isNotEmpty ? _address : 'موقع غير محدد',
        city: '',
        country: '',
        timestamp: DateTime.now(),
      );

      Navigator.pop(context, userLocation);
    } catch (e) {
      _showSnackBar('فشل في حفظ الموقع: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isRegistration ? 'تحديد موقعك الجغرافي' : 'تحديد موقع جديد',
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _selectedLocation ?? const LatLng(30.0444, 31.2357),
              zoom: 12.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onTap: _onMapTap,
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _selectedLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                      infoWindow: InfoWindow(
                        title: 'موقعك المحدد',
                        snippet: _address,
                      ),
                    ),
                  }
                : {},
            mapType: MapType.normal,
            minMaxZoomPreference: const MinMaxZoomPreference(10.0, 20.0),
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: false,
            zoomGesturesEnabled: true,
          ),

          Positioned(
            bottom: 200,
            right: 16,
            child: FloatingActionButton(
              onPressed: _isLoading ? null : _getCurrentLocation,
              child: const Icon(Icons.my_location),
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              heroTag: 'location_fab',
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isRegistration ? 'موقعك الجغرافي' : 'الموقع المحدد',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_address.isNotEmpty)
                    Text(
                      _address,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    const Text(
                      'انقر على الخريطة لتحديد موقعك',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _confirmLocation,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF782DCE),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'تأكيد الموقع',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
