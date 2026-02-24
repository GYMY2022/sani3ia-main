import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snae3ya/services/wallet_service.dart';
import 'package:snae3ya/screens/wallet/transaction_history_screen.dart';
import 'package:snae3ya/screens/wallet/deposit_screen.dart';
import 'package:snae3ya/screens/wallet/withdraw_screen.dart';
import 'package:snae3ya/models/wallet_models.dart';
import 'package:snae3ya/models/wallet_transaction_model.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletService>().loadWallet();
    });
  }

  @override
  Widget build(BuildContext context) {
    // حجم الشاشة
    final screenWidth = MediaQuery.of(context).size.width;
    // تحديد إذا كانت شاشة صغيرة أم لا
    final isSmallScreen = screenWidth < 400;
    final isTinyScreen = screenWidth < 350;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'المحفظة',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 18 : 20,
          ),
        ),
        backgroundColor: const Color(0xFF6C5CE7),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.white,
              size: isSmallScreen ? 22 : 24,
            ),
            onPressed: () => context.read<WalletService>().loadWallet(),
          ),
          IconButton(
            icon: Icon(
              Icons.history,
              color: Colors.white,
              size: isSmallScreen ? 22 : 24,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TransactionHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<WalletService>(
        builder: (context, walletService, child) {
          if (walletService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6C5CE7),
                strokeWidth: 3,
              ),
            );
          }

          if (walletService.error != null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: isSmallScreen ? 48 : 60,
                      color: Colors.red,
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    Text(
                      walletService.error!,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 20 : 24,
                          vertical: isSmallScreen ? 10 : 12,
                        ),
                      ),
                      onPressed: () => walletService.loadWallet(),
                      child: Text(
                        'إعادة المحاولة',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final wallet = walletService.wallet;
          if (wallet == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wallet,
                    size: isSmallScreen ? 48 : 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  Text(
                    'لا توجد بيانات للمحفظة',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFF6C5CE7),
            onRefresh: () => walletService.loadWallet(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Column(
                children: [
                  _buildBalanceCard(wallet, isSmallScreen, isTinyScreen),
                  SizedBox(height: isSmallScreen ? 20 : 24),
                  _buildQuickActions(context, isSmallScreen, isTinyScreen),
                  SizedBox(height: isSmallScreen ? 20 : 24),
                  _buildRecentTransactions(
                    walletService,
                    wallet,
                    isSmallScreen,
                    isTinyScreen,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(
    Wallet wallet,
    bool isSmallScreen,
    bool isTinyScreen,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'رصيد المحفظة',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            '${wallet.balance?.toStringAsFixed(2) ?? '0.00'} ج.م',
            style: TextStyle(
              color: Colors.white,
              fontSize: isTinyScreen
                  ? 24
                  : isSmallScreen
                  ? 26
                  : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          isSmallScreen
              ? Column(
                  children: [
                    _buildBalanceInfo(
                      title: 'إجمالي الإيداعات',
                      value:
                          '${wallet.totalDeposit?.toStringAsFixed(2) ?? '0.00'} ج.م',
                      icon: Icons.arrow_downward,
                      color: Colors.green[300]!,
                      isSmall: isSmallScreen,
                    ),
                    const SizedBox(height: 8),
                    _buildBalanceInfo(
                      title: 'إجمالي السحوبات',
                      value:
                          '${wallet.totalWithdraw?.toStringAsFixed(2) ?? '0.00'} ج.م',
                      icon: Icons.arrow_upward,
                      color: Colors.red[300]!,
                      isSmall: isSmallScreen,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildBalanceInfo(
                        title: 'إجمالي الإيداعات',
                        value:
                            '${wallet.totalDeposit?.toStringAsFixed(2) ?? '0.00'} ج.م',
                        icon: Icons.arrow_downward,
                        color: Colors.green[300]!,
                        isSmall: isSmallScreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildBalanceInfo(
                        title: 'إجمالي السحوبات',
                        value:
                            '${wallet.totalWithdraw?.toStringAsFixed(2) ?? '0.00'} ج.م',
                        icon: Icons.arrow_upward,
                        color: Colors.red[300]!,
                        isSmall: isSmallScreen,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isSmall,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(isSmall ? 6 : 8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isSmall ? 16 : 18),
          SizedBox(width: isSmall ? 6 : 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmall ? 10 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmall ? 10 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    bool isSmallScreen,
    bool isTinyScreen,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'العمليات السريعة',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3436),
            ),
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          isSmallScreen
              ? Column(
                  children: [
                    _buildActionButton(
                      icon: Icons.add,
                      label: 'إيداع',
                      color: const Color(0xFF00B894),
                      isSmall: isSmallScreen,
                      isTiny: isTinyScreen,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DepositScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      icon: Icons.remove,
                      label: 'سحب',
                      color: const Color(0xFFD63031),
                      isSmall: isSmallScreen,
                      isTiny: isTinyScreen,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WithdrawScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      icon: Icons.history,
                      label: 'السجل',
                      color: const Color(0xFF0984E3),
                      isSmall: isSmallScreen,
                      isTiny: isTinyScreen,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const TransactionHistoryScreen(),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.add,
                        label: 'إيداع',
                        color: const Color(0xFF00B894),
                        isSmall: isSmallScreen,
                        isTiny: isTinyScreen,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DepositScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.remove,
                        label: 'سحب',
                        color: const Color(0xFFD63031),
                        isSmall: isSmallScreen,
                        isTiny: isTinyScreen,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WithdrawScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.history,
                        label: 'السجل',
                        color: const Color(0xFF0984E3),
                        isSmall: isSmallScreen,
                        isTiny: isTinyScreen,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TransactionHistoryScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isSmall,
    required bool isTiny,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isSmall ? 8 : 10),
        ),
        padding: EdgeInsets.symmetric(
          vertical: isTiny
              ? 8
              : isSmall
              ? 10
              : 12,
        ),
        elevation: 0,
        minimumSize: Size(
          0,
          isTiny
              ? 45
              : isSmall
              ? 50
              : 55,
        ),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isTiny
                ? 20
                : isSmall
                ? 22
                : 24,
          ),
          SizedBox(
            height: isTiny
                ? 4
                : isSmall
                ? 5
                : 6,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isTiny
                  ? 12
                  : isSmall
                  ? 13
                  : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(
    WalletService walletService,
    Wallet wallet,
    bool isSmallScreen,
    bool isTinyScreen,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر المعاملات',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3436),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionHistoryScreen(),
                  ),
                ),
                child: Text(
                  'عرض الكل',
                  style: TextStyle(
                    color: const Color(0xFF6C5CE7),
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          FutureBuilder<List<WalletTransaction>>(
            future: walletService.getTransactions(wallet.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  'خطأ: ${snapshot.error}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.red,
                  ),
                );
              }

              final transactions = snapshot.data?.take(3).toList() ?? [];

              if (transactions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: Text(
                      'لا توجد معاملات حديثة',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: transactions.map((transaction) {
                  return Column(
                    children: [
                      _buildTransactionItem(
                        transaction,
                        isSmallScreen,
                        isTinyScreen,
                      ),
                      if (transaction != transactions.last)
                        Divider(height: isSmallScreen ? 12 : 16),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    WalletTransaction transaction,
    bool isSmallScreen,
    bool isTinyScreen,
  ) {
    final isDeposit = transaction.transactionType == 'deposit';
    final description = transaction.description ?? 'معاملة غير معروفة';
    final date = transaction.createdAt ?? DateTime.now();
    final amount = transaction.amount ?? 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: isSmallScreen ? 4 : 8,
      leading: Container(
        width: isTinyScreen
            ? 32
            : isSmallScreen
            ? 36
            : 40,
        height: isTinyScreen
            ? 32
            : isSmallScreen
            ? 36
            : 40,
        decoration: BoxDecoration(
          color: isDeposit
              ? const Color(0xFF00B894).withOpacity(0.1)
              : const Color(0xFFD63031).withOpacity(0.1),
          borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
        ),
        child: Icon(
          isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
          color: isDeposit ? const Color(0xFF00B894) : const Color(0xFFD63031),
          size: isTinyScreen
              ? 16
              : isSmallScreen
              ? 18
              : 20,
        ),
      ),
      title: Text(
        description,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: isTinyScreen
              ? 13
              : isSmallScreen
              ? 14
              : 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${date.day}/${date.month}/${date.year}',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: isTinyScreen
              ? 10
              : isSmallScreen
              ? 11
              : 12,
        ),
      ),
      trailing: Text(
        '${isDeposit ? '+' : '-'}${amount.toStringAsFixed(2)} ج.م',
        style: TextStyle(
          color: isDeposit ? const Color(0xFF00B894) : const Color(0xFFD63031),
          fontWeight: FontWeight.bold,
          fontSize: isTinyScreen
              ? 11
              : isSmallScreen
              ? 12
              : 15,
        ),
      ),
    );
  }
}
