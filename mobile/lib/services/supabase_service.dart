import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loan.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static Future<bool> init(String url, String anonKey) async {
    if (url.trim().isEmpty || anonKey.trim().isEmpty) return false;
    try {
      await Supabase.initialize(
        url: url.trim(),
        anonKey: anonKey.trim(),
      );
      _client = Supabase.instance.client;
      return true;
    } catch (_) {
      try {
        _client = Supabase.instance.client;
        return true;
      } catch (e) {
        return false;
      }
    }
  }

  static bool get isConfigured => _client != null;

  static Future<List<Loan>?> pullLoans() async {
    if (_client == null) return null;
    try {
      final res = await _client!.from('loans').select();
      final list = (res as List).map((row) {
        return Loan.fromJson(Map<String, dynamic>.from(row));
      }).toList();
      return list;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> pushLoans(List<Loan> loans) async {
    if (_client == null) return false;
    try {
      final rows = loans.map((l) {
        final map = l.toJson();
        return {
          'id': map['id'],
          'borrower': map['borrower'],
          'phone': map['phone'],
          'principal': map['principal'],
          'interest': map['interest'],
          'tenure': map['tenure'],
          'model': map['model'],
          'startDate': map['startDate'],
          'created': map['created'],
          'notes': map['notes'] ?? '',
          'payments': map['payments'],
        };
      }).toList();

      await _client!.from('loans').upsert(rows);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteLoan(String loanId) async {
    if (_client == null) return false;
    try {
      await _client!.from('loans').delete().eq('id', loanId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
