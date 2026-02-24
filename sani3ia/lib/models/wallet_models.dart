class Wallet {
  final String userId;
  final double? balance;
  final double? totalDeposit;
  final double? totalWithdraw;
  final double? escrowBalance;
  final String currency;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final String? id;

  Wallet({
    required this.userId,
    this.balance,
    this.totalDeposit,
    this.totalWithdraw,
    this.escrowBalance,
    required this.currency,
    required this.createdAt,
    required this.lastUpdated,
    this.id,
  });

  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: map['id'],
      userId: map['userId'],
      balance: map['balance']?.toDouble(),
      totalDeposit: map['totalDeposit']?.toDouble(),
      totalWithdraw: map['totalWithdraw']?.toDouble(),
      escrowBalance: map['escrowBalance']?.toDouble(),
      currency: map['currency'] ?? 'EGP',
      createdAt: DateTime.parse(map['createdAt']),
      lastUpdated: DateTime.parse(map['lastUpdated']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'balance': balance,
      'totalDeposit': totalDeposit,
      'totalWithdraw': totalWithdraw,
      'escrowBalance': escrowBalance,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
