// provider_coordinator.dart
import 'package:flutter/foundation.dart';
import 'package:snae3ya/providers/user_provider.dart';
import 'package:snae3ya/providers/chat_provider.dart';
import 'package:snae3ya/providers/application_provider.dart';
import 'package:snae3ya/providers/post_provider.dart';

class ProviderCoordinator with ChangeNotifier {
  static final ProviderCoordinator _instance = ProviderCoordinator._internal();
  factory ProviderCoordinator() => _instance;
  ProviderCoordinator._internal();

  UserProvider? _userProvider;
  ChatProvider? _chatProvider;
  ApplicationProvider? _applicationProvider;
  PostProvider? _postProvider;

  void registerProviders({
    required UserProvider userProvider,
    required ChatProvider chatProvider,
    required ApplicationProvider applicationProvider,
    required PostProvider postProvider,
  }) {
    _userProvider = userProvider;
    _chatProvider = chatProvider;
    _applicationProvider = applicationProvider;
    _postProvider = postProvider;
  }

  Future<void> stopAllProviders() async {
    print('🛑 تنسيق إيقاف جميع الـ providers...');

    // إيقاف الـ providers بالترتيب
    _chatProvider?.stopAllListeners();
    _applicationProvider?.stopAllListeners();
    _postProvider?.stopAllListeners();

    // إعطاء وقت للإيقاف
    await Future.delayed(const Duration(milliseconds: 500));

    print('✅ تم إيقاف جميع الـ providers بنجاح');
  }
}
