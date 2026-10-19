import 'dart:math';
import 'payment.dart';

class AmortizationRow {
  final int month;
  final String dueDate;
  final double emi;
  final double principal;
  final double interest;
  final double balance;
  final bool isPaid;

  AmortizationRow({
    required this.month,
    required this.dueDate,
    required this.emi,
    required this.principal,
    required this.interest,
    required this.balance,
    required this.isPaid,
  });
}

class Loan {
  final String id;
  final String borrower;
  final String phone;           // Calling mobile number
  final String whatsappPhone;   // WhatsApp number (optional, can match phone)
  final List<String> documentProofs; // Document attachment paths/names
  final double principal;
  final double interest;        // annual rate %
  final int tenure;             // months
  final String model;           // 'emi' or 'simple'
  final String startDate;
  final int created;
  final String? notes;
  final double legacyPaid;
  final List<Payment> payments;

  Loan({
    required this.id,
    required this.borrower,
    required this.phone,
    String? whatsappPhone,
    List<String>? documentProofs,
    required this.principal,
    required this.interest,
    required this.tenure,
    this.model = 'emi',
    required this.startDate,
    required this.created,
    this.notes,
    this.legacyPaid = 0.0,
    required this.payments,
  })  : whatsappPhone = (whatsappPhone != null && whatsappPhone.isNotEmpty) ? whatsappPhone : phone,
        documentProofs = documentProofs ?? const [];

  // Effective WhatsApp target
  String get effectiveWhatsApp => whatsappPhone.isNotEmpty ? whatsappPhone : phone;

  // Calculate Reducing EMI
  static double calcEmi(double p, double annualRate, int months) {
    if (p <= 0 || months <= 0) return 0;
    if (annualRate <= 0) return (p / months).roundToDouble();
    final r = (annualRate / 12) / 100;
    final top = p * r * pow(1 + r, months);
    final bottom = pow(1 + r, months) - 1;
    if (bottom == 0) return (p / months).roundToDouble();
    return (top / bottom).roundToDouble();
  }

  // Calculate Flat Simple Interest Installment
  static double calcSimple(double p, double annualRate, int months) {
    if (p <= 0 || months <= 0) return 0;
    final totalInterest = p * (annualRate / 100) * (months / 12);
    final totalPayable = p + totalInterest;
    return (totalPayable / months).roundToDouble();
  }

  double get monthlyInstallment {
    if (model == 'emi') {
      return calcEmi(principal, interest, tenure);
    } else {
      return calcSimple(principal, interest, tenure);
    }
  }

  double get totalPayable {
    if (model == 'emi') {
      return monthlyInstallment * tenure;
    } else {
      final totalInterest = principal * (interest / 100) * (tenure / 12);
      return (principal + totalInterest).roundToDouble();
    }
  }

  double get totalInterest {
    return max(0.0, totalPayable - principal);
  }

  double get totalPaid {
    final paymentsSum = payments.fold<double>(0.0, (sum, p) => sum + p.amount);
    return paymentsSum + legacyPaid;
  }

  double get remaining {
    return max(0.0, totalPayable - totalPaid);
  }

  double get progressPercent {
    if (totalPayable <= 0) return 0.0;
    return min(100.0, (totalPaid / totalPayable) * 100.0);
  }

  bool get isCompleted => remaining <= 0;

  int get paidInstallmentsCount {
    if (monthlyInstallment <= 0) return 0;
    return min(tenure, (totalPaid / monthlyInstallment).floor());
  }

  // Next EMI Due Date
  DateTime get nextDueDate {
    try {
      final start = DateTime.parse(startDate);
      final monthOffset = paidInstallmentsCount;
      return DateTime(start.year, start.month + monthOffset, start.day);
    } catch (_) {
      return DateTime.now();
    }
  }

  List<AmortizationRow> get amortizationSchedule {
    final rows = <AmortizationRow>[];
    DateTime cursor;
    try {
      cursor = DateTime.parse(startDate);
    } catch (_) {
      cursor = DateTime.now();
    }

    double balance = principal;
    double currentTotalPaid = totalPaid;
    final r = (interest / 12) / 100;

    for (int i = 1; i <= tenure; i++) {
      final due = DateTime(cursor.year, cursor.month + (i - 1), cursor.day);
      final dueStr = "${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}";
      
      double emiVal = monthlyInstallment;
      double intVal = 0.0;
      double prinVal = 0.0;

      if (model == 'emi') {
        intVal = balance * r;
        prinVal = emiVal - intVal;
        balance = max(0.0, balance - prinVal);
      } else {
        intVal = (principal * (interest / 100) * (1 / 12));
        prinVal = emiVal - intVal;
        balance = max(0.0, balance - prinVal);
      }

      final isPaid = currentTotalPaid >= emiVal;
      if (isPaid) {
        currentTotalPaid -= emiVal;
      }

      rows.add(AmortizationRow(
        month: i,
        dueDate: dueStr,
        emi: emiVal,
        principal: prinVal,
        interest: intVal,
        balance: balance,
        isPaid: isPaid,
      ));
    }

    return rows;
  }

  factory Loan.fromJson(Map<String, dynamic> json) {
    var rawPayments = json['payments'];
    List<Payment> parsedPayments = [];
    if (rawPayments is List) {
      parsedPayments = rawPayments
          .map((p) => Payment.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }

    var rawDocs = json['documentProofs'];
    List<String> parsedDocs = [];
    if (rawDocs is List) {
      parsedDocs = rawDocs.map((d) => d.toString()).toList();
    }

    return Loan(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      borrower: json['borrower']?.toString() ?? 'Unnamed Borrower',
      phone: json['phone']?.toString() ?? '',
      whatsappPhone: json['whatsappPhone']?.toString(),
      documentProofs: parsedDocs,
      principal: (json['principal'] as num?)?.toDouble() ?? 0.0,
      interest: (json['interest'] as num?)?.toDouble() ?? 12.0,
      tenure: (json['tenure'] as num?)?.toInt() ?? 12,
      model: json['model']?.toString() ?? 'emi',
      startDate: json['startDate']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
      created: (json['created'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      notes: json['notes']?.toString(),
      legacyPaid: (json['legacyPaid'] as num?)?.toDouble() ?? 0.0,
      payments: parsedPayments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'borrower': borrower,
      'phone': phone,
      'whatsappPhone': whatsappPhone,
      'documentProofs': documentProofs,
      'principal': principal,
      'interest': interest,
      'tenure': tenure,
      'model': model,
      'startDate': startDate,
      'created': created,
      'notes': notes,
      'legacyPaid': legacyPaid,
      'payments': payments.map((p) => p.toJson()).toList(),
    };
  }
}
