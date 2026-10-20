import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/loan.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/fin_theme.dart';
import '../../theme/app_locale.dart';

class AddEditLoanScreen extends StatefulWidget {
  final Loan? loanToEdit;
  final SecuritySettings? settings;

  const AddEditLoanScreen({super.key, this.loanToEdit, this.settings});

  @override
  State<AddEditLoanScreen> createState() => _AddEditLoanScreenState();
}

class _AddEditLoanScreenState extends State<AddEditLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _borrowerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _sameAsCallingPhone = true;
  List<String> _documentProofs = [];
  String _model = 'emi'; // 'emi' or 'simple'
  DateTime _startDate = DateTime.now();
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final edit = widget.loanToEdit;
    if (edit != null) {
      _borrowerCtrl.text = edit.borrower;
      _phoneCtrl.text = edit.phone;
      _whatsappCtrl.text = edit.whatsappPhone;
      _sameAsCallingPhone = edit.phone == edit.whatsappPhone;
      _documentProofs = List<String>.from(edit.documentProofs);
      _principalCtrl.text = edit.principal.toStringAsFixed(0);
      _interestCtrl.text = edit.interest.toString();
      _tenureCtrl.text = edit.tenure.toString();
      _model = edit.model;
      _notesCtrl.text = edit.notes ?? '';
      try {
        _startDate = DateTime.parse(edit.startDate);
      } catch (_) {}
    } else {
      _principalCtrl.text = '50000';
      _interestCtrl.text = '12';
      _tenureCtrl.text = '12';
    }

    _principalCtrl.addListener(() => setState(() {}));
    _interestCtrl.addListener(() => setState(() {}));
    _tenureCtrl.addListener(() => setState(() {}));
    _phoneCtrl.addListener(() {
      if (_sameAsCallingPhone) {
        _whatsappCtrl.text = _phoneCtrl.text;
      }
    });
  }

  @override
  void dispose() {
    _borrowerCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _principalCtrl.dispose();
    _interestCtrl.dispose();
    _tenureCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _currentLang => widget.settings?.language ?? AppLocale.currentLang;
  String _t(String key) => AppLocale.tr(key, _currentLang);

  double get _currentPrincipal => double.tryParse(_principalCtrl.text) ?? 0.0;
  double get _currentInterest => double.tryParse(_interestCtrl.text) ?? 0.0;
  int get _currentTenure => int.tryParse(_tenureCtrl.text) ?? 0;

  double get _computedMonthly {
    if (_model == 'rupee') {
      return Loan.calcRupeeMonthlyInterest(_currentPrincipal, _currentInterest);
    } else if (_model == 'emi') {
      return Loan.calcEmi(_currentPrincipal, _currentInterest, _currentTenure);
    } else {
      return Loan.calcSimple(_currentPrincipal, _currentInterest, _currentTenure);
    }
  }

  double get _computedTotalPayable {
    if (_model == 'rupee') {
      final monthlyInterest = Loan.calcRupeeMonthlyInterest(_currentPrincipal, _currentInterest);
      return (_currentPrincipal + (monthlyInterest * _currentTenure)).roundToDouble();
    } else if (_model == 'emi') {
      return (_computedMonthly * _currentTenure).roundToDouble();
    } else {
      final interest = _currentPrincipal * (_currentInterest / 100) * (_currentTenure / 12);
      return (_currentPrincipal + interest).roundToDouble();
    }
  }

  void _selectModel(String id) {
    setState(() {
      _model = id;
      if (id == 'rupee' && (_interestCtrl.text == '12' || (double.tryParse(_interestCtrl.text) ?? 0) > 10)) {
        _interestCtrl.text = '2';
      } else if (id != 'rupee' && (double.tryParse(_interestCtrl.text) ?? 0) <= 5) {
        _interestCtrl.text = '12';
      }
    });
  }

  double get _computedTotalInterest => (_computedTotalPayable - _currentPrincipal).clamp(0.0, double.infinity);

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

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final proofsDir = Directory('${appDir.path}/finvault_proofs');
        if (!await proofsDir.exists()) {
          await proofsDir.create(recursive: true);
        }

        setState(() {
          for (final f in result.files) {
            String savedPath = '';
            final cleanName = f.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final targetPath = '${proofsDir.path}/${timestamp}_$cleanName';

            if (f.path != null && File(f.path!).existsSync()) {
              File(f.path!).copySync(targetPath);
              savedPath = targetPath;
            } else if (f.bytes != null) {
              File(targetPath).writeAsBytesSync(f.bytes!);
              savedPath = targetPath;
            } else if (f.path != null) {
              savedPath = f.path!;
            } else {
              savedPath = f.name;
            }

            if (savedPath.isNotEmpty && !_documentProofs.contains(savedPath)) {
              _documentProofs.add(savedPath);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not pick file: $e")),
        );
      }
    }
  }

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) return;

    final callingPhone = _phoneCtrl.text.trim();
    final waPhone = _sameAsCallingPhone ? callingPhone : _whatsappCtrl.text.trim();

    final allLoans = await StorageService.getLoans();

    if (widget.loanToEdit != null) {
      final idx = allLoans.indexWhere((l) => l.id == widget.loanToEdit!.id);
      if (idx != -1) {
        allLoans[idx] = Loan(
          id: widget.loanToEdit!.id,
          borrower: _borrowerCtrl.text.trim(),
          phone: callingPhone,
          whatsappPhone: waPhone,
          documentProofs: _documentProofs,
          principal: _currentPrincipal,
          interest: _currentInterest,
          tenure: _currentTenure,
          model: _model,
          startDate: DateFormat('yyyy-MM-dd').format(_startDate),
          created: widget.loanToEdit!.created,
          notes: _notesCtrl.text.trim(),
          legacyPaid: widget.loanToEdit!.legacyPaid,
          payments: widget.loanToEdit!.payments,
        );
      }
    } else {
      final newLoan = Loan(
        id: "L-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
        borrower: _borrowerCtrl.text.trim(),
        phone: callingPhone,
        whatsappPhone: waPhone,
        documentProofs: _documentProofs,
        principal: _currentPrincipal,
        interest: _currentInterest,
        tenure: _currentTenure,
        model: _model,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        created: DateTime.now().millisecondsSinceEpoch,
        notes: _notesCtrl.text.trim(),
        payments: [],
      );
      allLoans.insert(0, newLoan);
    }

    await StorageService.saveLoans(allLoans);
    if (widget.settings?.cloudSyncEnabled == true && widget.settings!.vaultId.isNotEmpty) {
      SupabaseService.pushLoans(allLoans, widget.settings!.vaultId);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.loanToEdit != null ? _t('update_loan') : _t('add_new_loan')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Calculation Preview Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0071E3), Color(0xFF0056B3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: FinTheme.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      (_model == 'rupee' ? _t('monthly_interest') : _t('monthly_emi')).toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currency.format(_computedMonthly),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(_t('total_payable'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                            const SizedBox(height: 2),
                            Text(_currency.format(_computedTotalPayable), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        Container(width: 1, height: 26, color: Colors.white24),
                        Column(
                          children: [
                            Text(_t('total_interest'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                            const SizedBox(height: 2),
                            Text(_currency.format(_computedTotalInterest), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Borrower Name
              TextFormField(
                controller: _borrowerCtrl,
                decoration: InputDecoration(
                  labelText: "${_t('borrower_name')} *",
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: isDark ? FinTheme.cardDark : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Borrower name is required" : null,
              ),

              const SizedBox(height: 16),

              // Calling Phone Number
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "${_t('call_phone')} *",
                  hintText: "10-digit calling number",
                  prefixIcon: const Icon(Icons.phone_outlined),
                  filled: true,
                  fillColor: isDark ? FinTheme.cardDark : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Calling phone is required" : null,
              ),

              const SizedBox(height: 8),

              // WhatsApp Checkbox
              CheckboxListTile(
                value: _sameAsCallingPhone,
                onChanged: (val) {
                  setState(() {
                    _sameAsCallingPhone = val ?? true;
                    if (_sameAsCallingPhone) {
                      _whatsappCtrl.text = _phoneCtrl.text;
                    }
                  });
                },
                title: Text(_t('same_as_phone'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              // WhatsApp Phone Number (If different)
              if (!_sameAsCallingPhone) ...[
                const SizedBox(height: 6),
                TextFormField(
                  controller: _whatsappCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "${_t('whatsapp_phone')} *",
                    hintText: "WhatsApp number for reminders",
                    prefixIcon: const Icon(Icons.chat_bubble_outline, color: FinTheme.success),
                    filled: true,
                    fillColor: isDark ? FinTheme.cardDark : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (val) => (!_sameAsCallingPhone && (val == null || val.trim().isEmpty))
                      ? "WhatsApp phone is required"
                      : null,
                ),
              ],

              const SizedBox(height: 16),

              // Principal & Interest Rate
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _principalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "${_t('principal_amount')} *",
                        prefixIcon: const Icon(Icons.currency_rupee),
                        filled: true,
                        fillColor: isDark ? FinTheme.cardDark : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (val) {
                        final n = double.tryParse(val ?? '');
                        return (n == null || n <= 0) ? "Enter amount" : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _interestCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _model == 'rupee' ? "Vaddi (₹/₹100/mo) *" : "${_t('interest_rate')} *",
                        hintText: _model == 'rupee' ? "e.g. 2 for ₹2 vaddi" : "e.g. 12",
                        prefixIcon: Icon(_model == 'rupee' ? Icons.currency_rupee : Icons.percent),
                        filled: true,
                        fillColor: isDark ? FinTheme.cardDark : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (val) {
                        final n = double.tryParse(val ?? '');
                        return (n == null || n < 0) ? "Enter rate" : null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tenure
              TextFormField(
                controller: _tenureCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "${_t('tenure_months')} *",
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  filled: true,
                  fillColor: isDark ? FinTheme.cardDark : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  return (n == null || n <= 0) ? "Enter months" : null;
                },
              ),

              const SizedBox(height: 18),

              // Premium Loan Model Selection (3 Options)
              Text(
                _t('loan_type').toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              _buildModelOption(
                id: 'emi',
                title: _t('reducing_emi'),
                subtitle: _t('reducing_emi_sub'),
                icon: Icons.trending_down,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildModelOption(
                id: 'simple',
                title: _t('flat_simple'),
                subtitle: _t('flat_simple_sub'),
                icon: Icons.horizontal_rule,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildModelOption(
                id: 'rupee',
                title: _t('rupee_rate'),
                subtitle: _t('rupee_rate_sub'),
                icon: Icons.currency_rupee,
                isDark: isDark,
              ),

              const SizedBox(height: 18),

              // Document Proof Attachments Card (Zero Overflow Guaranteed)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? FinTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? FinTheme.borderDark : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_shared_outlined, size: 20, color: FinTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _t('proof_docs'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _pickDocuments,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: FinTheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 14, color: FinTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  _t('add_proof'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FinTheme.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_documentProofs.isEmpty)
                      Text(
                        _t('no_docs'),
                        style: TextStyle(fontSize: 12, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _documentProofs.map((docPath) {
                          final displayName = _getDocDisplayName(docPath);
                          final isImage = _isImagePath(docPath);
                          final file = File(docPath);
                          final exists = file.existsSync();

                          if (isImage && exists) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isDark ? FinTheme.borderDark : const Color(0xFFCBD5E1)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 28),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _documentProofs.remove(docPath)),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: FinTheme.danger,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          return Chip(
                            avatar: Icon(
                              isImage ? Icons.image_outlined : Icons.description_outlined,
                              size: 14,
                              color: FinTheme.primary,
                            ),
                            label: Text(
                              displayName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() => _documentProofs.remove(docPath));
                            },
                            backgroundColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Start Date Picker Card
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setState(() => _startDate = picked);
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
                          const Icon(Icons.event_outlined, size: 20, color: FinTheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            "${_t('start_date')}: ${DateFormat('dd MMM yyyy').format(_startDate)}",
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _t('notes_collateral'),
                  hintText: "Property pledge, gold weight, vehicle number, guarantor...",
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                  filled: true,
                  fillColor: isDark ? FinTheme.cardDark : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveLoan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FinTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: Text(
                    widget.loanToEdit != null ? _t('update_loan') : _t('save_loan'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildModelOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _model == id;
    return GestureDetector(
      onTap: () => _selectModel(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? FinTheme.primary.withOpacity(0.12)
              : (isDark ? FinTheme.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? FinTheme.primary : (isDark ? FinTheme.borderDark : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: isSelected ? FinTheme.primary : Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? FinTheme.primary : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
