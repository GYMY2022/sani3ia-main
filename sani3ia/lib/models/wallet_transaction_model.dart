class WalletTransaction {
  final String id;
  final String walletId;
  final double? amount;
  final String transactionType; // 'deposit', 'withdraw', 'transfer', 'payment'
  final String status; // 'pending', 'completed', 'failed', 'refunded'
  final DateTime? createdAt;
  final String? referenceId;
  final String? description;
  final String? senderId;
  final String? receiverId;
  final String? paymentMethod;
  final String? transactionFee;

  WalletTransaction({
    required this.id,
    required this.walletId,
    this.amount,
    required this.transactionType,
    this.status = 'completed',
    this.createdAt,
    this.referenceId,
    this.description,
    this.senderId,
    this.receiverId,
    this.paymentMethod,
    this.transactionFee,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id']?.toString() ?? '',
      walletId: map['walletId']?.toString() ?? '',
      amount: map['amount'] != null
          ? double.tryParse(map['amount'].toString())
          : null,
      transactionType: map['type']?.toString() ?? 'deposit',
      status: map['status']?.toString() ?? 'completed',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'])
          : null,
      referenceId: map['referenceId']?.toString(),
      description: map['description']?.toString(),
      senderId: map['senderId']?.toString(),
      receiverId: map['receiverId']?.toString(),
      paymentMethod: map['paymentMethod']?.toString(),
      transactionFee: map['transactionFee']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'walletId': walletId,
      'amount': amount,
      'type': transactionType,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'referenceId': referenceId,
      'description': description,
      'senderId': senderId,
      'receiverId': receiverId,
      'paymentMethod': paymentMethod,
      'transactionFee': transactionFee,
    };
  }

  bool get isDeposit => transactionType == 'deposit';

  String get formattedAmount {
    if (amount == null) return '0.00';
    return '${isDeposit ? '+' : '-'}${amount!.toStringAsFixed(2)}';
  }

  String get formattedDate {
    if (createdAt == null) return 'تاريخ غير معروف';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }
}
