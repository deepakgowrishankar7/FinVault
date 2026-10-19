import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/loan.dart';
import '../../models/payment.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/whatsapp_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/fin_theme.dart';
import '../../theme/app_locale.dart';

class RecordPaymentScreen extends StatefulWidget {
  final Loan loan;
  final StaffAgent? agent;
  final SecuritySettings settings;

  const RecordPaymentScreen({
    super.key,
    required this.loan,
    this.agent,
    required this.settings,
  });

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _mode = 'UPI'; // 'UPI', 'Cash', 'Bank Transfer', 'Cheque'
  DateTime _date = DateTime.now();
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // Pre-fill with EMI or remaining, whichever is smaller
    final defaultAmt = widget.loan.monthlyInstallment > widget.loan.remaining
        ? widget.loan.remaining
        : widget.loan.monthlyInstallment;
    _amountCtrl.text = defaultAmt.toStringAsFixed(0);
    _amountCtrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _currentLang => widget.settings.language;
  String _t(String key) => AppLocale.tr(key, _currentLang);

  double get _enteredAmount {
    return double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
  }

  String get _upiPayload {
    final amt = _enteredAmount;
    final pa = Uri.encodeComponent(widget.settings.ownerUpiId.trim());
    final pn = Uri.encodeComponent(widget.settings.firmName.trim());
    final tn = Uri.encodeComponent("EMI-${widget.loan.borrower}-${widget.loan.id}");

    if (amt > 0) {
      return "upi://pay?pa=$pa&pn=$pn&am=${amt.toStringAsFixed(2)}&cu=INR&tn=$tn";
    } else {
      return "upi://pay?pa=$pa&pn=$pn&cu=INR&tn=$tn";
    }
  }

  Future<void> _recordPayment() async {
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid payment amount")),
      );
      return;
    }

    final newPayment = Payment(
      id: DateTime.now().millisecondsSinceEpoch,
      amount: amt,
      date: DateFormat('yyyy-MM-dd').format(_date),
      mode: _mode,
      collectedBy: widget.agent != null ? widget.agent!.name : "Master Admin",
      note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
    );

    final allLoans = await StorageService.getLoans();
    final idx = allLoans.indexWhere((l) => l.id == widget.loan.id);
    if (idx != -1) {
      final updatedPayments = List<Payment>.from(allLoans[idx].payments)..add(newPayment);
      allLoans[idx] = Loan(
        id: allLoans[idx].id,
        borrower: allLoans[idx].borrower,
        phone: allLoans[idx].phone,
        whatsappPhone: allLoans[idx].whatsappPhone,
        documentProofs: allLoans[idx].documentProofs,
        principal: allLoans[idx].principal,
        interest: allLoans[idx].interest,
        tenure: allLoans[idx].tenure,
        model: allLoans[idx].model,
        startDate: allLoans[idx].startDate,
        created: allLoans[idx].created,
        notes: allLoans[idx].notes,
        legacyPaid: allLoans[idx].legacyPaid,
        payments: updatedPayments,
      );
      await StorageService.saveLoans(allLoans);
    }

    if (!mounted) return;

    // Show Success Modal with Print/WhatsApp options
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: FinTheme.success, size: 56),
            const SizedBox(height: 12),
            const Text(
              "Payment Recorded Successfully!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Received ${_currency.format(amt)} via $_mode",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      PdfService.printPaymentVoucher(
                        loan: widget.loan,
                        payment: newPayment,
                        firmName: widget.settings.firmName,
                      );
                      Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text("Print Slip"),
                    style: ElevatedButton.styleFrom(backgroundColor: FinTheme.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      WhatsAppService.sendPaymentReceipt(
                        loan: widget.loan,
                        payment: newPayment,
                        firmName: widget.settings.firmName,
                      );
                      Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("WhatsApp"),
                    style: ElevatedButton.styleFrom(backgroundColor: FinTheme.success),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text("Done"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('record_installment')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Borrower Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? FinTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.loan.borrower,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_t('monthly_emi')}: ${_currency.format(widget.loan.monthlyInstallment)} / mo",
                        style: TextStyle(fontSize: 12, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_t('pending_balance'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        _currency.format(widget.loan.remaining),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: FinTheme.danger),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Amount Input Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? FinTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? FinTheme.borderDark : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('amount_received'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        "₹",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: FinTheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "0",
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Premium EMI Multiplier Pills
            Row(
              children: [
                _buildAmountPill(
                  label: "1x EMI",
                  amount: widget.loan.monthlyInstallment,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildAmountPill(
                  label: "2x EMI",
                  amount: widget.loan.monthlyInstallment * 2,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildAmountPill(
                  label: _t('full_balance'),
                  amount: widget.loan.remaining,
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Premium Payment Mode Selection
            Text(
              _t('payment_mode').toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildPaymentModeCard(
                  id: 'UPI',
                  title: 'UPI / QR',
                  icon: Icons.qr_code_scanner,
                  color: FinTheme.primary,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildPaymentModeCard(
                  id: 'Cash',
                  title: 'Cash',
                  icon: Icons.payments_outlined,
                  color: FinTheme.success,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildPaymentModeCard(
                  id: 'Bank Transfer',
                  title: 'Bank',
                  icon: Icons.account_balance_outlined,
                  color: Colors.purple,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildPaymentModeCard(
                  id: 'Cheque',
                  title: 'Cheque',
                  icon: Icons.receipt_long_outlined,
                  color: Colors.orange,
                  isDark: isDark,
                ),
              ],
            ),

            // Dynamic In-Screen UPI QR Code Card (When UPI is selected)
            if (_mode == 'UPI') ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16213E) : const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FinTheme.primary.withOpacity(0.35), width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt, color: FinTheme.primary, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          _t('scan_qr_to_pay'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: FinTheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Pay to: ${widget.settings.ownerUpiId} • Amount: ${_currency.format(_enteredAmount)}",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    // High-res QR Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: QrImageView(
                        data: _upiPayload,
                        version: QrVersions.auto,
                        size: 190,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(_upiPayload);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("No UPI app found on device")),
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(_t('open_upi_app'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FinTheme.primary,
                        side: const BorderSide(color: FinTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Payment Date Picker Card
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? FinTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? FinTheme.borderDark : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 20, color: FinTheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          "${_t('payment_date')}: ${DateFormat('dd MMM yyyy').format(_date)}",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Collector / Agent Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? FinTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? FinTheme.borderDark : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 20, color: FinTheme.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_t('collector'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        widget.agent != null ? widget.agent!.name : "Master Admin",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Notes
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: _t('notes_ref'),
                prefixIcon: const Icon(Icons.edit_note),
                filled: true,
                fillColor: isDark ? FinTheme.cardDark : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _recordPayment,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  _t('save_generate_voucher'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountPill({
    required String label,
    required double amount,
    required bool isDark,
  }) {
    final isSelected = (_enteredAmount - amount).abs() < 1;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _amountCtrl.text = amount.toStringAsFixed(0);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? FinTheme.primary
                : (isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? FinTheme.primary : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: FinTheme.primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                : [],
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _currency.format(amount),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentModeCard({
    required String id,
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _mode == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.12)
                : (isDark ? FinTheme.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : (isDark ? FinTheme.borderDark : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: isSelected ? color : Colors.grey),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
