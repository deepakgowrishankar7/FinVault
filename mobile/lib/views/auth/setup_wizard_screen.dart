import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/fin_theme.dart';
import '../../theme/app_locale.dart';
import '../dashboard/dashboard_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  // Mode: 0 for Admin Registration, 1 for Field Agent Join
  int _onboardingMode = 0;

  final _adminFormKey = GlobalKey<FormState>();
  final _agentFormKey = GlobalKey<FormState>();

  // Admin Form Controllers
  final _firmNameController = TextEditingController(text: 'FinVault');
  final _adminNameController = TextEditingController(text: 'Admin');
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _questionController = TextEditingController(text: 'City where business was started?');
  final _answerController = TextEditingController();
  final _upiController = TextEditingController(text: 'owner@okhdfcbank');

  // Agent Form Controllers
  final _agentVaultCodeCtrl = TextEditingController();
  final _agentPinCtrl = TextEditingController();

  String _selectedLang = 'en';
  bool _obscurePin = true;
  bool _obscureConfirm = true;
  bool _obscureAgentPin = true;
  bool _isRestoring = false;
  bool _isConnectingAgent = false;

  @override
  void dispose() {
    _firmNameController.dispose();
    _adminNameController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    _upiController.dispose();
    _agentVaultCodeCtrl.dispose();
    _agentPinCtrl.dispose();
    super.dispose();
  }

  String _t(String key) => AppLocale.tr(key, _selectedLang);

  /// Generate a clean, 6-character alphanumeric code: e.g. "FV-849201"
  String _generateCleanVaultCode() {
    final rand = Random();
    final chars = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // Exclude I, O to prevent confusion
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return "FV-$code";
  }

  Future<void> _submitAdminSetup() async {
    if (!_adminFormKey.currentState!.validate()) return;

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

    final uniqueVaultId = _generateCleanVaultCode();

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
      SnackBar(
        content: Text("✨ Registered! Your Firm Code is $uniqueVaultId"),
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

  Future<void> _submitAgentJoin() async {
    if (!_agentFormKey.currentState!.validate()) return;

    final rawCode = _agentVaultCodeCtrl.text.trim().toUpperCase();
    final vaultCode = rawCode.startsWith('FV-') ? rawCode : 'FV-$rawCode';
    final agentPin = _agentPinCtrl.text.trim();

    setState(() => _isConnectingAgent = true);

    try {
      await SupabaseService.init();

      // Pull loans and firm settings for this vault code
      final remoteLoans = await SupabaseService.pullLoans(vaultCode);

      // Verify or configure agent credentials
      final newSettings = SecuritySettings(
        vaultId: vaultCode,
        isRegistered: true,
        firmName: "Firm ($vaultCode)",
        adminName: "Master Admin",
        adminPin: "9999", // Agent does not have master PIN
        cloudSyncEnabled: true,
        language: _selectedLang,
        agents: [
          StaffAgent(
            id: "ag_${DateTime.now().millisecondsSinceEpoch}",
            name: "Field Agent",
            pin: agentPin,
          ),
        ],
      );

      await StorageService.saveSettings(newSettings);

      if (remoteLoans != null && remoteLoans.isNotEmpty) {
        await StorageService.saveLoans(remoteLoans);
      }

      setState(() => _isConnectingAgent = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🎉 Connected to Firm $vaultCode! Welcome, Field Agent."),
          backgroundColor: FinTheme.success,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            role: UserRole.agent,
            agent: newSettings.agents.first,
            settings: newSettings,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isConnectingAgent = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ Connection failed: Could not reach Firm $vaultCode. Check code and try again."),
          backgroundColor: FinTheme.danger,
        ),
      );
    }
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
    final isDesktop = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: isDark ? FinTheme.bgDark : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 24,
                vertical: isDesktop ? 24 : 16,
              ),
              child: Card(
                elevation: isDesktop ? 4 : 0,
                color: isDesktop
                    ? (isDark ? FinTheme.cardDark : Colors.white)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: isDesktop
                      ? BorderSide(color: isDark ? FinTheme.borderDark : const Color(0xFFE2E8F0))
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 28.0 : 0.0),
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
                        if (val != null) {
                          setState(() {
                            _selectedLang = val;
                            AppLocale.currentLang = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Logo
              Container(
                width: 76,
                height: 76,
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
              const SizedBox(height: 14),

              // Welcome Title
              Text(
                _t('welcome_to_finvault'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _t('welcome_sub'),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Onboarding Role Segment (Admin vs Field Agent)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? FinTheme.cardDark : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? FinTheme.borderDark : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _onboardingMode = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _onboardingMode == 0 ? FinTheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _onboardingMode == 0
                                ? [BoxShadow(color: FinTheme.primary.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.admin_panel_settings, size: 16, color: _onboardingMode == 0 ? Colors.white : Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                "👑 ${_t('master_admin')}",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _onboardingMode == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _onboardingMode = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _onboardingMode == 1 ? FinTheme.success : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _onboardingMode == 1
                                ? [BoxShadow(color: FinTheme.success.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.badge, size: 16, color: _onboardingMode == 1 ? Colors.white : Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                "🏃 ${_t('field_agent')}",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _onboardingMode == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // VIEW 1: ADMIN REGISTRATION & RESTORE
              if (_onboardingMode == 0) ...[
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
                      Text(
                        _t('already_using_finvault'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t('transfer_vault_sub'),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
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
                              : const Icon(Icons.file_download_outlined, color: FinTheme.primary, size: 18),
                          label: Text(
                            _isRestoring ? _t('restoring_vault') : _t('transfer_vault_btn'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: FinTheme.primary, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        _t('or_register_new_firm'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 16),

                // Form
                Form(
                  key: _adminFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _firmNameController,
                        decoration: InputDecoration(
                          labelText: _t('firm_business_name'),
                          hintText: _t('firm_name_hint'),
                          prefixIcon: const Icon(Icons.business_outlined),
                          filled: true,
                          fillColor: isDark ? FinTheme.cardDark : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Firm name is required" : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _adminNameController,
                        decoration: InputDecoration(
                          labelText: _t('admin_full_name'),
                          hintText: _t('admin_name_hint'),
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: isDark ? FinTheme.cardDark : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Admin name is required" : null,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              obscureText: _obscurePin,
                              decoration: InputDecoration(
                                labelText: _t('master_admin_pin'),
                                hintText: "e.g. 7845",
                                counterText: "",
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility, size: 18),
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _confirmPinController,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              obscureText: _obscureConfirm,
                              decoration: InputDecoration(
                                labelText: _t('confirm_admin_pin'),
                                hintText: "Confirm 4 digits",
                                counterText: "",
                                prefixIcon: const Icon(Icons.lock_reset),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
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
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _questionController,
                        decoration: InputDecoration(
                          labelText: _t('security_question'),
                          hintText: _t('security_question_hint'),
                          prefixIcon: const Icon(Icons.help_outline),
                          filled: true,
                          fillColor: isDark ? FinTheme.cardDark : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Security question is required" : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _answerController,
                        decoration: InputDecoration(
                          labelText: _t('security_answer'),
                          hintText: _t('security_answer_hint'),
                          prefixIcon: const Icon(Icons.key_outlined),
                          filled: true,
                          fillColor: isDark ? FinTheme.cardDark : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Recovery answer is required" : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _upiController,
                        decoration: InputDecoration(
                          labelText: _t('owner_upi_id'),
                          hintText: _t('owner_upi_hint'),
                          prefixIcon: const Icon(Icons.qr_code_2),
                          filled: true,
                          fillColor: isDark ? FinTheme.cardDark : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitAdminSetup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FinTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          child: Text(
                            _t('complete_reg_btn'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ] else ...[
                // VIEW 2: FIELD AGENT JOIN FLOW
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? FinTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FinTheme.success.withOpacity(0.35), width: 1.5),
                  ),
                  child: Form(
                    key: _agentFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: FinTheme.success.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.badge, color: FinTheme.success, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _t('field_agent_signin'),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                  Text(
                                    _t('connect_to_firm_sub'),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _t('agent_instructions'),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),

                        // Admin Firm Code Input
                        TextFormField(
                          controller: _agentVaultCodeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: _t('admin_firm_code'),
                            hintText: _t('firm_code_hint'),
                            prefixIcon: const Icon(Icons.vpn_key_outlined, color: FinTheme.primary),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? "Firm code is required" : null,
                        ),

                        const SizedBox(height: 16),

                        // 4-Digit Agent PIN
                        TextFormField(
                          controller: _agentPinCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: _obscureAgentPin,
                          decoration: InputDecoration(
                            labelText: _t('your_agent_pin'),
                            hintText: "e.g. 5678",
                            counterText: "",
                            prefixIcon: const Icon(Icons.lock_outline, color: FinTheme.success),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureAgentPin ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setState(() => _obscureAgentPin = !_obscureAgentPin),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length != 4) return "4-digit PIN required";
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isConnectingAgent ? null : _submitAgentJoin,
                            icon: _isConnectingAgent
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.login),
                            label: Text(
                              _isConnectingAgent ? _t('connecting_firm') : _t('join_firm_btn'),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FinTheme.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
