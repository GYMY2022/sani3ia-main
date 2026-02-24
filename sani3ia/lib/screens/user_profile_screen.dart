import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/widgets/user_post_item.dart';
import 'package:snae3ya/providers/post_provider.dart';
import 'package:snae3ya/providers/user_provider.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMyProfile = currentUser != null && currentUser.uid == userId;

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: StreamBuilder(
        stream: Provider.of<PostProvider>(context).getUserPostsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ: ${snapshot.error}',
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            );
          }

          final userPosts = snapshot.data ?? [];
          final userProvider = Provider.of<UserProvider>(context);
          final user = userProvider.user;

          // إذا مفيش بيانات مستخدم، استخدم بيانات افتراضية
          final userName = user?.name ?? 'مستخدم';
          final userLocation = user?.location?['city'] ?? 'موقع غير محدد';
          final userImage =
              user?.profileImage ?? 'assets/images/default_profile.png';

          return SingleChildScrollView(
            child: Column(
              children: [
                // معلومات المستخدم
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).cardColor,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _getProfileImage(userImage),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(userLocation),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                userPosts.length.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('المنشورات'),
                            ],
                          ),
                          Column(
                            children: const [
                              Text(
                                '4.8', // تقييم افتراضي
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text('التقييم'),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                userPosts
                                    .fold<int>(
                                      0,
                                      (sum, post) => sum + post.views,
                                    )
                                    .toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('المشاهدات'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // منشورات المستخدم
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المنشورات السابقة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (userPosts.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.work_outline,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'لا توجد منشورات',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: userPosts.length,
                          itemBuilder: (ctx, index) =>
                              UserPostItem(post: userPosts[index]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ دالة مساعدة للصور
  ImageProvider _getProfileImage(String imagePath) {
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    } else {
      return const AssetImage('assets/images/default_profile.png');
    }
  }
}
