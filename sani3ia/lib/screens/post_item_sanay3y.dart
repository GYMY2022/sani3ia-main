import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snae3ya/models/post_model.dart';
import 'package:snae3ya/providers/favorites_provider.dart';
import 'package:snae3ya/screens/post_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PostItemSanay3y extends StatelessWidget {
  final Post post;

  const PostItemSanay3y({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailsScreen(post: post),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ التصحيح: استخدام Image بدل Image.asset
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: _buildPostImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${post.budget} ج.م',
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          post.location,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.map),
                        onPressed: () => _launchMap(post.location),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: _getProfileImage(post.authorImage),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'yyyy-MM-dd – kk:mm',
                              ).format(post.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () => _showShareOptions(context),
                      ),
                      Consumer<FavoritesProvider>(
                        builder: (context, provider, child) {
                          return IconButton(
                            icon: Icon(
                              provider.isFavorite(post.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              provider.toggleFavorite(post);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.isFavorite(post.id)
                                        ? 'تمت الإضافة إلى المفضلة'
                                        : 'تمت الإزالة من المفضلة',
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ دالة جديدة لبناء صورة البوست
  Widget _buildPostImage() {
    if (post.images.isEmpty) {
      return _buildPlaceholderImage();
    }

    final firstImage = post.images.first;

    return Image(
      image: _getImageProvider(firstImage),
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('❌ فشل تحميل صورة البوست: $error');
        return _buildPlaceholderImage();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 180,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 180,
      color: Colors.grey[200],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo, size: 50, color: Colors.grey),
          SizedBox(height: 8),
          Text('لا توجد صورة', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ✅ دالة مساعدة للصور (لصورة البروفايل)
  ImageProvider _getProfileImage(String imagePath) {
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    } else {
      return const AssetImage('assets/images/default_profile.png');
    }
  }

  // ✅ دالة مساعدة جديدة للصور (لصور البوست)
  ImageProvider _getImageProvider(String imagePath) {
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    } else {
      return const AssetImage('assets/images/default_job_1.png');
    }
  }

  void _showShareOptions(BuildContext context) {
    final shareContent =
        '${post.title}\n${post.description}\nالميزانية: ${post.budget} ج.م\nالموقع: ${post.location}';

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'شارك هذا المنشور عبر:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildShareOption(
                  icon: Icons.message,
                  label: 'الرسائل',
                  onTap: () => _shareViaSMS(shareContent),
                ),
                _buildShareOption(
                  icon: Icons.email,
                  label: 'البريد',
                  onTap: () => _shareViaEmail(shareContent),
                ),
                _buildShareOption(
                  icon: Icons.link,
                  label: 'نسخ الرابط',
                  onTap: () => _copyLink(context, shareContent),
                ),
                _buildShareOption(
                  icon: Icons.chat,
                  label: 'واتساب',
                  onTap: () => _shareViaWhatsApp(shareContent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _launchMap(String location) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _shareViaSMS(String content) async {
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(content)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copyToClipboard(content);
      ScaffoldMessenger.of(
        GlobalKey<NavigatorState>().currentContext!,
      ).showSnackBar(
        const SnackBar(content: Text('تم نسخ المحتوى للمشاركة عبر الرسائل')),
      );
    }
  }

  Future<void> _shareViaEmail(String content) async {
    final uri = Uri.parse(
      'mailto:?subject=منشور من تطبيق صنايعية&body=${Uri.encodeComponent(content)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copyToClipboard(content);
      ScaffoldMessenger.of(
        GlobalKey<NavigatorState>().currentContext!,
      ).showSnackBar(
        const SnackBar(content: Text('تم نسخ المحتوى للمشاركة عبر البريد')),
      );
    }
  }

  Future<void> _shareViaWhatsApp(String content) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(content)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copyToClipboard(content);
      ScaffoldMessenger.of(
        GlobalKey<NavigatorState>().currentContext!,
      ).showSnackBar(
        const SnackBar(content: Text('تم نسخ المحتوى للمشاركة عبر واتساب')),
      );
    }
  }

  void _copyLink(BuildContext context, String content) {
    _copyToClipboard(content);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم نسخ رابط المنشور')));
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
  }
}
