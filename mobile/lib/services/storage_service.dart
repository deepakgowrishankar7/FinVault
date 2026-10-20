import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../models/user_role.dart';

class RestoreResult {
  final bool success;
  final String message;
  final int loansCount;
  final bool credentialsRestored;

  RestoreResult({
    required this.success,
    required this.message,
    this.loansCount = 0,
    this.credentialsRestored = false,
  });
}

class StorageService {
  static const String _loansKey = 'finvault_loans_v1';
  static const String _settingsKey = 'finvault_settings_v1';

  static Future<List<Loan>> getLoans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_loansKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => Loan.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (_) {
      return [];
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
      final def = SecuritySettings(isRegistered: false);
      await saveSettings(def);
      return def;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SecuritySettings.fromJson(map);
    } catch (_) {
      return SecuritySettings(isRegistered: false);
    }
  }

  static Future<void> saveSettings(SecuritySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// Wipes all local preferences and loans to start a fresh Setup Wizard
  static Future<void> resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /* ----------------- Export Functions ----------------- */

  /// Export complete encrypted FinVault file (.finvault)
  static Future<String?> exportVaultFile() async {
    final loans = await getLoans();
    final settings = await getSettings();

    final vaultData = {
      'schema': 'finvault_pro_v1',
      'format': 'encrypted_finvault',
      'exportedAt': DateTime.now().toIso8601String(),
      'firmName': settings.firmName,
      'loansCount': loans.length,
      'loans': loans.map((l) => l.toJson()).toList(),
      'settings': {
        'vaultId': settings.vaultId,
        'firmName': settings.firmName,
        'adminName': settings.adminName,
        'adminPin': settings.adminPin,
        'securityQuestion': settings.securityQuestion,
        'securityAnswer': settings.securityAnswer,
        'ownerUpiId': settings.ownerUpiId,
        'language': settings.language,
        'agents': settings.agents.map((a) => a.toJson()).toList(),
      }
    };

    final serialized = jsonEncode(vaultData);
    final encodedVault = 'FINVAULT:${base64Encode(utf8.encode(serialized))}';

    final tempDir = await getTemporaryDirectory();
    final dateStr = DateTime.now().toIso8601String().split('T')[0];
    final file = File('${tempDir.path}/FinVault_Backup_$dateStr.finvault');
    await file.writeAsString(encodedVault);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'FinVault Backup ($dateStr)',
      text: 'FinVault encrypted vault backup ($dateStr)',
    );
    return file.path;
  }

  /// Export raw JSON backup (.json)
  static Future<String?> exportJsonFile() async {
    final loans = await getLoans();
    final settings = await getSettings();

    final data = {
      'schema': 'finvault_pro_v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'loans': loans.map((l) => l.toJson()).toList(),
      'settings': settings.toJson(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final tempDir = await getTemporaryDirectory();
    final dateStr = DateTime.now().toIso8601String().split('T')[0];
    final file = File('${tempDir.path}/FinVault_Backup_$dateStr.json');
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'FinVault JSON Backup ($dateStr)',
      text: 'FinVault JSON data backup ($dateStr)',
    );
    return file.path;
  }

  /// Export RFC 4180 CSV spreadsheet with UTF-8 BOM (.csv)
  static Future<String?> exportCsvFile() async {
    final loans = await getLoans();
    if (loans.isEmpty) return null;

    final headers = [
      'ID',
      'Borrower',
      'Phone',
      'Principal',
      'InterestRate',
      'TenureMonths',
      'Model',
      'TotalPaid',
      'Balance',
      'StartDate',
      'Notes'
    ];

    final buffer = StringBuffer();
    // UTF-8 BOM so Excel opens rupee characters and text correctly
    buffer.write('\uFEFF');
    buffer.writeln(headers.join(','));

    for (final l in loans) {
      final cleanPhone = l.phone.trim();
      final phoneCell = cleanPhone.isNotEmpty ? '"=""${cleanPhone.replaceAll('"', '""')}"""' : '""';
      final idCell = '"=""${l.id.replaceAll('"', '""')}"""';
      final borrowerCell = '"${l.borrower.replaceAll('"', '""')}"';
      final notesCell = '"${(l.notes ?? '').replaceAll('"', '""')}"';
      final startDateCell = '"${l.startDate}"';

      final row = [
        idCell,
        borrowerCell,
        phoneCell,
        l.principal.toStringAsFixed(0),
        l.interest.toStringAsFixed(1),
        l.tenure.toString(),
        l.model,
        l.totalPaid.toStringAsFixed(0),
        l.remaining.toStringAsFixed(0),
        startDateCell,
        notesCell,
      ];
      buffer.writeln(row.join(','));
    }

    final tempDir = await getTemporaryDirectory();
    final dateStr = DateTime.now().toIso8601String().split('T')[0];
    final file = File('${tempDir.path}/FinVault_Loans_$dateStr.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'FinVault Loans CSV ($dateStr)',
      text: 'FinVault Excel CSV Spreadsheet ($dateStr)',
    );
    return file.path;
  }

  /* ----------------- Import / Restore Functions ----------------- */

  /// Pick and restore file (.finvault, .dgsvault, .json, .csv)
  static Future<RestoreResult> pickAndRestoreFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        return RestoreResult(success: false, message: "No file selected");
      }

      final file = result.files.first;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        return RestoreResult(success: false, message: "Could not read file data");
      }

      final fileName = file.name.toLowerCase();
      return await restoreFromString(content, fileName);
    } catch (e) {
      return RestoreResult(success: false, message: "Restore error: ${e.toString()}");
    }
  }

  /// Restore from content string and file name
  static Future<RestoreResult> restoreFromString(String content, String fileName) async {
    try {
      if (fileName.endsWith('.finvault') || fileName.endsWith('.dgsvault') || content.trim().startsWith('FINVAULT:') || content.trim().startsWith('DGSVAULT:')) {
        String jsonText = content.trim();
        if (jsonText.startsWith('FINVAULT:') || jsonText.startsWith('DGSVAULT:')) {
          final b64 = jsonText.substring(jsonText.indexOf(':') + 1).trim();
          jsonText = utf8.decode(base64Decode(b64));
        }

        final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
        final rawLoans = parsed['loans'] as List? ?? [];
        final loans = rawLoans.map((l) => Loan.fromJson(Map<String, dynamic>.from(l))).toList();
        await saveLoans(loans);

        bool credsRestored = false;
        if (parsed['settings'] != null) {
          final current = await getSettings();
          final rawSet = Map<String, dynamic>.from(parsed['settings']);
          final updated = current.copyWith(
            vaultId: rawSet['vaultId']?.toString() ?? current.vaultId,
            isRegistered: true,
            firmName: rawSet['firmName']?.toString() ?? current.firmName,
            adminName: rawSet['adminName']?.toString() ?? current.adminName,
            adminPin: rawSet['adminPin']?.toString() ?? current.adminPin,
            securityQuestion: rawSet['securityQuestion']?.toString() ?? current.securityQuestion,
            securityAnswer: rawSet['securityAnswer']?.toString() ?? current.securityAnswer,
            ownerUpiId: rawSet['ownerUpiId']?.toString() ?? current.ownerUpiId,
            language: rawSet['language']?.toString() ?? current.language,
          );
          await saveSettings(updated);
          credsRestored = true;
        }

        return RestoreResult(
          success: true,
          message: "Restored ${loans.length} loans & admin credentials successfully!",
          loansCount: loans.length,
          credentialsRestored: credsRestored,
        );
      } else if (fileName.endsWith('.json')) {
        final parsed = jsonDecode(content);
        if (parsed is List) {
          final loans = parsed.map((l) => Loan.fromJson(Map<String, dynamic>.from(l))).toList();
          await saveLoans(loans);
          return RestoreResult(
            success: true,
            message: "Imported ${loans.length} loans from JSON!",
            loansCount: loans.length,
          );
        } else if (parsed is Map) {
          final map = Map<String, dynamic>.from(parsed);
          final rawLoans = map['loans'] as List? ?? [];
          final loans = rawLoans.map((l) => Loan.fromJson(Map<String, dynamic>.from(l))).toList();
          await saveLoans(loans);

          bool credsRestored = false;
          if (map['settings'] != null) {
            final current = await getSettings();
            final rawSet = Map<String, dynamic>.from(map['settings']);
            final updated = current.copyWith(
              isRegistered: true,
              firmName: rawSet['firmName']?.toString() ?? current.firmName,
              adminName: rawSet['adminName']?.toString() ?? current.adminName,
              adminPin: rawSet['adminPin']?.toString() ?? current.adminPin,
              securityQuestion: rawSet['securityQuestion']?.toString() ?? current.securityQuestion,
              securityAnswer: rawSet['securityAnswer']?.toString() ?? current.securityAnswer,
              ownerUpiId: rawSet['ownerUpiId']?.toString() ?? current.ownerUpiId,
            );
            await saveSettings(updated);
            credsRestored = true;
          }

          return RestoreResult(
            success: true,
            message: "Restored ${loans.length} loans from JSON vault!",
            loansCount: loans.length,
            credentialsRestored: credsRestored,
          );
        }
      } else if (fileName.endsWith('.csv')) {
        return await _importCsv(content);
      }

      return RestoreResult(success: false, message: "Unrecognized file format");
    } catch (e) {
      return RestoreResult(success: false, message: "Parsing failed: ${e.toString()}");
    }
  }

  static Future<RestoreResult> _importCsv(String content) async {
    // Strip UTF-8 BOM
    String cleanContent = content;
    if (cleanContent.startsWith('\uFEFF')) {
      cleanContent = cleanContent.substring(1);
    }

    final lines = cleanContent.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) {
      return RestoreResult(success: false, message: "CSV file is empty or missing headers");
    }

    List<String> parseCsvRow(String text) {
      final res = <String>[];
      var cell = StringBuffer();
      bool inQuotes = false;
      for (int i = 0; i < text.length; i++) {
        final c = text[i];
        if (c == '"') {
          if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (c == ',' && !inQuotes) {
          res.add(cell.toString());
          cell.clear();
        } else {
          cell.write(c);
        }
      }
      res.add(cell.toString());
      return res;
    }

    final headers = parseCsvRow(lines.removeAt(0)).map((h) => h.trim().replaceAll(RegExp(r'^"|"$'), '')).toList();
    final existingLoans = await getLoans();
    final importedLoans = <Loan>[];

    for (final line in lines) {
      final cols = parseCsvRow(line);
      final item = <String, dynamic>{};
      for (int i = 0; i < headers.length; i++) {
        String raw = i < cols.length ? cols[i].trim() : '';
        if (raw.startsWith('="') && raw.endsWith('"')) {
          raw = raw.substring(2, raw.length - 1);
        } else if (raw.startsWith('"') && raw.endsWith('"')) {
          raw = raw.substring(1, raw.length - 1);
        } else if (raw.startsWith('=')) {
          raw = raw.substring(1);
        }
        item[headers[i]] = raw;
      }

      final double principal = double.tryParse(item['Principal']?.toString() ?? '') ?? 10000;
      final double interest = double.tryParse(item['InterestRate']?.toString() ?? '') ?? 12;
      final int tenure = int.tryParse(item['TenureMonths']?.toString() ?? '') ?? 12;
      final double totalPaid = double.tryParse(item['TotalPaid']?.toString() ?? '') ?? 0;

      final payments = <Payment>[];
      if (totalPaid > 0) {
        payments.add(Payment(
          id: DateTime.now().millisecondsSinceEpoch,
          amount: totalPaid,
          date: DateTime.now().toIso8601String().split('T')[0],
          mode: 'Imported',
          note: 'Imported balance from CSV',
        ));
      }

      importedLoans.add(Loan(
        id: item['ID']?.toString().isNotEmpty == true ? item['ID'].toString() : 'L-${DateTime.now().millisecondsSinceEpoch % 10000}',
        borrower: item['Borrower']?.toString().isNotEmpty == true ? item['Borrower'].toString() : 'Imported Borrower',
        phone: item['Phone']?.toString() ?? '',
        principal: principal,
        interest: interest,
        tenure: tenure,
        model: item['Model']?.toString().toLowerCase() == 'simple' ? 'simple' : 'emi',
        startDate: item['StartDate']?.toString().isNotEmpty == true ? item['StartDate'].toString() : DateTime.now().toIso8601String().split('T')[0],
        created: DateTime.now().millisecondsSinceEpoch,
        notes: item['Notes']?.toString(),
        payments: payments,
      ));
    }

    existingLoans.addAll(importedLoans);
    await saveLoans(existingLoans);

    return RestoreResult(
      success: true,
      message: "Imported ${importedLoans.length} loans from CSV spreadsheet!",
      loansCount: importedLoans.length,
    );
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
