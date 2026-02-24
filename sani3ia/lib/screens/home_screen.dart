import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// استيراد الشاشات
import 'package:snae3ya/screens/chat_screen.dart';
import 'package:snae3ya/screens/add_job_screen.dart';
import 'package:snae3ya/screens/search_screen.dart';
import 'package:snae3ya/screens/market_screen.dart';
import 'package:snae3ya/screens/notifications_screen.dart';
import 'package:snae3ya/screens/wallet/wallet_screen.dart';
import 'package:snae3ya/screens/customer/customer_home_screen.dart';
import 'package:snae3ya/screens/sanay3y_screen.dart';
import 'package:snae3ya/screens/favorites_screen.dart';
import 'package:snae3ya/screens/personal_account_details.dart';
import 'package:snae3ya/screens/edit_profile_details.dart';
import 'package:snae3ya/providers/service_provider.dart';
import 'package:snae3ya/providers/user_provider.dart';
import 'package:snae3ya/providers/chat_provider.dart';
import 'package:snae3ya/services/location_service.dart'; // ⭐⭐ إضافة جديدة

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  double walletBalance = 1250.50;
  bool _isLoadingBalance = false;
  late ScrollController _scrollController;
  bool _isAppBarVisible = true;
  bool _servicesLoaded = false;
  bool _userDataLoaded = false;
  bool _chatInitialized = false;

  // ⭐ جديد: متغيرات لمنع التكرار
  bool _hasUpdatedOnlineStatus = false;
  bool _hasInitializedChat = false;

  int _selectedBottomIndex = 0;
  final List<Widget> _bottomPages = const [
    SizedBox(), // الصفحة الرئيسية
    MarketScreen(),
    NotificationsScreen(),
    AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // ⭐⭐ **التعديل الأساسي هنا**: إضافة initialIndex: 1
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 1, // ⭐⭐ غيرت من 0 إلى 1 (يفتح على تبويب الصنايعي أولاً)
    );

    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    // ⭐ جديد: إضافة مراقب لدورة حياة التطبيق
    WidgetsBinding.instance.addObserver(this);

    // ⭐ محسّن: تهيئة البيانات بعد اكتمال البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  // ⭐ محسّن: دالة مراقبة دورة حياة التطبيق مع منع التكرار
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.resumed:
        // ⭐ تحديث حالة الاتصال عند عودة التطبيق - مرة واحدة فقط
        if (!_hasUpdatedOnlineStatus) {
          chatProvider.updateMyOnlineStatus(true);
          _hasUpdatedOnlineStatus = true;
          print('📱 تحديث حالة الاتصال: متصل (عودة التطبيق)');
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // ⭐ تحديث حالة الاتصال عند خروج التطبيق
        chatProvider.updateMyOnlineStatus(false);
        _hasUpdatedOnlineStatus = false;
        print('📱 تحديث حالة الاتصال: غير متصل (خروج التطبيق)');
        break;
      case AppLifecycleState.inactive:
        // لا تفعل شيء
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ⭐ محسّن: دالة موحدة لتهيئة البيانات مع منع التكرار
  Future<void> _initializeData() async {
    await _loadUserData();
    await Future.wait([_fetchWalletBalance(), _initializeChat()]);
  }

  // ⭐ محسّن جداً: تهيئة نظام المحادثات مع منع التكرار
  Future<void> _initializeChat() async {
    if (_chatInitialized || _hasInitializedChat) {
      print('⏭️ تخطي تهيئة المحادثات - تم التهيئة مسبقاً');
      return;
    }

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      print('🔍 بدء تهيئة نظام المحادثات للمستخدم: ${currentUser.uid}');

      try {
        // ⭐ تحميل المحادثات مرة واحدة فقط إذا لم تكن محملة بالفعل
        if (chatProvider.chatRooms.isEmpty && !chatProvider.isLoading) {
          await chatProvider.loadChatRooms();
          print('✅ تم تحميل المحادثات بنجاح');
        } else {
          print('⏭️ تخطي تحميل المحادثات - البيانات محملة مسبقاً');
        }

        _chatInitialized = true;
        _hasInitializedChat = true;
        print('✅ تم تهيئة نظام المحادثات بنجاح');
      } catch (e) {
        print('❌ فشل في تهيئة المحادثات: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في تحميل المحادثات: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print('⚠️ لا يوجد مستخدم مسجل دخول لتحميل المحادثات');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_servicesLoaded) {
      _servicesLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final serviceProvider = Provider.of<ServiceProvider>(
          context,
          listen: false,
        );
        if (serviceProvider.services.isEmpty && !serviceProvider.isLoading) {
          serviceProvider.loadServices();
        }
      });
    }
  }

  void _scrollListener() {
    final direction = _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.reverse && _isAppBarVisible) {
      setState(() => _isAppBarVisible = false);
    } else if (direction == ScrollDirection.forward && !_isAppBarVisible) {
      setState(() => _isAppBarVisible = true);
    }
  }

  Future<void> _fetchWalletBalance() async {
    if (mounted) setState(() => _isLoadingBalance = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        walletBalance = 1850.75;
        _isLoadingBalance = false;
      });
    }
  }

  // ⭐⭐ **جديد: دالة تحميل المنشورات القريبة**
  Future<void> _loadNearbyPosts() async {
    try {
      final locationService = LocationService();

      // جلب موقع المستخدم
      final userLocation = await locationService.getCurrentLocation();

      // البحث عن المنشورات القريبة
      final nearbyPosts = await locationService.findNearbyPosts(
        userLocation: userLocation,
        radiusInKm: 20, // نصف قطر 20 كم
      );

      // يمكنك استخدام هذه البيانات لتحديث واجهة المستخدم
      print('✅ تم تحميل ${nearbyPosts.length} منشور قريب');
    } catch (e) {
      print('❌ خطأ في تحميل المنشورات القريبة: $e');
    }
  }

  // ⭐ محسّن: دالة تحميل بيانات المستخدم مع منع التكرار
  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && !userProvider.hasUserData && !_userDataLoaded) {
      await userProvider.loadUserData();
      if (mounted) {
        setState(() => _userDataLoaded = true);
        _checkProfileCompletion();

        // ⭐⭐ **جديد: تحميل المنشورات القريبة بعد تحميل بيانات المستخدم**
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadNearbyPosts();
        });
      }
    } else {
      print('⏭️ تخطي تحميل بيانات المستخدم - البيانات محملة مسبقاً');
    }
  }

  void _checkProfileCompletion() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (!userProvider.isProfileComplete && userProvider.hasUserData) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'برجاء إكمال ملفك الشخصي للحصول على أفضل تجربة',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'تعديل',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfileScreen(),
                    ),
                  );
                },
              ),
            ),
          );
        }
      });
    }
  }

  // ⭐ محسّن: دالة محسنة لفتح شاشة المحادثات مع منع التكرار
  Future<void> _openChatScreen() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('🚀 فتح شاشة المحادثات...');

    // ⭐ التأكد من تحميل المحادثات أولاً
    if (!_chatInitialized || chatProvider.chatRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري تحميل المحادثات...'),
          backgroundColor: Colors.blue,
        ),
      );

      try {
        await chatProvider.loadChatRooms();
        _chatInitialized = true;

        // الانتظار قليلاً لضمان اكتمال التحميل
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('❌ فشل في تحميل المحادثات: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحميل المحادثات: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // ⭐ فتح شاشة المحادثات
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );

    // ⭐ تحديث المحادثات عند العودة
    if (mounted) {
      print('🔄 تحديث المحادثات بعد العودة...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ⭐ تحديث المحادثات فقط إذا كانت هناك حاجة
        if (chatProvider.chatRooms.isEmpty || chatProvider.isLoading) {
          chatProvider.loadChatRooms();
        }
      });
    }
  }

  Widget _walletButton() {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WalletScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet, size: 25),
            const SizedBox(height: 2),
            _isLoadingBalance
                ? const SizedBox(
                    width: 20,
                    height: 10,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: Colors.blue,
                    ),
                  )
                : Text(
                    NumberFormat.currency(
                      locale: 'ar_EG',
                      symbol: 'ج.م',
                      decimalDigits: 2,
                    ).format(walletBalance),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          title: AnimatedOpacity(
            opacity: _isAppBarVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 40,
                  width: 40,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.build, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text(
                  'صنايعية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
          ),
          actions: _isAppBarVisible
              ? [
                  IconButton(
                    icon: const Icon(Icons.favorite),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FavoritesScreen(),
                      ),
                    ),
                  ),
                  // ⭐⭐ محسّن: زر الشات مع إشعار الرسائل غير المقروءة - تصميم جديد
                  Consumer<ChatProvider>(
                    builder: (context, chatProvider, child) {
                      final unreadCount = chatProvider.getUnreadCount();
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat, size: 25),
                            onPressed: _openChatScreen,
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Text(
                                  unreadCount > 99
                                      ? '99+'
                                      : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, size: 25),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SearchScreen(),
                      ),
                    ),
                  ),
                  _walletButton(),
                ]
              : null,
          bottom: _isAppBarVisible
              ? TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue[800],
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: const [
                    Tab(text: 'العميل'),
                    Tab(text: 'الصنايعي'),
                  ],
                )
              : null,
          pinned: true,
          elevation: 4,
          automaticallyImplyLeading: false,
        ),
        SliverFillRemaining(
          child: TabBarView(
            controller: _tabController,
            children: const [CustomerHomeScreen(), Sanay3yScreen()],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedBottomIndex == 0
          ? _buildMainContent()
          : _bottomPages[_selectedBottomIndex],
      floatingActionButton: _selectedBottomIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddJobScreen()),
              ),
              backgroundColor: Colors.blue[800],
              child: const Icon(Icons.add, size: 30),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(
                Icons.home,
                color: _selectedBottomIndex == 0
                    ? Colors.blue[800]
                    : Colors.grey[600],
              ),
              onPressed: () => setState(() => _selectedBottomIndex = 0),
            ),
            IconButton(
              icon: Icon(
                Icons.shopping_cart,
                color: _selectedBottomIndex == 1
                    ? Colors.blue[800]
                    : Colors.grey[600],
              ),
              onPressed: () => setState(() => _selectedBottomIndex = 1),
            ),
            const SizedBox(width: 40),
            // ⭐⭐ محسّن: زر الإشعارات مع إشعار الرسائل غير المقروءة - تصميم جديد
            Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final unreadCount = chatProvider.getUnreadCount();
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications,
                        color: _selectedBottomIndex == 2
                            ? Colors.blue[800]
                            : Colors.grey[600],
                      ),
                      onPressed: () => setState(() => _selectedBottomIndex = 2),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.person,
                color: _selectedBottomIndex == 3
                    ? Colors.blue[800]
                    : Colors.grey[600],
              ),
              onPressed: () => setState(() => _selectedBottomIndex = 3),
            ),
          ],
        ),
      ),
    );
  }
}
