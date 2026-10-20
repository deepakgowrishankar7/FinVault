import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loan.dart';
import '../models/user_role.dart';

class SupabaseService {
  // Central Supabase credentials matching the web app
  static const String defaultUrl = 'https://cpfpmnyipiqdtcnobwoq.supabase.co';
  static const String defaultKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwZnBtbnlpcGlxZHRjbm9id29xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIwMzYwMzcsImV4cCI6MjEwNzYxMjAzN30.KnKEfEWrUFNbvveRnwf9w71-nXULRDKQhrnhYoCrd_w';

  static SupabaseClient? _client;
  static String? _currentUrl;
  static String? _currentKey;

  static Future<bool> init({String? url, String? anonKey, SecuritySettings? settings}) async {
    String targetUrl = defaultUrl;
    String targetKey = defaultKey;

    if (settings != null && settings.useCustomCloud && settings.customSupabaseUrl.isNotEmpty && settings.customSupabaseKey.isNotEmpty) {
      targetUrl = settings.customSupabaseUrl.trim();
      targetKey = settings.customSupabaseKey.trim();
    } else if (url != null && url.trim().isNotEmpty && anonKey != null && anonKey.trim().isNotEmpty) {
      targetUrl = url.trim();
      targetKey = anonKey.trim();
    }

    try {
      if (_client == null || _currentUrl != targetUrl || _currentKey != targetKey) {
        _client = SupabaseClient(targetUrl, targetKey);
        _currentUrl = targetUrl;
        _currentKey = targetKey;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> testConnection(String url, String anonKey) async {
    try {
      if (url.trim().isEmpty || anonKey.trim().isEmpty) return false;
      final testClient = SupabaseClient(url.trim(), anonKey.trim());
      await testClient.from('loans').select().limit(1);
      return true;
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains("relation") || err.contains("table") || err.contains("column") || err.contains("not found")) {
        return true;
      }
      return false;
    }
  }

  static bool get isConfigured => _client != null;

  /// Pull ONLY loans belonging to this specific vault ID
  static Future<List<Loan>?> pullLoans(String vaultId) async {
    if (vaultId.isEmpty) return null;
    if (!isConfigured) await init();
    if (_client == null) return null;

    try {
      final res = await _client!.from('loans').select().filter('notes', 'ilike', '%[vault:$vaultId]%');
      final list = (res as List).map((row) {
        final map = Map<String, dynamic>.from(row);
        if (!map.containsKey('interest') && map.containsKey('rate')) {
          map['interest'] = map['rate'];
        }
        final createdVal = map['created'] != null ? int.tryParse(map['created'].toString()) ?? 0 : 0;
        final idVal = map['id']?.toString() ?? createdVal.toString();
        map['id'] = (createdVal > 0) ? createdVal.toString() : idVal;
        if (map['notes'] != null) {
          map['notes'] = map['notes'].toString().replaceAll(RegExp(r'\s*\[vault:[^\]]+\]'), '').trim();
        }
        return Loan.fromJson(map);
      }).toList();
      return list;
    } catch (_) {
      return null;
    }
  }

  /// Push loans tagged with this specific vault ID
  static Future<bool> pushLoans(List<Loan> loans, String vaultId) async {
    if (vaultId.isEmpty) return false;
    if (!isConfigured) await init();
    if (_client == null) return false;

    try {
      final rows = loans.map((l) {
        final rawId = l.created > 0 ? l.created : (int.tryParse(l.id) ?? l.id.hashCode.abs());
        final baseNotes = (l.notes ?? '').replaceAll(RegExp(r'\s*\[vault:[^\]]+\]'), '').trim();
        return {
          'id': rawId,
          'borrower': l.borrower,
          'phone': l.phone,
          'principal': l.principal,
          'rate': l.interest,
          'tenure': l.tenure,
          'model': l.model,
          'startDate': l.startDate,
          'created': l.created > 0 ? l.created : rawId,
          'notes': "$baseNotes [vault:$vaultId]".trim(),
          'payments': l.payments.map((p) => p.toJson()).toList(),
        };
      }).toList();

      await _client!.from('loans').upsert(rows);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteLoan(String loanId, String vaultId) async {
    if (!isConfigured) await init();
    if (_client == null) return false;
    try {
      final rawId = int.tryParse(loanId) ?? loanId.hashCode.abs();
      await _client!.from('loans').delete().eq('id', rawId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
