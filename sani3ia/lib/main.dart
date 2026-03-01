import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// ✅ Supabase imports
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:snae3ya/services/supabase_service.dart';

// ✅ Notification imports
import 'package:snae3ya/services/fcm_service.dart';
import 'package:snae3ya/services/notification_service.dart';
import 'package:snae3ya/providers/notification_provider.dart';

// ⭐ إضافة OneSignal
import 'package:onesignal_flutter/onesignal_flutter.dart';

// ⭐ إضافة flutter_local_notifications لإنشاء قناة الإشعارات
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:snae3ya/screens/splash_screen.dart';
import 'package:snae3ya/screens/auth_screen.dart';
import 'package:snae3ya/screens/email_verification_screen.dart';
import 'package:snae3ya/screens/home_screen.dart';
import 'package:snae3ya/screens/market_screen.dart';
import 'package:snae3ya/screens/chat_screen.dart';
import 'package:snae3ya/screens/product_details.dart';
import 'package:snae3ya/screens/app_settings.dart';
import 'package:snae3ya/models/product_model.dart';
import 'package:snae3ya/providers/user_provider.dart';
import 'package:snae3ya/providers/favorites_provider.dart';
import 'package:snae3ya/providers/service_provider.dart';
import 'package:snae3ya/providers/post_provider.dart';
import 'package:snae3ya/providers/worker_provider.dart';
import 'package:snae3ya/providers/product_provider.dart';
import 'package:snae3ya/providers/chat_provider.dart';
import 'package:snae3ya/providers/application_provider.dart';

// Wallet imports
import 'package:snae3ya/screens/wallet/wallet_screen.dart';
import 'package:snae3ya/screens/wallet/deposit_screen.dart';
import 'package:snae3ya/screens/wallet/withdraw_screen.dart';
import 'package:snae3ya/screens/wallet/transaction_history_screen.dart';
import 'package:snae3ya/screens/wallet/escrow_payment_screen.dart';
import 'package:snae3ya/repositories/wallet_repository.dart';
import 'package:snae3ya/services/wallet_service.dart';

// ✅ إضافة استيراد CompleteProfileScreen
import 'package:snae3ya/screens/complete_profile_screen.dart';

// ✅ استيراد شاشات البوستات الجديدة
import 'package:snae3ya/screens/add_job_screen.dart';
import 'package:snae3ya/screens/search_screen.dart';
import 'package:snae3ya/screens/sanay3y_screen.dart';
import 'package:snae3ya/screens/customer/customer_home_screen.dart';

// ✅ إضافة استيراد شاشة SingleChatScreen
import 'package:snae3ya/screens/single_chat_screen.dart';

// ✅ إضافة استيراد OnlineStatusManager
import 'package:snae3ya/services/online_status_manager.dart';

// ⭐ تعريف navigatorKey للتنقل من خارج الـ Widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AppRoutes {
  static const splash = '/';
  static const auth = '/auth';
  static const login = '/login';
  static const emailVerification = '/email-verification';
  static const home = '/home';
  static const market = '/market';
  static const chat = '/chat';
  static const singleChat = '/single-chat';
  static const settings = '/settings';
  static const product = '/product';
  static const wallet = '/wallet';
  static const deposit = '/deposit';
  static const withdraw = '/withdraw';
  static const transactions = '/transactions';
  static const escrowPayment = '/escrow_payment';
  static const completeProfile = '/complete-profile';
  static const addJob = '/add-job';
  static const search = '/search';
  static const postDetails = '/post-details';
}

