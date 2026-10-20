import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/loan.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../services/whatsapp_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/fin_theme.dart';
import 'add_edit_loan_screen.dart';
import 'document_viewer_screen.dart';
import '../payments/record_payment_screen.dart';
import '../payments/upi_qr_screen.dart';

class LoanDetailScreen extends StatefulWidget {
  final Loan loan;
  final UserRole role;
  final StaffAgent? agent;
  final SecuritySettings settings;

  const LoanDetailScreen({
    super.key,
    required this.loan,
    required this.role,
    this.agent,
    required this.settings,
  });

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> with SingleTickerProviderStateMixin {
  late Loan _currentLoan;
  bool _hasChanged = false;
  late TabController _tabController;
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _currentLoan = widget.loan;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshLoan() async {
    final all = await StorageService.getLoans();
    final updated = all.firstWhere((l) => l.id == _currentLoan.id, orElse: () => _currentLoan);
    setState(() => _currentLoan = updated);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Loan Record?"),
        content: Text("Are you sure you want to permanently delete the loan ledger for ${_currentLoan.borrower}? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: FinTheme.danger),
            child: const Text("Delete Permanently"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final all = await StorageService.getLoans();
      all.removeWhere((l) => l.id == _currentLoan.id);
      await StorageService.saveLoans(all);
      if (widget.settings.cloudSyncEnabled && widget.settings.vaultId.isNotEmpty) {
        SupabaseService.deleteLoan(_currentLoan.id, widget.settings.vaultId);
        SupabaseService.pushLoans(all, widget.settings.vaultId);
      }
      if (mounted) Navigator.pop(context, true);
    }
  }

  String _getDocDisplayName(String pathOrName) {
    final sep = pathOrName.contains('/') ? '/' : '\\';
    final name = pathOrName.split(sep).last;
    return name.replaceFirst(RegExp(r'^\d+_'), '');
  }

  bool _isImagePath(String pathOrName) {
    final lower = pathOrName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');
  }

  void _showFullImageViewer(BuildContext context, String docPath, String displayName) {
    FinImageViewerDialog.show(context, imagePath: docPath, title: displayName);
  }

  void _openDocument(BuildContext context, String docPath, String displayName) {
    FinDocumentHelper.openDocumentWithOptions(context, docPath: docPath, displayName: displayName);
  }

  Future<void> _openDigitalPassbook(BuildContext context) async {
    final loan = _currentLoan;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2638) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.indigoAccent, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Borrower Digital Passbook (రుణ పాస్‌బుక్)",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "${loan.borrower} • Balance: ${_currency.format(loan.remaining)}",
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FinTheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.visibility_outlined, color: FinTheme.primary),
                  ),
                  title: const Text("View & Print Passbook PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text("Bank-style mini-statement with full repayment history", style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final bytes = await PdfService.generateDigitalPassbookPdf(
                        loan: loan,
                        firmName: widget.settings.firmName,
                      );
                      final tempDir = await getTemporaryDirectory();
                      final filePath = '${tempDir.path}/Passbook_${loan.borrower}_${loan.id}.pdf';
                      await File(filePath).writeAsBytes(bytes);
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FinPdfViewerScreen(
                              filePath: filePath,
                              title: "Passbook - ${loan.borrower}",
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share, color: Colors.green),
                  ),
                  title: const Text("Send on WhatsApp (Mini-Statement)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text("Share statement PDF with breakdown directly to borrower", style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final bytes = await PdfService.generateDigitalPassbookPdf(
                        loan: loan,
                        firmName: widget.settings.firmName,
                      );
                      final tempDir = await getTemporaryDirectory();
                      final filePath = '${tempDir.path}/Passbook_${loan.borrower}_${loan.id}.pdf';
                      await File(filePath).writeAsBytes(bytes);

                      final msg = """
*LOAN PASSBOOK STATEMENT — ${widget.settings.firmName}*
━━━━━━━━━━━━━━━━━━━━
Dear *${loan.borrower}*,
Here is your official digital passbook statement:

📌 *Loan ID:* #${loan.id}
💰 *Principal Amount:* ${_currency.format(loan.principal)}
💸 *Total Repaid:* ${_currency.format(loan.totalPaid)} (${loan.payments.length} installments)
⚠️ *Remaining Balance:* ${_currency.format(loan.remaining)}

Please find your official passbook PDF statement attached.
━━━━━━━━━━━━━━━━━━━━
""";
                      await Share.shareXFiles([XFile(filePath)], text: msg);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPromissoryNoteOptions(BuildContext context) async {
    final loan = _currentLoan;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2638) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.description_outlined, color: Colors.deepOrange, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Auto Promissory Note (డిమాండ్ ప్రామిసరీ నోటు)",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Amount: ${_currency.format(loan.principal)} • ${loan.borrower}",
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FinTheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.print_outlined, color: FinTheme.primary),
                  ),
                  title: const Text("Standard A4 Plain Note", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text("Print on plain A4 paper with legal revenue stamp box", style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _generateAndShowBond(false),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gavel_outlined, color: Colors.deepOrange),
                  ),
                  title: const Text("₹100 Stamp Paper Margin (బాండ్ పేపర్)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text("Leaves top 3.3 inches for government stamp paper emblem", style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _generateAndShowBond(true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateAndShowBond(bool stampPaperMargin) async {
    Navigator.pop(context);
    try {
      final bytes = await PdfService.generatePromissoryNotePdf(
        loan: _currentLoan,
        firmName: widget.settings.firmName,
        lenderName: widget.settings.adminName,
        stampPaperMargin: stampPaperMargin,
      );
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/PromissoryNote_${_currentLoan.borrower}_${_currentLoan.id}.pdf';
      await File(filePath).writeAsBytes(bytes);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FinPdfViewerScreen(
              filePath: filePath,
              title: "Promissory Note - ${_currentLoan.borrower}",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loan = _currentLoan;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _hasChanged);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasChanged),
          ),
          title: Text(loan.borrower),
        actions: [
          if (widget.role == UserRole.admin)
            PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'edit') {
                  final edited = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditLoanScreen(
                        loanToEdit: loan,
                        settings: widget.settings,
                      ),
                    ),
                  );
                  if (edited == true) {
                    _hasChanged = true;
                    _refreshLoan();
                  }
                } else if (val == 'delete') {
                  _confirmDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit Loan")]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [Icon(Icons.delete, size: 18, color: FinTheme.danger), SizedBox(width: 8), Text("Delete Loan", style: TextStyle(color: FinTheme.danger))]),
                ),
              ],
            ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Borrower Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? FinTheme.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                        border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loan.borrower,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        loan.phone,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                                        ),
                                      ),
                                      if (loan.whatsappPhone.isNotEmpty && loan.whatsappPhone != loan.phone) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.chat_bubble_outline, size: 13, color: FinTheme.success),
                                        const SizedBox(width: 4),
                                        Text(
                                          loan.whatsappPhone,
                                          style: const TextStyle(fontSize: 12, color: FinTheme.success, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  if (loan.phone.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.phone, color: FinTheme.primary),
                                      tooltip: "Call Borrower",
                                      onPressed: () => launchUrl(Uri.parse("tel:${loan.phone}")),
                                    ),
                                  if (loan.effectiveWhatsApp.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.chat, color: FinTheme.success),
                                      tooltip: "WhatsApp Reminder",
                                      onPressed: () => WhatsAppService.sendEmiReminder(
                                        loan: loan,
                                        firmName: widget.settings.firmName,
                                        ownerUpiId: widget.settings.ownerUpiId,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Progress Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Repaid: ${_currency.format(loan.totalPaid)}",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                "Balance: ${_currency.format(loan.remaining)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: loan.isCompleted ? FinTheme.success : FinTheme.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: loan.progressPercent / 100,
                              minHeight: 8,
                              backgroundColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFE5E9F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                loan.isCompleted ? FinTheme.success : FinTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (loan.documentProofs.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? FinTheme.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
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
                                    Icon(Icons.folder_shared_outlined, size: 16, color: FinTheme.primary),
                                    SizedBox(width: 6),
                                    Text("Proof & KYC Documents", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: FinTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${loan.documentProofs.length} Attached",
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: FinTheme.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: loan.documentProofs.map((docPath) {
                                final displayName = _getDocDisplayName(docPath);
                                final isImage = _isImagePath(docPath);
                                final file = File(docPath);
                                final exists = file.existsSync();

                                if (isImage && exists) {
                                  return InkWell(
                                    onTap: () => _showFullImageViewer(context, docPath, displayName),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isDark ? FinTheme.borderDark : const Color(0xFFCBD5E1)),
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(11),
                                            child: Image.file(
                                              file,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Center(
                                                child: Icon(Icons.broken_image, size: 28, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.65),
                                                borderRadius: const BorderRadius.only(
                                                  bottomLeft: Radius.circular(11),
                                                  bottomRight: Radius.circular(11),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.zoom_in, size: 12, color: Colors.white),
                                                  const SizedBox(width: 2),
                                                  Expanded(
                                                    child: Text(
                                                      displayName,
                                                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return InkWell(
                                  onTap: () => _openDocument(context, docPath, displayName),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isDark ? FinTheme.borderDark : const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          displayName.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.description,
                                          size: 20,
                                          color: displayName.toLowerCase().endsWith('.pdf') ? Colors.redAccent : FinTheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 160),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                displayName,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const Text("Tap to view / share", style: TextStyle(fontSize: 9, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () {
                                            if (file.existsSync()) {
                                              Share.shareXFiles([XFile(docPath)], text: "FinVault Document: $displayName");
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.share, size: 16, color: FinTheme.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Financial Grid Summary
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? FinTheme.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                        border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow("Principal Amount", _currency.format(loan.principal), isDark),
                          const Divider(height: 16),
                          _buildDetailRow(
                            loan.model == 'rupee' ? "Rupee Interest Rate" : "Interest Rate",
                            loan.model == 'rupee'
                                ? "₹${loan.interest} per ₹100/mo"
                                : "${loan.interest}% (${loan.model == 'emi' ? 'Reducing EMI' : 'Flat Simple'})",
                            isDark,
                          ),
                          const Divider(height: 16),
                          _buildDetailRow("Tenure / Duration", "${loan.tenure} Months", isDark),
                          const Divider(height: 16),
                          _buildDetailRow(
                            loan.model == 'rupee' ? "Monthly Interest (Vaddi)" : "Monthly Installment",
                            _currency.format(loan.monthlyInstallment),
                            isDark,
                            highlight: true,
                          ),
                          const Divider(height: 16),
                          _buildDetailRow("Total Loan Amount", _currency.format(loan.totalPayable), isDark),
                          const Divider(height: 16),
                          _buildDetailRow("Start Date", loan.startDate, isDark),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons Bar
                    Row(
                      children: [
                        if (!loan.isCompleted)
                          Expanded(
                            child: ElevatedButton.icon(
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
                                  _hasChanged = true;
                                  _refreshLoan();
                                }
                              },
                              icon: const Icon(Icons.add_circle, size: 18),
                              label: const Text("Collect EMI"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FinTheme.success,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        if (!loan.isCompleted) const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UpiQrScreen(
                                    ownerUpiId: widget.settings.ownerUpiId,
                                    firmName: widget.settings.firmName,
                                    defaultAmount: loan.monthlyInstallment,
                                    note: "EMI for ${loan.borrower}",
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code, size: 18, color: FinTheme.primary),
                            label: const Text("UPI QR", style: TextStyle(color: FinTheme.primary)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: FinTheme.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openDigitalPassbook(context),
                            icon: const Icon(Icons.menu_book_rounded, size: 17, color: Colors.indigoAccent),
                            label: const Text("📑 Passbook", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigoAccent)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.indigoAccent),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openPromissoryNoteOptions(context),
                            icon: const Icon(Icons.description_outlined, size: 17, color: Colors.deepOrange),
                            label: const Text("📜 Bond Note", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.deepOrange),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: FinTheme.primary,
                  unselectedLabelColor: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                  indicatorColor: FinTheme.primary,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: "Payment Ledger (${loan.payments.length})"),
                    Tab(text: "Amortization (${loan.tenure} mo)"),
                  ],
                ),
                isDark: isDark,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Ledger Tab
            _buildLedgerTab(loan, isDark),
            // Amortization Tab
            _buildAmortizationTab(loan, isDark),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            color: highlight ? FinTheme.primary : (isDark ? Colors.white : FinTheme.textLightPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerTab(Loan loan, bool isDark) {
    if (loan.payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text("No installments recorded yet", style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final reversed = loan.payments.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final p = reversed[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currency.format(p.amount),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: FinTheme.success),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${p.date} • Mode: ${p.mode}",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                      ),
                    ),
                    if (p.note != null && p.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          p.note!,
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? Colors.grey : Colors.black54),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print, size: 20, color: FinTheme.primary),
                      onPressed: () => PdfService.printPaymentVoucher(
                        loan: loan,
                        payment: p,
                        firmName: widget.settings.firmName,
                      ),
                      tooltip: "Print Voucher",
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 20, color: FinTheme.success),
                      onPressed: () => WhatsAppService.sendPaymentReceipt(
                        loan: loan,
                        payment: p,
                        firmName: widget.settings.firmName,
                      ),
                      tooltip: "WhatsApp Receipt",
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmortizationTab(Loan loan, bool isDark) {
    final rows = loan.amortizationSchedule;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? FinTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: row.isPaid
                  ? FinTheme.success.withOpacity(0.4)
                  : (isDark ? FinTheme.borderDark : FinTheme.borderLight),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: row.isPaid ? FinTheme.success : Colors.grey.withOpacity(0.2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "${row.month}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: row.isPaid ? Colors.white : (isDark ? Colors.white : Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Due: ${row.dueDate}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        "Principal: ${_currency.format(row.principal)} • Interest: ${_currency.format(row.interest)}",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_currency.format(row.emi), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    row.isPaid ? "PAID" : "PENDING",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: row.isPaid ? FinTheme.success : FinTheme.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;

  _TabBarDelegate(this.tabBar, {required this.isDark});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? FinTheme.bgDark : FinTheme.bgLight,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
