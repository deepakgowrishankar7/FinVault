import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../theme/fin_theme.dart';
import 'team_management_screen.dart';
import 'cloud_sync_screen.dart';
import '../auth/passcode_screen.dart';

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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final updated = _settings.copyWith(
                firmName: firmCtrl.text.trim().isNotEmpty ? firmCtrl.text.trim() : 'FinVault',
                adminName: adminCtrl.text.trim().isNotEmpty ? adminCtrl.text.trim() : 'Admin',
                ownerUpiId: upiCtrl.text.trim().isNotEmpty ? upiCtrl.text.trim() : 'owner@okhdfcbank',
              );
              await StorageService.saveSettings(updated);
              setState(() => _settings = updated);
              widget.onSettingsChanged(updated);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
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
        title: const Text("Change Master PIN", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(labelText: "New 4-Digit Passcode", prefixIcon: Icon(Icons.lock)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
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
            child: const Text("Update PIN"),
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
        title: const Text("Settings & Vault Security"),
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
                          "Owner: ${_settings.adminName} • ${_settings.ownerUpiId}",
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
            _buildSectionHeader("Security & Passcode"),
            _buildTile(
              icon: Icons.pin,
              title: "Change Master PIN",
              subtitle: "Update your 4-digit admin security passcode",
              onTap: _changeAdminPin,
              isDark: isDark,
            ),
            _buildTile(
              icon: Icons.group,
              title: "Staff & Field Agents",
              subtitle: "${_settings.agents.length} Agent(s) Configured",
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

            _buildSectionHeader("Cloud Synchronization"),
            _buildTile(
              icon: Icons.cloud_outlined,
              title: "Central Cloud Sync (Supabase)",
              subtitle: _settings.cloudSyncEnabled ? "Connected & Active (Project: cpfpmnyipiqdtcnobwoq)" : "Disabled (Offline Mode)",
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
          ],

          _buildSectionHeader("Live Web Application"),
          _buildTile(
            icon: Icons.open_in_browser,
            title: "FinVault Web App",
            subtitle: "https://deepakgowrishankar7.github.io/FinVault/",
            onTap: () => launchUrl(
              Uri.parse("https://deepakgowrishankar7.github.io/FinVault/"),
              mode: LaunchMode.externalApplication,
            ),
            trailing: const Icon(Icons.launch, size: 18, color: FinTheme.primary),
            isDark: isDark,
          ),

          const SizedBox(height: 18),

          _buildSectionHeader("App Information"),
          _buildTile(
            icon: Icons.info_outline,
            title: "Version",
            subtitle: "FinVault Native 2.0.0 (Flutter 60-120 FPS)",
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
              label: const Text("Lock Vault & Log Out", style: TextStyle(color: FinTheme.danger, fontWeight: FontWeight.bold)),
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
