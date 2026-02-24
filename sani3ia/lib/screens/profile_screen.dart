import 'package:flutter/material.dart';
import 'package:snae3ya/screens/personal_account_details.dart';
import 'package:snae3ya/screens/worker_portfolio_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الملف الشخصي'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'معلومات الحساب'),
              Tab(text: 'أعمالي السابقة'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [AccountScreen(), WorkerPortfolioScreen()],
        ),
      ),
    );
  }
}
