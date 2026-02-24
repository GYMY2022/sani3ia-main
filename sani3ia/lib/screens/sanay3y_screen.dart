import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/screens/filter_screen.dart';
import 'package:snae3ya/widgets/post_item_sanay3y.dart';
import 'package:snae3ya/providers/post_provider.dart';
import 'package:snae3ya/models/post_model.dart';

class Sanay3yScreen extends StatefulWidget {
  const Sanay3yScreen({super.key});

  @override
  State<Sanay3yScreen> createState() => _Sanay3yScreenState();
}

class _Sanay3yScreenState extends State<Sanay3yScreen> {
  String? _selectedCategory;
  double? _minBudget;
  double? _maxBudget;
  bool _sortByDistance = true;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateUserLocation();
    });
  }

  Future<void> _updateUserLocation() async {
    print('🔄 محاولة تحديث موقع المستخدم...');
    setState(() {
      _isLoadingLocation = true;
    });

    final postProvider = Provider.of<PostProvider>(context, listen: false);
    await postProvider.updateUserLocation();

    print('📍 موقع المستخدم بعد التحديث: ${postProvider.hasUserLocation}');
    if (postProvider.hasUserLocation) {
      print('   - خط العرض: ${postProvider.userLatitude}');
      print('   - خط الطول: ${postProvider.userLongitude}');
    }

    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _toggleSortByDistance() async {
    print('🔄 تبديل ترتيب المسافة: $_sortByDistance -> ${!_sortByDistance}');

    // لو المستخدم بيحاول يفعل الترتيب حسب المسافة
    if (!_sortByDistance) {
      final postProvider = Provider.of<PostProvider>(context, listen: false);

      print(
        '📊 حالة الموقع قبل التبديل: hasLocation=${postProvider.hasUserLocation}',
      );

      // لو الموقع مش متاح، جرب نحدثه
      if (!postProvider.hasUserLocation) {
        print('🔄 موقع المستخدم غير متاح، جاري التحديث...');
        setState(() {
          _isLoadingLocation = true;
        });

        await postProvider.updateUserLocation();

        setState(() {
          _isLoadingLocation = false;
        });

        print('📍 موقع المستخدم بعد التحديث: ${postProvider.hasUserLocation}');
      }

      // بعد التحديث، لو الموقع لسه مش متاح، نعرض رسالة
      if (!postProvider.hasUserLocation && mounted) {
        print('❌ فشل في تحديد موقع المستخدم');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لم نتمكن من تحديد موقعك. يرجى التحقق من صلاحيات الموقع.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    // تغيير حالة الترتيب
    setState(() {
      _sortByDistance = !_sortByDistance;
    });
    print('✅ تم التبديل، حالة الترتيب الآن: $_sortByDistance');
  }

  @override
  Widget build(BuildContext context) {
    final postProvider = Provider.of<PostProvider>(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    print(
      '🏗️ بناء Sanay3yScreen: sortByDistance=$_sortByDistance, hasLocation=${postProvider.hasUserLocation}',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض المتاحة'),
        actions: [
          // زر تبديل الترتيب
          IconButton(
            icon: Icon(
              _sortByDistance ? Icons.sort_by_alpha : Icons.location_on,
              color: _sortByDistance ? Colors.blue : Colors.grey,
            ),
            onPressed: _toggleSortByDistance,
            tooltip: _sortByDistance ? 'ترتيب حسب المسافة' : 'ترتيب عادي',
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FilterScreen(
                    onApply: (category, minBudget, maxBudget) {
                      setState(() {
                        _selectedCategory = category;
                        _minBudget = minBudget;
                        _maxBudget = maxBudget;
                      });
                    },
                    currentCategory: _selectedCategory,
                    currentMinBudget: _minBudget,
                    currentMaxBudget: _maxBudget,
                  ),
                ),
              );

              if (result == true) {
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // مؤشر موقع المستخدم
          if (_isLoadingLocation || postProvider.isLocationLoading)
            const LinearProgressIndicator(
              backgroundColor: Colors.blue,
              minHeight: 2,
            )
          else if (!postProvider.hasUserLocation && _sortByDistance)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange[100],
              child: Row(
                children: [
                  const Icon(Icons.location_off, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لم يتم تحديد موقعك. سيتم عرض المنشورات بدون ترتيب.',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                  TextButton(
                    onPressed: _updateUserLocation,
                    child: const Text('تحديد الموقع'),
                  ),
                ],
              ),
            ),

          // عرض المنشورات
          Expanded(
            child: StreamBuilder<List<Post>>(
              stream: _getPostsStream(postProvider),
              builder: (context, snapshot) {
                print(
                  '📊 StreamBuilder state: ${snapshot.connectionState}, hasData=${snapshot.hasData}, data length=${snapshot.data?.length}',
                );

                if (snapshot.hasError) {
                  print('❌ Stream error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'حدث خطأ: ${snapshot.error}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.work_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد عروض متاحة حالياً',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedCategory != null
                              ? 'جرب تغيير الفلاتر'
                              : 'تحقق لاحقاً',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = null;
                              _minBudget = null;
                              _maxBudget = null;
                            });
                          },
                          child: const Text('إعادة تعيين الفلاتر'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: posts.length,
                    itemBuilder: (ctx, index) {
                      final post = posts[index];
                      final isMyPost =
                          currentUser != null &&
                          post.authorId == currentUser.uid;

                      return Stack(
                        children: [
                          PostItemSanay3y(post: post),

                          // عرض المسافة إذا كانت متوفرة
                          if (post.distance != null)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  post.distanceText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                          // علامة "منشورك"
                          if (isMyPost)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'منشورك',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // دالة مساعدة لاختيار الـ Stream المناسب
  Stream<List<Post>> _getPostsStream(PostProvider postProvider) {
    // إذا كان الترتيب حسب المسافة مفعل والموقع متاح
    if (_sortByDistance && postProvider.hasUserLocation) {
      print('📍 استخدام Stream المنشورات القريبة');
      print('   - خط العرض: ${postProvider.userLatitude}');
      print('   - خط الطول: ${postProvider.userLongitude}');
      return postProvider.getNearbyPostsStream(
        type: 'customer',
        category: _selectedCategory,
      );
    }

    // وإلا استخدم Stream المنشورات العادي
    print('📋 استخدام Stream المنشورات العادي');
    print('   - التصنيف: $_selectedCategory');
    print('   - الميزانية: $_minBudget - $_maxBudget');
    return postProvider.getPostsStream(
      type: 'customer',
      category: _selectedCategory,
      minBudget: _minBudget,
      maxBudget: _maxBudget,
    );
  }
}
