class Commission {
  final String id;
  final String transactionId;
  final String serviceType; // 'job' or 'market'
  final double amount;
  final double commissionRate;
  final double commissionAmount;
  final DateTime date;
  final String userId;
  final String clientId;

  Commission({
    required this.id,
    required this.transactionId,
    required this.serviceType,
    required this.amount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.date,
    required this.userId,
    required this.clientId,
  });

  factory Commission.fromMap(Map<String, dynamic> map) {
    return Commission(
      id: map['id'] ?? '',
      transactionId: map['transactionId'] ?? '',
      serviceType: map['serviceType'] ?? '',
      amount: map['amount']?.toDouble() ?? 0.0,
      commissionRate: map['commissionRate']?.toDouble() ?? 0.0,
      commissionAmount: map['commissionAmount']?.toDouble() ?? 0.0,
      date: DateTime.parse(map['date']),
      userId: map['userId'] ?? '',
      clientId: map['clientId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'serviceType': serviceType,
      'amount': amount,
      'commissionRate': commissionRate,
      'commissionAmount': commissionAmount,
      'date': date.toIso8601String(),
      'userId': userId,
      'clientId': clientId,
    };
  }
}