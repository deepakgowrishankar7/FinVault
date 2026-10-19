import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/loan.dart';
import '../../services/storage_service.dart';
import '../../theme/fin_theme.dart';

class AddEditLoanScreen extends StatefulWidget {
  final Loan? loanToEdit;

  const AddEditLoanScreen({super.key, this.loanToEdit});

  @override
  State<AddEditLoanScreen> createState() => _AddEditLoanScreenState();
}

class _AddEditLoanScreenState extends State<AddEditLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _borrowerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

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
  }

  @override
  void dispose() {
    _borrowerCtrl.dispose();
    _phoneCtrl.dispose();
    _principalCtrl.dispose();
    _interestCtrl.dispose();
    _tenureCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _currentPrincipal => double.tryParse(_principalCtrl.text) ?? 0.0;
  double get _currentInterest => double.tryParse(_interestCtrl.text) ?? 0.0;
  int get _currentTenure => int.tryParse(_tenureCtrl.text) ?? 0;

  double get _computedMonthly {
    if (_model == 'emi') {
      return Loan.calcEmi(_currentPrincipal, _currentInterest, _currentTenure);
    } else {
      return Loan.calcSimple(_currentPrincipal, _currentInterest, _currentTenure);
    }
  }

  double get _computedTotalPayable {
    if (_model == 'emi') {
      return _computedMonthly * _currentTenure;
    } else {
      final interest = _currentPrincipal * (_currentInterest / 100) * (_currentTenure / 12);
      return (_currentPrincipal + interest).roundToDouble();
    }
  }

  double get _computedTotalInterest => (_computedTotalPayable - _currentPrincipal).clamp(0.0, double.infinity);

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) return;

    final allLoans = await StorageService.getLoans();

    if (widget.loanToEdit != null) {
      final idx = allLoans.indexWhere((l) => l.id == widget.loanToEdit!.id);
      if (idx != -1) {
        allLoans[idx] = Loan(
          id: widget.loanToEdit!.id,
          borrower: _borrowerCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
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
        phone: _phoneCtrl.text.trim(),
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
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.loanToEdit != null ? "Edit Loan" : "Create New Loan"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Calculation Preview Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0071E3), Color(0xFF0056B3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
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
                    const Text(
                      "ESTIMATED MONTHLY INSTALLMENT",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currency.format(_computedMonthly),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text("Total Payable", style: TextStyle(fontSize: 11, color: Colors.white70)),
                            const SizedBox(height: 2),
                            Text(_currency.format(_computedTotalPayable), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        Container(width: 1, height: 24, color: Colors.white24),
                        Column(
                          children: [
                            const Text("Total Interest", style: TextStyle(fontSize: 11, color: Colors.white70)),
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
                decoration: const InputDecoration(
                  labelText: "Borrower Full Name *",
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Borrower name is required" : null,
              ),

              const SizedBox(height: 14),

              // Phone Number
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number (WhatsApp) *",
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Phone number is required" : null,
              ),

              const SizedBox(height: 14),

              // Principal & Interest Rate
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _principalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Principal (₹) *",
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      validator: (val) {
                        final n = double.tryParse(val ?? '');
                        return (n == null || n <= 0) ? "Enter valid amount" : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _interestCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Annual Rate (%) *",
                        prefixIcon: Icon(Icons.percent),
                      ),
                      validator: (val) {
                        final n = double.tryParse(val ?? '');
                        return (n == null || n < 0) ? "Enter rate" : null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Tenure & Interest Model
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tenureCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Tenure (Months) *",
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (val) {
                        final n = int.tryParse(val ?? '');
                        return (n == null || n <= 0) ? "Enter months" : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _model,
                      decoration: const InputDecoration(
                        labelText: "Calculation Model",
                        prefixIcon: Icon(Icons.calculate),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'emi', child: Text("Reducing EMI")),
                        DropdownMenuItem(value: 'simple', child: Text("Flat Simple")),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _model = val);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Start Date Picker
              InkWell(
                borderRadius: BorderRadius.circular(FinTheme.radiusSmall),
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
                    color: isDark ? const Color(0xFF1A2332) : const Color(0xFFF0F2F6),
                    borderRadius: BorderRadius.circular(FinTheme.radiusSmall),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event, size: 20, color: FinTheme.primary),
                          const SizedBox(width: 12),
                          Text("Disbursement Date: ${DateFormat('dd MMM yyyy').format(_startDate)}"),
                        ],
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Notes / Collateral / Purpose",
                  prefixIcon: Icon(Icons.note),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    widget.loanToEdit != null ? "Update Loan" : "Create Loan Ledger",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
