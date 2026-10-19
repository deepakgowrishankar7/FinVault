class Payment {
  final dynamic id;
  final double amount;
  final String date;
  final String mode; // 'UPI', 'Cash', 'Bank Transfer', etc.
  final String? collectedBy;
  final String? note;

  Payment({
    required this.id,
    required this.amount,
    required this.date,
    required this.mode,
    this.collectedBy,
    this.note,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
      mode: json['mode']?.toString() ?? 'UPI',
      collectedBy: json['collectedBy']?.toString(),
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'date': date,
      'mode': mode,
      if (collectedBy != null) 'collectedBy': collectedBy,
      if (note != null) 'note': note,
    };
  }
}
