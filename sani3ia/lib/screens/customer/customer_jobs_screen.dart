import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/widgets/customer/customer_job_card.dart';
import 'package:snae3ya/providers/post_provider.dart';
import 'package:snae3ya/screens/add_job_screen.dart';

class CustomerJobsScreen extends StatelessWidget {
  const CustomerJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('شغلاناتي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddJobScreen()),
              );
            },
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(
              child: Text(
                'يجب تسجيل الدخول لعرض الشغلانات',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : Consumer<PostProvider>(
              builder: (context, postProvider, child) {
                return StreamBuilder(
                  stream: postProvider.getUserPostsStream(currentUser.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'حدث خطأ: ${snapshot.error}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                      );
                    }

                    final myJobs = snapshot.data ?? [];

                    if (myJobs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.work_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'لا توجد شغلانات منشورة',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'انقر على أيقونة + لإضافة أول شغلانة',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: myJobs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: CustomerJobCard(post: myJobs[index]),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