// 🔐 خدمة للتحقق من تأكيد البريد
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<bool> isUserVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      final updatedUser = _auth.currentUser;
      return updatedUser?.emailVerified ?? false;
    }
    return false;
  }

  static Future<void> forceEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
    }
  }

  static Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // ✅ تهيئة Firebase بشكل آمن
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully!");
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      Firebase.app();
      print("✅ Firebase already initialized, using existing instance");
    } else {
      print("❌ Firebase initialization error: $e");
    }
  }

  // ✅ تهيئة Supabase
  try {
    await SupabaseService().initialize();
    print("✅ Supabase initialized successfully!");
  } catch (e) {
    print("❌ Supabase initialization error: $e");
  }

  // ✅ تهيئة FCM والإشعارات المحلية
  try {
    final fcmService = FCMService();
    await fcmService.initialize();

    final notificationService = NotificationService();
    await notificationService.initialize();
    print("✅ FCM and Local Notifications initialized");
  } catch (e) {
    print("❌ Failed to initialize notifications: $e");
  }

  // ⭐ تهيئة OneSignal
  try {
    // 🔥 تفعيل وضع التصحيح
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    OneSignal.initialize("06a56c7a-1579-4cf0-997d-11982bfb1c35");

    // ⭐ مراقبة حالة المستخدم
    OneSignal.User.addObserver((state) {
      print("📌 OneSignal User state: ${state.jsonRepresentation()}");
    });

    // ⭐ طباعة معرف الاشتراك بعد تأخير طويل (15 ثانية)
    Future.delayed(const Duration(seconds: 15), () {
      final subscriptionId = OneSignal.User.pushSubscription.id;
      print(
        "📌 OneSignal User.pushSubscription.id (after 15s): $subscriptionId",
      );
      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        print("✅ OneSignal Subscription is active with ID: $subscriptionId");
      } else {
        print(
          "❌ OneSignal Subscription is NOT active (pushSubscription.id is null/empty).",
        );
      }
    });

    OneSignal.Notifications.requestPermission(true);
    OneSignal.Notifications.addClickListener((event) {
      print(
        '🔔 تم الضغط على إشعار: ${event.notification.jsonRepresentation()}',
      );
      final data = event.notification.additionalData;
      if (data != null) {
        final screen = data['screen'];
        final arguments = <String, dynamic>{};
        data.forEach((key, value) {
          if (key != 'screen') arguments[key] = value;
        });
        navigatorKey.currentState?.pushNamed('/$screen', arguments: arguments);
      }
    });
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print('📩 إشعار جديد في المقدمة');
    });
    print("✅ OneSignal initialized successfully!");
  } catch (e) {
    print("❌ Failed to initialize OneSignal: $e");
  }

  // ⭐ إنشاء قناة إشعارات لنظام Android
  try {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'الإشعارات الهامة',
      description: 'قناة الإشعارات الهامة للرسائل والتنبيهات',
      importance: Importance.high,
      playSound: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    print("✅ تم إنشاء قناة الإشعارات بنجاح");
  } catch (e) {
    print("❌ فشل إنشاء قناة الإشعارات: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (context) => WalletRepository()),
        ChangeNotifierProxyProvider<WalletRepository, WalletService>(
          create: (context) => WalletService(context.read<WalletRepository>()),
          update: (context, repository, service) =>
              service ?? WalletService(repository),
        ),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ServiceProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => WorkerProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('ar'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: MyApp(isDarkMode: isDarkMode, isLoggedIn: isLoggedIn),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool isDarkMode;
  final bool isLoggedIn;

  const MyApp({super.key, required this.isDarkMode, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    if (state != null && state.mounted) {
      state.setLocale(newLocale);
    }
  }
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isDarkMode = false;
  Locale? _currentLocale;
  bool _hasUpdatedOnlineStatus = false;
  bool _hasInitializedProviders = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialNotification();
    });
  }

  void _handleInitialNotification() {
    final data = FCMService.getLastNotificationData();
    if (data != null) {
      print('📱 فتح التطبيق من إشعار FCM: $data');
      FCMService.clearLastNotificationData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!mounted) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.resumed:
        if (!_hasUpdatedOnlineStatus) {
          chatProvider.updateMyOnlineStatus(true);
          _hasUpdatedOnlineStatus = true;
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        chatProvider.updateMyOnlineStatus(false);
        _hasUpdatedOnlineStatus = false;
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _initializeApp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRealTimeServices();
    });
  }

  void _initializeRealTimeServices() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (!_hasUpdatedOnlineStatus) {
          final onlineManager = OnlineStatusManager();
          onlineManager.setOnlineStatus(true);
          _hasUpdatedOnlineStatus = true;
        }
        print('✅ تم تهيئة خدمات الوقت الحقيقي للمستخدم: ${user.email}');
      }
    } catch (e) {
      print('⚠️ خطأ في تهيئة خدمات الوقت الحقيقي: $e');
    }
  }

  void setLocale(Locale locale) {
    if (mounted) {
      setState(() {
        _currentLocale = locale;
      });
      EasyLocalization.of(context)?.setLocale(locale);
    }
  }

  void setDarkMode(bool isDarkMode) async {
    if (mounted) {
      setState(() {
        _isDarkMode = isDarkMode;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  Future<void> _checkProtectedRoute(
    String routeName,
    BuildContext context,
  ) async {
    final protectedRoutes = [
      AppRoutes.home,
      AppRoutes.market,
      AppRoutes.chat,
      AppRoutes.singleChat,
      AppRoutes.wallet,
      AppRoutes.deposit,
      AppRoutes.withdraw,
      AppRoutes.transactions,
      AppRoutes.addJob,
      AppRoutes.postDetails,
    ];

    if (protectedRoutes.contains(routeName)) {
      try {
        final isVerified = await AuthService.isUserVerified();
        if (!isVerified) {
          print('❌ منع الوصول لـ $routeName - البريد غير مؤكد');

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null && !user.emailVerified) {
              Navigator.pushReplacementNamed(
                context,
                AppRoutes.emailVerification,
                arguments: {
                  'email': user.email ?? '',
                  'password': '',
                  'fullName': 'مستخدم',
                  'phone': '',
                },
              );
            }
          });
        } else {
          print('✅ الوصول مسموح لـ $routeName - البريد مؤكد');
        }
      } catch (e) {
        print('⚠️ خطأ في التحقق من الصفحة المحمية: $e');
      }
    }
  }

  void _initializeProviders(BuildContext context) {
    if (_hasInitializedProviders) return;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.loadChatRooms();

      final applicationProvider = Provider.of<ApplicationProvider>(
        context,
        listen: false,
      );
      applicationProvider.loadUserApplications();
      applicationProvider.loadReceivedApplications();

      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      productProvider.loadAllProducts();

      final notificationProvider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      notificationProvider.loadNotifications();

      _hasInitializedProviders = true;
      print('✅ تم تهيئة جميع الـ Providers بنجاح');
    } catch (e) {
      print('⚠️ خطأ في تهيئة الـ Providers: $e');
    }
  }

  Future<void> _checkUserState(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('🔍 حالة المستخدم الحالي:');
        print('   - البريد: ${user.email}');
        print('   - مفعل: ${user.emailVerified}');
        print('   - UID: ${user.uid}');

        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

        if (!isLoggedIn) {
          print(
            '⚠️ حالة غير متطابقة: مستخدم في Firebase لكن ليس في SharedPreferences',
          );
          await FirebaseAuth.instance.signOut();
          return;
        }

        final userProvider = Provider.of<UserProvider>(context, listen: false);

        if (!userProvider.hasUserData && !userProvider.isLoading) {
          await userProvider.loadUserData();
        }

        if (!user.emailVerified) {
          print('📧 إرسال بريد التحقق...');
          await user.sendEmailVerification();
        }

        if (!_hasUpdatedOnlineStatus) {
          final onlineManager = OnlineStatusManager();
          onlineManager.setOnlineStatus(true);
          _hasUpdatedOnlineStatus = true;
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        if (isLoggedIn) {
          print(
            '⚠️ حالة غير متطابقة: لا يوجد مستخدم في Firebase لكن موجود في SharedPreferences',
          );
          await prefs.setBool('isLoggedIn', false);
        }
      }
    } catch (e) {
      print('⚠️ خطأ في التحقق من حالة المستخدم: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasInitializedProviders) {
        _initializeProviders(context);
        _checkUserState(context);
      }
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'app_name'.tr(),
      locale: _currentLocale ?? context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: [
        ...context.localizationDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _isDarkMode
          ? ThemeData.dark().copyWith(
              primaryColor: const Color.fromARGB(255, 120, 45, 206),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color.fromARGB(255, 120, 45, 206),
                foregroundColor: Colors.white,
              ),
              colorScheme: ColorScheme.dark(
                primary: const Color.fromARGB(255, 120, 45, 206),
                secondary: Colors.blueAccent,
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
              cardColor: const Color(0xFF1E1E1E),
            )
          : ThemeData.light().copyWith(
              primaryColor: const Color.fromARGB(255, 120, 45, 206),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color.fromARGB(255, 120, 45, 206),
                foregroundColor: Colors.white,
              ),
              colorScheme: ColorScheme.light(
                primary: const Color.fromARGB(255, 120, 45, 206),
                secondary: Colors.blueAccent,
              ),
              scaffoldBackgroundColor: Colors.white,
              cardColor: Colors.grey[50],
            ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (settings) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _checkProtectedRoute(settings.name!, context);
          }
        });

        switch (settings.name) {
          case AppRoutes.splash:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case AppRoutes.auth:
          case AppRoutes.login:
            return MaterialPageRoute(
              builder: (_) =>
                  AuthScreen(isLogin: settings.name == AppRoutes.login),
            );
          case AppRoutes.emailVerification:
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(
                email: args['email'] ?? '',
                password: args['password'] ?? '',
                fullName: args['fullName'] ?? 'مستخدم',
                phone: args['phone'] ?? '',
                birthDate: args['birthDate'],
                gender: args['gender'],
                address: args['address'],
                profession: args['profession'],
                location: args['location'],
                profileImagePath: args['profileImagePath'],
              ),
            );
          case AppRoutes.home:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case AppRoutes.market:
            return MaterialPageRoute(builder: (_) => const MarketScreen());
          case AppRoutes.chat:
            return MaterialPageRoute(builder: (_) => const ChatScreen());
          case AppRoutes.singleChat:
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => SingleChatScreen(
                userName: args['userName'] ?? 'مستخدم',
                userImage:
                    args['userImage'] ?? 'assets/images/default_profile.png',
                receiverId: args['receiverId'] ?? '',
                isOnline: args['isOnline'] ?? false,
                initialMessage: args['initialMessage'],
                postId: args['postId'],
                isFromJobApplication: args['isFromJobApplication'] ?? false,
              ),
            );
          case AppRoutes.settings:
            return MaterialPageRoute(
              builder: (_) => AppSettingsScreen(onDarkModeChanged: setDarkMode),
            );
          case AppRoutes.product:
            final product = settings.arguments as Product;
            return MaterialPageRoute(
              builder: (_) => ProductDetailsScreen(product: product),
            );
          case AppRoutes.wallet:
            return MaterialPageRoute(builder: (_) => const WalletScreen());
          case AppRoutes.deposit:
            return MaterialPageRoute(builder: (_) => const DepositScreen());
          case AppRoutes.withdraw:
            return MaterialPageRoute(builder: (_) => const WithdrawScreen());
          case AppRoutes.transactions:
            return MaterialPageRoute(
              builder: (_) => const TransactionHistoryScreen(),
            );
          case AppRoutes.escrowPayment:
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => EscrowPaymentScreen(
                jobId: args['jobId'] ?? '',
                amount: args['amount'] ?? 0.0,
              ),
            );
          case AppRoutes.completeProfile:
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => CompleteProfileScreen(
                user: args['user'],
                isFromGoogle: args['isFromGoogle'] ?? false,
              ),
            );
          case AppRoutes.addJob:
            return MaterialPageRoute(builder: (_) => const AddJobScreen());
          case AppRoutes.search:
            return MaterialPageRoute(builder: (_) => const SearchScreen());
          case AppRoutes.postDetails:
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: const Text('تفاصيل المنشور'),
                  backgroundColor: const Color.fromARGB(255, 120, 45, 206),
                ),
                body: Center(
                  child: Text(
                    'تفاصيل المنشور: ${args['postId'] ?? 'غير معروف'}',
                  ),
                ),
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: const Text('الصفحة غير موجودة'),
                  backgroundColor: const Color.fromARGB(255, 120, 45, 206),
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'الصفحة غير موجودة: ${settings.name}',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.home,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            120,
                            45,
                            206,
                          ),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('العودة للرئيسية'),
                      ),
                    ],
                  ),
                ),
              ),
            );
        }
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: const Text('خطأ'),
              backgroundColor: const Color.fromARGB(255, 120, 45, 206),
            ),
            body: const Center(child: Text('حدث خطأ غير متوقع')),
          ),
        );
      },
    );
  }
}
