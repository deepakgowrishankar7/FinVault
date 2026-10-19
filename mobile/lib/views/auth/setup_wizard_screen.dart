import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../theme/fin_theme.dart';
import '../../theme/app_locale.dart';
import '../dashboard/dashboard_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firmNameController = TextEditingController(text: 'FinVault');
  final _adminNameController = TextEditingController(text: 'Admin');
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _questionController = TextEditingController(text: 'City where business was started?');
  final _answerController = TextEditingController();
  final _upiController = TextEditingController(text: 'owner@okhdfcbank');

  String _selectedLang = 'en';
  bool _obscurePin = true;
  bool _obscureConfirm = true;
  bool _isRestoring = false;

  @override
  void dispose() {
    _firmNameController.dispose();
    _adminNameController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  String _t(String key) => AppLocale.tr(key, _selectedLang);

  String _generateUniqueVaultId() {
    final rand = Random();
    final chars = '0123456789ABCDEF';
    String randomHex(int len) => List.generate(len, (_) => chars[rand.nextInt(chars.length)]).join();
    final timeHex = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    return "FV-${randomHex(4)}-$timeHex-${randomHex(4)}";
  }

  Future<void> _submitSetup() async {
    if (!_formKey.currentState!.validate()) return;

    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (pin.length != 4 || int.tryParse(pin) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Master Passcode must be exactly 4 digits"),
          backgroundColor: FinTheme.danger,
        ),
      );
      return;
    }

    if (pin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Passcodes do not match! Please check again."),
          backgroundColor: FinTheme.danger,
        ),
      );
      return;
    }

    final uniqueVaultId = _generateUniqueVaultId();

    final newSettings = SecuritySettings(
      vaultId: uniqueVaultId,
      isRegistered: true,
      firmName: _firmNameController.text.trim().isEmpty ? 'FinVault' : _firmNameController.text.trim(),
      adminName: _adminNameController.text.trim().isEmpty ? 'Admin' : _adminNameController.text.trim(),
      adminPin: pin,
      securityQuestion: _questionController.text.trim().isEmpty ? 'City where business was started?' : _questionController.text.trim(),
      securityAnswer: _answerController.text.trim().toLowerCase(),
      ownerUpiId: _upiController.text.trim().isEmpty ? 'owner@okhdfcbank' : _upiController.text.trim(),
      cloudSyncEnabled: false, // Default is 100% offline local storage
      language: _selectedLang,
    );

    await StorageService.saveSettings(newSettings);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✨ Lending Firm registered successfully!"),
        backgroundColor: FinTheme.success,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(
          role: UserRole.admin,
          settings: newSettings,
        ),
      ),
    );
  }

  Future<void> _handleRestore() async {
    setState(() => _isRestoring = true);
    final result = await StorageService.pickAndRestoreFile();
    setState(() => _isRestoring = false);

    if (!mounted) return;

    if (result.success) {
      final updatedSettings = await StorageService.getSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🎉 ${result.message}"),
          backgroundColor: FinTheme.success,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            role: UserRole.admin,
            settings: updatedSettings,
          ),
        ),
      );
    } else if (result.message != "No file selected") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ ${result.message}"),
          backgroundColor: FinTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FinTheme.bgDark : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Language Switcher Selector Bar
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? FinTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? FinTheme.borderDark : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLang,
                      icon: const Icon(Icons.language, size: 18, color: FinTheme.primary),
                      isDense: true,
                      items: AppLocale.languages.map((l) {
                        return DropdownMenuItem<String>(
                          value: l['code'],
                          child: Text(
                            "${l['native']} (${l['name']})",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedLang = val);
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: FinTheme.primary.withOpacity(0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: FinTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "INITIAL DEVICE SETUP",
                  style: TextStyle(
                    color: FinTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Register Your Lending Firm",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "Configure your master security credentials. Stored 100% on this device with zero external tracking.",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Restore Existing Vault Card (Method A)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? FinTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FinTheme.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Already using FinVault on another device?",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Transfer your complete vault (.finvault, .json, or .csv) from Phone/PC in 1 click.",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isRestoring ? null : _handleRestore,
                        icon: _isRestoring
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.file_download_outlined, color: FinTheme.primary),
                        label: Text(
                          _isRestoring ? "Restoring Vault..." : "Transfer Vault from Another Device (.finvault)",
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: FinTheme.primary, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "OR REGISTER NEW FIRM",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 20),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _firmNameController,
                      decoration: InputDecoration(
                        labelText: "Firm / Business Name *",
                        hintText: "e.g. FinVault Lending Co.",
                        prefixIcon: const Icon(Icons.business_outlined),
                        filled: true,
                        fillColor: isDark ? FinTheme.cardDark : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Firm name is required" : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _adminNameController,
                      decoration: InputDecoration(
                        labelText: "Admin Full Name *",
                        hintText: "e.g. Dhanasekar",
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: isDark ? FinTheme.cardDark : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Admin name is required" : null,
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: _obscurePin,
                            decoration: InputDecoration(
                              labelText: "Master PIN (4 Digits) *",
                              hintText: "e.g. 7845",
                              counterText: "",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility, size: 20),
                                onPressed: () => setState(() => _obscurePin = !_obscurePin),
                              ),
                              filled: true,
                              fillColor: isDark ? FinTheme.cardDark : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().length != 4 || int.tryParse(v.trim()) == null) {
                                return "4 digits required";
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _confirmPinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: "Confirm PIN *",
                              hintText: "Confirm 4 digits",
                              counterText: "",
                              prefixIcon: const Icon(Icons.lock_reset),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                              filled: true,
                              fillColor: isDark ? FinTheme.cardDark : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().length != 4) {
                                return "Confirm PIN";
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _questionController,
                      decoration: InputDecoration(
                        labelText: "Security Recovery Question *",
                        hintText: "e.g. City where business was started?",
                        prefixIcon: const Icon(Icons.help_outline),
                        filled: true,
                        fillColor: isDark ? FinTheme.cardDark : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Security question is required" : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _answerController,
                      decoration: InputDecoration(
                        labelText: "Secret Recovery Answer *",
                        hintText: "Answer to reset PIN if forgotten",
                        prefixIcon: const Icon(Icons.key_outlined),
                        filled: true,
                        fillColor: isDark ? FinTheme.cardDark : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Recovery answer is required" : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _upiController,
                      decoration: InputDecoration(
                        labelText: "Owner UPI ID (for QR code payments)",
                        hintText: "e.g. yourname@okhdfcbank",
                        prefixIcon: const Icon(Icons.qr_code_2),
                        filled: true,
                        fillColor: isDark ? FinTheme.cardDark : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FinTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        child: const Text(
                          "✨ Complete Registration & Enter Vault",
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
