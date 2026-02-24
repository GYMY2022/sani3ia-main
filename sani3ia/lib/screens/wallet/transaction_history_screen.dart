import 'package:flutter/material.dart';
import '../../../widgets/transaction_item.dart';
import '../../../services/wallet_service.dart';
import '../../../models/wallet_transaction_model.dart';
import 'package:provider/provider.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final walletService = Provider.of<WalletService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('سجل المعاملات')),
      body: FutureBuilder<List<WalletTransaction>>(
        future: walletService.getTransactions(
          'wallet_id',
        ), // Replace with actual wallet ID
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final transactions = snapshot.data!;

          if (transactions.isEmpty) {
            return const Center(child: Text('لا توجد معاملات سابقة'));
          }

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              return TransactionItem(transaction: transactions[index]);
            },
          );
        },
      ),
    );
  }
}
