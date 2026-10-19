import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/fin_theme.dart';

class UpiQrScreen extends StatefulWidget {
  final String ownerUpiId;
  final String firmName;
  final double defaultAmount;
  final String note;

  const UpiQrScreen({
    super.key,
    required this.ownerUpiId,
    required this.firmName,
    this.defaultAmount = 0.0,
    this.note = 'Loan Repayment',
  });

  @override
  State<UpiQrScreen> createState() => _UpiQrScreenState();
}

class _UpiQrScreenState extends State<UpiQrScreen> {
  late TextEditingController _amountCtrl;
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.defaultAmount > 0 ? widget.defaultAmount.toStringAsFixed(0) : '',
    );
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String get _upiPayload {
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final pa = Uri.encodeComponent(widget.ownerUpiId.trim());
    final pn = Uri.encodeComponent(widget.firmName.trim());
    final tn = Uri.encodeComponent(widget.note);

    if (amt > 0) {
      return "upi://pay?pa=$pa&pn=$pn&am=${amt.toStringAsFixed(2)}&cu=INR&tn=$tn";
    } else {
      return "upi://pay?pa=$pa&pn=$pn&cu=INR&tn=$tn";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAmt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dynamic UPI Payment QR"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Amount Input Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? FinTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
              ),
              child: TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: "Payment Amount (₹)",
                  hintText: "Enter amount (Optional for dynamic QR)",
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: InputBorder.none,
                  fillColor: Colors.transparent,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // QR Code Container
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
                border: Border.all(color: const Color(0xFFE5E5EA), width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    widget.firmName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1D1D1F),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (currentAmt > 0)
                    Text(
                      _currency.format(currentAmt),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: FinTheme.primary,
                      ),
                    )
                  else
                    const Text(
                      "Scan to Pay Any Amount",
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: _upiPayload,
                    version: QrVersions.auto,
                    size: 220.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 14, color: FinTheme.success),
                        const SizedBox(width: 6),
                        Text(
                          widget.ownerUpiId,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Copy UPI ID Button
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.ownerUpiId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("UPI ID copied to clipboard!"),
                    backgroundColor: FinTheme.success,
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text("Copy UPI ID"),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: FinTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              "Compatible with Google Pay, PhonePe, Paytm, BHIM, CRED and all major Indian UPI bank apps.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
