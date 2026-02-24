import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snae3ya/services/wallet_service.dart';

class EscrowPaymentScreen extends StatelessWidget {
  final String jobId;
  final double amount;

  const EscrowPaymentScreen({
    super.key,
    required this.jobId,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final commission = amount * 0.07;
    final craftmanAmount = amount - commission;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدفع الآمن'),
        backgroundColor: const Color.fromARGB(255, 120, 45, 206),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تفاصيل الدفع الآمن',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildPaymentRow('المبلغ الإجمالي', '$amount ج.م'),
                    const Divider(),
                    _buildPaymentRow(
                      'العمولة (7%)',
                      '${commission.toStringAsFixed(2)} ج.م',
                    ),
                    const Divider(),
                    _buildPaymentRow(
                      'المبلغ المستلم للصنايعي',
                      '${craftmanAmount.toStringAsFixed(2)} ج.م',
                      isHighlighted: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'سيتم حجز المبلغ في حساب ضمان حتى إتمام العمل بنجاح',
              style: TextStyle(color: Colors.grey),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 120, 45, 206),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () async {
                  final walletService = Provider.of<WalletService>(
                    context,
                    listen: false,
                  );
                  try {
                    final success = await walletService.payToEscrow(
                      'current_user_id',
                      jobId,
                      amount,
                    );

                    if (success) {
                      Navigator.pop(context, true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم الدفع بنجاح')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('فشل في عملية الدفع')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
                    );
                  }
                },
                child: const Text(
                  'تأكيد الدفع الآمن',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
