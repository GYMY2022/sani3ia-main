import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class ShareService {
  static Future<void> shareText(String text, {String? subject}) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(
        GlobalKey<NavigatorState>().currentContext!,
      ).showSnackBar(const SnackBar(content: Text('تم نسخ المحتوى للمشاركة')));
    } catch (e) {
      debugPrint('Error sharing text: $e');
    }
  }

  static Future<void> shareViaEmail(String text, {String? subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': subject ?? 'منشور من تطبيق صنايعية',
        'body': text,
      },
    );

    try {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      ScaffoldMessenger.of(
        GlobalKey<NavigatorState>().currentContext!,
      ).showSnackBar(
        const SnackBar(content: Text('تم تحضير المحتوى لمشاركته عبر البريد')),
      );
    } catch (e) {
      debugPrint('Error sharing via email: $e');
    }
  }
}
