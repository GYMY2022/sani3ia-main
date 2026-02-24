import '../models/commission_model.dart';

class CommissionRepository {
  Future<void> saveCommission(Commission commission) async {
    // Implement actual save to database
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<List<Commission>> getUserCommissions(String userId) async {
    // Mock data - replace with actual database call
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Commission(
        id: '1',
        transactionId: 'txn_123',
        serviceType: 'job',
        amount: 100.0,
        commissionRate: 0.15,
        commissionAmount: 15.0,
        date: DateTime.now(),
        userId: userId,
        clientId: 'client_123',
      ),
    ];
  }
}