import 'package:flutter/material.dart';
import '../models/wallet_models.dart';
import '../models/wallet_transaction_model.dart';

class WalletRepository extends ChangeNotifier {
  Future<Wallet> getWallet(String userId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      return Wallet(
        userId: userId,
        balance: 1000.0,
        totalDeposit: 1500.0,
        totalWithdraw: 500.0,
        escrowBalance: 0.0,
        currency: 'EGP',
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<WalletTransaction>> getTransactions(String walletId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      return [
        WalletTransaction(
          id: '1',
          walletId: walletId,
          amount: 500.0,
          transactionType: 'deposit',
          status: 'completed',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          description: 'Initial deposit',
        ),
      ];
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
      await Future.delayed(const Duration(seconds: 1));
      notifyListeners();
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
      await Future.delayed(const Duration(seconds: 1));
      notifyListeners();
    } catch (e) {
      throw Exception('Withdrawal failed: $e');
    }
  }

  Future<bool> payToEscrow(String userId, String jobId, double amount) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      notifyListeners();
      return true;
    } catch (e) {
      throw Exception('Escrow payment failed: $e');
    }
  }

  Future<bool> releaseFromEscrow(
    String jobId,
    double totalAmount,
    double commission,
  ) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      notifyListeners();
      return true;
    } catch (e) {
      throw Exception('Escrow release failed: $e');
    }
  }

  Future<bool> refundFromEscrow(String jobId, double amount) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      notifyListeners();
      return true;
    } catch (e) {
      throw Exception('Escrow refund failed: $e');
    }
  }
}
