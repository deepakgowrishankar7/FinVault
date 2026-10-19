import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/fin_theme.dart';

class CloudSyncScreen extends StatefulWidget {
  final SecuritySettings settings;
  final ValueChanged<SecuritySettings> onSettingsUpdated;

  const CloudSyncScreen({
    super.key,
    required this.settings,
    required this.onSettingsUpdated,
  });

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _enabled = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = widget.settings.supabaseUrl;
    _keyCtrl.text = widget.settings.supabaseKey;
    _enabled = widget.settings.cloudSyncEnabled;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    setState(() => _isTesting = true);
    final url = _urlCtrl.text.trim();
    final key = _keyCtrl.text.trim();

    if (_enabled && (url.isEmpty || key.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Supabase URL and Anon Key are required")),
      );
      setState(() => _isTesting = false);
      return;
    }

    bool success = false;
    if (_enabled) {
      success = await SupabaseService.init(url, key);
    }

    final updated = widget.settings.copyWith(
      supabaseUrl: url,
      supabaseKey: key,
      cloudSyncEnabled: _enabled,
    );

    await StorageService.saveSettings(updated);
    widget.onSettingsUpdated(updated);

    setState(() => _isTesting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_enabled
              ? (success ? "Connected to Supabase successfully!" : "Saved credentials (Check URL/Key)")
              : "Cloud Sync disabled"),
          backgroundColor: success ? FinTheme.success : FinTheme.warning,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Private Cloud Sync (Supabase)"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FinTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                border: Border.all(color: FinTheme.primary.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: FinTheme.primary, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      "Multi-device cloud synchronization powered by your own private Supabase PostgreSQL database. 100% data ownership.",
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Toggle Switch
            SwitchListTile(
              title: const Text("Enable Cloud Sync", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Automatically sync loan ledgers across web and mobile"),
              value: _enabled,
              activeColor: FinTheme.primary,
              onChanged: (val) => setState(() => _enabled = val),
            ),

            const Divider(height: 24),

            // Supabase URL
            TextField(
              controller: _urlCtrl,
              enabled: _enabled,
              decoration: const InputDecoration(
                labelText: "Supabase Project URL",
                hintText: "https://xyz.supabase.co",
                prefixIcon: Icon(Icons.link),
              ),
            ),

            const SizedBox(height: 14),

            // Supabase Anon Key
            TextField(
              controller: _keyCtrl,
              enabled: _enabled,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Supabase Public Anon Key",
                hintText: "eyJhbGciOiJIUzI1NiIsIn...",
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),

            const SizedBox(height: 28),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _saveAndTest,
                icon: _isTesting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: const Text("Save & Connect", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Schema Reference
            ExpansionTile(
              title: const Text("Supabase Table Setup SQL", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141923) : const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SelectableText(
                    """create table if not exists loans (
  id text primary key,
  borrower text,
  phone text,
  principal numeric,
  interest numeric,
  tenure numeric,
  model text,
  startDate text,
  created bigint,
  notes text,
  payments jsonb default '[]'::jsonb
);
alter table loans enable row level security;
create policy "Allow all" on loans for all using (true) with check (true);""",
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
