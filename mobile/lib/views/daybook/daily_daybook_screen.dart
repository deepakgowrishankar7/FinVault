import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/loan.dart';
import '../../models/payment.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/fin_theme.dart';
import '../loans/document_viewer_screen.dart';

class DailyDaybookScreen extends StatefulWidget {
  final SecuritySettings settings;
  final UserRole role;

  const DailyDaybookScreen({
    super.key,
    required this.settings,
    required this.role,
  });

  @override
  State<DailyDaybookScreen> createState() => _DailyDaybookScreenState();
}

class _DailyDaybookScreenState extends State<DailyDaybookScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Loan> _allLoans = [];
  bool _isLoading = true;
  double _openingCash = 0.0;
  final TextEditingController _openingCashCtrl = TextEditingController();

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _displayDateFormat = DateFormat('dd MMM yyyy (EEE)');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _openingCashCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final loans = await StorageService.getLoans();
    final prefs = await SharedPreferences.getInstance();
    final dateKey = 'daybook_opening_${_dateFormat.format(_selectedDate)}';
    final opening = prefs.getDouble(dateKey) ?? 0.0;

    setState(() {
      _allLoans = loans;
      _openingCash = opening;
      _openingCashCtrl.text = opening > 0 ? opening.toStringAsFixed(0) : '';
      _isLoading = false;
    });
  }

  Future<void> _updateOpeningCash(String val) async {
    final amount = double.tryParse(val) ?? 0.0;
    final prefs = await SharedPreferences.getInstance();
    final dateKey = 'daybook_opening_${_dateFormat.format(_selectedDate)}';
    await prefs.setDouble(dateKey, amount);
    setState(() {
      _openingCash = amount;
    });
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  Future<void> _exportPdf() async {
    try {
      final bytes = await PdfService.generateDaybookPdf(
        date: _selectedDate,
        allLoans: _allLoans,
        firmName: widget.settings.firmName,
        openingCash: _openingCash,
      );

      final tempDir = await getTemporaryDirectory();
      final dateStr = _dateFormat.format(_selectedDate);
      final filePath = '${tempDir.path}/FinVault_Daybook_$dateStr.pdf';
      await File(filePath).writeAsBytes(bytes);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FinPdfViewerScreen(
              filePath: filePath,
              title: "Daybook - $dateStr",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating Daybook PDF: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = _dateFormat.format(_selectedDate);
    final isToday = dateStr == _dateFormat.format(DateTime.now());

    // Calculate Outflows (Disbursements on this date)
    double cashDisbursed = 0.0;
    final List<Map<String, dynamic>> disbursements = [];
    for (final l in _allLoans) {
      final loanCreatedDate = _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(l.created));
      if (loanCreatedDate == dateStr || l.startDate == dateStr) {
        cashDisbursed += l.principal;
        disbursements.add({
          'borrower': l.borrower,
          'phone': l.phone,
          'amount': l.principal,
          'model': l.model,
          'id': l.id,
        });
      }
    }

    // Calculate Inflows (Payments on this date)
    double cashCollected = 0.0;
    double onlineCollected = 0.0;
    final List<Map<String, dynamic>> collections = [];
    final Map<String, double> agentCashTotals = {};
    final Map<String, double> agentOnlineTotals = {};

    for (final l in _allLoans) {
      for (final p in l.payments) {
        if (p.date == dateStr) {
          final isCash = p.mode.toLowerCase() == 'cash';
          final collector = p.collectedBy ?? 'Admin';

          if (isCash) {
            cashCollected += p.amount;
            agentCashTotals[collector] = (agentCashTotals[collector] ?? 0) + p.amount;
          } else {
            onlineCollected += p.amount;
            agentOnlineTotals[collector] = (agentOnlineTotals[collector] ?? 0) + p.amount;
          }

          collections.add({
            'borrower': l.borrower,
            'amount': p.amount,
            'mode': p.mode,
            'voucherId': p.id,
            'collector': collector,
          });
        }
      }
    }

    final double netDrawerCash = _openingCash + cashCollected - cashDisbursed;

    return Scaffold(
      backgroundColor: isDark ? FinTheme.bgDark : FinTheme.bgLight,
      appBar: AppBar(
        title: const Text("Daily Cash Daybook (నిత్య క్యాష్ బుక్)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: "Export Daybook PDF",
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Date Selector Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? FinTheme.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 22),
                            tooltip: "Previous Day",
                            onPressed: () => _changeDate(-1),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.calendar_month, size: 18, color: FinTheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      _displayDateFormat.format(_selectedDate),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    if (isToday) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: FinTheme.primary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text("TODAY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: FinTheme.primary)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 22),
                            tooltip: "Next Day",
                            onPressed: () => _changeDate(1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4 Core Tally Metric Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            title: "Disbursed (ఇచ్చినవి)",
                            amount: cashDisbursed,
                            icon: Icons.arrow_outward_rounded,
                            color: FinTheme.danger,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            title: "Cash Collected (వసూలు)",
                            amount: cashCollected,
                            icon: Icons.south_west_rounded,
                            color: FinTheme.success,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            title: "UPI / Bank (ఆన్‌లైన్)",
                            amount: onlineCollected,
                            icon: Icons.account_balance_wallet_outlined,
                            color: FinTheme.primary,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            title: "Cash Box (గల్లా పెట్టె)",
                            amount: netDrawerCash,
                            icon: Icons.savings_outlined,
                            color: Colors.deepPurpleAccent,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Cash Drawer Tally Reconciliation Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? FinTheme.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                                  Icon(Icons.calculate_outlined, size: 18, color: FinTheme.primary),
                                  SizedBox(width: 6),
                                  Text("Physical Cash Drawer Tally (గల్లా లెక్క)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              Text("Closing 8:00 PM", style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54)),
                            ],
                          ),
                          const Divider(height: 20),

                          // Editable Opening Cash
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Opening Cash in Box (ఉదయం మొదలు):", style: TextStyle(fontSize: 12)),
                              SizedBox(
                                width: 110,
                                height: 36,
                                child: TextField(
                                  controller: _openingCashCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  decoration: InputDecoration(
                                    prefixText: "₹ ",
                                    hintText: "0",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: _updateOpeningCash,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("+ Cash Collected Today:", style: TextStyle(fontSize: 12, color: FinTheme.success)),
                              Text("+ ${_currency.format(cashCollected)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: FinTheme.success)),
                            ],
                          ),
                          const SizedBox(height: 6),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("- Cash Loans Disbursed:", style: TextStyle(fontSize: 12, color: FinTheme.danger)),
                              Text("- ${_currency.format(cashDisbursed)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: FinTheme.danger)),
                            ],
                          ),
                          const Divider(height: 18),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Net Cash Box Balance:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(
                                _currency.format(netDrawerCash),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: netDrawerCash >= 0 ? FinTheme.primary : FinTheme.danger,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Agent-wise collections breakdown (if any collections exist)
                    if (agentCashTotals.isNotEmpty || agentOnlineTotals.isNotEmpty) ...[
                      Text("COLLECTIONS BY STAFF / AGENTS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.black54, letterSpacing: 0.6)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? FinTheme.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
                        ),
                        child: Column(
                          children: { ...agentCashTotals.keys, ...agentOnlineTotals.keys }.map((name) {
                            final cash = agentCashTotals[name] ?? 0.0;
                            final online = agentOnlineTotals[name] ?? 0.0;
                            final total = cash + online;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: FinTheme.primary.withOpacity(0.12),
                                    child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FinTheme.primary)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text("Cash: ${_currency.format(cash)} • UPI: ${_currency.format(online)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  Text(_currency.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Collections Transaction Log
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("COLLECTIONS (${collections.length})", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.black54, letterSpacing: 0.6)),
                        Text("Total: ${_currency.format(cashCollected + onlineCollected)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FinTheme.success)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (collections.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? FinTheme.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text("No installments received on this date", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      )
                    else
                      ...collections.map((c) {
                        final isCash = c['mode'].toString().toLowerCase() == 'cash';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isDark ? FinTheme.cardDark : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isCash ? FinTheme.success : FinTheme.primary).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCash ? Icons.payments_outlined : Icons.qr_code,
                                size: 18,
                                color: isCash ? FinTheme.success : FinTheme.primary,
                              ),
                            ),
                            title: Text(c['borrower'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text("Voucher #${c['voucherId']} • ${c['mode'].toString().toUpperCase()} • By ${c['collector']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            trailing: Text(
                              "+ ${_currency.format(c['amount'])}",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isCash ? FinTheme.success : FinTheme.primary),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 16),

                    // Disbursements Transaction Log
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("NEW DISBURSEMENTS (${disbursements.length})", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.black54, letterSpacing: 0.6)),
                        Text("Total: ${_currency.format(cashDisbursed)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FinTheme.danger)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (disbursements.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? FinTheme.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text("No new loans disbursed on this date", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      )
                    else
                      ...disbursements.map((d) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isDark ? FinTheme.cardDark : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: FinTheme.danger.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_outward_rounded, size: 18, color: FinTheme.danger),
                            ),
                            title: Text(d['borrower'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text("Phone: ${d['phone']} • Model: ${d['model'].toString().toUpperCase()}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            trailing: Text(
                              "- ${_currency.format(d['amount'])}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: FinTheme.danger),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _currency.format(amount),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
