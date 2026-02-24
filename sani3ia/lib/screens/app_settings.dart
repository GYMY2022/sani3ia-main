import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart'; // ← مهم علشان kIsWeb

class AppSettingsScreen extends StatefulWidget {
  final Function(bool)? onDarkModeChanged;

  const AppSettingsScreen({super.key, this.onDarkModeChanged});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _isDarkMode = false;
  String _selectedLanguage = 'العربية';
  bool _notificationsEnabled = true;
  bool _biometricAuthEnabled = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  final List<Map<String, dynamic>> _supportedLanguages = [
    {'name': 'العربية', 'code': 'ar', 'locale': const Locale('ar')},
    {'name': 'English', 'code': 'en', 'locale': const Locale('en')},
    {'name': 'Español', 'code': 'es', 'locale': const Locale('es')},
    {'name': 'Français', 'code': 'fr', 'locale': const Locale('fr')},
    {'name': 'Deutsch', 'code': 'de', 'locale': const Locale('de')},
    {'name': '中文', 'code': 'zh', 'locale': const Locale('zh')},
    {'name': '日本語', 'code': 'ja', 'locale': const Locale('ja')},
    {'name': 'Русский', 'code': 'ru', 'locale': const Locale('ru')},
    {'name': 'Português', 'code': 'pt', 'locale': const Locale('pt')},
    {'name': 'हिन्दी', 'code': 'hi', 'locale': const Locale('hi')},
  ];

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    if (kIsWeb) return;

    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    bool isDeviceSupported = await _localAuth.isDeviceSupported();
    if (!canCheckBiometrics || !isDeviceSupported) {
      setState(() {
        _biometricAuthEnabled = false;
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المصادقة البيومترية غير مدعومة على الويب'),
        ),
      );
      return;
    }

    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'تمكين المصادقة البيومترية',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      setState(() {
        _biometricAuthEnabled = authenticated;
      });
    } catch (e) {
      setState(() {
        _biometricAuthEnabled = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التحقق: $e')));
    }
  }

  Future<void> _requestNotificationPermission() async {
    // يمكن استخدام permission_handler هنا لاحقاً
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات التطبيق'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المظهر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('الوضع الداكن'),
              value: _isDarkMode,
              onChanged: (value) {
                setState(() {
                  _isDarkMode = value;
                });
                if (widget.onDarkModeChanged != null) {
                  widget.onDarkModeChanged!(value);
                }
              },
            ),
            const Divider(),
            const Text(
              'اللغة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              items: _supportedLanguages
                  .map(
                    (lang) => DropdownMenuItem<String>(
                      value: lang['name'] as String,
                      child: Text(lang['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const Divider(),
            const Text(
              'الإشعارات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('تفعيل الإشعارات'),
              value: _notificationsEnabled,
              onChanged: (value) async {
                if (value) {
                  await _requestNotificationPermission();
                }
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            const Divider(),
            const Text(
              'الأمان',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (!kIsWeb)
              SwitchListTile(
                title: const Text('المصادقة البيومترية'),
                subtitle: const Text(
                  'استخدم البصمة أو التعرف على الوجه لتسجيل الدخول',
                ),
                value: _biometricAuthEnabled,
                onChanged: (value) async {
                  if (value) {
                    await _authenticateWithBiometrics();
                  } else {
                    setState(() {
                      _biometricAuthEnabled = false;
                    });
                  }
                },
              )
            else
              const ListTile(
                title: Text('المصادقة البيومترية غير مدعومة على الويب'),
                subtitle: Text('يمكنك استخدامها فقط على الهاتف'),
              ),
            const Divider(),
            const Text(
              'حسابي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('سياسة الخصوصية'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('المساعدة والدعم'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('حول التطبيق'),
              onTap: () {},
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'حفظ الإعدادات',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
