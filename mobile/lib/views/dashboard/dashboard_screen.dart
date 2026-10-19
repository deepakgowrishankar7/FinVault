import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/loan.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/fin_theme.dart';
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
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadLoans();
    _checkCloudSync();
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);
    final list = await StorageService.getLoans();
    setState(() {
      _loans = list;
      _isLoading = false;
    });
  }

  Future<void> _checkCloudSync() async {
    if (widget.settings.cloudSyncEnabled &&
        widget.settings.supabaseUrl.isNotEmpty &&
        widget.settings.supabaseKey.isNotEmpty) {
      await SupabaseService.init(widget.settings.supabaseUrl, widget.settings.supabaseKey);
    }
  }

  Future<void> _triggerCloudSync() async {
    if (!widget.settings.cloudSyncEnabled || !SupabaseService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enable Supabase Cloud Sync in Settings first")),
      );
      return;
    }

    setState(() => _isSyncing = true);
    final remoteLoans = await SupabaseService.pullLoans();
    if (remoteLoans != null && remoteLoans.isNotEmpty) {
      // Merge remote with local
      final mergedMap = {for (var l in _loans) l.id: l};
      for (var r in remoteLoans) {
        mergedMap[r.id] = r;
      }
      final mergedList = mergedMap.values.toList();
      await StorageService.saveLoans(mergedList);
      setState(() => _loans = mergedList);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Synced ${mergedList.length} loans with Cloud!"),
          backgroundColor: FinTheme.success,
        ),
      );
    } else {
      // Push local
      await SupabaseService.pushLoans(_loans);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pushed local loans to Cloud Vault!"),
          backgroundColor: FinTheme.success,
        ),
      );
    }
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
        settings: widget.settings,
        onLoansChanged: _loadLoans,
      ),
      SettingsScreen(
        role: widget.role,
        agent: widget.agent,
        settings: widget.settings,
        onSettingsChanged: (updated) {},
      ),
    ];

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
          elevation: 0,
          selectedItemColor: FinTheme.primary,
          unselectedItemColor: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: "Overview",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: "Loans",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardView(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
                                  widget.role == UserRole.admin ? "👑 Master Admin" : "🏃 ${widget.agent?.name ?? 'Agent'}",
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
                          tooltip: "Cloud Sync",
                        ),
                      IconButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const PasscodeScreen()),
                          );
                        },
                        icon: const Icon(Icons.lock_outline, color: FinTheme.danger),
                        tooltip: "Lock Vault",
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
                    title: "Total Collected",
                    amount: _currency.format(totalCollected),
                    subtitle: "${_loans.length} Total Loans",
                    icon: Icons.payments,
                    color: FinTheme.success,
                    isDark: isDark,
                  ),
                  _buildKpiCard(
                    title: "Outstanding",
                    amount: _currency.format(totalOutstanding),
                    subtitle: "${activeLoans.length} Active Loans",
                    icon: Icons.account_balance,
                    color: FinTheme.warning,
                    isDark: isDark,
                  ),
                  if (widget.role == UserRole.admin) ...[
                    _buildKpiCard(
                      title: "Total Disbursed",
                      amount: _currency.format(totalPrincipal),
                      subtitle: "Initial Principal",
                      icon: Icons.outbox,
                      color: FinTheme.primary,
                      isDark: isDark,
                    ),
                    _buildKpiCard(
                      title: "Net Interest Profit",
                      amount: _currency.format(totalInterest),
                      subtitle: "Projected Profit",
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
                        const Text(
                          "Portfolio Recovery Rate",
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
                          "Recovered: ${_currency.format(totalCollected)}",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                          ),
                        ),
                        Text(
                          "Goal: ${_currency.format(totalPayable)}",
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
                              builder: (context) => const AddEditLoanScreen(),
                            ),
                          );
                          if (created == true) _loadLoans();
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text("New Loan"),
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
                      label: const Text("Show UPI QR", style: TextStyle(color: FinTheme.primary)),
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
                  const Text(
                    "Active Loans",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _currentIndex = 1),
                    child: const Text("View All", style: TextStyle(color: FinTheme.primary)),
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
                      const Text(
                        "No pending loans. All settled!",
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
