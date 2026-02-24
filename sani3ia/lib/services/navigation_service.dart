import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  // فتح خرائط جوجل للملاحة إلى وجهة
  static Future<void> openGoogleMapsNavigation({
    required double destLat,
    required double destLng,
    String? destName,
  }) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng${destName != null ? '&destination_place_id=$destName' : ''}';

    final Uri uri = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('🗺️ تم فتح خرائط جوجل للملاحة');
      } else {
        throw Exception('لا يمكن فتح خرائط جوجل');
      }
    } catch (e) {
      print('❌ خطأ في فتح الملاحة: $e');

      final browserUrl =
          'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng';
      final browserUri = Uri.parse(browserUrl);

      if (await canLaunchUrl(browserUri)) {
        await launchUrl(browserUri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('لا يمكن فتح الملاحة');
      }
    }
  }

  // فتح خرائط جوجل لعرض موقع محدد
  static Future<void> openGoogleMapsAtLocation({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final String url =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final Uri uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('🗺️ تم فتح الموقع في خرائط جوجل');
      } else {
        throw Exception('لا يمكن فتح الموقع');
      }
    } catch (e) {
      print('❌ خطأ في فتح الموقع: $e');

      final browserUrl =
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final browserUri = Uri.parse(browserUrl);

      if (await canLaunchUrl(browserUri)) {
        await launchUrl(browserUri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('لا يمكن فتح الموقع');
      }
    }
  }

  // فتح ويز (Waze) للملاحة
  static Future<void> openWazeNavigation({
    required double destLat,
    required double destLng,
  }) async {
    final String wazeUrl = 'waze://?ll=$destLat,$destLng&navigate=yes';
    final Uri wazeUri = Uri.parse(wazeUrl);

    try {
      if (await canLaunchUrl(wazeUri)) {
        await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
        print('🗺️ تم فتح ويز للملاحة');
        return;
      }
    } catch (e) {
      print('⚠️ لم يتم العثور على تطبيق ويز: $e');
    }

    await openGoogleMapsNavigation(destLat: destLat, destLng: destLng);
  }
}
