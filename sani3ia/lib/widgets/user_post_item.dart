import 'package:flutter/material.dart';
import 'package:snae3ya/models/post_model.dart';

class UserPostItem extends StatelessWidget {
  final Post post;

  const UserPostItem({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ التصحيح: استخدام Image بدل Image.asset
          if (post.images.isNotEmpty)
            Image(
              image: _getImageProvider(post.images.first),
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Icon(Icons.photo, size: 40, color: Colors.grey),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  post.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.attach_money, size: 16),
                    const SizedBox(width: 4),
                    Text('${post.budget} ج.م'),
                    const Spacer(),
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 4),
                    Text(post.location),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ دالة مساعدة للصور
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
