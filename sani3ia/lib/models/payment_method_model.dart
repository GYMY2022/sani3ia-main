class PaymentMethod {
  final String id;
  final String userId;
  final String type; // 'credit_card', 'vodafone_cash', etc.
  final String lastFourDigits; // For cards
  final bool isDefault;
  final DateTime addedDate;

  PaymentMethod({
    required this.id,
    required this.userId,
    required this.type,
    required this.lastFourDigits,
    this.isDefault = false,
    required this.addedDate,
  });

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      lastFourDigits: map['lastFourDigits'] ?? '',
      isDefault: map['isDefault'] ?? false,
      addedDate: DateTime.parse(map['addedDate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'lastFourDigits': lastFourDigits,
      'isDefault': isDefault,
      'addedDate': addedDate.toIso8601String(),
    };
  }
}