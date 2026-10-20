import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/loan.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/whatsapp_service.dart';
import '../../theme/fin_theme.dart';
import 'add_edit_loan_screen.dart';
import 'loan_detail_screen.dart';
import '../payments/record_payment_screen.dart';

import '../../theme/app_locale.dart';

class LoansListScreen extends StatefulWidget {
  final UserRole role;
  final StaffAgent? agent;
  final SecuritySettings settings;
  final VoidCallback onLoansChanged;

  const LoansListScreen({
    super.key,
    required this.role,
    this.agent,
    required this.settings,
    required this.onLoansChanged,
  });

  @override
  State<LoansListScreen> createState() => _LoansListScreenState();
}

class _LoansListScreenState extends State<LoansListScreen> {
  List<Loan> _allLoans = [];
  String _searchQuery = '';
  String _filter = 'active'; // 'all', 'active', 'completed'
  bool _isLoading = true;
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  String get _currentLang => AppLocale.currentLang;
  String _t(String key) => AppLocale.tr(key, _currentLang);

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);
    final loans = await StorageService.getLoans();
    setState(() {
      _allLoans = loans;
      _isLoading = false;
    });
    widget.onLoansChanged();
  }

  List<Loan> get _filteredLoans {
    return _allLoans.where((loan) {
      final matchesSearch = loan.borrower.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          loan.phone.contains(_searchQuery) ||
          loan.whatsappPhone.contains(_searchQuery);
      if (!matchesSearch) return false;

      if (_filter == 'active') return !loan.isCompleted;
      if (_filter == 'completed') return loan.isCompleted;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('loans')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLoans,
            tooltip: "Refresh Loans",
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: _t('search_borrowers'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),

          // Filter Segment Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip("${_t('filter_active')} (${_allLoans.where((l) => !l.isCompleted).length})", 'active'),
                const SizedBox(width: 8),
                _buildFilterChip("${_t('filter_all')} (${_allLoans.length})", 'all'),
                const SizedBox(width: 8),
                _buildFilterChip("${_t('filter_completed')} (${_allLoans.where((l) => l.isCompleted).length})", 'completed'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Loans List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLoans.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _t('no_loans_yet'),
                              style: TextStyle(
                                color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _t('tap_add_to_start'),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredLoans.length,
                        itemBuilder: (context, index) {
                          final loan = _filteredLoans[index];
                          return _buildLoanCard(loan, isDark);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.role == UserRole.admin
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (context) => AddEditLoanScreen(settings: widget.settings)),
                );
                if (created == true) _loadLoans();
              },
              backgroundColor: FinTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(_t('add_new_loan'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _filter = key);
      },
      selectedColor: FinTheme.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? FinTheme.primary : Colors.grey,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? FinTheme.primary : Colors.grey.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildLoanCard(Loan loan, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
          if (changed == true) {
            _loadLoans();
            widget.onLoansChanged?.call();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.borrower,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loan.phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: loan.isCompleted
                          ? FinTheme.success.withOpacity(0.12)
                          : FinTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      loan.isCompleted ? "COMPLETED" : "ACTIVE",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: loan.isCompleted ? FinTheme.success : FinTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetric("Principal", _currency.format(loan.principal), isDark),
                  _buildMetric("Monthly EMI", _currency.format(loan.monthlyInstallment), isDark),
                  _buildMetric(
                    "Balance",
                    _currency.format(loan.remaining),
                    isDark,
                    color: loan.isCompleted ? FinTheme.success : FinTheme.danger,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Repaid: ${_currency.format(loan.totalPaid)}",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                    ),
                  ),
                  Text(
                    "${loan.progressPercent.toStringAsFixed(0)}%",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: FinTheme.success),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: loan.progressPercent / 100,
                  minHeight: 6,
                  backgroundColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFE5E9F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    loan.isCompleted ? FinTheme.success : FinTheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Call button
                      if (loan.phone.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.call, size: 18, color: FinTheme.primary),
                          onPressed: () => launchUrl(Uri.parse("tel:${loan.phone}")),
                          tooltip: "Call Borrower",
                          visualDensity: VisualDensity.compact,
                        ),
                      // WhatsApp Reminder
                      if (loan.effectiveWhatsApp.isNotEmpty && !loan.isCompleted)
                        IconButton(
                          icon: const Icon(Icons.chat, size: 18, color: FinTheme.success),
                          onPressed: () => WhatsAppService.sendEmiReminder(
                            loan: loan,
                            firmName: widget.settings.firmName,
                            ownerUpiId: widget.settings.ownerUpiId,
                          ),
                          tooltip: "WhatsApp Reminder",
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  if (!loan.isCompleted)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final paid = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecordPaymentScreen(
                              loan: loan,
                              agent: widget.agent,
                              settings: widget.settings,
                            ),
                          ),
                        );
                        if (paid == true) {
                          _loadLoans();
                          widget.onLoansChanged?.call();
                        }
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Collect"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FinTheme.success,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, bool isDark, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
