import '../models/wallet_models.dart';
import '../models/wallet_transaction_model.dart';
import '../repositories/wallet_repository.dart';
import 'package:flutter/material.dart';

class WalletService extends ChangeNotifier {
  final WalletRepository _repository;
  Wallet? _wallet;
  bool _isLoading = false;
  String? _error;

  WalletService(this._repository);

  Wallet? get wallet => _wallet;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadWallet() async {
    try {
      _setLoading(true);
      _wallet = await _repository.getWallet(
        'user1',
      ); // استبدل 'user1' بالمعرف الفعلي للمستخدم
      _setError(null);
    } catch (e) {
      _setError('فشل في جلب بيانات المحفظة');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<WalletTransaction>> getTransactions(String walletId) async {
    try {
      return await _repository.getTransactions(walletId);
    } catch (e) {
      throw Exception('Failed to get transactions: $e');
    }
  }

  Future<void> deposit(
    String userId,
    double amount,
    String paymentMethodId,
  ) async {
    try {
      await _repository.deposit(userId, amount, paymentMethodId);
      await loadWallet();
    } catch (e) {
      throw Exception('Deposit failed: $e');
    }
  }

  Future<void> withdraw(
    String userId,
    double amount,
    String bankAccountId,
  ) async {
    try {
      await _repository.withdraw(userId, amount, bankAccountId);
      await loadWallet();
    } catch (e) {
      throw Exception('Withdrawal failed: $e');
    }
  }

  Future<bool> payToEscrow(String userId, String jobId, double amount) async {
    try {
      if (_wallet == null || _wallet!.balance! < amount) {
        return false;
      }

      await _repository.payToEscrow(userId, jobId, amount);
      await loadWallet();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> releaseFromEscrow(
    String jobId,
    double totalAmount,
    double commission,
  ) async {
    try {
      await _repository.releaseFromEscrow(jobId, totalAmount, commission);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> refundFromEscrow(String jobId, double amount) async {
    try {
      await _repository.refundFromEscrow(jobId, amount);
      return true;
    } catch (e) {
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
}
