import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/loan.dart';
import '../../models/payment.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/whatsapp_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/fin_theme.dart';

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
  String _mode = 'UPI';
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
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
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
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: FinTheme.success, size: 32),
            ),
            const SizedBox(height: 12),
            const Text(
              "Payment Successfully Recorded!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "${_currency.format(amt)} collected for ${widget.loan.borrower}",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
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
                    label: const Text("Print Voucher"),
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
        title: const Text("Record Installment"),
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
                borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.loan.borrower,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text("EMI: ${_currency.format(widget.loan.monthlyInstallment)} / mo",
                          style: TextStyle(fontSize: 12, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Balance Due", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        _currency.format(widget.loan.remaining),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: FinTheme.danger),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Amount Input
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: "Amount Received (₹) *",
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),

            const SizedBox(height: 10),

            // Quick Amount Suggestion Chips
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: Text("1x EMI (${_currency.format(widget.loan.monthlyInstallment)})"),
                  onPressed: () => _amountCtrl.text = widget.loan.monthlyInstallment.toStringAsFixed(0),
                ),
                ActionChip(
                  label: Text("2x EMI (${_currency.format(widget.loan.monthlyInstallment * 2)})"),
                  onPressed: () => _amountCtrl.text = (widget.loan.monthlyInstallment * 2).toStringAsFixed(0),
                ),
                ActionChip(
                  label: Text("Full Balance (${_currency.format(widget.loan.remaining)})"),
                  onPressed: () => _amountCtrl.text = widget.loan.remaining.toStringAsFixed(0),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Payment Mode Selector
            DropdownButtonFormField<String>(
              value: _mode,
              decoration: const InputDecoration(
                labelText: "Payment Mode",
                prefixIcon: Icon(Icons.payment),
              ),
              items: const [
                DropdownMenuItem(value: 'UPI', child: Text("UPI (GPay / PhonePe / Paytm)")),
                DropdownMenuItem(value: 'Cash', child: Text("Cash in Hand")),
                DropdownMenuItem(value: 'Bank Transfer', child: Text("Bank Transfer / IMPS / NEFT")),
                DropdownMenuItem(value: 'Cheque', child: Text("Cheque")),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _mode = val);
              },
            ),

            const SizedBox(height: 14),

            // Payment Date Picker
            InkWell(
              borderRadius: BorderRadius.circular(FinTheme.radiusSmall),
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
                  color: isDark ? const Color(0xFF1A2332) : const Color(0xFFF0F2F6),
                  borderRadius: BorderRadius.circular(FinTheme.radiusSmall),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 20, color: FinTheme.primary),
                        const SizedBox(width: 12),
                        Text("Payment Date: ${DateFormat('dd MMM yyyy').format(_date)}"),
                      ],
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Collector / Agent
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? FinTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(FinTheme.radiusSmall),
                border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 20, color: FinTheme.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Collector", style: TextStyle(fontSize: 10, color: Colors.grey)),
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
              decoration: const InputDecoration(
                labelText: "Payment Note / Reference No.",
                prefixIcon: Icon(Icons.edit_note),
              ),
            ),

            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _recordPayment,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text("Record Installment & Generate Voucher", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
