import 'package:flutter/material.dart';
import '../models/payment_method_model.dart';

class PaymentMethodCard extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback? onTap;

  const PaymentMethodCard({
    super.key,
    required this.method,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Colors.blue[50] : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(
                method.type == 'credit_card' ? Icons.credit_card : Icons.phone_android,
                size: 40,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.type == 'credit_card' ? 'بطاقة ائتمان' : 'فودافون كاش',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('**** **** **** ${method.lastFourDigits}'),
                ],
              ),
              const Spacer(),
              if (method.isDefault)
                const Chip(
                  label: Text('افتراضي'),
                  backgroundColor: Colors.green,
                  labelStyle: TextStyle(color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}