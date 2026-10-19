import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loan.dart';

class SupabaseService {
  // Pre-configured developer Supabase credentials matching the web app
  static const String defaultUrl = 'https://cpfpmnyipiqdtcnobwoq.supabase.co';
  static const String defaultKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwZnBtbnlpcGlxZHRjbm9id29xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIwMzYwMzcsImV4cCI6MjEwNzYxMjAzN30.KnKEfEWrUFNbvveRnwf9w71-nXULRDKQhrnhYoCrd_w';

  static SupabaseClient? _client;
  static bool _isInitialized = false;

  static Future<bool> init({String? url, String? anonKey}) async {
    final targetUrl = (url != null && url.trim().isNotEmpty) ? url.trim() : defaultUrl;
    final targetKey = (anonKey != null && anonKey.trim().isNotEmpty) ? anonKey.trim() : defaultKey;

    try {
      if (!_isInitialized) {
        await Supabase.initialize(
          url: targetUrl,
          anonKey: targetKey,
        );
        _isInitialized = true;
      }
      _client = Supabase.instance.client;
      return true;
    } catch (_) {
      try {
        _client = Supabase.instance.client;
        _isInitialized = true;
        return true;
      } catch (e) {
        return false;
      }
    }
  }

  static bool get isConfigured => _client != null || _isInitialized;

  static Future<List<Loan>?> pullLoans() async {
    if (!isConfigured) await init();
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
    if (!isConfigured) await init();
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
    if (!isConfigured) await init();
    if (_client == null) return false;
    try {
      await _client!.from('loans').delete().eq('id', loanId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
