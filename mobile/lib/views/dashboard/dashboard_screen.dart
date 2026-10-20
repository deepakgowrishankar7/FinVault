import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/loan.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/fin_theme.dart';
import '../../theme/app_locale.dart';
import '../calculator/emi_calculator_screen.dart';
import '../loans/loans_list_screen.dart';
import '../loans/add_edit_loan_screen.dart';
import '../loans/loan_detail_screen.dart';
import '../payments/upi_qr_screen.dart';
import '../settings/settings_screen.dart';
import '../auth/passcode_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserRole role;
  final StaffAgent? agent;
  final SecuritySettings settings;

  const DashboardScreen({
    super.key,
    required this.role,
    this.agent,
    required this.settings,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  List<Loan> _loans = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  late SecuritySettings _currentSettings;
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.settings;
    _loadLoans();
    if (_currentSettings.cloudSyncEnabled) {
      _triggerCloudSync();
    }
  }

  String get _currentLang => AppLocale.currentLang;
  String _t(String key) => AppLocale.tr(key, _currentLang);

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);
    final list = await StorageService.getLoans();
    setState(() {
      _loans = list;
      _isLoading = false;
    });
  }

  Future<void> _triggerCloudSync() async {
    final vaultId = _currentSettings.vaultId;
    if (vaultId.isEmpty) return;

    if (!SupabaseService.isConfigured) {
      await SupabaseService.init(settings: _currentSettings);
    }

    setState(() => _isSyncing = true);
    try {
      final remoteLoans = await SupabaseService.pullLoans(vaultId);
      if (remoteLoans != null && remoteLoans.isNotEmpty) {
        final mergedList = StorageService.deduplicateLoans([..._loans, ...remoteLoans]);
        await StorageService.saveLoans(mergedList);
        setState(() => _loans = mergedList);
        await SupabaseService.pushLoans(mergedList, vaultId);
      } else if (_loans.isNotEmpty) {
        await SupabaseService.pushLoans(_loans, vaultId);
      }
    } catch (_) {}
    setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pages = [
      _buildDashboardView(isDark),
      LoansListScreen(
        role: widget.role,
        agent: widget.agent,
        settings: _currentSettings,
        onLoansChanged: _loadLoans,
      ),
      const EmiCalculatorScreen(),
      SettingsScreen(
        role: widget.role,
        agent: widget.agent,
        settings: _currentSettings,
        onSettingsChanged: (updated) {
          AppLocale.currentLang = updated.language;
          setState(() => _currentSettings = updated);
        },
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 750;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildDesktopSidebar(isDark),
            Expanded(
              child: pages[_currentIndex],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? FinTheme.cardDark : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? FinTheme.borderDark : FinTheme.borderLight,
              width: 0.8,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedItemColor: FinTheme.primary,
          unselectedItemColor: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard),
              label: _t('overview'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              activeIcon: const Icon(Icons.account_balance_wallet),
              label: _t('loans'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calculate_outlined),
              activeIcon: const Icon(Icons.calculate),
              label: _t('calculator'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: _t('settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(bool isDark) {
    final navItems = [
      {'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard, 'label': _t('overview')},
      {'icon': Icons.account_balance_wallet_outlined, 'activeIcon': Icons.account_balance_wallet, 'label': _t('loans')},
      {'icon': Icons.calculate_outlined, 'activeIcon': Icons.calculate, 'label': _t('calculator')},
      {'icon': Icons.settings_outlined, 'activeIcon': Icons.settings, 'label': _t('settings')},
    ];

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? FinTheme.borderDark : FinTheme.borderLight,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentSettings.firmName.isNotEmpty ? _currentSettings.firmName : "FinVault",
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentSettings.cloudSyncEnabled ? FinTheme.success : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.role == UserRole.admin ? "ADMIN DESKTOP" : "STAFF PORTAL",
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: FinTheme.primary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Navigation Links
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = _currentIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _currentIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? FinTheme.primary.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: FinTheme.primary.withOpacity(0.35))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? item['activeIcon'] as IconData : item['icon'] as IconData,
                              color: isSelected ? FinTheme.primary : (isDark ? Colors.white60 : Colors.black54),
                              size: 20,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                item['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? FinTheme.primary : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_isSyncing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text("Syncing Cloud...", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const PasscodeScreen()),
                    );
                  },
                  icon: const Icon(Icons.lock_outline, size: 16),
                  label: const Text("Lock Vault", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardView(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDesktop = MediaQuery.of(context).size.width > 750;
    if (isDesktop) {
      return _buildDesktopDashboardView(isDark);
    }

    // Calculations
    double totalPrincipal = 0.0;
    double totalCollected = 0.0;
    double totalPayable = 0.0;
    double totalOutstanding = 0.0;
    double totalInterest = 0.0;

    for (var l in _loans) {
      totalPrincipal += l.principal;
      totalCollected += l.totalPaid;
      totalPayable += l.totalPayable;
      totalOutstanding += l.remaining;
      totalInterest += l.totalInterest;
    }

    final collectionRate = totalPayable > 0 ? (totalCollected / totalPayable) * 100 : 0.0;
    final activeLoans = _loans.where((l) => !l.isCompleted).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadLoans();
          if (widget.settings.cloudSyncEnabled) {
            await _triggerCloudSync();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: FinTheme.primary.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.settings.firmName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.role == UserRole.admin
                                      ? FinTheme.primary.withOpacity(0.12)
                                      : FinTheme.success.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.role == UserRole.admin ? "👑 ${_t('master_admin')}" : "🏃 ${widget.agent?.name ?? _t('field_agent')}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: widget.role == UserRole.admin ? FinTheme.primary : FinTheme.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (widget.settings.cloudSyncEnabled)
                        IconButton(
                          onPressed: _isSyncing ? null : _triggerCloudSync,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_sync, color: FinTheme.primary),
                          tooltip: _t('cloud_sync'),
                        ),
                      IconButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const PasscodeScreen()),
                          );
                        },
                        icon: const Icon(Icons.lock_outline, color: FinTheme.danger),
                        tooltip: _t('lock_vault'),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // KPI Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _buildKpiCard(
                    title: _t('total_collected'),
                    amount: _currency.format(totalCollected),
                    subtitle: "${_loans.length} ${_t('loans')}",
                    icon: Icons.payments,
                    color: FinTheme.success,
                    isDark: isDark,
                  ),
                  _buildKpiCard(
                    title: _t('pending_balance'),
                    amount: _currency.format(totalOutstanding),
                    subtitle: "${activeLoans.length} ${_t('filter_active')}",
                    icon: Icons.account_balance,
                    color: FinTheme.warning,
                    isDark: isDark,
                  ),
                  if (widget.role == UserRole.admin) ...[
                    _buildKpiCard(
                      title: _t('total_principal'),
                      amount: _currency.format(totalPrincipal),
                      subtitle: _t('initial_principal'),
                      icon: Icons.outbox,
                      color: FinTheme.primary,
                      isDark: isDark,
                    ),
                    _buildKpiCard(
                      title: _t('net_interest_profit'),
                      amount: _currency.format(totalInterest),
                      subtitle: _t('projected_profit'),
                      icon: Icons.trending_up,
                      color: FinTheme.purple,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 18),

              // Recovery Efficiency Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? FinTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                  border: Border.all(
                    color: isDark ? FinTheme.borderDark : FinTheme.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _t('portfolio_recovery_rate'),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          "${collectionRate.toStringAsFixed(1)}%",
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: FinTheme.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: collectionRate / 100,
                        minHeight: 10,
                        backgroundColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFE5E9F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(FinTheme.success),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${_t('recovered')}: ${_currency.format(totalCollected)}",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                          ),
                        ),
                        Text(
                          "${_t('goal')}: ${_currency.format(totalPayable)}",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Quick Actions
              Row(
                children: [
                  if (widget.role == UserRole.admin)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final created = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEditLoanScreen(settings: _currentSettings),
                            ),
                          );
                          if (created == true) _loadLoans();
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: Text(_t('add_new_loan')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FinTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  if (widget.role == UserRole.admin) const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UpiQrScreen(
                              ownerUpiId: widget.settings.ownerUpiId,
                              firmName: widget.settings.firmName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code, size: 18, color: FinTheme.primary),
                      label: Text(_t('show_upi_qr'), style: const TextStyle(color: FinTheme.primary)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: FinTheme.primary, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FinTheme.radiusSmall),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Active Loans Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _t('active_loans'),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _currentIndex = 1),
                    child: Text(_t('view_all'), style: const TextStyle(color: FinTheme.primary)),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if (activeLoans.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 48, color: FinTheme.success.withOpacity(0.5)),
                      const SizedBox(height: 10),
                      Text(
                        _t('no_pending_loans'),
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeLoans.take(5).length,
                  itemBuilder: (context, index) {
                    final loan = activeLoans[index];
                    return _buildLoanTile(loan, isDark);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopKpiCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? FinTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDashboardView(bool isDark) {
    double totalPrincipal = 0.0;
    double totalCollected = 0.0;
    double totalPayable = 0.0;
    double totalOutstanding = 0.0;
    double totalInterest = 0.0;

    for (var l in _loans) {
      totalPrincipal += l.principal;
      totalCollected += l.totalPaid;
      totalPayable += l.totalPayable;
      totalOutstanding += l.remaining;
      totalInterest += l.totalInterest;
    }

    final collectionRate = totalPayable > 0 ? (totalCollected / totalPayable) * 100 : 0.0;
    final activeLoans = _loans.where((l) => !l.isCompleted).toList();
    final recentLoans = _loans.take(8).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Desktop Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentSettings.firmName.isNotEmpty ? _currentSettings.firmName : "FinVault",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Enterprise Financial Overview & Real-Time Loan Ledgers",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: FinTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: FinTheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, size: 16, color: FinTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          _currentSettings.cloudSyncEnabled ? "Cloud Sync: Active" : "100% Offline Vault",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FinTheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      _loadLoans();
                      if (_currentSettings.cloudSyncEnabled) _triggerCloudSync();
                    },
                    icon: _isSyncing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    tooltip: "Refresh Ledger Data",
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 2. 4 Metric Cards in 1 Row
          Row(
            children: [
              Expanded(
                child: _buildDesktopKpiCard(
                  title: _t('total_collected'),
                  amount: _currency.format(totalCollected),
                  subtitle: "${_loans.length} ${_t('loans')}",
                  icon: Icons.payments,
                  color: FinTheme.success,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildDesktopKpiCard(
                  title: _t('pending_balance'),
                  amount: _currency.format(totalOutstanding),
                  subtitle: "${activeLoans.length} ${_t('filter_active')}",
                  icon: Icons.account_balance,
                  color: FinTheme.warning,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildDesktopKpiCard(
                  title: _t('total_principal'),
                  amount: _currency.format(totalPrincipal),
                  subtitle: _t('initial_principal'),
                  icon: Icons.outbox,
                  color: FinTheme.primary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildDesktopKpiCard(
                  title: _t('net_interest_profit'),
                  amount: _currency.format(totalInterest),
                  subtitle: _t('projected_profit'),
                  icon: Icons.trending_up,
                  color: FinTheme.purple,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3. Quick Action Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? FinTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
            ),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final added = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEditLoanScreen(settings: _currentSettings),
                      ),
                    );
                    if (added == true) _loadLoans();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("New Loan Entry", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FinTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentIndex = 1),
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text("Record Payment", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UpiQrScreen(
                          ownerUpiId: _currentSettings.ownerUpiId,
                          firmName: _currentSettings.firmName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code, size: 18),
                  label: const Text("Dynamic UPI QR", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final path = await StorageService.exportCsvFile();
                    if (path != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("📊 Ledger spreadsheet (.csv) exported successfully!"),
                          backgroundColor: FinTheme.success,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text("Export Excel", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 4. Two-Column Layout (Recent Ledgers & Portfolio Health)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Recent Loans Table
              Expanded(
                flex: 65,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? FinTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, size: 18, color: FinTheme.primary),
                              SizedBox(width: 8),
                              Text(
                                "Live Loan Book & Recent Ledgers",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => setState(() => _currentIndex = 1),
                            child: const Text("View All Loans →", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loans.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.library_books_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              const Text("No loan ledgers yet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 6),
                              Text(
                                "Add your first borrower loan entry to start tracking collections and rupee vaddi.",
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final added = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (context) => AddEditLoanScreen(settings: _currentSettings)),
                                  );
                                  if (added == true) _loadLoans();
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text("Add First Loan"),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recentLoans.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final loan = recentLoans[index];
                            return InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LoanDetailScreen(
                                      loan: loan,
                                      role: widget.role,
                                      agent: widget.agent,
                                      settings: _currentSettings,
                                    ),
                                  ),
                                );
                                _loadLoans();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: loan.isCompleted
                                          ? FinTheme.success.withOpacity(0.12)
                                          : FinTheme.primary.withOpacity(0.12),
                                      child: Icon(
                                        loan.isCompleted ? Icons.check_circle_outline : Icons.person_outline,
                                        size: 20,
                                        color: loan.isCompleted ? FinTheme.success : FinTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            loan.borrower,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            loan.phone,
                                            style: TextStyle(fontSize: 11, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: loan.model == 'rupee'
                                            ? Colors.orange.withOpacity(0.12)
                                            : FinTheme.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        loan.model == 'rupee' ? "₹${loan.interest} Vaddi" : "EMI",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: loan.model == 'rupee' ? Colors.deepOrange : FinTheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _currency.format(loan.remaining),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            "${loan.progressPercent.toStringAsFixed(0)}% Repaid",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: loan.isCompleted ? FinTheme.success : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 18),

              // Right: Portfolio Health & Security
              Expanded(
                flex: 35,
                child: Column(
                  children: [
                    // Health Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? FinTheme.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.pie_chart_outline, size: 18, color: FinTheme.success),
                              SizedBox(width: 8),
                              Text("Collection Health", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Recovery Rate", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(
                                "${collectionRate.toStringAsFixed(1)}%",
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: FinTheme.success),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: collectionRate / 100,
                              minHeight: 8,
                              backgroundColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFE5E9F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(FinTheme.success),
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Collected So Far", style: TextStyle(fontSize: 12, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary)),
                              Text(_currency.format(totalCollected), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Pending In Field", style: TextStyle(fontSize: 12, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary)),
                              Text(_currency.format(totalOutstanding), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Security Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? FinTheme.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lock_outline, size: 18, color: FinTheme.primary),
                              SizedBox(width: 8),
                              Text("Vault Security", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "All records are secured with AES-256 local encrypted storage on this device.",
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.vpn_key_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                "Firm Code: ${_currentSettings.vaultId.isNotEmpty ? _currentSettings.vaultId : 'LOCAL-VAULT'}",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FinTheme.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? FinTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
        border: Border.all(
          color: isDark ? FinTheme.borderDark : FinTheme.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanTile(Loan loan, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => LoanDetailScreen(
                loan: loan,
                role: widget.role,
                agent: widget.agent,
                settings: widget.settings,
              ),
            ),
          );
          if (changed == true) _loadLoans();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loan.borrower,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    _currency.format(loan.remaining),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: FinTheme.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "EMI: ${_currency.format(loan.monthlyInstallment)} / mo",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                    ),
                  ),
                  Text(
                    "${loan.progressPercent.toStringAsFixed(0)}% Repaid",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: FinTheme.success),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: loan.progressPercent / 100,
                  minHeight: 5,
                  backgroundColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFE5E9F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(FinTheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
