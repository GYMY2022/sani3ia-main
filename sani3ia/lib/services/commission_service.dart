import '../models/commission_model.dart';
import '../repositories/commission_repository.dart';

class CommissionService {
  final CommissionRepository _repository;

  CommissionService(this._repository);

  Future<double> calculateCommission(double amount, String serviceType) async {
    const double commissionRate = 0.15; // 15%
    return amount * commissionRate;
  }

  Future<void> applyCommission(Commission commission) async {
    try {
      await _repository.saveCommission(commission);
    } catch (e) {
      throw Exception('Failed to apply commission: $e');
    }
  }

  Future<List<Commission>> getUserCommissions(String userId) async {
    try {
      return await _repository.getUserCommissions(userId);
    } catch (e) {
      throw Exception('Failed to get commissions: $e');
    }
  }
}