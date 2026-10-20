import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/fin_theme.dart';
import '../../theme/app_locale.dart';
import 'package:local_auth/local_auth.dart';
import 'team_management_screen.dart';
import 'cloud_sync_screen.dart';
import '../auth/passcode_screen.dart';
import '../auth/setup_wizard_screen.dart';

class SettingsScreen extends StatefulWidget {
  final UserRole role;
  final StaffAgent? agent;
  final SecuritySettings settings;
  final ValueChanged<SecuritySettings> onSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.role,
    this.agent,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _t(String key) => AppLocale.tr(key, _settings.language);
  late SecuritySettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _editFirmProfile() {
    final firmCtrl = TextEditingController(text: _settings.firmName);
    final adminCtrl = TextEditingController(text: _settings.adminName);
    final upiCtrl = TextEditingController(text: _settings.ownerUpiId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Business Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: firmCtrl, decoration: const InputDecoration(labelText: "Firm / App Name", prefixIcon: Icon(Icons.business))),
            const SizedBox(height: 12),
            TextField(controller: adminCtrl, decoration: const InputDecoration(labelText: "Owner Name", prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 12),
            TextField(controller: upiCtrl, decoration: const InputDecoration(labelText: "Owner UPI VPA", prefixIcon: Icon(Icons.qr_code))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final updated = _settings.copyWith(
                firmName: firmCtrl.text.trim().isNotEmpty ? firmCtrl.text.trim() : 'FinVault',
                adminName: adminCtrl.text.trim().isNotEmpty ? adminCtrl.text.trim() : 'Admin',
                ownerUpiId: upiCtrl.text.trim().isNotEmpty ? upiCtrl.text.trim() : 'owner@okhdfcbank',
              );
              await StorageService.saveSettings(updated);
              if (updated.vaultId.isNotEmpty) {
                SupabaseService.pushVaultProfile(updated);
              }
              setState(() => _settings = updated);
              widget.onSettingsChanged(updated);
              if (mounted) Navigator.pop(ctx);
            },
            child: Text(_t('confirm')),
          ),
        ],
      ),
    );
  }

  void _changeAdminPin() {
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_t('change_master_pin'), style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: InputDecoration(labelText: _t('master_admin_pin'), prefixIcon: const Icon(Icons.lock)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (pinCtrl.text.trim().length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passcode must be 4 digits")));
                return;
              }
              final updated = _settings.copyWith(adminPin: pinCtrl.text.trim());
              await StorageService.saveSettings(updated);
              setState(() => _settings = updated);
              widget.onSettingsChanged(updated);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Master Passcode updated!"), backgroundColor: FinTheme.success),
                );
              }
            },
            child: Text(_t('confirm')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('settings_vault_security')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: FinTheme.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _settings.firmName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${_t('owner_prefix')}: ${_settings.adminName} • ${_settings.ownerUpiId}",
                          style: TextStyle(fontSize: 12, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (widget.role == UserRole.admin)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: FinTheme.primary),
                      onPressed: _editFirmProfile,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          if (widget.role == UserRole.admin) ...[
            _buildSectionHeader(_t('sec_security_passcode')),
            _buildTile(
              icon: Icons.pin,
              title: _t('change_master_pin'),
              subtitle: _t('change_pin_desc'),
              onTap: _changeAdminPin,
              isDark: isDark,
            ),
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: isDark ? FinTheme.cardDark : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FinTheme.radiusSmall),
                side: BorderSide(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
              ),
              child: SwitchListTile(
                secondary: const Icon(Icons.fingerprint, color: FinTheme.primary),
                title: const Text("Fingerprint / Face Unlock", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text("Unlock FinVault instantly without retyping PIN", style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _settings.biometricEnabled,
                onChanged: (val) async {
                  if (val) {
                    try {
                      final auth = LocalAuthentication();
                      final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
                      if (!canCheck && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Biometrics not available on this device")),
                        );
                        return;
                      }
                      final didAuth = await auth.authenticate(
                        localizedReason: 'Verify biometric identity to enable quick unlock',
                        options: const AuthenticationOptions(stickyAuth: true),
                      );
                      if (!didAuth) return;
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Biometric verification error: $e")),
                        );
                      }
                      return;
                    }
                  }
                  final updated = _settings.copyWith(biometricEnabled: val);
                  await StorageService.saveSettings(updated);
                  setState(() => _settings = updated);
                  widget.onSettingsChanged(updated);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val ? "✨ Biometric Unlock Enabled!" : "Biometric Unlock Disabled"),
                        backgroundColor: val ? FinTheme.success : Colors.grey,
                      ),
                    );
                  }
                },
              ),
            ),
            _buildTile(
              icon: Icons.group,
              title: _t('staff_field_agents'),
              subtitle: "${_settings.agents.length} ${_t('agents_configured')}",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamManagementScreen(
                      settings: _settings,
                      onSettingsUpdated: (updated) {
                        setState(() => _settings = updated);
                        widget.onSettingsChanged(updated);
                      },
                    ),
                  ),
                );
              },
              isDark: isDark,
            ),

            const SizedBox(height: 18),

            _buildSectionHeader(_t('sec_cloud_sync')),
            _buildTile(
              icon: Icons.cloud_outlined,
              title: _t('central_cloud_sync'),
              subtitle: _settings.cloudSyncEnabled ? "${_t('connected_active')} (Project: cpfpmnyipiqdtcnobwoq)" : _t('disabled_offline'),
              trailing: _settings.cloudSyncEnabled
                  ? const Icon(Icons.check_circle, color: FinTheme.success, size: 20)
                  : const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CloudSyncScreen(
                      settings: _settings,
                      onSettingsUpdated: (updated) {
                        setState(() => _settings = updated);
                        widget.onSettingsChanged(updated);
                      },
                    ),
                  ),
                );
              },
              isDark: isDark,
            ),

            const SizedBox(height: 18),

            _buildSectionHeader(_t('sec_backup_portability')),
            _buildTile(
              icon: Icons.shield_outlined,
              title: _t('export_snapshot'),
              subtitle: _t('export_snapshot_desc'),
              trailing: const Icon(Icons.share, size: 18, color: FinTheme.primary),
              onTap: () async {
                final path = await StorageService.exportVaultFile();
                if (path != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("🛡️ Complete .finvault backup generated and shared!"),
                      backgroundColor: FinTheme.success,
                    ),
                  );
                }
              },
              isDark: isDark,
            ),
            _buildTile(
              icon: Icons.table_view_outlined,
              title: _t('export_csv'),
              subtitle: _t('export_csv_desc'),
              trailing: const Icon(Icons.share, size: 18, color: FinTheme.primary),
              onTap: () async {
                final path = await StorageService.exportCsvFile();
                if (path != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("📊 CSV spreadsheet exported!"),
                      backgroundColor: FinTheme.success,
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("⚠️ No loan data to export"),
                      backgroundColor: FinTheme.danger,
                    ),
                  );
                }
              },
              isDark: isDark,
            ),
            _buildTile(
              icon: Icons.data_object,
              title: _t('export_json'),
              subtitle: _t('export_json_desc'),
              trailing: const Icon(Icons.share, size: 18, color: FinTheme.primary),
              onTap: () async {
                final path = await StorageService.exportJsonFile();
                if (path != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("📦 Complete JSON backup exported!"),
                      backgroundColor: FinTheme.success,
                    ),
                  );
                }
              },
              isDark: isDark,
            ),
            _buildTile(
              icon: Icons.restore_page_outlined,
              title: _t('restore_file'),
              subtitle: _t('restore_file_desc'),
              trailing: const Icon(Icons.file_upload_outlined, size: 18, color: FinTheme.primary),
              onTap: () async {
                final result = await StorageService.pickAndRestoreFile();
                if (!mounted) return;
                if (result.success) {
                  final updated = await StorageService.getSettings();
                  setState(() => _settings = updated);
                  widget.onSettingsChanged(updated);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("🎉 ${result.message}"),
                      backgroundColor: FinTheme.success,
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
              },
              isDark: isDark,
            ),
            _buildTile(
              icon: Icons.lock_outline,
              title: "Lock Vault Screen",
              subtitle: "Instantly lock app and require 4-digit PIN / fingerprint to unlock",
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const PasscodeScreen()),
                );
              },
              isDark: isDark,
            ),
            _buildTile(
              icon: Icons.logout_rounded,
              title: "Logout from Device",
              subtitle: "Sign out of Vault ID ${_settings.vaultId} safely and return to Welcome screen",
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: FinTheme.danger),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: FinTheme.danger.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.logout_rounded, color: FinTheme.danger, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text("Logout of Vault?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Are you sure you want to log out of Vault ${_settings.vaultId} on this device?",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "✓ Your loans, borrower ledgers, and collection history remain safely stored in the cloud under your Vault ID.\n\n✓ You will be returned to the Welcome setup screen where you can sign back in anytime or connect a different firm.",
                          style: TextStyle(fontSize: 12, height: 1.5, color: Colors.grey),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FinTheme.danger,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Yes, Logout", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  final def = SecuritySettings(isRegistered: false);
                  await StorageService.saveSettings(def);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const SetupWizardScreen()),
                    (route) => false,
                  );
                }
              },
              isDark: isDark,
            ),
            _buildTile(
              icon: Icons.restart_alt,
              title: "Reset Vault / Fresh Setup",
              subtitle: "Clear local cache and restart the initial Setup Wizard",
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: FinTheme.danger),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: FinTheme.danger),
                        SizedBox(width: 8),
                        Text("Reset All Data?"),
                      ],
                    ),
                    content: const Text(
                      "This will clear all local loans, borrower ledgers, and firm settings on this computer, and restart the initial Setup Wizard.\n\nAre you sure you want to proceed?",
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: FinTheme.danger),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Reset All Data", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  await StorageService.resetAllData();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const SetupWizardScreen()),
                    (route) => false,
                  );
                }
              },
              isDark: isDark,
            ),

            const SizedBox(height: 18),
          ],

          _buildSectionHeader(AppLocale.tr('language')),
          _buildTile(
            icon: Icons.language,
            title: AppLocale.tr('app_language'),
            subtitle: AppLocale.languages.firstWhere((l) => l['code'] == _settings.language, orElse: () => {'name': 'English', 'native': 'English'})['native']!,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(AppLocale.tr('select_language'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: AppLocale.languages.map((l) {
                      final isSelected = _settings.language == l['code'];
                      return ListTile(
                        leading: isSelected
                            ? const Icon(Icons.check_circle, color: FinTheme.primary)
                            : const Icon(Icons.circle_outlined, color: Colors.grey),
                        title: Text(l['native']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        onTap: () async {
                          final newLang = l['code']!;
                          AppLocale.currentLang = newLang;
                          final updated = _settings.copyWith(language: newLang);
                          await StorageService.saveSettings(updated);
                          setState(() => _settings = updated);
                          widget.onSettingsChanged(updated);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            },
            isDark: isDark,
          ),

          const SizedBox(height: 18),

          _buildSectionHeader(_t('sec_live_web')),
          _buildTile(
            icon: Icons.open_in_browser,
            title: _t('finvault_web_app'),
            subtitle: "https://deepakgowrishankar7.github.io/FinVault/",
            onTap: () => launchUrl(
              Uri.parse("https://deepakgowrishankar7.github.io/FinVault/"),
              mode: LaunchMode.externalApplication,
            ),
            trailing: const Icon(Icons.launch, size: 18, color: FinTheme.primary),
            isDark: isDark,
          ),

          const SizedBox(height: 18),

          _buildSectionHeader(_t('sec_app_info')),
          _buildTile(
            icon: Icons.info_outline,
            title: _t('version'),
            subtitle: "FinVault Native 2.0.0",
            isDark: isDark,
          ),
          if (_settings.vaultId.isNotEmpty)
            _buildTile(
              icon: Icons.fingerprint,
              title: _t('vault_unique_id'),
              subtitle: _settings.vaultId,
              isDark: isDark,
            ),

          const SizedBox(height: 24),

          // Lock Vault Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const PasscodeScreen()),
                );
              },
              icon: const Icon(Icons.lock, color: FinTheme.danger),
              label: Text(_t('lock_vault_logout'), style: TextStyle(color: FinTheme.danger, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: FinTheme.danger),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    required bool isDark,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: FinTheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary)),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
        onTap: onTap,
      ),
    );
  }
}
