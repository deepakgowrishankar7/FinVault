import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../models/user_role.dart';

class StorageService {
  static const String _loansKey = 'finvault_loans_v1';
  static const String _settingsKey = 'finvault_settings_v1';

  static Future<List<Loan>> getLoans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_loansKey);
    if (raw == null || raw.isEmpty) {
      final sample = _getSampleLoans();
      await saveLoans(sample);
      return sample;
    }
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => Loan.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (_) {
      return _getSampleLoans();
    }
  }

  static Future<void> saveLoans(List<Loan> loans) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = loans.map((l) => l.toJson()).toList();
    await prefs.setString(_loansKey, jsonEncode(jsonList));
  }

  static Future<SecuritySettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      final def = SecuritySettings();
      await saveSettings(def);
      return def;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SecuritySettings.fromJson(map);
    } catch (_) {
      return SecuritySettings();
    }
  }

  static Future<void> saveSettings(SecuritySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  static List<Loan> _getSampleLoans() {
    final now = DateTime.now();
    return [
      Loan(
        id: 'L-101',
        borrower: 'Rajesh Sharma',
        phone: '9840123456',
        principal: 100000,
        interest: 12,
        tenure: 12,
        model: 'emi',
        startDate: now.subtract(const Duration(days: 90)).toIso8601String().split('T')[0],
        created: now.subtract(const Duration(days: 90)).millisecondsSinceEpoch,
        notes: 'Grocery store inventory expansion',
        payments: [
          Payment(id: 1, amount: 8885, date: now.subtract(const Duration(days: 60)).toIso8601String().split('T')[0], mode: 'UPI', note: 'EMI 1/12'),
          Payment(id: 2, amount: 8885, date: now.subtract(const Duration(days: 30)).toIso8601String().split('T')[0], mode: 'UPI', note: 'EMI 2/12'),
        ],
      ),
      Loan(
        id: 'L-102',
        borrower: 'Priya Sundaram',
        phone: '9840987654',
        principal: 50000,
        interest: 14,
        tenure: 6,
        model: 'simple',
        startDate: now.subtract(const Duration(days: 30)).toIso8601String().split('T')[0],
        created: now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        notes: 'Boutique stock purchase',
        payments: [
          Payment(id: 3, amount: 8917, date: now.subtract(const Duration(days: 5)).toIso8601String().split('T')[0], mode: 'Cash', note: 'First Installment'),
        ],
      ),
      Loan(
        id: 'L-103',
        borrower: 'Karthik V',
        phone: '9790112233',
        principal: 30000,
        interest: 10,
        tenure: 3,
        model: 'emi',
        startDate: now.subtract(const Duration(days: 120)).toIso8601String().split('T')[0],
        created: now.subtract(const Duration(days: 120)).millisecondsSinceEpoch,
        notes: 'Equipment maintenance',
        payments: [
          Payment(id: 4, amount: 10167, date: now.subtract(const Duration(days: 90)).toIso8601String().split('T')[0], mode: 'UPI', note: 'EMI 1/3'),
          Payment(id: 5, amount: 10167, date: now.subtract(const Duration(days: 60)).toIso8601String().split('T')[0], mode: 'UPI', note: 'EMI 2/3'),
          Payment(id: 6, amount: 10167, date: now.subtract(const Duration(days: 30)).toIso8601String().split('T')[0], mode: 'Cash', note: 'Final EMI (Settled)'),
        ],
      ),
    ];
  }
}
