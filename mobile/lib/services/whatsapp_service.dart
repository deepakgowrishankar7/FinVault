import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../models/payment.dart';

class WhatsAppService {
  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  static Future<bool> sendPaymentReceipt({
    required Loan loan,
    required Payment payment,
    required String firmName,
  }) async {
    final cleanPhone = loan.phone.replaceAll(RegExp(r'\D'), '');
    final targetPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;

    final msg = """
*PAYMENT RECEIPT — $firmName*
━━━━━━━━━━━━━━━━━━━━
Dear *${loan.borrower}*,
Thank you for your payment! Here is your installment acknowledgment:

💸 *Amount Received:* ${_currency.format(payment.amount)}
📅 *Date:* ${payment.date}
💳 *Mode:* ${payment.mode}
🔖 *Voucher ID:* #${payment.id}

📊 *Loan Status:*
• Total Loan: ${_currency.format(loan.totalPayable)}
• Total Paid: ${_currency.format(loan.totalPaid)}
• Balance Outstanding: ${_currency.format(loan.remaining)}

_FinVault Smart Ledger • Verified Receipt_
━━━━━━━━━━━━━━━━━━━━
""";

    final url = Uri.parse("https://wa.me/$targetPhone?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> sendEmiReminder({
    required Loan loan,
    required String firmName,
    required String ownerUpiId,
  }) async {
    final cleanPhone = loan.phone.replaceAll(RegExp(r'\D'), '');
    final targetPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;

    final dueDateStr = DateFormat('dd MMM yyyy').format(loan.nextDueDate);

    final msg = """
*PAYMENT REMINDER — $firmName*
━━━━━━━━━━━━━━━━━━━━
Dear *${loan.borrower}*,
This is a gentle reminder regarding your upcoming loan installment.

📌 *Installment Due:* ${_currency.format(loan.monthlyInstallment)}
📅 *Due Date:* $dueDateStr
📊 *Current Balance:* ${_currency.format(loan.remaining)}

📲 *Quick UPI Payment:*
UPI ID: `$ownerUpiId`

Please notify us once paid to instantly receive your digital receipt. Thank you!
━━━━━━━━━━━━━━━━━━━━
""";

    final url = Uri.parse("https://wa.me/$targetPhone?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
