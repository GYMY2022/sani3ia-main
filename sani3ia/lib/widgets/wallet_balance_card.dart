import 'package:flutter/material.dart';
import 'package:snae3ya/models/wallet_models.dart';

class WalletBalanceCard extends StatelessWidget {
  final Wallet wallet;

  const WalletBalanceCard({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'رصيد المحفظة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${wallet.balance!.toStringAsFixed(2)} ${wallet.currency}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            if (wallet.escrowBalance! > 0)
              Text(
                'الرصيد المحجوز: ${wallet.escrowBalance!.toStringAsFixed(2)} ${wallet.currency}',
                style: const TextStyle(fontSize: 14, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }
}
