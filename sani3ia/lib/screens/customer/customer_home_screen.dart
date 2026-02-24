import 'package:flutter/material.dart';
import 'package:snae3ya/screens/customer/workers_category_screen.dart';
import 'package:snae3ya/screens/customer/customer_jobs_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = screenHeight * 0.38;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // كارت الصنايعية
            _buildCategoryCard(
              context,
              'الصنايعية على التطبيق',
              'تصفح جميع المهن المتاحة - مرتبة حسب القرب من موقعك',
              'assets/images/workers.jpg',
              Colors.blue,
              const WorkersCategoryScreen(),
              height: cardHeight,
            ),
            const SizedBox(height: 20),
            // كارت الشغلانات
            _buildCategoryCard(
              context,
              'شغلاناتي',
              'إدارة الشغلانات المنشورة',
              'assets/images/jobs.jpg',
              Colors.green,
              const CustomerJobsScreen(),
              height: cardHeight,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String title,
    String subtitle,
    String imagePath,
    Color color,
    Widget screen, {
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => screen),
            );
          },
          child: Stack(
            children: [
              // صورة الخلفية
              Positioned.fill(
                child: Image(
                  image: _getImageProvider(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.photo,
                        size: 50,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
              // طبقة تدرج لوني
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
              ),
              // المحتوى
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'اضغط للعرض',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة مساعدة للصور
  ImageProvider _getImageProvider(String imagePath) {
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    } else {
      return const AssetImage('assets/images/default_job_1.png');
    }
  }
}
