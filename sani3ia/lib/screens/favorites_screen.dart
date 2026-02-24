import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snae3ya/providers/favorites_provider.dart';
import 'package:snae3ya/widgets/post_item_sanay3y.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final favoritePosts = favoritesProvider.favoritePosts;

    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: favoritePosts.isEmpty
          ? const Center(
              child: Text(
                'لا توجد منشورات في المفضلة',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: favoritePosts.length,
              itemBuilder: (ctx, index) =>
                  PostItemSanay3y(post: favoritePosts[index]),
            ),
    );
  }
}
