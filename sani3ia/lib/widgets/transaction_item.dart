import 'package:flutter/material.dart';
import '../models/wallet_transaction_model.dart';

class TransactionItem extends StatelessWidget {
  final WalletTransaction transaction;

  const TransactionItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isDeposit = transaction.transactionType == 'deposit';
    final amount = transaction.amount ?? 0;
    final date = transaction.createdAt ?? DateTime.now();
    final description = transaction.description ?? 'معاملة';

    return ListTile(
      leading: Icon(
        isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
        color: isDeposit ? Colors.green : Colors.red,
      ),
      title: Text(description),
      subtitle: Text('${date.day}/${date.month}/${date.year}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isDeposit ? '+' : '-'}${amount.toStringAsFixed(2)} ج.م',
            style: TextStyle(
              color: isDeposit ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            transaction.status,
            style: TextStyle(
              color: transaction.status == 'completed'
                  ? Colors.green
                  : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
