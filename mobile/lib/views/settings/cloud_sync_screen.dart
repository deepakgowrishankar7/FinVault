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
  late bool _enabled;
  bool _isSyncing = false;
  String _statusMessage = 'Checking connection...';
  bool _isHealthy = false;
  int _cloudCount = 0;

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.cloudSyncEnabled;
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() => _isSyncing = true);
    final connected = await SupabaseService.init();
    if (connected) {
      final remoteLoans = await SupabaseService.pullLoans(widget.settings.vaultId);
      setState(() {
        _isHealthy = true;
        _isSyncing = false;
        _cloudCount = remoteLoans?.length ?? 0;
        _statusMessage = "Connected & Active • Private partition (Vault: ${widget.settings.vaultId.isEmpty ? 'Offline' : widget.settings.vaultId})";
      });
    } else {
      setState(() {
        _isHealthy = false;
        _isSyncing = false;
        _statusMessage = "Unable to connect to central database. Running in 100% offline private mode.";
      });
    }
  }

  Future<void> _toggleSync(bool value) async {
    setState(() => _enabled = value);
    final updated = widget.settings.copyWith(cloudSyncEnabled: value);
    await StorageService.saveSettings(updated);
    widget.onSettingsUpdated(updated);

    if (value) {
      _syncNow();
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    final connected = await SupabaseService.init();
    if (!connected) {
      setState(() {
        _isSyncing = false;
        _isHealthy = false;
        _statusMessage = "Failed to connect to central cloud database.";
      });
      return;
    }

    final vaultId = widget.settings.vaultId;
    final localLoans = await StorageService.getLoans();
    final remoteLoans = await SupabaseService.pullLoans(vaultId);

    if (remoteLoans != null && remoteLoans.isNotEmpty) {
      final mergedMap = {for (var l in localLoans) l.id: l};
      for (var r in remoteLoans) {
        mergedMap[r.id] = r;
      }
      final mergedList = mergedMap.values.toList();
      await StorageService.saveLoans(mergedList);
      await SupabaseService.pushLoans(mergedList, vaultId);
      setState(() {
        _cloudCount = mergedList.length;
        _isHealthy = true;
        _isSyncing = false;
        _statusMessage = "Synchronized $_cloudCount loans for Vault: $vaultId";
      });
    } else if (localLoans.isNotEmpty) {
      await SupabaseService.pushLoans(localLoans, vaultId);
      setState(() {
        _cloudCount = localLoans.length;
        _isHealthy = true;
        _isSyncing = false;
        _statusMessage = "Pushed ${localLoans.length} loans to your private cloud partition!";
      });
    } else {
      setState(() {
        _isHealthy = true;
        _isSyncing = false;
        _statusMessage = "Connected to private partition (Vault: $vaultId). 0 loans.";
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_statusMessage),
          backgroundColor: FinTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cloud Backup & Sync"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isSyncing ? null : _syncNow,
            tooltip: "Sync Now",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Switch Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? FinTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "☁️ Central Cloud Database",
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Project: cpfpmnyipiqdtcnobwoq",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _enabled,
                        activeColor: FinTheme.primary,
                        onChanged: _toggleSync,
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    _enabled
                        ? "Central cloud sync is active. Your loans and repayment ledgers automatically back up and sync across Web and Android in real-time."
                        : "Cloud sync is disabled. All borrower identities and loans live 100% private and offline on this device.",
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Live Diagnostic Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isHealthy
                    ? FinTheme.success.withOpacity(0.08)
                    : (isDark ? FinTheme.cardDark : Colors.white),
                borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                border: Border.all(
                  color: _isHealthy
                      ? FinTheme.success.withOpacity(0.3)
                      : (isDark ? FinTheme.borderDark : FinTheme.borderLight),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isHealthy ? Icons.check_circle : Icons.cloud_off,
                        color: _isHealthy ? FinTheme.success : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isHealthy ? "Connected & Healthy" : "Offline Mode",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _isHealthy ? FinTheme.success : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (_isHealthy) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Cloud Backed Records", style: TextStyle(fontSize: 12, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary)),
                        Text("$_cloudCount Loans", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sync Now Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _syncNow,
                icon: _isSyncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_sync),
                label: Text(
                  _isSyncing ? "Synchronizing with Cloud..." : "☁️ Sync Now Across Devices",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
