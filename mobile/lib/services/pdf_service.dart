import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../utils/indian_number_words.dart';

class PdfService {
  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd MMM yyyy');

  /// Print or preview single payment installment receipt voucher
  static Future<void> printPaymentVoucher({
    required Loan loan,
    required Payment payment,
    required String firmName,
  }) async {
    final bytes = await generateReceiptBytes(loan: loan, payment: payment, firmName: firmName);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Receipt_${loan.borrower}_${payment.id}.pdf',
    );
  }

  static Future<Uint8List> generateReceiptBytes({
    required Loan loan,
    required Payment payment,
    required String firmName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey700, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          firmName.toUpperCase(),
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.Text("OFFICIAL PAYMENT ACKNOWLEDGMENT", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.green50,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text("PAID", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 10),

                // Voucher Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Voucher No: #${payment.id}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Date: ${payment.date}", style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 10),

                // Borrower Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Received From:", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          pw.Text(loan.borrower, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Phone: ${loan.phone}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Payment Mode:", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          pw.Text(payment.mode.toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Amount Highlight
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text("AMOUNT RECEIVED", style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _currency.format(payment.amount),
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Loan Account Position
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Total Loan", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Total Repaid", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Balance Due", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_currency.format(loan.totalPayable), style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_currency.format(loan.totalPaid), style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_currency.format(loan.remaining), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800))),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),

                // Footer Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Collected By:", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.Text(payment.collectedBy ?? "Authorized Signatory", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(width: 80, height: 1, color: PdfColors.grey600),
                        pw.SizedBox(height: 4),
                        pw.Text("Borrower Signature", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text("Generated securely via FinVault — Smart Loan Ledger", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// 📑 Feature 2: Generate Official Borrower Digital Passbook & Statement PDF
  static Future<Uint8List> generateDigitalPassbookPdf({
    required Loan loan,
    required String firmName,
  }) async {
    final pdf = pw.Document();

    // Sort payments chronologically
    final sortedPayments = List<Payment>.from(loan.payments)
      ..sort((a, b) => a.date.compareTo(b.date));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      firmName.toUpperCase(),
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                    pw.Text("OFFICIAL BORROWER DIGITAL PASSBOOK (రుణ పాస్‌బుక్ స్టేట్‌మెంట్)",
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: loan.remaining <= 0 ? PdfColors.green100 : PdfColors.blue100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    loan.remaining <= 0 ? "SETTLED / LOAN CLOSED" : "ACTIVE LEDGER",
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: loan.remaining <= 0 ? PdfColors.green900 : PdfColors.blue900,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1.5, color: PdfColors.blue900),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) {
          // Compute running balances
          double runningBalance = loan.totalPayable;

          return [
            // Borrower & Loan Information Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Borrower: ${loan.borrower}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text("Phone: ${loan.phone}", style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 2),
                      pw.Text("Loan ID: #${loan.id}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Start Date: ${loan.startDate}", style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        loan.model == 'rupee'
                            ? "Rate: Rs.${loan.interest}/Rs.100/mo"
                            : "Rate: ${loan.interest}% p.a. (${loan.model.toUpperCase()})",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text("Tenure: ${loan.tenure} Months", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Financial Summary 4-Grid Card
            pw.Row(
              children: [
                _buildPassbookSummaryTile("Principal Amount", _currency.format(loan.principal), PdfColors.grey800),
                pw.SizedBox(width: 8),
                _buildPassbookSummaryTile("Total Payable", _currency.format(loan.totalPayable), PdfColors.blue800),
                pw.SizedBox(width: 8),
                _buildPassbookSummaryTile("Total Repaid", _currency.format(loan.totalPaid), PdfColors.green800),
                pw.SizedBox(width: 8),
                _buildPassbookSummaryTile("Remaining Balance", _currency.format(loan.remaining), PdfColors.red800),
              ],
            ),
            pw.SizedBox(height: 18),

            pw.Text("REPAYMENT INSTALLMENT LEDGER", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 8),

            // Passbook Ledger Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell("#", isHeader: true),
                    _tableCell("Date", isHeader: true),
                    _tableCell("Voucher", isHeader: true),
                    _tableCell("Mode", isHeader: true),
                    _tableCell("Collected By", isHeader: true),
                    _tableCell("Paid (Rs.)", isHeader: true, alignRight: true),
                    _tableCell("Balance (Rs.)", isHeader: true, alignRight: true),
                  ],
                ),
                if (sortedPayments.isEmpty)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text("No installments recorded yet. Opening balance: ${_currency.format(loan.totalPayable)}",
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ),
                      ...List.generate(6, (_) => pw.Container()),
                    ],
                  )
                else
                  ...sortedPayments.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final p = entry.value;
                    runningBalance = (runningBalance - p.amount).clamp(0.0, double.infinity);

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: idx % 2 == 0 ? PdfColors.grey50 : PdfColors.white),
                      children: [
                        _tableCell("$idx"),
                        _tableCell(p.date),
                        _tableCell("#${p.id}"),
                        _tableCell(p.mode.toUpperCase()),
                        _tableCell(p.collectedBy ?? "Admin"),
                        _tableCell(_currency.format(p.amount), alignRight: true, isBold: true),
                        _tableCell(_currency.format(runningBalance), alignRight: true),
                      ],
                    );
                  }),
              ],
            ),
            pw.SizedBox(height: 24),

            // Footer / Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Statement Date: ${_dateFormat.format(DateTime.now())}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    pw.Text("Total Installments: ${sortedPayments.length}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 120, height: 1, color: PdfColors.grey600),
                    pw.SizedBox(height: 4),
                    pw.Text("Authorized Signatory ($firmName)", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPassbookSummaryTile(String title, String val, PdfColor valColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: PdfColors.white,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(val, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: valColor)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false, bool alignRight = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 8.5,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.black : PdfColors.grey900,
        ),
      ),
    );
  }

  /// 📜 Feature 4: Generate Bilingual Demand Promissory Note (బాండ్ పేపర్ నోటు / D.P. Note)
  static Future<Uint8List> generatePromissoryNotePdf({
    required Loan loan,
    required String firmName,
    required String lenderName,
    bool stampPaperMargin = false,
  }) async {
    final pdf = pw.Document();
    final amountWords = IndianNumberWords.convert(loan.principal);
    final rateDisplay = loan.model == 'rupee'
        ? "Rs. ${loan.interest} per Rs. 100 per month (రూపాయి వడ్డీ)"
        : "${loan.interest}% per annum (${loan.model.toUpperCase()})";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.only(
          left: 36,
          right: 36,
          bottom: 36,
          top: stampPaperMargin ? 240 : 36, // Leaves ~3.3 inches for ₹100 stamp paper emblem if selected
        ),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: stampPaperMargin
                ? null
                : pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.5),
                  ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title Header
                pw.Center(
                  child: pw.Text(
                    "DEMAND PROMISSORY NOTE (డిమాండ్ ప్రామిసరీ నోటు)",
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                ),
                pw.SizedBox(height: 12),

                // Loan Place, Date, Amount Badge
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Date: ${loan.startDate}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text("Loan ID: #${loan.id}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1.2),
                        color: PdfColors.grey100,
                      ),
                      child: pw.Text(
                        "AMOUNT: ${_currency.format(loan.principal)}/-",
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 12),

                // Legal Promise Covenant
                pw.Text(
                  "ON DEMAND, I / WE, the undersigned borrower:",
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),

                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Borrower Name: ${loan.borrower.toUpperCase()}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Phone Number: ${loan.phone}", style: const pw.TextStyle(fontSize: 10)),
                      if (loan.whatsappPhone.isNotEmpty && loan.whatsappPhone != loan.phone)
                        pw.Text("WhatsApp: ${loan.whatsappPhone}", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                pw.Text(
                  "Promise to pay to $firmName / $lenderName, or order, the sum of ${_currency.format(loan.principal)}/- (in words: $amountWords) together with interest at the agreed rate of $rateDisplay for value received in cash / bank credit.",
                  style: const pw.TextStyle(fontSize: 10, height: 1.4),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 10),

                pw.Text(
                  "తెలుగు ఒప్పందం: పైన పేర్కొన్న రుణదాత ($firmName) గారి వద్ద నుండి నగదు రూపంలో ముట్టిన అసలు మొత్తం ${_currency.format(loan.principal)}/- (అక్షరాలా $amountWords) కు గాను నిర్ణయించిన వడ్డీ రేటుతో కోరిన వెంటనే లేదా నా/మా స్థిర చరాస్తుల ద్వారా చెల్లించగలనని స్వచ్ఛందంగా అంగీకరిస్తూ వ్రాసిచ్చిన ప్రామిసరీ నోటు.",
                  style: const pw.TextStyle(fontSize: 9, height: 1.4),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 14),

                // Terms Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      children: [
                        _tableCell("Principal Amount", isBold: true),
                        _tableCell(_currency.format(loan.principal)),
                        _tableCell("Interest Model", isBold: true),
                        _tableCell(loan.model.toUpperCase()),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _tableCell("Agreed Rate", isBold: true),
                        _tableCell(rateDisplay),
                        _tableCell("Tenure (Months)", isBold: true),
                        _tableCell("${loan.tenure} Months"),
                      ],
                    ),
                  ],
                ),

                pw.Spacer(),

                // Signatures & Revenue Stamp Box
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Witnesses Section
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("WITNESSES (సాక్షులు):", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Text("1. Sign: ___________________________", style: const pw.TextStyle(fontSize: 9)),
                        pw.Text("   Name & Address: _________________", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        pw.SizedBox(height: 8),
                        pw.Text("2. Sign: ___________________________", style: const pw.TextStyle(fontSize: 9)),
                        pw.Text("   Name & Address: _________________", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      ],
                    ),

                    // Revenue Stamp Box
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 80,
                          height: 90,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.black, style: pw.BorderStyle.dashed),
                          ),
                          alignment: pw.Alignment.center,
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text("AFFIX", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                              pw.Text("Rs. 1.00", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.Text("REVENUE", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                              pw.Text("STAMP", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                              pw.Text("& SIGN ACROSS", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text("Borrower Signature / Thumb", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text(loan.borrower, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text("FinVault Legal Bond & Promissory Note Template", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// 📅 Feature 1: Generate Daily Daybook PDF (నిత్య క్యాష్ బుక్ స్టేట్‌మెంట్)
  static Future<Uint8List> generateDaybookPdf({
    required DateTime date,
    required List<Loan> allLoans,
    required String firmName,
    double openingCash = 0.0,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final displayDate = DateFormat('dd MMMM yyyy (EEEE)').format(date);

    // 1. Calculate Outflow (Loans disbursed on this date)
    double cashDisbursed = 0.0;
    final List<Map<String, dynamic>> disbursements = [];
    for (final l in allLoans) {
      final loanCreatedDate = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(l.created));
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

    // 2. Calculate Inflows (Payments collected on this date)
    double cashCollected = 0.0;
    double onlineCollected = 0.0;
    final List<Map<String, dynamic>> collections = [];
    final Map<String, double> agentCashTotals = {};
    final Map<String, double> agentOnlineTotals = {};

    for (final l in allLoans) {
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

    final double netDrawerCash = (openingCash + cashCollected - cashDisbursed);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(firmName.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text("DAILY CASH DAYBOOK & DRAWER TALLY (నిత్య క్యాష్ బుక్)", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                  child: pw.Text(displayDate, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1.5, color: PdfColors.blue900),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) {
          return [
            // 4 Core Tally Cards
            pw.Row(
              children: [
                _buildPassbookSummaryTile("Cash Disbursed (-)", _currency.format(cashDisbursed), PdfColors.red800),
                pw.SizedBox(width: 8),
                _buildPassbookSummaryTile("Cash Collected (+)", _currency.format(cashCollected), PdfColors.green800),
                pw.SizedBox(width: 8),
                _buildPassbookSummaryTile("UPI / Bank Online", _currency.format(onlineCollected), PdfColors.blue800),
                pw.SizedBox(width: 8),
                _buildPassbookSummaryTile("Expected Drawer Cash", _currency.format(netDrawerCash), PdfColors.purple900),
              ],
            ),
            pw.SizedBox(height: 12),

            // Cash Drawer Arithmetic Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text("Opening Cash: ${_currency.format(openingCash)}", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text("+ Cash Collected: ${_currency.format(cashCollected)}", style: pw.TextStyle(fontSize: 9, color: PdfColors.green800)),
                  pw.Text("- Cash Disbursed: ${_currency.format(cashDisbursed)}", style: pw.TextStyle(fontSize: 9, color: PdfColors.red800)),
                  pw.Text("= Net Cash Drawer: ${_currency.format(netDrawerCash)}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Collections Table
            pw.Text("TODAY'S COLLECTIONS & RECOVERIES (${collections.length})", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell("#", isHeader: true),
                    _tableCell("Borrower", isHeader: true),
                    _tableCell("Voucher ID", isHeader: true),
                    _tableCell("Mode", isHeader: true),
                    _tableCell("Collector", isHeader: true),
                    _tableCell("Amount", isHeader: true, alignRight: true),
                  ],
                ),
                if (collections.isEmpty)
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("No collections recorded on this date.", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
                      ...List.generate(5, (_) => pw.Container()),
                    ],
                  )
                else
                  ...collections.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final c = e.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: idx % 2 == 0 ? PdfColors.grey50 : PdfColors.white),
                      children: [
                        _tableCell("$idx"),
                        _tableCell(c['borrower']),
                        _tableCell("#${c['voucherId']}"),
                        _tableCell(c['mode'].toString().toUpperCase()),
                        _tableCell(c['collector']),
                        _tableCell(_currency.format(c['amount']), alignRight: true, isBold: true),
                      ],
                    );
                  }),
              ],
            ),
            pw.SizedBox(height: 16),

            // Disbursements Table
            pw.Text("NEW LOANS DISBURSED TODAY (${disbursements.length})", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell("#", isHeader: true),
                    _tableCell("Borrower", isHeader: true),
                    _tableCell("Phone", isHeader: true),
                    _tableCell("Model", isHeader: true),
                    _tableCell("Disbursed Amount", isHeader: true, alignRight: true),
                  ],
                ),
                if (disbursements.isEmpty)
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("No new loans disbursed on this date.", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
                      ...List.generate(4, (_) => pw.Container()),
                    ],
                  )
                else
                  ...disbursements.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final d = e.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: idx % 2 == 0 ? PdfColors.grey50 : PdfColors.white),
                      children: [
                        _tableCell("$idx"),
                        _tableCell(d['borrower']),
                        _tableCell(d['phone']),
                        _tableCell(d['model'].toString().toUpperCase()),
                        _tableCell(_currency.format(d['amount']), alignRight: true, isBold: true),
                      ],
                    );
                  }),
              ],
            ),
            pw.SizedBox(height: 24),

            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Verified & Reconciled at physical cash drawer closing", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 120, height: 1, color: PdfColors.grey600),
                    pw.SizedBox(height: 4),
                    pw.Text("Cashier / Admin Signature", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
