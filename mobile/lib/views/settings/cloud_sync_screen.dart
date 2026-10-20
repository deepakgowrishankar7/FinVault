import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_locale.dart';
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
  late bool _useCustomCloud;
  late TextEditingController _customUrlCtrl;
  late TextEditingController _customKeyCtrl;

  bool _isSyncing = false;
  bool _isTestingConnection = false;
  String _statusMessage = 'Checking connection...';
  bool _isHealthy = false;
  int _cloudCount = 0;
  String? _testResult;
  bool _testSuccess = false;

  String get _lang => widget.settings.language;
  String _t(String key) => AppLocale.tr(key, _lang);

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.cloudSyncEnabled;
    _useCustomCloud = widget.settings.useCustomCloud;
    _customUrlCtrl = TextEditingController(text: widget.settings.customSupabaseUrl);
    _customKeyCtrl = TextEditingController(text: widget.settings.customSupabaseKey);
    _checkHealth();
  }

  @override
  void dispose() {
    _customUrlCtrl.dispose();
    _customKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    if (!_enabled) {
      setState(() {
        _isHealthy = false;
        _isSyncing = false;
        _statusMessage = "Cloud sync is disabled. All loan ledgers are stored strictly offline on this device.";
      });
      return;
    }

    if (_useCustomCloud) {
      final url = _customUrlCtrl.text.trim();
      final key = _customKeyCtrl.text.trim();
      if (url.isEmpty || key.isEmpty) {
        setState(() {
          _isHealthy = false;
          _isSyncing = false;
          _statusMessage = "Custom cloud is selected, but Supabase URL or Key is empty. Please enter credentials and test connection below.";
        });
        return;
      }
    }

    setState(() => _isSyncing = true);
    final connected = await SupabaseService.init(settings: widget.settings);
    if (connected) {
      final remoteLoans = await SupabaseService.pullLoans(widget.settings.vaultId);
      setState(() {
        _isHealthy = true;
        _isSyncing = false;
        _cloudCount = remoteLoans?.length ?? 0;
        final target = _useCustomCloud ? "Your Own Supabase" : "Central Cloud (Vault: ${widget.settings.vaultId})";
        _statusMessage = "Connected & Active on $target";
      });
    } else {
      setState(() {
        _isHealthy = false;
        _isSyncing = false;
        _statusMessage = "Unable to connect to cloud database. Operating in 100% offline local mode.";
      });
    }
  }

  Future<void> _toggleSync(bool value) async {
    setState(() => _enabled = value);
    final updated = widget.settings.copyWith(cloudSyncEnabled: value);
    await StorageService.saveSettings(updated);
    widget.onSettingsUpdated(updated);

    if (value) {
      await _checkHealth();
      if (_isHealthy) {
        _syncNow();
      }
    } else {
      setState(() {
        _isHealthy = false;
        _isSyncing = false;
        _statusMessage = "Cloud sync is disabled. All loan ledgers are stored strictly offline on this device.";
      });
    }
  }

  Future<void> _selectCloudMode(bool useCustom) async {
    setState(() {
      _useCustomCloud = useCustom;
      _testResult = null;
    });

    final updated = widget.settings.copyWith(
      useCustomCloud: useCustom,
    );
    await StorageService.saveSettings(updated);
    widget.onSettingsUpdated(updated);
    _checkHealth();
  }

  Future<void> _testAndSaveCustomCredentials() async {
    final url = _customUrlCtrl.text.trim();
    final key = _customKeyCtrl.text.trim();

    if (url.isEmpty || key.isEmpty) {
      setState(() {
        _testResult = "Please provide both Supabase URL and Anon Key";
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _testResult = null;
    });

    final ok = await SupabaseService.testConnection(url, key);
    setState(() {
      _isTestingConnection = false;
      _testSuccess = ok;
      _testResult = ok
          ? _t('connection_success')
          : _t('connection_failed');
    });

    if (ok) {
      final updated = widget.settings.copyWith(
        useCustomCloud: true,
        customSupabaseUrl: url,
        customSupabaseKey: key,
      );
      await StorageService.saveSettings(updated);
      widget.onSettingsUpdated(updated);
      await SupabaseService.init(settings: updated);
      _checkHealth();
    }
  }

  Future<void> _syncNow() async {
    if (!_enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cloud sync is turned off. Enable the toggle above to sync."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);
    final connected = await SupabaseService.init(settings: widget.settings);
    if (!connected) {
      setState(() {
        _isSyncing = false;
        _isHealthy = false;
        _statusMessage = "Failed to connect to the selected database.";
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
      final ok = await SupabaseService.pushLoans(localLoans, vaultId);
      final fresh = await SupabaseService.pullLoans(vaultId);
      setState(() {
        _cloudCount = fresh?.length ?? (ok ? localLoans.length : 0);
        _isHealthy = ok;
        _isSyncing = false;
        _statusMessage = ok
            ? "Pushed ${localLoans.length} loans to cloud database!"
            : "Could not connect to cloud. Operating in local mode.";
      });
    } else {
      setState(() {
        _isHealthy = true;
        _isSyncing = false;
        _statusMessage = "Connected to database partition (Vault: $vaultId). 0 loans.";
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
        title: Text(_t('cloud_sync')),
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
            // 1. 100% Offline Local Storage Default Guarantee Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FinTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                border: Border.all(color: FinTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: FinTheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "100% Offline Local Storage (Primary)",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: FinTheme.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _t('offline_local_note'),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. Cloud Sync Activation Toggle Card
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
                            "☁️ Cloud Synchronization",
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _enabled ? "Real-time sync active" : "Disabled (Offline Only)",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _enabled ? FinTheme.success : Colors.grey,
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
                  const Divider(height: 20),
                  Text(
                    _enabled
                        ? "Cloud sync is enabled. Your loans and repayment entries automatically sync across devices."
                        : "Cloud sync is turned off. All loan ledgers are stored strictly offline on this mobile device.",
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

            // 3. Dual Database Options Selection Card
            Text(
              "DATABASE STORAGE PROVIDER".toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),

            // Choice A: Central FinVault Cloud (Default)
            GestureDetector(
              onTap: () => _selectCloudMode(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: !_useCustomCloud
                      ? FinTheme.primary.withOpacity(0.10)
                      : (isDark ? FinTheme.cardDark : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: !_useCustomCloud ? FinTheme.primary : (isDark ? FinTheme.borderDark : FinTheme.borderLight),
                    width: !_useCustomCloud ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      !_useCustomCloud ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: !_useCustomCloud ? FinTheme.primary : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _t('central_cloud'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: !_useCustomCloud ? FinTheme.primary : null,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: FinTheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "Default",
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: FinTheme.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Zero setup. Isolated by your unique Firm Code: ${widget.settings.vaultId}",
                            style: TextStyle(fontSize: 11, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Choice B: Custom Database (Own Supabase)
            GestureDetector(
              onTap: () => _selectCloudMode(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _useCustomCloud
                      ? FinTheme.primary.withOpacity(0.10)
                      : (isDark ? FinTheme.cardDark : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _useCustomCloud ? FinTheme.primary : (isDark ? FinTheme.borderDark : FinTheme.borderLight),
                    width: _useCustomCloud ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _useCustomCloud ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: _useCustomCloud ? FinTheme.primary : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('custom_cloud'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _useCustomCloud ? FinTheme.primary : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Connect your personal Supabase project URL & Anon Key",
                            style: TextStyle(fontSize: 11, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Custom Supabase Inputs Card (Visible when Custom is chosen)
            if (_useCustomCloud) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? FinTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FinTheme.primary.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('supabase_url'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _customUrlCtrl,
                      decoration: InputDecoration(
                        hintText: "https://xyzcompany.supabase.co",
                        prefixIcon: const Icon(Icons.link, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('supabase_key'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _customKeyCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                        prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_testResult != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _testSuccess ? FinTheme.success.withOpacity(0.12) : FinTheme.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _testSuccess ? Icons.check_circle : Icons.error_outline,
                              size: 16,
                              color: _testSuccess ? FinTheme.success : FinTheme.danger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _testResult!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _testSuccess ? FinTheme.success : FinTheme.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isTestingConnection ? null : _testAndSaveCustomCredentials,
                        icon: _isTestingConnection
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_done, size: 18),
                        label: Text(
                          _isTestingConnection ? "Testing Connection..." : _t('test_connection'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FinTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // 4. Live Diagnostic Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: !_enabled
                    ? (isDark ? const Color(0xFF1E2838) : const Color(0xFFF1F5F9))
                    : (_isHealthy
                        ? FinTheme.success.withOpacity(0.08)
                        : FinTheme.danger.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                border: Border.all(
                  color: !_enabled
                      ? (isDark ? FinTheme.borderDark : FinTheme.borderLight)
                      : (_isHealthy
                          ? FinTheme.success.withOpacity(0.3)
                          : FinTheme.danger.withOpacity(0.3)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        !_enabled
                            ? Icons.lock_outline
                            : (_isHealthy ? Icons.check_circle : Icons.cloud_off),
                        color: !_enabled
                            ? Colors.grey
                            : (_isHealthy ? FinTheme.success : FinTheme.danger),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        !_enabled
                            ? "Offline Only (Cloud Sync Disabled)"
                            : (_isHealthy ? "Connected & Healthy" : "Connection Offline"),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: !_enabled
                              ? Colors.grey
                              : (_isHealthy ? FinTheme.success : FinTheme.danger),
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
                  if (_enabled && _isHealthy) ...[
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

            // 5. Sync Now Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing
                    ? null
                    : (!_enabled
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enable the Cloud Synchronization toggle above first."),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        : _syncNow),
                icon: _isSyncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_enabled ? Icons.cloud_sync : Icons.lock_outline),
                label: Text(
                  _isSyncing
                      ? "Synchronizing with Cloud..."
                      : (_enabled ? "☁️ Sync Now Across Devices" : "Cloud Sync Disabled (Operating 100% Offline)"),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _enabled ? FinTheme.primary : (isDark ? const Color(0xFF2D3748) : const Color(0xFF94A3B8)),
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
